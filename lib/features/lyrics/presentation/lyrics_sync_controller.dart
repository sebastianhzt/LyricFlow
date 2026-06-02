import 'dart:async';
import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../domain/lyric_line.dart';

class LyricsSyncController extends ChangeNotifier {
  LyricsSyncController({
    required TickerProvider vsync,
    required Stream<Duration> positionStream,
    required Stream<bool> playingStream,
    required List<LyricLine> lines,
    required double lineHeight,
  })  : _lines = lines,
        _lineHeight = lineHeight {
    _ticker = vsync.createTicker(_tick);
    _positionSubscription = positionStream.listen(_syncAudioPosition);
    _playingSubscription = playingStream.listen(_syncPlayingState);
    _syncAudioPosition(Duration.zero, jump: true);
  }

  static const _scrollDuration = Duration(milliseconds: 640);
  static const _largeSeekLineThreshold = 3;

  late final Ticker _ticker;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<bool> _playingSubscription;

  List<LyricLine> _lines;
  double _lineHeight;
  Duration _audioPositionReal = Duration.zero;
  Duration _visualPositionInterpolated = Duration.zero;
  Duration _lastAudioSamplePosition = Duration.zero;
  Duration _lastAudioSampleElapsed = Duration.zero;
  Duration _lastTickerElapsed = Duration.zero;
  int _currentLineIndex = 0;
  double _currentScrollOffset = 0;
  double _targetScrollOffset = 0;
  double _scrollStartOffset = 0;
  Duration _scrollStartElapsed = Duration.zero;
  bool _isPlaying = false;
  bool _isScrollAnimating = false;

  Duration get audioPositionReal => _audioPositionReal;
  Duration get visualPositionInterpolated => _visualPositionInterpolated;
  int get currentLineIndex => _currentLineIndex;
  double get currentScrollOffset => _currentScrollOffset;
  double get targetScrollOffset => _targetScrollOffset;

  void update({
    required List<LyricLine> lines,
    required double lineHeight,
  }) {
    final linesChanged = !identical(_lines, lines);
    final lineHeightChanged = _lineHeight != lineHeight;
    _lineHeight = lineHeight;
    if (!linesChanged && !lineHeightChanged) {
      return;
    }

    _lines = lines;
    _currentLineIndex = _findActiveIndex(_audioPositionReal);
    _targetScrollOffset = _offsetForLine(_currentLineIndex);
    _currentScrollOffset = _targetScrollOffset;
    _isScrollAnimating = false;
    _stopTickerIfIdle();
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription.cancel();
    _playingSubscription.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _syncAudioPosition(Duration position, {bool jump = false}) {
    _audioPositionReal = position;
    _visualPositionInterpolated = position;
    _lastAudioSamplePosition = position;
    _lastAudioSampleElapsed = _lastTickerElapsed;
    if (_isPlaying) {
      _ensureTickerRunning();
    }
    if (_syncLineForPosition(position, jump: jump)) {
      notifyListeners();
    }
  }

  void _syncPlayingState(bool isPlaying) {
    _isPlaying = isPlaying;
    _lastAudioSamplePosition = _audioPositionReal;
    _lastAudioSampleElapsed = _lastTickerElapsed;
    if (isPlaying) {
      _ensureTickerRunning();
    } else {
      _stopTickerIfIdle();
    }
  }

  bool _syncLineForPosition(Duration position, {bool jump = false}) {
    if (_lines.isEmpty) {
      return false;
    }

    final nextLineIndex = _findActiveIndex(position);
    if (nextLineIndex == _currentLineIndex && !jump) {
      return false;
    }

    final previousLineIndex = _currentLineIndex;
    _currentLineIndex = nextLineIndex;

    final lineDelta = (nextLineIndex - previousLineIndex).abs();
    final shouldJump = jump || lineDelta > _largeSeekLineThreshold;
    _beginScrollToLine(nextLineIndex, jump: shouldJump);
    return true;
  }

  void _beginScrollToLine(int lineIndex, {required bool jump}) {
    _targetScrollOffset = _offsetForLine(lineIndex);
    if (jump) {
      _isScrollAnimating = false;
      _currentScrollOffset = _targetScrollOffset;
      _stopTickerIfIdle();
      return;
    }

    _scrollStartOffset = _currentScrollOffset;
    _scrollStartElapsed = Duration.zero;
    _isScrollAnimating = true;
    _ensureTickerRunning();
  }

  void _tick(Duration elapsed) {
    _lastTickerElapsed = elapsed;
    var changed = false;

    if (_isPlaying) {
      final extrapolatedElapsed = elapsed - _lastAudioSampleElapsed;
      _visualPositionInterpolated =
          _lastAudioSamplePosition + extrapolatedElapsed;
      changed = _syncLineForPosition(_visualPositionInterpolated);
    }

    if (!_isScrollAnimating) {
      if (changed) {
        notifyListeners();
      }
      _stopTickerIfIdle();
      return;
    }

    if (_scrollStartElapsed == Duration.zero) {
      _scrollStartElapsed = elapsed;
    }

    final animationElapsed = elapsed - _scrollStartElapsed;
    final rawProgress =
        animationElapsed.inMicroseconds / _scrollDuration.inMicroseconds;
    final progress = rawProgress.clamp(0.0, 1.0);
    final curved = Curves.easeOutCubic.transform(progress);

    _currentScrollOffset = lerpDouble(
          _scrollStartOffset,
          _targetScrollOffset,
          curved,
        ) ??
        _targetScrollOffset;

    if (progress >= 1) {
      _currentScrollOffset = _targetScrollOffset;
      _isScrollAnimating = false;
      _stopTickerIfIdle();
    }

    notifyListeners();
  }

  int _findActiveIndex(Duration position) {
    if (_lines.isEmpty) {
      return 0;
    }

    var low = 0;
    var high = _lines.length - 1;
    var result = 0;

    while (low <= high) {
      final mid = (low + high) >> 1;
      if (_lines[mid].timestamp <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return result;
  }

  double _offsetForLine(int index) => index * _lineHeight;

  void _ensureTickerRunning() {
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _stopTickerIfIdle() {
    if (!_isPlaying && !_isScrollAnimating && _ticker.isActive) {
      _ticker.stop();
      _lastTickerElapsed = Duration.zero;
      _lastAudioSampleElapsed = Duration.zero;
    }
  }
}
