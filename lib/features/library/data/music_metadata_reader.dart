import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../domain/song.dart';

class MusicMetadataReader {
  const MusicMetadataReader();

  Song readSong(File file) {
    try {
      final metadata = readMetadata(file, getImage: false);
      return Song(
        path: file.path,
        title: _fallback(metadata.title, _fileNameWithoutExtension(file)),
        artist: _fallback(metadata.artist, 'Artista desconocido'),
        album: _fallback(metadata.album, 'Album desconocido'),
        duration: metadata.duration ?? Duration.zero,
        genre: _genreFrom(metadata),
      );
    } catch (_) {
      return Song(
        path: file.path,
        title: _fileNameWithoutExtension(file),
        artist: 'Artista desconocido',
        album: 'Album desconocido',
        duration: Duration.zero,
      );
    }
  }

  Uint8List? readCoverArt(File file) {
    try {
      final metadata = readMetadata(file, getImage: true);
      return _coverArtFrom(metadata);
    } catch (_) {
      return null;
    }
  }

  Uint8List? _coverArtFrom(AudioMetadata metadata) {
    if (metadata.pictures.isEmpty) {
      return null;
    }
    return metadata.pictures.first.bytes;
  }

  String? _genreFrom(AudioMetadata metadata) {
    final genres = metadata.genres
        .map((genre) => genre.trim())
        .where((genre) => genre.isNotEmpty)
        .toList(growable: false);
    if (genres.isEmpty) {
      return null;
    }
    return genres.join(', ');
  }

  String _fallback(String? value, String fallback) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return fallback;
    }
    return trimmed;
  }

  String _fileNameWithoutExtension(File file) {
    final name = file.uri.pathSegments.last;
    final extensionIndex = name.lastIndexOf('.');
    if (extensionIndex <= 0) {
      return name;
    }
    return name.substring(0, extensionIndex);
  }
}
