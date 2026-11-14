import 'package:flutter_test/flutter_test.dart';

class ParsedSegment {
  final List<String> chords;
  final String textUnder;
  ParsedSegment(this.chords, this.textUnder);
}

class ParsedLine {
  final String textBefore;
  final List<ParsedSegment> segments;
  ParsedLine(this.textBefore, this.segments);
}

ParsedLine parseLineWithChords(String line) {
  final RegExp blockRegex = RegExp(r'((?:\[[^\]]+\]\s*)+)');
  final matches = blockRegex.allMatches(line).toList();

  if (matches.isEmpty) {
    return ParsedLine(line, []);
  }

  String textBefore = '';
  if (matches.first.start > 0) {
    textBefore = line.substring(0, matches.first.start);
  }

  final segments = <ParsedSegment>[];

  for (int i = 0; i < matches.length; i++) {
    final match = matches[i];
    final chordBlock = match.group(0)!;
    final chords = RegExp(r'\[([^\]]+)\]')
        .allMatches(chordBlock)
        .map((m) => m.group(1)!)
        .toList();

    final nextMatchStart = (i == matches.length - 1) ? line.length : matches[i + 1].start;
    final textUnder = line.substring(match.end, nextMatchStart);

    segments.add(ParsedSegment(chords, textUnder));
  }

  return ParsedLine(textBefore, segments);
}

void main() {
  test('Parses grouped chords correctly', () {
    final res1 = parseLineWithChords('¡Cuán [DOADD9] [LAM7] firme cimiento se ha dado a la fe,');
    expect(res1.textBefore, equals('¡Cuán '));
    expect(res1.segments.length, equals(1));
    expect(res1.segments[0].chords, equals(['DOADD9', 'LAM7']));
    expect(res1.segments[0].textUnder, equals('firme cimiento se ha dado a la fe,'));

    final res2 = parseLineWithChords('De Dios en su eterna Palabra [RE]de [DOM7(B5)]amor!');
    expect(res2.textBefore, equals('De Dios en su eterna Palabra '));
    expect(res2.segments.length, equals(2));
    expect(res2.segments[0].chords, equals(['RE']));
    expect(res2.segments[0].textUnder, equals('de '));
    expect(res2.segments[1].chords, equals(['DOM7(B5)']));
    expect(res2.segments[1].textUnder, equals('amor!'));
  });
}
