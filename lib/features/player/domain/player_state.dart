import '../../library/domain/song.dart';

class PlayerState {
  const PlayerState({
    required this.track,
    required this.position,
    required this.isPlaying,
  });

  final Song track;
  final Duration position;
  final bool isPlaying;

  double get progress {
    final total = track.duration.inMilliseconds;
    if (total == 0) {
      return 0;
    }
    return position.inMilliseconds / total;
  }

  PlayerState copyWith({
    Song? track,
    Duration? position,
    bool? isPlaying,
  }) {
    return PlayerState(
      track: track ?? this.track,
      position: position ?? this.position,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}
