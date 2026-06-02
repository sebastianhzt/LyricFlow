import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/app_routes.dart';
import '../../../shared/widgets/album_art.dart';
import '../../../shared/widgets/theme_mode_button.dart';
import '../../gamepad/input_shortcuts.dart';
import '../../lyrics/data/lyrics_repository.dart';
import '../../lyrics/domain/lyric_line.dart';
import '../../lyrics/presentation/lyrics_view.dart';
import '../../library/data/cover_art_cache.dart';
import '../../library/domain/song.dart';
import '../data/audio_player_service.dart';
import '../data/cover_accent_extractor.dart';
import '../domain/player_route_args.dart';
import '../domain/player_state.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  static const routeName = AppRoutes.nowPlaying;

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  static const _seekStep = Duration(seconds: 5);
  static const _seekRepeatThrottle = Duration(milliseconds: 110);

  final CoverAccentExtractor _coverAccentExtractor =
      const CoverAccentExtractor();
  final CoverArtCache _coverArtCache = CoverArtCache();
  final LyricsRepository _lyricsRepository = const LyricsRepository();
  final AudioPlayerService _audioPlayerService = AudioPlayerService();

  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Song>? _currentSongSubscription;
  late final Stream<Duration> _positionStream;
  late final Stream<bool> _playingStream;

  late PlayerState player;
  List<LyricLine> _lyrics = const [];
  Color? _coverAccent;
  String? _loadedQueueKey;
  DateTime? _lastRepeatedSeekAt;
  bool _isLoadingLyrics = false;
  bool _useCoverBackdrop = true;
  bool _showLyrics = true;

  @override
  void initState() {
    super.initState();
    _positionStream = _audioPlayerService.positionStream;
    _playingStream = _audioPlayerService.playingStream;
    _durationSubscription = _audioPlayerService.durationStream.listen(
      _handleDurationChanged,
    );
    _playingSubscription = _playingStream.listen(
      _handlePlayingChanged,
    );
    _currentSongSubscription = _audioPlayerService.currentSongStream.listen(
      _handleSongChanged,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final argument = ModalRoute.of(context)?.settings.arguments;
    final (routeSongs, initialIndex) = switch (argument) {
      PlayerRouteArgs(:final songs, :final initialIndex) => (
          songs,
          initialIndex,
        ),
      Song song => (
          [song],
          0,
        ),
      _ => (
          const [
            Song(
              path: '',
              title: 'Sin cancion',
              artist: 'Artista desconocido',
              album: 'Album desconocido',
              duration: Duration.zero,
            ),
          ],
          0,
        ),
    };

    final songs = routeSongs.isEmpty
        ? const [
            Song(
              path: '',
              title: 'Sin cancion',
              artist: 'Artista desconocido',
              album: 'Album desconocido',
              duration: Duration.zero,
            ),
          ]
        : routeSongs;
    final index = initialIndex.clamp(0, songs.length - 1).toInt();
    final track = songs[index];
    final queueKey = '${songs.length}|$index|${track.path}';
    if (_loadedQueueKey == queueKey) {
      return;
    }
    _loadedQueueKey = queueKey;
    player = PlayerState(
      track: track,
      position: Duration.zero,
      isPlaying: false,
    );
    unawaited(_loadAudioQueue(songs: songs, initialIndex: index));
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _currentSongSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _coverAccent ?? Color(player.track.accent);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        !isDark && !_useCoverBackdrop ? const Color(0xFF101820) : Colors.white;
    final topButtonStyle = IconButton.styleFrom(
      foregroundColor: foreground,
      backgroundColor: foreground.withValues(alpha: isDark ? 0.14 : 0.16),
    );

    return AppShortcuts(
      onTogglePlayback: _togglePlayback,
      onSeekBackward: () => _seekBy(-_seekStep, throttle: true),
      onSeekForward: () => _seekBy(_seekStep, throttle: true),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: _BlurredBackdrop(
                accent: accent,
                coverArt: _useCoverBackdrop ? player.track.coverArt : null,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          autofocus: true,
                          tooltip: 'Volver',
                          onPressed: () => Navigator.of(context).pop(),
                          style: topButtonStyle,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          tooltip: _useCoverBackdrop
                              ? 'Fondo abstracto'
                              : 'Fondo con caratula',
                          onPressed: _toggleBackdropMode,
                          style: topButtonStyle,
                          icon: Icon(
                            _useCoverBackdrop
                                ? Icons.gradient_rounded
                                : Icons.image_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          tooltip:
                              _showLyrics ? 'Ocultar letras' : 'Mostrar letras',
                          onPressed: _toggleLyricsVisibility,
                          style: topButtonStyle,
                          icon: Icon(
                            _showLyrics
                                ? Icons.subtitles_off_rounded
                                : Icons.subtitles_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ThemeModeButton(style: topButtonStyle),
                      ],
                    ),
                    Expanded(
                      child: _CenteredNowPlaying(
                        player: player,
                        accent: accent,
                        lyrics: _lyrics,
                        positionStream: _positionStream,
                        playingStream: _playingStream,
                        showLyrics: _showLyrics,
                        foreground: foreground,
                        isLoadingLyrics: _isLoadingLyrics,
                        onTogglePlayback: _togglePlayback,
                        onPrevious: _playPrevious,
                        onNext: _playNext,
                        onSeekTo: _seekTo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePlayback() {
    unawaited(_runAudioAction(_audioPlayerService.togglePlayPause));
  }

  void _playPrevious() {
    unawaited(_runAudioAction(() => _audioPlayerService.previous()));
  }

  void _playNext() {
    unawaited(_runAudioAction(() => _audioPlayerService.next()));
  }

  void _seekTo(Duration position) {
    unawaited(_runAudioAction(() => _audioPlayerService.seekTo(position)));
  }

  void _seekBy(Duration delta, {bool throttle = false}) {
    if (throttle && !_canRunRepeatedSeek()) {
      return;
    }
    unawaited(_runAudioAction(() => _audioPlayerService.seekBy(delta)));
  }

  void _toggleBackdropMode() {
    setState(() {
      _useCoverBackdrop = !_useCoverBackdrop;
    });
  }

  void _toggleLyricsVisibility() {
    setState(() {
      _showLyrics = !_showLyrics;
    });
  }

  Future<void> _loadLyrics(Song song) async {
    setState(() {
      _isLoadingLyrics = true;
      _lyrics = const [];
    });

    final lyrics = await _lyricsRepository.loadForSong(song);
    if (!mounted || song.path != player.track.path) {
      return;
    }
    setState(() {
      _lyrics = lyrics;
      _isLoadingLyrics = false;
    });
  }

  Future<void> _loadAudioQueue({
    required List<Song> songs,
    required int initialIndex,
  }) async {
    await _runAudioAction(() async {
      if (_audioPlayerService.hasQueueFor(songs, initialIndex)) {
        final song = _audioPlayerService.currentSong;
        if (song != null) {
          _handleSongChanged(song);
        }
        return;
      }

      final duration = await _audioPlayerService.loadQueue(
        songs: songs,
        initialIndex: initialIndex,
        autoplay: true,
      );
      if (!mounted || duration == null) {
        return;
      }
      setState(() {
        player = player.copyWith(
          track: player.track.copyWith(duration: duration),
        );
      });
    });
  }

  Future<void> _runAudioAction(Future<dynamic> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('LyricFlow audio error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool _canRunRepeatedSeek() {
    final now = DateTime.now();
    final last = _lastRepeatedSeekAt;
    if (last != null && now.difference(last) < _seekRepeatThrottle) {
      return false;
    }

    _lastRepeatedSeekAt = now;
    return true;
  }

  void _handleSongChanged(Song song) {
    if (!mounted) {
      return;
    }
    setState(() {
      player = PlayerState(
        track: song,
        position: Duration.zero,
        isPlaying: _audioPlayerService.isPlaying,
      );
    });
    unawaited(_loadLyrics(song));
    unawaited(_loadSongArtwork(song));
  }

  Future<void> _loadSongArtwork(Song song) async {
    setState(() {
      _coverAccent = null;
    });

    final coverArt = await _coverArtCache.coverArtFor(song);
    final accent = await _coverAccentExtractor.extract(coverArt);
    if (!mounted || song.path != player.track.path) {
      return;
    }

    setState(() {
      _coverAccent = accent;
      if (coverArt != null) {
        player = player.copyWith(
          track: player.track.copyWith(coverArt: coverArt),
        );
      }
    });
  }

  void _handleDurationChanged(Duration? duration) {
    if (!mounted || duration == null) {
      return;
    }
    setState(() {
      player = player.copyWith(
        track: player.track.copyWith(duration: duration),
      );
    });
  }

  void _handlePlayingChanged(bool isPlaying) {
    if (!mounted) {
      return;
    }
    setState(() {
      player = player.copyWith(isPlaying: isPlaying);
    });
  }
}

class _BlurredBackdrop extends StatelessWidget {
  const _BlurredBackdrop({
    required this.accent,
    required this.coverArt,
  });

  final Color accent;
  final Uint8List? coverArt;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textOverlay =
        coverArt == null && !isDark ? Colors.white : Colors.black;
    final textOverlayStrength = coverArt == null && !isDark ? 0.0 : 1.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 520),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: coverArt == null
              ? _AbstractBackdrop(
                  key: const ValueKey('abstract-backdrop'),
                  accent: accent,
                  isDark: isDark,
                )
              : _CoverBackdrop(
                  key: const ValueKey('cover-backdrop'),
                  coverArt: coverArt!,
                  accent: accent,
                  isDark: isDark,
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                textOverlay.withValues(
                  alpha: (isDark ? 0.16 : 0.18) * textOverlayStrength,
                ),
                textOverlay.withValues(
                  alpha: (isDark ? 0.42 : 0.36) * textOverlayStrength,
                ),
                textOverlay.withValues(
                  alpha: (isDark ? 0.74 : 0.58) * textOverlayStrength,
                ),
              ],
            ),
          ),
        ),
        ColoredBox(
          color: Colors.black.withValues(
            alpha: (isDark ? 0.08 : 0.06) * textOverlayStrength,
          ),
        ),
      ],
    );
  }
}

class _AbstractBackdrop extends StatelessWidget {
  const _AbstractBackdrop({
    required this.accent,
    required this.isDark,
    super.key,
  });

  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _VisualizerBackdrop(
      accent: accent,
      isDark: isDark,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.55, -0.35),
            radius: 1.2,
            colors: [
              accent.withValues(alpha: isDark ? 0.72 : 0.24),
              isDark ? const Color(0xFF171A20) : const Color(0xFFF3F8FF),
              isDark ? const Color(0xFF07080A) : const Color(0xFFE4EEF8),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverBackdrop extends StatelessWidget {
  const _CoverBackdrop({
    required this.coverArt,
    required this.accent,
    required this.isDark,
    super.key,
  });

  final Uint8List coverArt;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final decodeWidth = _decodeWidthFor(context, constraints.biggest);
        return Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Transform.scale(
                scale: 1.05,
                child: Image.memory(
                  coverArt,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  cacheWidth: decodeWidth,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.15, -0.22),
                  radius: 0.95,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.05 : 0.04),
                    accent.withValues(alpha: isDark ? 0.26 : 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            ColoredBox(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.28),
            ),
          ],
        );
      },
    );
  }

  int _decodeWidthFor(BuildContext context, Size size) {
    final width = size.width.isFinite && size.width > 0 ? size.width : 1280.0;
    final devicePixels = width * MediaQuery.devicePixelRatioOf(context);
    return devicePixels.clamp(1600, 2600).round();
  }
}

class _VisualizerBackdrop extends StatefulWidget {
  const _VisualizerBackdrop({
    required this.accent,
    required this.isDark,
    required this.child,
  });

  final Color accent;
  final bool isDark;
  final Widget child;

  @override
  State<_VisualizerBackdrop> createState() => _VisualizerBackdropState();
}

class _VisualizerBackdropState extends State<_VisualizerBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 19),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _VisualizerPainter(
                  progress: _controller.value,
                  accent: widget.accent,
                  isDark: widget.isDark,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  const _VisualizerPainter({
    required this.progress,
    required this.accent,
    required this.isDark,
  });

  final double progress;
  final Color accent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = accent.withValues(alpha: isDark ? 0.16 : 0.18);

    final circlePaint = Paint()..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final circles = [
      (
        base: const Offset(0.18, 0.28),
        radius: 86.0,
        speed: 1.0,
        phase: 0.0,
      ),
      (
        base: const Offset(0.78, 0.22),
        radius: 118.0,
        speed: 0.72,
        phase: 1.8,
      ),
      (
        base: const Offset(0.62, 0.74),
        radius: 96.0,
        speed: 0.86,
        phase: 3.1,
      ),
      (
        base: const Offset(0.3, 0.82),
        radius: 64.0,
        speed: 1.18,
        phase: 4.4,
      ),
    ];

    for (final circle in circles) {
      final phase = (progress * 6.28318 * circle.speed) + circle.phase;
      final center = Offset(
        (circle.base.dx * size.width) + (sin(phase) * size.width * 0.035),
        (circle.base.dy * size.height) +
            (cos(phase * 0.86) * size.height * 0.05),
      );
      final radius = circle.radius * (0.82 + (0.18 * sin(phase + 0.7).abs()));
      circlePaint.color = accent.withValues(alpha: isDark ? 0.065 : 0.105);
      ringPaint.color = accent.withValues(alpha: isDark ? 0.12 : 0.16);
      canvas
        ..drawCircle(center, radius, circlePaint)
        ..drawCircle(center, radius * 1.18, ringPaint);
    }

    final centerY = size.height * 0.56;
    final spacing = size.width / 18;
    for (var i = 0; i < 20; i++) {
      final x = (i - 1) * spacing;
      final phase = (progress * 6.28318) + (i * 0.72);
      final height = size.height * (0.08 + (0.09 * (0.5 + 0.5 * sin(phase))));
      canvas.drawLine(
        Offset(x, centerY - height),
        Offset(x, centerY + height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.isDark != isDark;
  }
}

class _CenteredNowPlaying extends StatelessWidget {
  const _CenteredNowPlaying({
    required this.player,
    required this.accent,
    required this.lyrics,
    required this.positionStream,
    required this.playingStream,
    required this.showLyrics,
    required this.foreground,
    required this.isLoadingLyrics,
    required this.onTogglePlayback,
    required this.onPrevious,
    required this.onNext,
    required this.onSeekTo,
  });

  final PlayerState player;
  final Color accent;
  final List<LyricLine> lyrics;
  final Stream<Duration> positionStream;
  final Stream<bool> playingStream;
  final bool showLyrics;
  final Color foreground;
  final bool isLoadingLyrics;
  final VoidCallback onTogglePlayback;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<Duration> onSeekTo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final compactHeight = constraints.maxHeight < 760;
        final tightHeight = constraints.maxHeight < 660;
        final artMax = !showLyrics
            ? (tightHeight ? 330.0 : 500.0)
            : (tightHeight ? 300.0 : (compactHeight ? 340.0 : 460.0));
        final artMin = !showLyrics
            ? (tightHeight ? 240.0 : 300.0)
            : (tightHeight ? 210.0 : (compactHeight ? 235.0 : 260.0));
        final artBase = wide
            ? constraints.maxWidth *
                (!showLyrics ? 0.29 : (compactHeight ? 0.24 : 0.28))
            : constraints.biggest.shortestSide;
        final artSize = artBase.clamp(artMin, artMax).toDouble();
        final summary = _NowPlayingSummary(
          player: player,
          accent: accent,
          positionStream: positionStream,
          artSize: artSize,
          compactHeight: compactHeight,
          tvMode: !showLyrics,
          foreground: foreground,
          onTogglePlayback: onTogglePlayback,
          onPrevious: onPrevious,
          onNext: onNext,
          onSeekTo: onSeekTo,
        );

        if (wide) {
          return _AnimatedWideNowPlayingLayout(
            showLyrics: showLyrics,
            compactHeight: compactHeight,
            summary: summary,
            lyrics: lyrics,
            positionStream: positionStream,
            playingStream: playingStream,
            foreground: foreground,
            isLoadingLyrics: isLoadingLyrics,
            onSeekTo: onSeekTo,
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 560),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.965, end: 1).animate(curved),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.025),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              ),
            );
          },
          child: showLyrics
              ? _LyricsNowPlayingLayout(
                  key: const ValueKey('with-lyrics'),
                  compactHeight: compactHeight,
                  summary: summary,
                  lyrics: lyrics,
                  positionStream: positionStream,
                  playingStream: playingStream,
                  foreground: foreground,
                  isLoadingLyrics: isLoadingLyrics,
                  onSeekTo: onSeekTo,
                )
              : Center(
                  key: const ValueKey('tv-mode'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: summary,
                  ),
                ),
        );
      },
    );
  }
}

class _LyricsNowPlayingLayout extends StatelessWidget {
  const _LyricsNowPlayingLayout({
    required this.compactHeight,
    required this.summary,
    required this.lyrics,
    required this.positionStream,
    required this.playingStream,
    required this.foreground,
    required this.isLoadingLyrics,
    required this.onSeekTo,
    super.key,
  });

  final bool compactHeight;
  final Widget summary;
  final List<LyricLine> lyrics;
  final Stream<Duration> positionStream;
  final Stream<bool> playingStream;
  final Color foreground;
  final bool isLoadingLyrics;
  final ValueChanged<Duration> onSeekTo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              summary,
              const SizedBox(height: 34),
              SizedBox(
                height: 360,
                child: LyricsView(
                  lines: lyrics,
                  positionStream: positionStream,
                  playingStream: playingStream,
                  foreground: foreground,
                  onSeekToLine: onSeekTo,
                  isLoading: isLoadingLyrics,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedWideNowPlayingLayout extends StatelessWidget {
  const _AnimatedWideNowPlayingLayout({
    required this.showLyrics,
    required this.compactHeight,
    required this.summary,
    required this.lyrics,
    required this.positionStream,
    required this.playingStream,
    required this.foreground,
    required this.isLoadingLyrics,
    required this.onSeekTo,
  });

  final bool showLyrics;
  final bool compactHeight;
  final Widget summary;
  final List<LyricLine> lyrics;
  final Stream<Duration> positionStream;
  final Stream<bool> playingStream;
  final Color foreground;
  final bool isLoadingLyrics;
  final ValueChanged<Duration> onSeekTo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = compactHeight ? 28.0 : 44.0;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: showLyrics ? 1 : 0),
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) {
            final maxWidth = constraints.maxWidth;
            final summaryLeftWidth = ((maxWidth - gap) * 0.45).clamp(
              360.0,
              maxWidth,
            );
            final summaryCenterWidth = min(820.0, maxWidth);
            final summaryWidth =
                lerpDouble(summaryCenterWidth, summaryLeftWidth, t)!;
            final summaryLeft = lerpDouble(
              (maxWidth - summaryCenterWidth) / 2,
              0,
              t,
            )!;
            final lyricsLeft = summaryLeftWidth + gap;
            final lyricsWidth = max(0.0, maxWidth - lyricsLeft);

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: summaryLeft,
                  top: 0,
                  bottom: 0,
                  width: summaryWidth,
                  child: summary,
                ),
                Positioned(
                  left: lyricsLeft,
                  top: 0,
                  bottom: 0,
                  width: lyricsWidth,
                  child: IgnorePointer(
                    ignoring: t < 0.98,
                    child: Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(28 * (1 - t), 0),
                        child: LyricsView(
                          lines: lyrics,
                          positionStream: positionStream,
                          playingStream: playingStream,
                          foreground: foreground,
                          onSeekToLine: onSeekTo,
                          isLoading: isLoadingLyrics,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _NowPlayingSummary extends StatelessWidget {
  const _NowPlayingSummary({
    required this.player,
    required this.accent,
    required this.positionStream,
    required this.artSize,
    required this.compactHeight,
    required this.tvMode,
    required this.foreground,
    required this.onTogglePlayback,
    required this.onPrevious,
    required this.onNext,
    required this.onSeekTo,
  });

  final PlayerState player;
  final Color accent;
  final Stream<Duration> positionStream;
  final double artSize;
  final bool compactHeight;
  final bool tvMode;
  final Color foreground;
  final VoidCallback onTogglePlayback;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<Duration> onSeekTo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tvMode ? 760 : 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: artSize,
                child: AlbumArt(
                  accent: accent,
                  coverArt: player.track.coverArt,
                  borderRadius: compactHeight ? 18 : 24,
                ),
              ),
              SizedBox(height: compactHeight ? 24 : 34),
              _TrackDetails(
                player: player,
                accent: accent,
                positionStream: positionStream,
                compactHeight: compactHeight,
                tvMode: tvMode,
                foreground: foreground,
                onTogglePlayback: onTogglePlayback,
                onPrevious: onPrevious,
                onNext: onNext,
                onSeekTo: onSeekTo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackDetails extends StatelessWidget {
  const _TrackDetails({
    required this.player,
    required this.accent,
    required this.positionStream,
    required this.compactHeight,
    required this.tvMode,
    required this.foreground,
    required this.onTogglePlayback,
    required this.onPrevious,
    required this.onNext,
    required this.onSeekTo,
  });

  final PlayerState player;
  final Color accent;
  final Stream<Duration> positionStream;
  final bool compactHeight;
  final bool tvMode;
  final Color foreground;
  final VoidCallback onTogglePlayback;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<Duration> onSeekTo;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          player.track.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: tvMode
                    ? (compactHeight ? 38 : 48)
                    : (compactHeight ? 34 : 46),
                color: foreground,
                height: 1.02,
              ),
        ),
        SizedBox(height: compactHeight ? 8 : 12),
        Text(
          player.track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: foreground.withValues(alpha: 0.74),
                fontSize: tvMode
                    ? (compactHeight ? 24 : 30)
                    : (compactHeight ? 20 : 25),
              ),
        ),
        SizedBox(height: compactHeight ? 5 : 8),
        Text(
          '${player.track.album} - ${player.track.format}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: foreground.withValues(alpha: 0.56),
              ),
        ),
        SizedBox(height: compactHeight ? 18 : 32),
        _ProgressBar(
          player: player,
          accent: accent,
          positionStream: positionStream,
          compactHeight: compactHeight,
          foreground: foreground,
          onSeekTo: onSeekTo,
        ),
        SizedBox(height: compactHeight ? 16 : 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              tooltip: 'Anterior',
              onPressed: onPrevious,
              style: _secondaryControlStyle(context, accent),
              iconSize: compactHeight ? 28 : 34,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            SizedBox(width: compactHeight ? 10 : 16),
            IconButton.filled(
              tooltip: player.isPlaying ? 'Pausar' : 'Reproducir',
              onPressed: onTogglePlayback,
              style: _primaryControlStyle(context, accent),
              iconSize: compactHeight ? 36 : 44,
              icon: Icon(
                player.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
            SizedBox(width: compactHeight ? 10 : 16),
            IconButton.filledTonal(
              tooltip: 'Siguiente',
              onPressed: onNext,
              style: _secondaryControlStyle(context, accent),
              iconSize: compactHeight ? 28 : 34,
              icon: const Icon(Icons.skip_next_rounded),
            ),
          ],
        ),
      ],
    );
  }

  ButtonStyle _primaryControlStyle(BuildContext context, Color accent) {
    return IconButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: _foregroundFor(accent),
    );
  }

  ButtonStyle _secondaryControlStyle(BuildContext context, Color accent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton.styleFrom(
      backgroundColor: accent.withValues(alpha: isDark ? 0.18 : 0.14),
      foregroundColor: accent,
    );
  }

  Color _foregroundFor(Color background) {
    return background.computeLuminance() > 0.48 ? Colors.black : Colors.white;
  }
}

class _ProgressBar extends StatefulWidget {
  const _ProgressBar({
    required this.player,
    required this.accent,
    required this.positionStream,
    required this.compactHeight,
    required this.foreground,
    required this.onSeekTo,
  });

  final PlayerState player;
  final Color accent;
  final Stream<Duration> positionStream;
  final bool compactHeight;
  final Color foreground;
  final ValueChanged<Duration> onSeekTo;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  static const _minimumDigitalScrub = Duration(seconds: 1);
  static const _maximumDigitalScrub = Duration(seconds: 10);

  Duration? _previewPosition;
  bool _isSeeking = false;
  bool _isEditMode = false;
  bool _isFocused = false;
  int _seekSession = 0;
  DateTime? _lastScrubAt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<Duration>(
      stream: widget.positionStream,
      initialData: Duration.zero,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = widget.player.track.duration;
        final total = duration.inMilliseconds;
        final displayPosition = _isEditMode
            ? (_previewPosition ?? position)
            : _clampPosition(position, duration);
        final progress =
            total == 0 ? 0.0 : displayPosition.inMilliseconds / total;
        final canSeek = total > 0;

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              FocusableActionDetector(
                enabled: canSeek,
                onShowFocusHighlight: (focused) {
                  if (_isFocused != focused) {
                    setState(() => _isFocused = focused);
                  }
                },
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      _toggleEditMode(position);
                      return null;
                    },
                  ),
                  SeekBackwardIntent: CallbackAction<SeekBackwardIntent>(
                    onInvoke: (_) {
                      return _scrubDigitally(-1, position);
                    },
                  ),
                  SeekForwardIntent: CallbackAction<SeekForwardIntent>(
                    onInvoke: (_) {
                      return _scrubDigitally(1, position);
                    },
                  ),
                  ScrubIntent: CallbackAction<ScrubIntent>(
                    onInvoke: (intent) {
                      return _scrubAnalog(intent.amount, position);
                    },
                  ),
                  MoveFocusIntent: CallbackAction<MoveFocusIntent>(
                    onInvoke: (intent) {
                      if (!_isEditMode) {
                        return null;
                      }
                      if (intent.direction == TraversalDirection.left) {
                        return _scrubDigitally(-1, position);
                      }
                      if (intent.direction == TraversalDirection.right) {
                        return _scrubDigitally(1, position);
                      }
                      return null;
                    },
                  ),
                  BackIntent: CallbackAction<BackIntent>(
                    onInvoke: (_) {
                      if (!_isEditMode) {
                        return null;
                      }
                      _cancelEditMode();
                      return true;
                    },
                  ),
                },
                child: SizedBox(
                  height: widget.compactHeight ? 34 : 38,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: canSeek
                        ? (details) =>
                            _seekFromLocalPosition(details.localPosition)
                        : null,
                    onHorizontalDragStart: canSeek
                        ? (details) => _updatePreview(details.localPosition)
                        : null,
                    onHorizontalDragUpdate: canSeek
                        ? (details) => _updatePreview(details.localPosition)
                        : null,
                    onHorizontalDragEnd:
                        canSeek ? (_) => _commitPreview() : null,
                    onHorizontalDragCancel: _hidePreview,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _SeekBarTrack(
                          accent: widget.accent,
                          backgroundColor:
                              colorScheme.onSurface.withValues(alpha: 0.14),
                          progress: progress.clamp(0.0, 1.0).toDouble(),
                          focused: _isFocused,
                          showIndicator: _isSeeking || _isEditMode,
                          indicatorLabel: _formatDuration(displayPosition),
                          compactHeight: widget.compactHeight,
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: widget.compactHeight ? 2 : 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: TextStyle(
                      color: widget.foreground.withValues(alpha: 0.86),
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: widget.foreground.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _seekFromLocalPosition(Offset localPosition) {
    _updatePreview(localPosition);
    _commitPreview();
  }

  void _updatePreview(Offset localPosition) {
    final box = context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 0;
    final duration = widget.player.track.duration;
    if (width <= 0 || duration <= Duration.zero) {
      return;
    }

    final progress = (localPosition.dx / width).clamp(0.0, 1.0);
    final position = Duration(
      milliseconds: (duration.inMilliseconds * progress).round(),
    );

    setState(() {
      _previewPosition = position;
      _isSeeking = true;
      _seekSession++;
    });
  }

  void _commitPreview() {
    final position = _previewPosition;
    if (position == null) {
      return;
    }
    widget.onSeekTo(position);
    _isEditMode = false;
    _hidePreviewDelayed();
  }

  void _hidePreview() {
    if (!mounted) {
      return;
    }
    setState(() {
      _previewPosition = null;
      _isSeeking = false;
      _isEditMode = false;
    });
  }

  void _toggleEditMode(Duration currentPosition) {
    if (_isEditMode) {
      _commitPreview();
      return;
    }

    setState(() {
      _previewPosition = currentPosition;
      _isSeeking = true;
      _isEditMode = true;
      _seekSession++;
    });
  }

  void _cancelEditMode() {
    _hidePreview();
  }

  Object? _scrubDigitally(int direction, Duration currentPosition) {
    if (!_isEditMode) {
      return null;
    }

    _nudgePreview(_digitalStep() * direction, currentPosition);
    return true;
  }

  Object? _scrubAnalog(double amount, Duration currentPosition) {
    if (!_isEditMode) {
      return null;
    }

    final strength = amount.abs().clamp(0.0, 1.0);
    final duration = widget.player.track.duration;
    if (duration <= Duration.zero) {
      return true;
    }

    final minStep = duration.inMilliseconds * 0.001;
    final maxStep = duration.inMilliseconds * 0.045;
    final shaped = strength * strength;
    final stepMs = minStep + ((maxStep - minStep) * shaped);
    final delta = Duration(
      milliseconds: (stepMs * amount.sign).round(),
    );
    _nudgePreview(delta, currentPosition);
    return true;
  }

  Duration _digitalStep() {
    final now = DateTime.now();
    final last = _lastScrubAt;
    _lastScrubAt = now;

    final duration = widget.player.track.duration;
    final baseMs = (duration.inMilliseconds * 0.004).round();
    final repeatedQuickly = last != null &&
        now.difference(last) < const Duration(milliseconds: 320);
    final acceleratedMs = repeatedQuickly ? baseMs * 2 : baseMs;

    return Duration(
      milliseconds: acceleratedMs.clamp(
        _minimumDigitalScrub.inMilliseconds,
        _maximumDigitalScrub.inMilliseconds,
      ),
    );
  }

  void _nudgePreview(Duration delta, Duration currentPosition) {
    if (!_isEditMode) {
      return;
    }

    final duration = widget.player.track.duration;
    final base = _previewPosition ?? currentPosition;
    final target = _clampPosition(base + delta, duration);
    setState(() {
      _previewPosition = target;
      _isSeeking = true;
      _seekSession++;
    });
  }

  Duration _clampPosition(Duration position, Duration duration) {
    if (position < Duration.zero) {
      return Duration.zero;
    }
    if (duration > Duration.zero && position > duration) {
      return duration;
    }
    return position;
  }

  void _hidePreviewDelayed() {
    final session = _seekSession;
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted && session == _seekSession) {
        _hidePreview();
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _SeekBarTrack extends StatelessWidget {
  const _SeekBarTrack({
    required this.accent,
    required this.backgroundColor,
    required this.progress,
    required this.focused,
    required this.showIndicator,
    required this.indicatorLabel,
    required this.compactHeight,
  });

  final Color accent;
  final Color backgroundColor;
  final double progress;
  final bool focused;
  final bool showIndicator;
  final String indicatorLabel;
  final bool compactHeight;

  @override
  Widget build(BuildContext context) {
    final barHeight = compactHeight ? 8.0 : 10.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: focused ? 4 : 0,
        vertical: focused ? 3 : 0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: focused ? accent.withValues(alpha: 0.52) : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final indicatorLeft = width * progress;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: barHeight,
                  backgroundColor: backgroundColor,
                  color: accent,
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOut,
                left: (indicatorLeft - 1.25).clamp(0.0, width),
                top: compactHeight ? -5 : -6,
                bottom: compactHeight ? -5 : -6,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: showIndicator ? 1 : 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.32),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const SizedBox(width: 2.5),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOut,
                left: (indicatorLeft - 20).clamp(0.0, width - 40),
                top: compactHeight ? -29 : -31,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: showIndicator ? 1 : 0,
                  child: _SeekBubble(
                    accent: accent,
                    label: indicatorLabel,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SeekBubble extends StatelessWidget {
  const _SeekBubble({
    required this.accent,
    required this.label,
  });

  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
