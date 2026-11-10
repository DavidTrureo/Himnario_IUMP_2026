import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:himnario_iump/features/hymns/domain/hymn.dart';
import 'package:himnario_iump/features/hymns/presentation/add_hymn_screen.dart';
import 'package:himnario_iump/features/hymns/presentation/scanner_result_screen.dart';
import 'package:himnario_iump/core/services/spanish_accent_engine.dart';
import 'package:himnario_iump/core/services/spanish_grammar_corrector.dart';

class _FakeAdminModeNotifier extends AdminModeNotifier {
  final bool initialValue;
  _FakeAdminModeNotifier(this.initialValue);

  @override
  bool build() => initialValue;
}

class _FakeHymnsNotifier extends HymnsNotifier {
  _FakeHymnsNotifier(super.collection);

  @override
  Future<List<Hymn>> build() async => const [];
}

void main() {
  group('Hymn Model Tests', () {
    test('Hymn parseToneComponents desglosa tono, métrica y compás correctamente', () {
      final parsed = Hymn.parseToneComponents('SOL / 3 TIEMPOS (3/4)');
      expect(parsed['toneNote'], 'SOL');
      expect(parsed['beats'], '3');
      expect(parsed['timeSignature'], '3/4');
    });

    test('Hymn normalización de búsqueda elimina acentos y puntuación', () {
      final hymn = Hymn(
        id: 1,
        title: '¡VEN, OH TODOPODEROSO!',
        toneNote: 'SOL',
        beats: '3 TIEMPOS',
        timeSignature: '3/4',
        lyrics: 'Padre Santo, cariñoso, manifiesta tu amor.',
        collection: 'iump',
      );

      expect(hymn.normalizedTitle, contains('ven oh todopoderoso'));
      expect(hymn.normalizedSearchableText, contains('padre santo'));
    });

    test('Hymn serialización toJson y fromJson', () {
      final jsonMap = {
        'id': 10,
        'title': 'GRANDE ES TU FIDELIDAD',
        'toneNote': 'RE',
        'beats': '3',
        'timeSignature': '3/4',
        'tone': 'RE / 3 TIEMPOS (3/4)',
        'lyrics': 'Oh Dios eterno, tu misericordia...',
        'collection': 'iump',
        'audioUrl': 'https://example.com/audio.mp3',
        'category': 'Adoración',
      };

      final hymn = Hymn.fromJson(jsonMap, 'iump');
      expect(hymn.id, 10);
      expect(hymn.title, 'GRANDE ES TU FIDELIDAD');
      expect(hymn.toneNote, 'RE');
      expect(hymn.category, 'Adoración');

      final serialized = hymn.toJson();
      expect(serialized['id'], 10);
      expect(serialized['title'], 'GRANDE ES TU FIDELIDAD');
    });
  });

  group('Spanish Accent Engine & Grammar Corrector Tests', () {
    test('SpanishAccentEngine.processWord corrige acentuación de palabras litúrgicas respetando casing', () {
      expect(SpanishAccentEngine.processWord('Jehova'), 'Jehová');
      expect(SpanishAccentEngine.processWord('Espiritu'), 'Espíritu');
      expect(SpanishAccentEngine.processWord('oracion'), 'oración');
      expect(SpanishAccentEngine.processWord('ORACION'), 'ORACIÓN');
    });

    test('SpanishGrammarCorrector.correctText formatea y corrige mayúsculas y tildes', () {
      final result = SpanishGrammarCorrector.correctText(
        title: 'dios de mi salvacion',
        lyrics: '1.\njesus me amo y se entrego por mi.\nel es mi pastor.',
      );

      expect(result.title, contains('SALVACIÓN'));
      expect(result.lyrics, contains('Jesús me amó'));
    });
  });

  group('Hymn Helpers & AddHymnScreen Widget Tests', () {
    test('findPossibleDuplicate detecta similitud y evita falsos positivos con cantos vacíos', () {
      final existing = [
        Hymn(
          id: 1,
          title: 'VACIO',
          toneNote: '',
          beats: '',
          timeSignature: '',
          lyrics: '',
          collection: 'iump',
        ),
        Hymn(
          id: 2,
          title: 'LA GRAN VICTORIA',
          toneNote: 'MI',
          beats: '3',
          timeSignature: '12/8',
          lyrics: 'Hijo no temas, yo soy el que habla contigo, vi tus lágrimas y escuché tus gemidos.',
          collection: 'especiales',
        ),
      ];

      expect(
        Hymn.findPossibleDuplicate('Hijo no temas, yo soy el que habla contigo, vi tus lágrimas y escuché tus gemidos.', existing)?.id,
        2,
      );
      expect(
        Hymn.findPossibleDuplicate('Un canto completamente distinto sobre la gracia divina del Señor.', existing),
        isNull,
      );
    });

    testWidgets('AddHymnScreen renderiza sin errores en Modo Admin y oculta Datos del Sugeridor', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminModeProvider.overrideWith(() => _FakeAdminModeNotifier(true)),
            hymnsProvider('iump').overrideWith(() => _FakeHymnsNotifier('iump')),
          ],
          child: const MaterialApp(
            home: AddHymnScreen(initialCollection: 'iump'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Publicar Nuevo Canto'), findsOneWidget);
      expect(find.text('Publicar Oficial'), findsOneWidget);
      expect(find.text('Sugerir Oficial'), findsNothing);
      expect(find.text('Datos del Sugeridor'), findsNothing);
      expect(find.text('Número del Himno (IUMP)'), findsOneWidget);
    });

    testWidgets('AddHymnScreen renderiza sin errores para Usuario normal con Datos del Sugeridor', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminModeProvider.overrideWith(() => _FakeAdminModeNotifier(false)),
            hymnsProvider('coros').overrideWith(() => _FakeHymnsNotifier('coros')),
          ],
          child: const MaterialApp(
            home: AddHymnScreen(initialCollection: 'coros'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Añadir Canto'), findsOneWidget);
      expect(find.text('Sugerir Oficial'), findsOneWidget);
      expect(find.text('Publicar Oficial'), findsNothing);
      expect(find.text('Datos del Sugeridor'), findsOneWidget);
    });

    testWidgets('ScannerResultScreen muestra Publicar Oficial para Admin', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminModeProvider.overrideWith(() => _FakeAdminModeNotifier(true)),
          ],
          child: const MaterialApp(
            home: ScannerResultScreen(
              initialData: {
                'title': 'Canto de Prueba',
                'key': 'SOL',
                'timeSignature': '4/4',
                'lyrics': '1.\nAlabaré a mi Dios.',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Publicar Oficial'), findsOneWidget);
      expect(find.text('Sugerir Oficial'), findsNothing);
    });
  });
}
