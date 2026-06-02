import '../domain/song.dart';

class SongSearchService {
  const SongSearchService();

  List<Song> filter(List<Song> songs, String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return songs;
    }

    final tokens = normalizedQuery.split(' ').where((part) => part.isNotEmpty);
    return songs.where((song) {
      final haystack = _normalize(
        [
          song.title,
          song.artist,
          song.album,
          song.genre,
          song.fileName,
          song.format,
          _formatDuration(song.duration),
        ].whereType<String>().join(' '),
      );

      return tokens.every(haystack.contains);
    }).toList(growable: false);
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) {
      return '';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds ${duration.inSeconds}s ${duration.inMinutes}m';
  }
}
