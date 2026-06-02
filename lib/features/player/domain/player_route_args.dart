import '../../library/domain/song.dart';

class PlayerRouteArgs {
  const PlayerRouteArgs({
    required this.songs,
    required this.initialIndex,
  });

  final List<Song> songs;
  final int initialIndex;
}
