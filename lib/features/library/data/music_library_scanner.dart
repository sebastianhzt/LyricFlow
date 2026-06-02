import 'dart:io';

import '../domain/song.dart';
import 'music_metadata_reader.dart';

class MusicLibraryScanner {
  const MusicLibraryScanner({
    this.metadataReader = const MusicMetadataReader(),
  });

  static const supportedExtensions = {'.flac', '.mp3', '.wav'};

  final MusicMetadataReader metadataReader;

  Future<List<Song>> scan(String folderPath) async {
    final root = Directory(folderPath);
    if (!await root.exists()) {
      throw const FileSystemException('La carpeta seleccionada no existe');
    }

    final songs = <Song>[];
    final entities = root.list(
      recursive: true,
      followLinks: false,
    );

    await for (final entity in entities) {
      if (entity is! File || !_isSupported(entity.path)) {
        continue;
      }

      songs.add(metadataReader.readSong(entity));
    }

    songs.sort((a, b) {
      final artistCompare = a.artist.compareTo(b.artist);
      if (artistCompare != 0) {
        return artistCompare;
      }
      final albumCompare = a.album.compareTo(b.album);
      if (albumCompare != 0) {
        return albumCompare;
      }
      return a.title.compareTo(b.title);
    });

    return songs;
  }

  bool _isSupported(String path) {
    final lower = path.toLowerCase();
    return supportedExtensions.any(lower.endsWith);
  }
}
