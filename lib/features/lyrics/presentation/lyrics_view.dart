import 'package:flutter/material.dart';

import '../domain/lyric_line.dart';
import 'lyrics_sync_controller.dart';

class LyricsView extends StatefulWidget {
  const LyricsView({
    required this.lines,
    required this.positionStream,
    required this.playingStream,
    required this.foreground,
    required this.onSeekToLine,
    this.isLoading = false,
    super.key,
  });

  final List<LyricLine> lines;
  final Stream<Duration> positionStream;
  final Stream<bool> playingStream;
  final Color foreground;
  final ValueChanged<Duration> onSeekToLine;
  final bool isLoading;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView>
    with SingleTickerProviderStateMixin {
  static const _defaultLineHeight = 108.0;

  final ScrollController _scrollController = ScrollController();
  late LyricsSyncController _syncController;
  int _renderedActiveIndex = 0;
  bool _hasPendingScrollSync = false;
  bool _hasPendingMetricsSync = false;
  _LyricsMetrics _metrics = _LyricsMetrics.defaultMetrics();

  @override
  void initState() {
    super.initState();
    _syncController = _createSyncController();
    _renderedActiveIndex = _syncController.currentLineIndex;
    _syncController.addListener(_syncVisualState);
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.positionStream != widget.positionStream ||
        oldWidget.playingStream != widget.playingStream) {
      _syncController
        ..removeListener(_syncVisualState)
        ..dispose();
      _syncController = _createSyncController();
      _syncController.addListener(_syncVisualState);
      _renderedActiveIndex = _syncController.currentLineIndex;
      return;
    }

    _syncController.update(
      lines: widget.lines,
      lineHeight: _metrics.lineHeight,
    );
  }

  @override
  void dispose() {
    _syncController
      ..removeListener(_syncVisualState)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lyricColor = widget.foreground;

    if (widget.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 18),
            Text(
              'Buscando letras sincronizadas',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: lyricColor.withValues(alpha: 0.68),
                  ),
            ),
          ],
        ),
      );
    }

    if (widget.lines.isEmpty) {
      return Center(
        child: Text(
          'Sin letras sincronizadas',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: lyricColor.withValues(alpha: 0.58),
              ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _updateMetrics(_LyricsMetrics.fromHeight(constraints.maxHeight));

        return RepaintBoundary(
          child: ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0, 0.14, 0.86, 1],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              controller: _scrollController,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(vertical: _metrics.verticalPadding),
              itemExtent: _metrics.lineHeight,
              itemCount: widget.lines.length,
              itemBuilder: (context, index) {
                final distance = (index - _renderedActiveIndex).abs();
                final isActive = index == _renderedActiveIndex;
                final opacity = isActive ? 1.0 : (distance == 1 ? 0.52 : 0.3);

                return RepaintBoundary(
                  child: _SelectableLyricsLine(
                    timestamp: widget.lines[index].timestamp,
                    onSeek: widget.onSeekToLine,
                    child: isActive
                        ? ActiveLyricsLine(
                            text: widget.lines[index].text,
                            color: lyricColor.withValues(alpha: opacity),
                            shadowColor: _shadowColor(isDark),
                            fontSize: _metrics.activeFontSize,
                          )
                        : LyricsLine(
                            text: widget.lines[index].text,
                            color: lyricColor.withValues(alpha: opacity),
                            shadowColor: _shadowColor(isDark),
                            fontSize: _metrics.inactiveFontSize,
                          ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  LyricsSyncController _createSyncController() {
    return LyricsSyncController(
      vsync: this,
      positionStream: widget.positionStream,
      playingStream: widget.playingStream,
      lines: widget.lines,
      lineHeight: _metrics.lineHeight,
    );
  }

  void _updateMetrics(_LyricsMetrics nextMetrics) {
    if (_metrics == nextMetrics) {
      return;
    }

    _metrics = nextMetrics;
    if (_hasPendingMetricsSync) {
      return;
    }

    _hasPendingMetricsSync = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hasPendingMetricsSync = false;
      if (!mounted) {
        return;
      }
      _syncController.update(
        lines: widget.lines,
        lineHeight: _metrics.lineHeight,
      );
    });
  }

  Color _shadowColor(bool isDark) {
    return isDark
        ? Colors.black.withValues(alpha: 0.36)
        : Colors.white.withValues(alpha: 0.46);
  }

  void _syncVisualState() {
    _syncScrollOffset();
    final nextActiveIndex = _syncController.currentLineIndex;
    if (nextActiveIndex == _renderedActiveIndex || !mounted) {
      return;
    }

    setState(() {
      _renderedActiveIndex = nextActiveIndex;
    });
  }

  void _syncScrollOffset() {
    if (!_scrollController.hasClients) {
      if (_hasPendingScrollSync) {
        return;
      }
      _hasPendingScrollSync = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hasPendingScrollSync = false;
        if (mounted) {
          _syncScrollOffset();
        }
      });
      return;
    }

    final target = _syncController.currentScrollOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if ((target - _scrollController.offset).abs() < 0.5) {
      return;
    }

    _scrollController.jumpTo(target);
  }
}

class _SelectableLyricsLine extends StatefulWidget {
  const _SelectableLyricsLine({
    required this.timestamp,
    required this.onSeek,
    required this.child,
  });

  final Duration timestamp;
  final ValueChanged<Duration> onSeek;
  final Widget child;

  @override
  State<_SelectableLyricsLine> createState() => _SelectableLyricsLineState();
}

class _SelectableLyricsLineState extends State<_SelectableLyricsLine> {
  late final FocusNode _focusNode = FocusNode(skipTraversal: true);
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return FocusableActionDetector(
      descendantsAreFocusable: false,
      descendantsAreTraversable: false,
      focusNode: _focusNode,
      onShowFocusHighlight: (focused) {
        if (_focused != focused) {
          setState(() => _focused = focused);
        }
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onSeek(widget.timestamp);
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSeek(widget.timestamp),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color:
                _focused ? accent.withValues(alpha: 0.12) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: _focused ? accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class LyricsLine extends StatelessWidget {
  const LyricsLine({
    required this.text,
    required this.color,
    required this.shadowColor,
    required this.fontSize,
    super.key,
  });

  final String text;
  final Color color;
  final Color shadowColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return _AnimatedLyricsText(
      text: text,
      color: color,
      shadowColor: shadowColor,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      scale: 1,
    );
  }
}

class ActiveLyricsLine extends StatelessWidget {
  const ActiveLyricsLine({
    required this.text,
    required this.color,
    required this.shadowColor,
    required this.fontSize,
    super.key,
  });

  final String text;
  final Color color;
  final Color shadowColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return _AnimatedLyricsText(
      text: text,
      color: color,
      shadowColor: shadowColor,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      scale: 1.025,
    );
  }
}

class _LyricsMetrics {
  const _LyricsMetrics({
    required this.lineHeight,
    required this.verticalPadding,
    required this.activeFontSize,
    required this.inactiveFontSize,
  });

  factory _LyricsMetrics.defaultMetrics() {
    return const _LyricsMetrics(
      lineHeight: _LyricsViewState._defaultLineHeight,
      verticalPadding: 170,
      activeFontSize: 50,
      inactiveFontSize: 40,
    );
  }

  factory _LyricsMetrics.fromHeight(double height) {
    final resolvedHeight = height.isFinite ? height : 720.0;
    final compactFactor = ((resolvedHeight - 420) / 320).clamp(0.0, 1.0);

    return _LyricsMetrics(
      lineHeight: 78 + (30 * compactFactor),
      verticalPadding: 74 + (96 * compactFactor),
      activeFontSize: 34 + (16 * compactFactor),
      inactiveFontSize: 28 + (12 * compactFactor),
    );
  }

  final double lineHeight;
  final double verticalPadding;
  final double activeFontSize;
  final double inactiveFontSize;

  @override
  bool operator ==(Object other) {
    return other is _LyricsMetrics &&
        other.lineHeight == lineHeight &&
        other.verticalPadding == verticalPadding &&
        other.activeFontSize == activeFontSize &&
        other.inactiveFontSize == inactiveFontSize;
  }

  @override
  int get hashCode => Object.hash(
        lineHeight,
        verticalPadding,
        activeFontSize,
        inactiveFontSize,
      );
}

class _AnimatedLyricsText extends StatelessWidget {
  const _AnimatedLyricsText({
    required this.text,
    required this.color,
    required this.shadowColor,
    required this.fontSize,
    required this.fontWeight,
    required this.scale,
  });

  final String text;
  final Color color;
  final Color shadowColor;
  final double fontSize;
  final FontWeight fontWeight;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      style: Theme.of(context).textTheme.headlineMedium!.copyWith(
        fontSize: fontSize,
        height: 1.06,
        fontWeight: fontWeight,
        color: color,
        shadows: [
          Shadow(
            color: shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: scale,
        alignment: Alignment.centerLeft,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
