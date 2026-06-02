import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lyricflow/features/library/domain/song.dart';
import 'package:lyricflow/features/lyrics/data/lyrics_repository.dart';

void main() {
  test('loads lrc with the same basename as the song', () async {
    final directory = await Directory.systemTemp.createTemp('lyricflow_lrc_');
    addTearDown(() => directory.delete(recursive: true));

    final audio = File('${directory.path}/Bad.flac')..writeAsStringSync('');
    File('${directory.path}/Bad.lrc').writeAsStringSync('[00:01.00]Bad');

    final lines = await const LyricsRepository().loadForSong(
      Song(
        path: audio.path,
        title: 'Bad',
        artist: 'Michael Jackson',
        album: 'Bad',
        duration: const Duration(minutes: 4),
      ),
    );

    expect(lines.single.text, 'Bad');
  });

  test('loads lrc named as artist dash title', () async {
    final directory = await Directory.systemTemp.createTemp('lyricflow_lrc_');
    addTearDown(() => directory.delete(recursive: true));

    final audio = File('${directory.path}/track01.mp3')..writeAsStringSync('');
    File('${directory.path}/Michael Jackson - Bad.lrc')
        .writeAsStringSync('[00:02.00]Your butt is mine');

    final lines = await const LyricsRepository().loadForSong(
      Song(
        path: audio.path,
        title: 'Bad',
        artist: 'Michael Jackson',
        album: 'Bad',
        duration: const Duration(minutes: 4),
      ),
    );

    expect(lines.single.timestamp, const Duration(seconds: 2));
  });
}
