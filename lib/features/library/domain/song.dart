import 'dart:typed_data';

class Song {
  const Song({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.genre,
    this.coverArt,
  });

  final String path;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String? genre;
  final Uint8List? coverArt;

  Song copyWith({
    String? path,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? genre,
    Uint8List? coverArt,
  }) {
    return Song(
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      genre: genre ?? this.genre,
      coverArt: coverArt ?? this.coverArt,
    );
  }

  String get fileName {
    final segments = Uri.file(path).pathSegments;
    return segments.isEmpty ? path : segments.last;
  }

  String get format {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == path.length - 1) {
      return 'AUDIO';
    }
    return path.substring(dotIndex + 1).toUpperCase();
  }

  int get accent {
    final seed = path.hashCode.abs();
    const palette = [
      0xFF37C6A6,
      0xFF2A9DCC,
      0xFF4D7CFE,
      0xFFE05A78,
      0xFFF1C75B,
      0xFF8F7DF2,
    ];
    return palette[seed % palette.length];
  }
}
