import 'dart:io';

import '../../library/domain/song.dart';
import '../domain/lyric_line.dart';
import 'lrclib_lyrics_client.dart';
import 'lrc_parser.dart';

class LyricsRepository {
  const LyricsRepository({
    this.parser = const LrcParser(),
    this.remoteLyricsClient = const LrclibLyricsClient(),
  });

  final LrcParser parser;
  final LrclibLyricsClient remoteLyricsClient;

  Future<List<LyricLine>> loadForSong(Song song) async {
    for (final path in _candidatePaths(song)) {
      final lrcFile = File(path);
      if (!await lrcFile.exists()) {
        continue;
      }

      final content = await lrcFile.readAsString();
      return parser.parse(content);
    }

    final remoteLyrics = await remoteLyricsClient.fetchSyncedLyrics(song);
    if (remoteLyrics == null) {
      return const [];
    }

    await _cacheRemoteLyrics(song, remoteLyrics);
    return parser.parse(remoteLyrics);
  }

  Future<void> _cacheRemoteLyrics(Song song, String lyrics) async {
    try {
      final path = _candidatePaths(song).first;
      await File(path).writeAsString(lyrics);
    } catch (_) {
      // Lyrics can still be shown even when the music folder is read-only.
    }
  }

  Future<List<LyricLine>> loadLocalForSong(Song song) async {
    for (final path in _candidatePaths(song)) {
      final lrcFile = File(path);
      if (!await lrcFile.exists()) {
        continue;
      }

      final content = await lrcFile.readAsString();
      return parser.parse(content);
    }

    return const [];
  }

  List<String> _candidatePaths(Song song) {
    final songPath = song.path;
    final audioFile = File(songPath);
    final parent = audioFile.parent.path;
    final basePath = _withoutExtension(songPath);
    final sanitizedTitle = _sanitizeFileName(song.title);
    final sanitizedArtist = _sanitizeFileName(song.artist);

    return {
      '$basePath.lrc',
      if (sanitizedTitle.isNotEmpty) '$parent/$sanitizedTitle.lrc',
      if (sanitizedArtist.isNotEmpty && sanitizedTitle.isNotEmpty)
        '$parent/$sanitizedArtist - $sanitizedTitle.lrc',
      if (sanitizedArtist.isNotEmpty && sanitizedTitle.isNotEmpty)
        '$parent/$sanitizedTitle - $sanitizedArtist.lrc',
    }.toList();
  }

  String _withoutExtension(String songPath) {
    final dotIndex = songPath.lastIndexOf('.');
    if (dotIndex <= 0) {
      return songPath;
    }
    return songPath.substring(0, dotIndex);
  }

  String _sanitizeFileName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
