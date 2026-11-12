import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:himnario_iump/features/home/presentation/home_screen.dart';
import 'package:himnario_iump/features/hymns/domain/hymn.dart';

class _StubAdminModeNotifier extends AdminModeNotifier {
  @override
  bool build() => false;
}

class _StubHymnsNotifier extends HymnsNotifier {
  _StubHymnsNotifier(super.collection);

  @override
  Future<List<Hymn>> build() async => [
        Hymn(
          id: 1,
          title: 'CANTO DE PRUEBA',
          toneNote: 'DO',
          beats: '4',
          timeSignature: '4/4',
          lyrics: 'Alabaré al Señor.',
          collection: collection,
        ),
      ];
}

void main() {
  testWidgets(
    'HomeScreen renderiza el buscador sin Hero ni opacidad oculta',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'local_custom_hymns': '[]'});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminModeProvider.overrideWith(_StubAdminModeNotifier.new),
            hymnsProvider('iump')
                .overrideWith(() => _StubHymnsNotifier('iump')),
            hymnsProvider('especiales')
                .overrideWith(() => _StubHymnsNotifier('especiales')),
            hymnsProvider('coros')
                .overrideWith(() => _StubHymnsNotifier('coros')),
            hymnsProvider('acordes')
                .overrideWith(() => _StubHymnsNotifier('acordes')),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      // Sin delay ni Hero: el buscador debe estar visible de inmediato en el primer frame tras el pump inicial
      await tester.pump();

      final searchFieldFinder =
          find.widgetWithText(TextField, 'Buscar por título, letra o número...');
      expect(searchFieldFinder, findsOneWidget);

      final heroSearchFinder = find.byWidgetPredicate(
        (widget) => widget is Hero && widget.tag == 'search-bar',
      );
      expect(heroSearchFinder, findsNothing);

      await tester.pumpAndSettle();
      expect(searchFieldFinder, findsOneWidget);
    },
  );
}

