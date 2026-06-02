import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../library/domain/song.dart';
import 'audio_backend.dart';

class AudioPlayerService {
  factory AudioPlayerService() {
    return _shared;
  }

  AudioPlayerService._()
      : _player = AudioBackend.isAvailable ? AudioPlayer() : null;

  static final AudioPlayerService _shared = AudioPlayerService._();

  final AudioPlayer? _player;
  final StreamController<Song> _currentSongController =
      StreamController<Song>.broadcast();

  List<Song> _queue = const [];
  int _currentIndex = 0;
  Song? _currentSong;
  bool _isDisposed = false;

  Stream<Duration> get positionStream =>
      _player?.positionStream ?? const Stream.empty();
  Stream<Duration?> get durationStream =>
      _player?.durationStream ?? const Stream.empty();
  Stream<bool> get playingStream =>
      _player?.playerStateStream
          .map(
            (state) =>
                state.playing &&
                state.processingState != ProcessingState.completed,
          )
          .distinct() ??
      const Stream.empty();
  Stream<Song> get currentSongStream => _currentSongController.stream;
  bool get isPlaying =>
      _player != null &&
      _player.playing &&
      _player.processingState != ProcessingState.completed;
  Song? get currentSong => _currentSong;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;

  bool hasQueueFor(List<Song> songs, int index) {
    if (_queue.length != songs.length || songs.isEmpty) {
      return false;
    }
    final normalizedIndex = index.clamp(0, songs.length - 1).toInt();
    return _currentIndex == normalizedIndex &&
        _currentSong?.path == songs[normalizedIndex].path;
  }

  Future<Duration?> loadQueue({
    required List<Song> songs,
    required int initialIndex,
    bool autoplay = false,
  }) async {
    final player = _requirePlayer();
    if (songs.isEmpty) {
      return null;
    }

    _queue = List.unmodifiable(songs);
    _currentIndex = initialIndex.clamp(0, songs.length - 1).toInt();
    return _loadCurrentSong(player, autoplay: autoplay);
  }

  Future<void> togglePlayPause() async {
    final player = _requirePlayer();
    if (isPlaying) {
      await player.pause();
    } else {
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
    }
  }

  Future<void> play() => _requirePlayer().play();

  Future<void> pause() => _requirePlayer().pause();

  Future<void> seekTo(Duration position) async {
    final player = _requirePlayer();
    final duration = player.duration;
    await player.seek(_clampPosition(position, duration));
  }

  Future<void> seekBy(Duration delta) async {
    final player = _requirePlayer();
    final duration = player.duration;
    await player.seek(_clampPosition(player.position + delta, duration));
  }

  Future<Duration?> next() async {
    final player = _requirePlayer();
    if (_queue.isEmpty) {
      return null;
    }

    _currentIndex = (_currentIndex + 1) % _queue.length;
    return _loadCurrentSong(player, autoplay: isPlaying);
  }

  Future<Duration?> previous() async {
    final player = _requirePlayer();
    if (_queue.isEmpty) {
      return null;
    }

    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    return _loadCurrentSong(player, autoplay: isPlaying);
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    await _currentSongController.close();
    await _player?.dispose();
  }

  AudioPlayer _requirePlayer() {
    if (_isDisposed) {
      throw StateError('El reproductor de audio ya fue cerrado.');
    }

    final player = _player;
    if (player == null) {
      throw StateError(
        'El backend de audio no esta disponible. En Linux instala libmpv.',
      );
    }
    return player;
  }

  Duration _clampPosition(Duration position, Duration? duration) {
    if (position < Duration.zero) {
      return Duration.zero;
    }

    final total = duration;
    if (total != null && total > Duration.zero && position > total) {
      return total;
    }

    return position;
  }

  Future<Duration?> _loadCurrentSong(
    AudioPlayer player, {
    required bool autoplay,
  }) async {
    final song = _queue[_currentIndex];
    _currentSong = song;
    _currentSongController.add(song);

    final duration = await player.setFilePath(song.path);
    if (autoplay) {
      await player.play();
    }
    return duration;
  }
}
