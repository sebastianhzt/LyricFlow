import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../library/domain/song.dart';

class LrclibLyricsClient {
  const LrclibLyricsClient({
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  static const _baseUrl = 'https://lrclib.net';
  static const _headers = {
    'User-Agent': 'LyricFlow/0.1.0 (https://github.com/local/lyricflow)',
    'Accept': 'application/json',
  };

  final http.Client? _httpClient;

  Future<String?> fetchSyncedLyrics(Song song) async {
    final client = _httpClient ?? http.Client();
    final closeClient = _httpClient == null;

    try {
      final exact = await _fetchExact(client, song);
      if (exact != null) {
        return exact;
      }
      return _searchBestMatch(client, song);
    } finally {
      if (closeClient) {
        client.close();
      }
    }
  }

  Future<String?> _fetchExact(http.Client client, Song song) async {
    final uri = Uri.parse('$_baseUrl/api/get').replace(
      queryParameters: {
        'track_name': song.title,
        'artist_name': song.artist,
        'album_name': song.album,
        if (song.duration > Duration.zero)
          'duration': song.duration.inSeconds.toString(),
      },
    );

    final response = await client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return null;
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return _syncedLyricsFrom(json);
  }

  Future<String?> _searchBestMatch(http.Client client, Song song) async {
    final uri = Uri.parse('$_baseUrl/api/search').replace(
      queryParameters: {
        'q': '${song.artist} ${song.title}',
      },
    );

    final response = await client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return null;
    }

    final json = jsonDecode(response.body);
    if (json is! List) {
      return null;
    }

    for (final item in json) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final syncedLyrics = _syncedLyricsFrom(item);
      if (syncedLyrics != null) {
        return syncedLyrics;
      }
    }

    return null;
  }

  String? _syncedLyricsFrom(Map<String, dynamic> json) {
    final syncedLyrics = json['syncedLyrics'];
    if (syncedLyrics is String && syncedLyrics.trim().isNotEmpty) {
      return syncedLyrics;
    }
    return null;
  }
}
