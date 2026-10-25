import 'package:flutter_test/flutter_test.dart';
import 'package:himnario_iump/features/hymns/domain/hymn.dart';
import 'package:himnario_iump/core/services/spanish_accent_engine.dart';
import 'package:himnario_iump/core/services/spanish_grammar_corrector.dart';

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
}
