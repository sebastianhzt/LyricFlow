import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import '../domain/song.dart';
import 'music_metadata_reader.dart';

class CoverArtCache {
  factory CoverArtCache() => _shared;

  CoverArtCache._();

  static final CoverArtCache _shared = CoverArtCache._();
  static const _maxEntries = 4;
  static const _maxBytes = 8 * 1024 * 1024;

  final MusicMetadataReader _metadataReader = const MusicMetadataReader();
  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  final Map<String, Future<Uint8List?>> _pending = {};
  int _cachedBytes = 0;

  Future<Uint8List?> coverArtFor(Song song) {
    final embedded = song.coverArt;
    if (embedded != null && embedded.isNotEmpty) {
      return Future.value(embedded);
    }

    final cached = _cache.remove(song.path);
    if (cached != null) {
      _cache[song.path] = cached;
      return Future.value(cached);
    }

    return _pending.putIfAbsent(song.path, () async {
      try {
        final coverArt = _metadataReader.readCoverArt(File(song.path));
        if (coverArt != null && coverArt.isNotEmpty) {
          _remember(song.path, coverArt);
        }
        return coverArt;
      } finally {
        _pending.remove(song.path);
      }
    });
  }

  void clear() {
    _cache.clear();
    _cachedBytes = 0;
  }

  void _remember(String path, Uint8List coverArt) {
    final bytes = coverArt.lengthInBytes;
    if (bytes > _maxBytes ~/ 2) {
      return;
    }

    final previous = _cache.remove(path);
    if (previous != null) {
      _cachedBytes -= previous.lengthInBytes;
    }

    _cache[path] = coverArt;
    _cachedBytes += bytes;

    while (_cache.length > _maxEntries || _cachedBytes > _maxBytes) {
      final oldestKey = _cache.keys.first;
      final oldest = _cache.remove(oldestKey);
      if (oldest == null) {
        break;
      }
      _cachedBytes -= oldest.lengthInBytes;
    }
  }
}
