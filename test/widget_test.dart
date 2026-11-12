import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:himnario_iump/core/services/hymn_semantic_retriever.dart';
import 'package:himnario_iump/features/hymns/domain/hymn.dart';
import 'package:himnario_iump/features/hymns/presentation/add_hymn_screen.dart';
import 'package:himnario_iump/features/hymns/presentation/hymn_list_screen.dart';
import 'package:himnario_iump/features/hymns/presentation/scanner_result_screen.dart';
import 'package:himnario_iump/features/hymns/presentation/widgets/semantic_search_dialog.dart';
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

  group('HymnSemanticRetriever & SemanticSearchDialog Tests', () {
    test('cleanLyrics y buildCompactDigest eliminan acordes y estribillos repetidos', () {
      const rawLyrics = '''
[Estrofa 1]
[G]En medio de la [D]mar tempestuosa
[Em]Clamo a Jesús mi [C]Salvador fiel.

[Coro]
[G]Él calma la tempestad
[D]Su voz da tranquilidad.

[Coro]
[G]Él calma la tempestad
[D]Su voz da tranquilidad.
''';
      final cleaned = HymnSemanticRetriever.cleanLyrics(rawLyrics);
      expect(cleaned.contains('[G]'), isFalse);
      expect(cleaned.contains('[Coro]'), isFalse);
      expect(cleaned, contains('mar tempestuosa'));

      final hymn = Hymn(
        id: 1,
        title: 'VOZ EN LA TORMENTA',
        toneNote: 'SOL',
        beats: '4',
        timeSignature: '4/4',
        lyrics: rawLyrics,
        collection: 'iump',
      );
      final digest = HymnSemanticRetriever.buildCompactDigest(hymn, maxChars: 320);
      expect(digest, contains('mar tempestuosa'));
      // El estribillo idéntico solo aparece una vez tras deduplicación
      expect('calma la tempestad'.allMatches(digest).length, 1);
    });

    test('searchLocally devuelve hasta 10 en IUMP, menos de 10 sin relleno en Especiales y 0 en Coros', () {
      final catalog = <Hymn>[];

      // 14 himnos IUMP cuyo título NO dice tormenta pero su letra sí trata del mar/barca/tempestad
      for (int i = 1; i <= 14; i++) {
        catalog.add(
          Hymn(
            id: i,
            title: 'ALABANZA CONGREGACIONAL $i',
            toneNote: 'SOL',
            beats: '4',
            timeSignature: '4/4',
            lyrics: 'Cuando la barca tiembla en el mar tempestuoso y rugen las olas, Cristo calma la tempestad.',
            collection: 'iump',
          ),
        );
      }

      // 4 himnos IUMP totalmente no relacionados (NO deben entrar de relleno)
      for (int i = 100; i <= 103; i++) {
        catalog.add(
          Hymn(
            id: i,
            title: 'BODAS Y GRATITUD FAMILIAR $i',
            toneNote: 'DO',
            beats: '4',
            timeSignature: '4/4',
            lyrics: 'Damos gracias por el hogar bendecido y la mesa diaria en unidad familiar.',
            collection: 'iump',
          ),
        );
      }

      // 4 especiales afines + 5 especiales sin relación (solo deben salir 4, jamás 10 con relleno)
      for (int i = 1; i <= 4; i++) {
        catalog.add(
          Hymn(
            id: i,
            title: 'ESPECIAL DE CONFIANZA $i',
            toneNote: 'RE',
            beats: '4',
            timeSignature: '4/4',
            lyrics: 'Aunque la tormenta azote la barca, tengo un ancla segura en las aguas profundas.',
            collection: 'especiales',
          ),
        );
      }
      for (int i = 200; i <= 204; i++) {
        catalog.add(
          Hymn(
            id: i,
            title: 'HIMNO DE NAVIDAD $i',
            toneNote: 'FA',
            beats: '3',
            timeSignature: '3/4',
            lyrics: 'En un pesebre humilde nació en Belén el niño rey entre pastores.',
            collection: 'especiales',
          ),
        );
      }

      // 6 coros totalmente ajenos al tema de tempestad/barca (deben resultar 0 en Coros)
      for (int i = 1; i <= 6; i++) {
        catalog.add(
          Hymn(
            id: i,
            title: 'CORO DE PENTECOSTÉS $i',
            toneNote: 'MI',
            beats: '4',
            timeSignature: '4/4',
            lyrics: 'Fuego divino desciende en el aposento alto como viento recio.',
            collection: 'coros',
          ),
        );
      }

      final result = HymnSemanticRetriever.searchLocally(
        query: 'el mar tempestuoso, las olas y Jesús calmando la tormenta en la barca',
        catalog: catalog,
        allowedCollections: const {'iump', 'especiales', 'coros'},
        searchMode: 'conceptual',
      );

      final collections =
          result['collections'] as Map<String, Map<String, dynamic>>;

      final iumpMatches = collections['iump']!['matches'] as List;
      final especialesMatches = collections['especiales']!['matches'] as List;
      final corosMatches = collections['coros']!['matches'] as List;

      expect(iumpMatches.length, 10);
      expect(especialesMatches.length, 4);
      expect(corosMatches.length, 0);
      expect(
        collections['especiales']!['noMoreReason'].toString(),
        contains('las 4 alabanzas especiales'),
      );
      expect(
        collections['coros']!['noMoreReason'].toString(),
        contains('No hallamos coros en Coros de Avivamiento'),
      );
    });

    testWidgets(
      'SemanticSearchDialog muestra pestañas 10 / <10 / 0 y mensajes descriptivos sin relleno',
      (tester) async {
        final catalog = <Hymn>[
          for (int i = 1; i <= 10; i++)
            Hymn(
              id: i,
              title: 'SALMO CANTADO $i',
              toneNote: 'DO',
              beats: '4',
              timeSignature: '4/4',
              lyrics: 'Jehová es mi pastor, nada me faltará en delicados pastos.',
              collection: 'iump',
            ),
          for (int i = 1; i <= 3; i++)
            Hymn(
              id: i,
              title: 'ESPECIAL PASTORAL $i',
              toneNote: 'SOL',
              beats: '4',
              timeSignature: '4/4',
              lyrics: 'Aunque ande en valle de sombra de muerte no temeré.',
              collection: 'especiales',
            ),
        ];

        Future<Map<String, dynamic>> fakeExecutor({
          required BuildContext context,
          required String query,
          required List<Hymn> catalog,
          Set<String>? allowedCollections,
          String searchMode = 'biblical',
        }) async {
          final iumpMatches = catalog
              .where((h) => h.collection == 'iump')
              .map((h) => {
                    'hymn': h,
                    'relevanceReason': 'Reafirma la guía del Buen Pastor del Salmo 23.',
                    'worshipMoment': 'Sellar la Predicación',
                    'relevanceLevel': 'directa',
                  })
              .toList();
          final espMatches = catalog
              .where((h) => h.collection == 'especiales')
              .map((h) => {
                    'hymn': h,
                    'relevanceReason': 'Aborda la paz en medio del valle oscuro.',
                    'worshipMoment': 'Oración de Fe',
                    'relevanceLevel': 'alta',
                  })
              .toList();

          return {
            'summary': 'Cantos sobre el cuidado fiel del Buen Pastor.',
            'biblicalPassage': 'Salmo 23:1-4',
            'biblicalContext': 'Dios guía y fortalece en el valle de prueba.',
            'spiritualTone': 'Consuelo y Esperanza',
            'keywords': const ['pastor', 'confianza'],
            'fromCache': false,
            'isLocalFallback': false,
            'quotaReached': false,
            'matches': [...iumpMatches, ...espMatches],
            'collections': {
              'iump': {
                'matches': iumpMatches,
                'noMoreReason': 'Mostrando los 10 más certeros.',
              },
              'especiales': {
                'matches': espMatches,
                'noMoreReason':
                    'Solo 3 alabanzas especiales de la base guardan relación teológica directa con Salmo 23.',
              },
              'coros': {
                'matches': const <Map<String, dynamic>>[],
                'noMoreReason':
                    'No se encontraron cantos en Coros de Avivamiento directamente vinculados al Salmo 23 sin forzar coincidencias.',
              },
            },
          };
        }

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              allHymnsGlobalProvider.overrideWithValue(AsyncValue.data(catalog)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SemanticSearchDialog(
                  initialQuery: 'Salmo 23 Jehová es mi pastor',
                  defaultMode: 'biblical',
                  searchExecutor: fakeExecutor,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('ai_collection_tab_iump')), findsOneWidget);
        expect(find.byKey(const ValueKey('ai_collection_tab_especiales')), findsOneWidget);
        expect(find.byKey(const ValueKey('ai_collection_tab_coros')), findsOneWidget);
        expect(find.text('10'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);

        final resultsScrollable = find.descendant(
          of: find.byKey(const ValueKey('ai_results_listview')),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('SALMO CANTADO 1'),
          150,
          scrollable: resultsScrollable,
        );
        expect(find.text('SALMO CANTADO 1'), findsOneWidget);

        // Cambiar a Especiales (< 10 resultados con explicación UX)
        await tester.tap(find.byKey(const ValueKey('ai_collection_tab_especiales')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('ESPECIAL PASTORAL 1'),
          150,
          scrollable: resultsScrollable,
        );
        expect(find.text('ESPECIAL PASTORAL 1'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.textContaining('Solo 3 alabanzas especiales de la base'),
          150,
          scrollable: resultsScrollable,
        );
        expect(
          find.textContaining('Solo 3 alabanzas especiales de la base'),
          findsOneWidget,
        );

        // Cambiar a Coros (0 resultados con mensaje vacío descriptivo + accesos rápidos)
        await tester.tap(find.byKey(const ValueKey('ai_collection_tab_coros')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Sin coincidencias en Coros de Avivamiento'),
          150,
          scrollable: resultsScrollable,
        );
        expect(
          find.text('Sin coincidencias en Coros de Avivamiento'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.textContaining('#pastor'),
          150,
          scrollable: resultsScrollable,
        );
        expect(
          find.textContaining('No se encontraron cantos en Coros de Avivamiento'),
          findsOneWidget,
        );
        expect(find.textContaining('#pastor'), findsOneWidget);
      },
    );
  });
}
