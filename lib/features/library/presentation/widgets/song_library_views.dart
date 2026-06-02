import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../shared/widgets/album_art.dart';
import '../../data/cover_art_cache.dart';
import '../../domain/song.dart';

typedef SongSelected = void Function(Song song, int index);

class SongListView extends StatelessWidget {
  const SongListView({
    required this.songs,
    required this.onSongSelected,
    super.key,
  });

  final List<Song> songs;
  final SongSelected onSongSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      cacheExtent: 120,
      itemCount: songs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _SongListTile(
          song: songs[index],
          autofocus: index == 0,
          compact: false,
          onPressed: () => onSongSelected(songs[index], index),
        );
      },
    );
  }
}

class SongCompactView extends StatelessWidget {
  const SongCompactView({
    required this.songs,
    required this.onSongSelected,
    super.key,
  });

  final List<Song> songs;
  final SongSelected onSongSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      cacheExtent: 80,
      itemCount: songs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        return _SongListTile(
          song: songs[index],
          autofocus: index == 0,
          compact: true,
          onPressed: () => onSongSelected(songs[index], index),
        );
      },
    );
  }
}

class SongCardView extends StatelessWidget {
  const SongCardView({
    required this.songs,
    required this.onSongSelected,
    super.key,
  });

  final List<Song> songs;
  final SongSelected onSongSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      cacheExtent: 180,
      itemCount: songs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _SongWideCard(
          song: songs[index],
          autofocus: index == 0,
          onPressed: () => onSongSelected(songs[index], index),
        );
      },
    );
  }
}

class SongGridView extends StatelessWidget {
  const SongGridView({
    required this.songs,
    required this.onSongSelected,
    super.key,
  });

  final List<Song> songs;
  final SongSelected onSongSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 620
            ? 2
            : width < 980
                ? 3
                : width < 1320
                    ? 4
                    : 5;
        return GridView.builder(
          cacheExtent: 180,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.78,
          ),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            return _SongGridCard(
              song: songs[index],
              autofocus: index == 0,
              onPressed: () => onSongSelected(songs[index], index),
            );
          },
        );
      },
    );
  }
}

class _SongListTile extends StatelessWidget {
  const _SongListTile({
    required this.song,
    required this.autofocus,
    required this.compact,
    required this.onPressed,
  });

  final Song song;
  final bool autofocus;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = Color(song.accent);
    final colorScheme = Theme.of(context).colorScheme;
    final height = compact ? 54.0 : 92.0;

    return _FocusableSongSurface(
      autofocus: autofocus,
      accent: accent,
      compact: compact,
      onPressed: onPressed,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (!compact) ...[
              LazyAlbumArt(
                song: song,
                accent: accent,
                size: 64,
                borderRadius: 7,
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              flex: 3,
              child: _SongTitleBlock(song: song, compact: compact),
            ),
            if (!compact) ...[
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: Text(
                  song.album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.62),
                      ),
                ),
              ),
            ],
            const SizedBox(width: 14),
            _FormatBadge(label: song.format),
            const SizedBox(width: 14),
            Text(
              formatSongDuration(song.duration),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SongWideCard extends StatelessWidget {
  const _SongWideCard({
    required this.song,
    required this.autofocus,
    required this.onPressed,
  });

  final Song song;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = Color(song.accent);
    final colorScheme = Theme.of(context).colorScheme;

    return _FocusableSongSurface(
      autofocus: autofocus,
      accent: accent,
      compact: false,
      onPressed: onPressed,
      child: SizedBox(
        height: 142,
        child: Row(
          children: [
            LazyAlbumArt(song: song, accent: accent, size: 114, borderRadius: 8),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${song.artist} - ${song.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.68),
                        ),
                  ),
                  if (song.genre != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      song.genre!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 18),
            Text(
              formatSongDuration(song.duration),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SongGridCard extends StatelessWidget {
  const _SongGridCard({
    required this.song,
    required this.autofocus,
    required this.onPressed,
  });

  final Song song;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = Color(song.accent);

    return _FocusableSongSurface(
      autofocus: autofocus,
      accent: accent,
      compact: false,
      onPressed: onPressed,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: LazyAlbumArt(
                  song: song,
                  accent: accent,
                  borderRadius: 8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.64),
                ),
          ),
        ],
      ),
    );
  }
}

class _FocusableSongSurface extends StatelessWidget {
  const _FocusableSongSurface({
    required this.autofocus,
    required this.accent,
    required this.compact,
    required this.onPressed,
    required this.child,
    this.padding,
  });

  final bool autofocus;
  final Color accent;
  final bool compact;
  final VoidCallback onPressed;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FocusableActionDetector(
      autofocus: autofocus,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onPressed();
            return null;
          },
        ),
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: focused
                  ? accent.withValues(alpha: isDark ? 0.18 : 0.13)
                  : colorScheme.surfaceContainerHighest.withValues(
                      alpha: compact
                          ? (isDark ? 0.10 : 0.38)
                          : (isDark ? 0.18 : 0.62),
                    ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: focused
                    ? accent
                    : colorScheme.outlineVariant.withValues(
                        alpha: isDark ? 0.14 : 0.42,
                      ),
                width: focused ? 2 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onPressed,
              child: Padding(
                padding: padding ??
                    EdgeInsets.symmetric(
                      horizontal: compact ? 12 : 14,
                      vertical: compact ? 8 : 14,
                    ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SongTitleBlock extends StatelessWidget {
  const _SongTitleBlock({
    required this.song,
    required this.compact,
  });

  final Song song;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (compact
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.titleLarge)
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.68),
                ),
          ),
        ],
      ],
    );
  }
}

class LazyAlbumArt extends StatefulWidget {
  const LazyAlbumArt({
    required this.song,
    required this.accent,
    this.size,
    this.borderRadius = 8,
    super.key,
  });

  final Song song;
  final Color accent;
  final double? size;
  final double borderRadius;

  @override
  State<LazyAlbumArt> createState() => _LazyAlbumArtState();
}

class _LazyAlbumArtState extends State<LazyAlbumArt> {
  final CoverArtCache _coverArtCache = CoverArtCache();
  Uint8List? _coverArt;

  @override
  void initState() {
    super.initState();
    _loadCoverArt();
  }

  @override
  void didUpdateWidget(covariant LazyAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.path != widget.song.path) {
      _coverArt = null;
      _loadCoverArt();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlbumArt(
      accent: widget.accent,
      coverArt: _coverArt,
      size: widget.size,
      borderRadius: widget.borderRadius,
    );
  }

  Future<void> _loadCoverArt() async {
    final path = widget.song.path;
    final coverArt = await _coverArtCache.coverArtFor(widget.song);
    if (!mounted || path != widget.song.path) {
      return;
    }
    setState(() {
      _coverArt = coverArt;
    });
  }
}

class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.68),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface.withValues(alpha: 0.72),
              ),
        ),
      ),
    );
  }
}

String formatSongDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
