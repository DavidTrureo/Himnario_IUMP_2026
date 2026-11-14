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

  const GlobalAudioState({
    this.hymn,
    this.isPlaying = false,
    this.isLoading = false,
    this.isLooping = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isVisible = false,
  });

  GlobalAudioState copyWith({
    Hymn? hymn,
    bool? isPlaying,
    bool? isLoading,
    bool? isLooping,
    Duration? position,
    Duration? duration,
    bool? isVisible,
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
    );
  }
}

class GlobalAudioNotifier extends Notifier<GlobalAudioState> {
  static AudioPlayer? _globalAudioPlayerInstance;

  /// Detiene y limpia globalmente cualquier reproducción activa
  static void stopActiveGlobalAudio() {
    final p = _globalAudioPlayerInstance;
    if (p != null) {
      try {
        p.stop();
        p.dispose();
      } catch (_) {}
      _globalAudioPlayerInstance = null;
    }
  }

  AudioPlayer? _player;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  String? _currentAudioUrl;

  @override
  GlobalAudioState build() {
    ref.onDispose(() {
      _cleanupSubscriptions();
      _player?.dispose();
      _player = null;
      _globalAudioPlayerInstance = null;
    });
    return const GlobalAudioState();
  }

  void _cleanupSubscriptions() {
    _playerStateSub?.cancel();
    _playerStateSub = null;
    _durationSub?.cancel();
    _durationSub = null;
    _positionSub?.cancel();
    _positionSub = null;
  }

  Future<String> _getLocalAudioPath(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    final hash = url.hashCode.toString();
    String ext = 'mp3';
    try {
      final uri = Uri.parse(url);
      final decodedPath = Uri.decodeComponent(uri.path);
      if (decodedPath.contains('.')) {
        final possibleExt = decodedPath.split('.').last.toLowerCase();
        if (['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'].contains(possibleExt)) {
          ext = possibleExt;
        }
      }
    } catch (_) {}
    return '${dir.path}/hymn_audio_$hash.$ext';
  }

  Future<void> playHymn(Hymn hymn) async {
    if (hymn.audioUrl.trim().isEmpty) return;

    final url = hymn.audioUrl.trim();

    // Si es el mismo canto y misma URL y ya tenemos reproductor cargado
    if (_player != null && _currentAudioUrl == url && state.hymn?.id == hymn.id && state.hymn?.collection == hymn.collection) {
      state = state.copyWith(isVisible: true);
      if (state.isPlaying) {
        await pause();
      } else {
        await resume();
      }
      return;
    }

    // Nuevo canto o diferente URL: detener anterior inmediatamente (nunca solapar audios)
    await _stopPlayerOnly();

    state = state.copyWith(
      hymn: hymn,
      isLoading: true,
      isPlaying: false,
      isVisible: true,
      position: Duration.zero,
      duration: Duration.zero,
    );

    try {
      final player = AudioPlayer();
      _player = player;
      _globalAudioPlayerInstance = player;
      _currentAudioUrl = url;

      if (state.isLooping) {
        await player.setLoopMode(LoopMode.one);
      }

      if (kIsWeb) {
        await player.setUrl(url);
      } else {
        final localPath = await _getLocalAudioPath(url);
        final file = File(localPath);
        if (await file.exists()) {
          debugPrint('>>> [GlobalAudio] Reproduciendo desde caché local: $localPath');
          await player.setFilePath(localPath);
        } else {
          try {
            final audioSource = LockCachingAudioSource(Uri.parse(url));
            await player.setAudioSource(audioSource);
          } catch (e) {
            debugPrint('>>> [GlobalAudio] Fallback AudioSource.uri: $e');
            await player.setAudioSource(AudioSource.uri(Uri.parse(url)));
          }
        }
      }

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

      _positionSub = player.positionStream.listen((p) {
        state = state.copyWith(position: p);
      });

      state = state.copyWith(isLoading: false);
      await player.play();
    } catch (e) {
      debugPrint('>>> [GlobalAudio] Error al reproducir audio: $e');
      await stopAndClose();
    }
  }

  Future<void> pause() async {
    try {
      await _player?.pause();
    } catch (_) {}
    state = state.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    try {
      await _player?.play();
      state = state.copyWith(isPlaying: true, isVisible: true);
    } catch (_) {}
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

  Future<void> _stopPlayerOnly() async {
    _cleanupSubscriptions();
    final p = _player;
    if (p != null) {
      try {
        await p.stop();
        await p.dispose();
      } catch (_) {}
    }
    _player = null;
    _currentAudioUrl = null;
    _globalAudioPlayerInstance = null;
  }

  Future<void> stopAndClose() async {
    await _stopPlayerOnly();
    state = const GlobalAudioState();
  }
}

final globalAudioProvider =
    NotifierProvider<GlobalAudioNotifier, GlobalAudioState>(
  GlobalAudioNotifier.new,
);

