import 'package:flutter_test/flutter_test.dart';

String normalizeEmbeddedChords(String line) {
  if (!line.contains('[')) return line;

  // Divide respetando los espacios
  final tokens = line.split(RegExp(r'(?<=\s)|(?=\s)'));
  final newTokens = <String>[];

  for (final token in tokens) {
    if (token.contains('[') && token.contains(']')) {
      final parts = token.split(RegExp(r'(?=\[)|(?<=\])'));
      final chords = <String>[];
      final nonChords = <String>[];

      for (final p in parts) {
        if (p.startsWith('[') && p.endsWith(']')) {
          chords.add(p);
        } else if (p.isNotEmpty) {
          nonChords.add(p);
        }
      }

      final textLetters = nonChords.join();
      final firstChordPos = token.indexOf('[');
      final hasLettersBeforeChord = firstChordPos > 0 &&
          token.substring(0, firstChordPos).contains(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ0-9]'));

      if (hasLettersBeforeChord && textLetters.contains(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ0-9]'))) {
        final matchLeading = RegExp(r'^([¡¿"\(]+)(.*)$').firstMatch(textLetters);
        String leadingPunct = '';
        String coreText = textLetters;
        if (matchLeading != null) {
          leadingPunct = matchLeading.group(1)!;
          coreText = matchLeading.group(2)!;
        }

        if (chords.length == 1) {
          newTokens.add('$leadingPunct${chords.first}$coreText');
        } else {
          newTokens.add('$leadingPunct${chords.join(' ')} $coreText');
        }
      } else {
        newTokens.add(token);
      }
    } else {
      newTokens.add(token);
    }
  }

  return newTokens.join();
}

void main() {
  test('Normalizes embedded chords correctly', () {
    expect(
      normalizeEmbeddedChords('¡Cuán f[DOADD9]irm[LAM7]e cimiento se ha dado a la fe,'),
      equals('¡Cuán [DOADD9] [LAM7] firme cimiento se ha dado a la fe,'),
    );
    expect(
      normalizeEmbeddedChords('De Dios en su eterna Palabra d[RE]e am[DOM7(B5)]or!'),
      equals('De Dios en su eterna Palabra [RE]de [DOM7(B5)]amor!'),
    );
    expect(
      normalizeEmbeddedChords('cora[DO]zón de amor'),
      equals('[DO]corazón de amor'),
    );
    expect(
      normalizeEmbeddedChords('¡cora[DO]zón!'),
      equals('¡[DO]corazón!'),
    );
    expect(
      normalizeEmbeddedChords('[DO]Señor [FA]mi Dios'),
      equals('[DO]Señor [FA]mi Dios'),
    );
    expect(
      normalizeEmbeddedChords('Señor [DO] mi Dios'),
      equals('Señor [DO] mi Dios'),
    );
  });
}
