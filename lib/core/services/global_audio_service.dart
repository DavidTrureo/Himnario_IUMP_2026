import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/hymns/domain/hymn.dart';

class GlobalAudioState {
  final Hymn? hymn;
  final bool isPlaying;
  final bool isLoading;
  final bool isLooping;
  final Duration position;
  final Duration duration;
  final bool isVisible;
  final String? errorMessage;

  const GlobalAudioState({
    this.hymn,
    this.isPlaying = false,
    this.isLoading = false,
    this.isLooping = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isVisible = false,
    this.errorMessage,
  });

  GlobalAudioState copyWith({
    Hymn? hymn,
    bool? isPlaying,
    bool? isLoading,
    bool? isLooping,
    Duration? position,
    Duration? duration,
    bool? isVisible,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool clearHymn = false,
  }) {
    return GlobalAudioState(
      hymn: clearHymn ? null : (hymn ?? this.hymn),
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      isLooping: isLooping ?? this.isLooping,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isVisible: isVisible ?? this.isVisible,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class GlobalAudioNotifier extends Notifier<GlobalAudioState> {
  static AudioPlayer? _persistentPlayerInstance;

  /// Detiene y limpia globalmente cualquier reproducción activa
  static void stopActiveGlobalAudio() {
    final p = _persistentPlayerInstance;
    if (p != null) {
      try {
        p.stop();
      } catch (_) {}
    }
  }

  AudioPlayer? _player;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  String? _currentAudioUrl;
  Duration _lastEmittedPos = Duration.zero;
  int _activeSessionId = 0;

  @override
  GlobalAudioState build() {
    ref.onDispose(() {
      _cleanup();
    });
    return const GlobalAudioState();
  }

  void _cleanup() {
    _cleanupSubscriptions();
    try {
      _player?.stop();
      _player?.dispose();
    } catch (_) {}
    _player = null;
    _persistentPlayerInstance = null;
  }

  void _cleanupSubscriptions() {
    _playerStateSub?.cancel();
    _playerStateSub = null;
    _durationSub?.cancel();
    _durationSub = null;
    _positionSub?.cancel();
    _positionSub = null;
  }

  /// Inicializa de forma perezosa una ÚNICA instancia persistente de AudioPlayer
  /// para evitar saturar los canales de hardware nativos de Android/iOS (AudioTrack limit en Android OS).
  AudioPlayer _getOrCreatePlayer() {
    if (_player != null) return _player!;

    final player = AudioPlayer();
    _player = player;
    _persistentPlayerInstance = player;

    _cleanupSubscriptions();

    _playerStateSub = player.playerStateStream.listen((ps) {
      final playing = ps.playing;
      final loading = ps.processingState == ProcessingState.loading ||
          ps.processingState == ProcessingState.buffering;

      if (ps.processingState == ProcessingState.completed) {
        if (state.isLooping) {
          player.seek(Duration.zero);
          player.play();
        } else {
          player.pause();
          player.seek(Duration.zero);
          state = state.copyWith(isPlaying: false, position: Duration.zero);
        }
      } else {
        state = state.copyWith(isPlaying: playing, isLoading: loading);
      }
    });

    _durationSub = player.durationStream.listen((d) {
      if (d != null) {
        state = state.copyWith(duration: d);
      }
    });

    _lastEmittedPos = Duration.zero;
    _positionSub = player.positionStream.listen((p) {
      // Throttling a 500ms para mantener el scroll a 120 FPS
      if ((p - _lastEmittedPos).abs() >= const Duration(milliseconds: 500) ||
          p == Duration.zero) {
        _lastEmittedPos = p;
        state = state.copyWith(position: p);
      }
    });

    return player;
  }

  Future<String> _getLocalAudioPath(String url) async {
    if (kIsWeb) return '';
    try {
      final dir = await getApplicationDocumentsDirectory();
      final hash = url.hashCode.toString();
      String ext = 'mp3';
      final uri = Uri.parse(url);
      final decodedPath = Uri.decodeComponent(uri.path);
      if (decodedPath.contains('.')) {
        final possibleExt = decodedPath.split('.').last.toLowerCase();
        if (['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'].contains(possibleExt)) {
          ext = possibleExt;
        }
      }
      return '${dir.path}/hymn_audio_$hash.$ext';
    } catch (_) {
      return '';
    }
  }

  Future<void> playHymn(Hymn hymn) async {
    if (hymn.audioUrl.trim().isEmpty) return;

    final url = hymn.audioUrl.trim();

    // 1. Si es exactamente el mismo canto y URL, simplemente alternar play/pause
    if (_player != null &&
        _currentAudioUrl == url &&
        state.hymn?.id == hymn.id &&
        state.hymn?.collection == hymn.collection) {
      state = state.copyWith(isVisible: true);
      if (state.isPlaying) {
        await pause();
      } else {
        await resume();
      }
      return;
    }

    // 2. Token de sesión incremental: invalida en seco cualquier solicitud previa que siga volando
    final currentSession = ++_activeSessionId;

    // 3. Notificar inmediatamente a la UI del nuevo canto y poner en estado de carga
    state = state.copyWith(
      hymn: hymn,
      isLoading: true,
      isPlaying: false,
      isVisible: true,
      position: Duration.zero,
      duration: Duration.zero,
      clearErrorMessage: true,
    );

    try {
      final player = _getOrCreatePlayer();

      // Detener audio anterior en el mismo reproductor sin destruirlo ni matar los canales nativos
      await player.stop();

      // Si el usuario ya tocó otro canto mientras se detenía el anterior, abortar de inmediato
      if (_activeSessionId != currentSession) return;

      _currentAudioUrl = url;

      if (state.isLooping) {
        await player.setLoopMode(LoopMode.one);
      }

      if (_activeSessionId != currentSession) return;

      // 4. Carga segura del audio (Local vs Streaming Directo) con timeout de seguridad
      if (kIsWeb) {
        await player.setUrl(url).timeout(const Duration(seconds: 14));
      } else {
        final localPath = await _getLocalAudioPath(url);
        final file = localPath.isNotEmpty ? File(localPath) : null;
        if (file != null && await file.exists()) {
          debugPrint(
              '>>> [GlobalAudio] Reproduciendo desde caché local: $localPath');
          await player.setFilePath(localPath);
        } else {
          // Streaming progresivo directo nativo: ExoPlayer y AVPlayer manejan buffers
          // nativos en memoria y disco mucho mejor y sin los bloqueos de archivo de LockCachingAudioSource
          debugPrint(
              '>>> [GlobalAudio] Streaming directo nativo desde URL: $url');
          await player
              .setAudioSource(
                AudioSource.uri(Uri.parse(url)),
                preload: true,
              )
              .timeout(const Duration(seconds: 14));
        }
      }

      // Si otra solicitud superó a esta durante la conexión de red, descartar en silencio
      if (_activeSessionId != currentSession) return;

      state = state.copyWith(isLoading: false);
      await player.play();
    } on TimeoutException {
      if (_activeSessionId == currentSession) {
        debugPrint('>>> [GlobalAudio] Timeout al conectar con el audio');
        state = state.copyWith(
          isLoading: false,
          isPlaying: false,
          errorMessage: 'Tiempo de espera agotado al cargar audio',
        );
      }
    } catch (e) {
      if (_activeSessionId == currentSession) {
        debugPrint('>>> [GlobalAudio] Error al reproducir audio: $e');
        state = state.copyWith(
          isLoading: false,
          isPlaying: false,
          errorMessage: 'Error al reproducir audio',
        );
      }
    }
  }

  Future<void> pause() async {
    try {
      await _player?.pause();
    } catch (_) {}
    state = state.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    if (state.hymn != null &&
        (_currentAudioUrl == null || _player?.audioSource == null)) {
      await playHymn(state.hymn!);
      return;
    }
    try {
      await _player?.play();
      state = state.copyWith(isPlaying: true, isVisible: true);
    } catch (_) {
      if (state.hymn != null) {
        await playHymn(state.hymn!);
      }
    }
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration pos) async {
    try {
      await _player?.seek(pos);
      _lastEmittedPos = pos;
      state = state.copyWith(position: pos);
    } catch (_) {}
  }

  Future<void> seekRelative(Duration delta) async {
    final current = state.position;
    final total = state.duration;
    var target = current + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (total > Duration.zero && target > total) target = total;
    await seek(target);
  }

  Future<void> toggleLoop() async {
    final newLoop = !state.isLooping;
    state = state.copyWith(isLooping: newLoop);
    try {
      await _player?.setLoopMode(newLoop ? LoopMode.one : LoopMode.off);
    } catch (_) {}
  }

  Future<void> stopAndClose() async {
    _activeSessionId++; // Invalida cualquier solicitud en curso
    _currentAudioUrl = null;
    try {
      await _player?.stop();
    } catch (_) {}
    state = const GlobalAudioState();
  }
}

final globalAudioProvider =
    NotifierProvider<GlobalAudioNotifier, GlobalAudioState>(
  GlobalAudioNotifier.new,
);

/// Señal ligera para indicar a HymnDetailScreen que salte de inmediato al canto en reproducción
/// (útil si el usuario deslizó a otro himno dentro del PageView y luego tocó el mini-reproductor).
class JumpToPlayingHymnSignalNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state = state + 1;
}

final jumpToPlayingHymnSignalProvider =
    NotifierProvider<JumpToPlayingHymnSignalNotifier, int>(
  JumpToPlayingHymnSignalNotifier.new,
);
