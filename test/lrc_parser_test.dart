import 'package:flutter_test/flutter_test.dart';
import 'package:lyricflow/features/lyrics/data/lrc_parser.dart';

void main() {
  test('parses timestamped lyric lines', () {
    final lines = const LrcParser().parse('''
[00:01.50]First line
[00:03.250]Second line
''');

    expect(lines, hasLength(2));
    expect(lines.first.timestamp, const Duration(milliseconds: 1500));
    expect(lines.first.text, 'First line');
    expect(lines.last.timestamp, const Duration(milliseconds: 3250));
  });

  test('supports multiple timestamps for the same lyric text', () {
    final lines = const LrcParser().parse('[00:01.00][00:02.00]Echo');

    expect(lines, hasLength(2));
    expect(lines[0].timestamp, const Duration(seconds: 1));
    expect(lines[1].timestamp, const Duration(seconds: 2));
    expect(lines[0].text, 'Echo');
    expect(lines[1].text, 'Echo');
  });
}
