import '../domain/lyric_line.dart';

class LrcParser {
  const LrcParser();

  static final _timestampPattern = RegExp(
    r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]',
  );

  List<LyricLine> parse(String source) {
    final lines = <LyricLine>[];

    for (final rawLine in source.split(RegExp(r'\r?\n'))) {
      final matches = _timestampPattern.allMatches(rawLine).toList();
      if (matches.isEmpty) {
        continue;
      }

      final text = rawLine.replaceAll(_timestampPattern, '').trim();
      if (text.isEmpty) {
        continue;
      }

      for (final match in matches) {
        final timestamp = _timestampFrom(match);
        if (timestamp == null) {
          continue;
        }
        lines.add(LyricLine(timestamp: timestamp, text: text));
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  Duration? _timestampFrom(RegExpMatch match) {
    final minutes = int.tryParse(match.group(1) ?? '');
    final seconds = int.tryParse(match.group(2) ?? '');
    final fraction = match.group(3);
    if (minutes == null || seconds == null) {
      return null;
    }

    final milliseconds = switch (fraction?.length) {
      1 => int.parse(fraction!) * 100,
      2 => int.parse(fraction!) * 10,
      3 => int.parse(fraction!),
      _ => 0,
    };

    return Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }
}
