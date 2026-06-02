import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_routes.dart';
import '../../../player/data/audio_player_service.dart';
import '../../../player/domain/player_route_args.dart';
import '../../domain/song.dart';
import 'song_library_views.dart';

class LibraryMiniPlayer extends StatefulWidget {
  const LibraryMiniPlayer({super.key});

  @override
  State<LibraryMiniPlayer> createState() => _LibraryMiniPlayerState();
}

class _LibraryMiniPlayerState extends State<LibraryMiniPlayer> {
  final AudioPlayerService _audioPlayerService = AudioPlayerService();

  StreamSubscription<Song>? _songSubscription;
  StreamSubscription<bool>? _playingSubscription;
  Song? _song;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _song = _audioPlayerService.currentSong;
    _isPlaying = _audioPlayerService.isPlaying;
    _songSubscription = _audioPlayerService.currentSongStream.listen((song) {
      if (!mounted) {
        return;
      }
      setState(() => _song = song);
    });
    _playingSubscription = _audioPlayerService.playingStream.listen((playing) {
      if (!mounted) {
        return;
      }
      setState(() => _isPlaying = playing);
    });
  }

  @override
  void dispose() {
    _songSubscription?.cancel();
    _playingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = _song;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: song == null
          ? const SizedBox.shrink(key: ValueKey('no-mini-player'))
          : Padding(
              key: ValueKey(song.path),
              padding: const EdgeInsets.only(top: 18),
              child: _MiniPlayerSurface(
                song: song,
                isPlaying: _isPlaying,
                onOpen: _openNowPlaying,
                onPrevious: () => unawaited(_run(_audioPlayerService.previous)),
                onTogglePlayback: () => unawaited(
                  _run(_audioPlayerService.togglePlayPause),
                ),
                onNext: () => unawaited(_run(_audioPlayerService.next)),
              ),
            ),
    );
  }

  Future<void> _run(Future<dynamic> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('LyricFlow mini player error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _openNowPlaying() {
    final queue = _audioPlayerService.queue;
    if (queue.isEmpty) {
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.nowPlaying,
      arguments: PlayerRouteArgs(
        songs: queue,
        initialIndex: _audioPlayerService.currentIndex,
      ),
    );
  }
}

class _MiniPlayerSurface extends StatelessWidget {
  const _MiniPlayerSurface({
    required this.song,
    required this.isPlaying,
    required this.onOpen,
    required this.onPrevious,
    required this.onTogglePlayback,
    required this.onNext,
  });

  final Song song;
  final bool isPlaying;
  final VoidCallback onOpen;
  final VoidCallback onPrevious;
  final VoidCallback onTogglePlayback;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final accent = Color(song.accent);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.32 : 0.74,
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              LazyAlbumArt(
                song: song,
                accent: accent,
                size: 58,
                borderRadius: 7,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${song.artist} - ${song.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.66),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Anterior',
                onPressed: onPrevious,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              IconButton.filled(
                tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                style: IconButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: onTogglePlayback,
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
              IconButton(
                tooltip: 'Siguiente',
                onPressed: onNext,
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
