import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sdl_gamepad/flutter_sdl_gamepad.dart';
import 'package:sdl3/sdl3.dart' as sdl;

import 'input_shortcuts.dart';

enum GamepadFaceButtonLayout {
  standard,
  nintendo,
}

class GamepadInputScope extends StatefulWidget {
  const GamepadInputScope({
    required this.child,
    this.faceButtonLayout = GamepadFaceButtonLayout.nintendo,
    this.debugLogging = true,
    super.key,
  });

  final Widget child;
  final GamepadFaceButtonLayout faceButtonLayout;
  final bool debugLogging;

  static final ValueNotifier<bool> hasGamepad = ValueNotifier<bool>(false);

  @override
  State<GamepadInputScope> createState() => _GamepadInputScopeState();
}

class _GamepadInputScopeState extends State<GamepadInputScope> {
  static const _pollInterval = Duration(milliseconds: 50);
  static const _axisDeadZone = 0.55;
  static const _axisRepeatDelay = Duration(milliseconds: 190);
  static const _noGamepadLogInterval = Duration(seconds: 5);

  Timer? _pollTimer;
  SdlGamepad? _gamepad;
  _ButtonSnapshot _previousButtons = const _ButtonSnapshot.empty();
  DateTime _lastAxisMove = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastNoGamepadLog = DateTime.fromMillisecondsSinceEpoch(0);
  bool _sdlReady = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);
    _initializeSdlGamepad();
  }

  @override
  void dispose() {
    GamepadInputScope.hasGamepad.value = false;
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    _pollTimer?.cancel();
    _gamepad?.close();
    if (_sdlReady) {
      SdlLibrary.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _initializeSdlGamepad() {
    if (!defaultTargetPlatform.supportsSdlGamepads) {
      _log('SDL gamepad backend is not enabled for $defaultTargetPlatform');
      return;
    }

    try {
      _registerBundledSdlLibrary();
      _sdlReady = SdlLibrary.init();
      if (!_sdlReady) {
        _log('SDL could not initialize');
        return;
      }

      _openFirstAvailableGamepad();
      _pollTimer = Timer.periodic(_pollInterval, (_) => _pollGamepad());
    } catch (error) {
      _log('SDL gamepad initialization failed: $error');
    }
  }

  void _registerBundledSdlLibrary() {
    final executable = File(Platform.resolvedExecutable);
    final bundleDirectory = executable.parent;
    final candidates = [
      File('${bundleDirectory.path}/lib/libSDL3.so.0.1.5'),
      File('${bundleDirectory.path}/lib/libSDL3.so.0'),
      File('${bundleDirectory.path}/lib/libSDL3.so'),
      File(
        '${Directory.current.path}/build/linux/x64/debug/plugins/'
        'flutter_sdl_gamepad/shared/sdl/libSDL3.so',
      ),
    ];

    for (final candidate in candidates) {
      if (!candidate.existsSync()) {
        continue;
      }

      final library = DynamicLibrary.open(candidate.path);
      sdl.SdlDynamicLibraryService().add('SDL3', library);
      _log('registered SDL library at ${candidate.path}');
      return;
    }

    _log('no bundled SDL library found near ${bundleDirectory.path}');
  }

  void _openFirstAvailableGamepad() {
    _pumpSdlInput();
    final ids = SdlGamepad.getConnectedGamepadIds();
    if (ids.isEmpty) {
      _logNoGamepadThrottled();
      return;
    }

    _gamepad?.close();
    _gamepad = SdlGamepad.fromGamepadIndex(ids.first);

    if (_gamepad?.isConnected ?? false) {
      GamepadInputScope.hasGamepad.value = true;
      final info = _gamepad!.getInfo();
      _log('SDL connected gamepad id=${_gamepad!.id} info=$info');
    } else {
      _log('SDL found ids=$ids but could not open the first gamepad');
    }
  }

  void _pollGamepad() {
    _pumpSdlInput();
    var gamepad = _gamepad;
    if (gamepad == null || !gamepad.isConnected) {
      _openFirstAvailableGamepad();
      gamepad = _gamepad;
      if (gamepad == null || !gamepad.isConnected) {
        GamepadInputScope.hasGamepad.value = false;
        return;
      }
    }

    final state = gamepad.getState();
    final buttons = _ButtonSnapshot.fromState(state);
    _handlePressedEdges(buttons);
    _handleAxes(state);
    _previousButtons = buttons;
  }

  void _pumpSdlInput() {
    if (!_sdlReady) {
      return;
    }

    try {
      // SDL only refreshes hotplugged devices after its event queue is pumped.
      sdl.sdlPumpEvents();
      sdl.sdlUpdateGamepads();
    } catch (error) {
      _log('SDL input refresh failed: $error');
    }
  }

  bool _handleHardwareKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }

    final key = event.logicalKey;
    if (_isTextEditingFocused()) {
      return false;
    }

    if (key == LogicalKeyboardKey.space) {
      _invoke(const TogglePlaybackIntent());
      return true;
    }
    if (key == LogicalKeyboardKey.keyJ) {
      _invoke(const SeekBackwardIntent());
      return true;
    }
    if (key == LogicalKeyboardKey.keyL) {
      _invoke(const SeekForwardIntent());
      return true;
    }

    if (!_isGamepadLogicalKey(key)) {
      return false;
    }

    GamepadInputScope.hasGamepad.value = true;

    if (key == LogicalKeyboardKey.gameButtonA) {
      _handleFaceButton(isNintendoA: false);
      return true;
    }
    if (key == LogicalKeyboardKey.gameButtonB) {
      _handleFaceButton(isNintendoA: true);
      return true;
    }
    if (key == LogicalKeyboardKey.gameButtonSelect) {
      if (_invoke(const OpenSearchIntent()) == null) {
        _invoke(const BackIntent());
      }
      return true;
    }
    if (key == LogicalKeyboardKey.gameButtonStart) {
      _invoke(const TogglePlaybackIntent());
      return true;
    }
    if (key == LogicalKeyboardKey.gameButtonLeft1 ||
        key == LogicalKeyboardKey.gameButtonLeft2) {
      _invoke(const SeekBackwardIntent());
      return true;
    }
    if (key == LogicalKeyboardKey.gameButtonRight1 ||
        key == LogicalKeyboardKey.gameButtonRight2) {
      _invoke(const SeekForwardIntent());
      return true;
    }

    return false;
  }

  bool _isGamepadLogicalKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.gameButtonSelect ||
        key == LogicalKeyboardKey.gameButtonStart ||
        key == LogicalKeyboardKey.gameButtonLeft1 ||
        key == LogicalKeyboardKey.gameButtonLeft2 ||
        key == LogicalKeyboardKey.gameButtonRight1 ||
        key == LogicalKeyboardKey.gameButtonRight2;
  }

  bool _isTextEditingFocused() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }
    return focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _handlePressedEdges(_ButtonSnapshot buttons) {
    if (buttons.dpadUp && !_previousButtons.dpadUp) {
      _moveFocus(TraversalDirection.up);
    }
    if (buttons.dpadDown && !_previousButtons.dpadDown) {
      _moveFocus(TraversalDirection.down);
    }
    if (buttons.dpadLeft && !_previousButtons.dpadLeft) {
      if (_invoke(const SeekBackwardIntent()) == null) {
        _moveFocus(TraversalDirection.left);
      }
    }
    if (buttons.dpadRight && !_previousButtons.dpadRight) {
      if (_invoke(const SeekForwardIntent()) == null) {
        _moveFocus(TraversalDirection.right);
      }
    }
    if (buttons.start && !_previousButtons.start) {
      _invoke(const TogglePlaybackIntent());
    }
    if (buttons.back && !_previousButtons.back) {
      if (_invoke(const OpenSearchIntent()) == null) {
        _invoke(const BackIntent());
      }
    }
    if (buttons.buttonA && !_previousButtons.buttonA) {
      _handleFaceButton(isNintendoA: false);
    }
    if (buttons.buttonB && !_previousButtons.buttonB) {
      _handleFaceButton(isNintendoA: true);
    }
  }

  void _handleAxes(GamepadState state) {
    final x = state.normalLeftJoystickX;
    final y = state.normalLeftJoystickY;
    if (x.abs() < _axisDeadZone && y.abs() < _axisDeadZone) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastAxisMove) < _axisRepeatDelay) {
      return;
    }
    _lastAxisMove = now;

    if (x.abs() > y.abs()) {
      final scrubHandled = _invoke(ScrubIntent(x));
      if (scrubHandled != null) {
        return;
      }
      _moveFocus(x > 0 ? TraversalDirection.right : TraversalDirection.left);
    } else {
      _moveFocus(y > 0 ? TraversalDirection.down : TraversalDirection.up);
    }
  }

  void _handleFaceButton({required bool isNintendoA}) {
    final usesNintendoLayout =
        widget.faceButtonLayout == GamepadFaceButtonLayout.nintendo;
    final shouldActivate = usesNintendoLayout ? isNintendoA : !isNintendoA;

    _invoke(shouldActivate ? const ActivateIntent() : const BackIntent());
  }

  void _moveFocus(TraversalDirection direction) {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) {
      FocusScope.of(context).nextFocus();
      return;
    }

    primaryFocus.focusInDirection(direction);
  }

  Object? _invoke(Intent intent) {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final targetContext = focusContext ?? context;
    return Actions.maybeInvoke(targetContext, intent);
  }

  void _log(String message) {
    if (!widget.debugLogging) {
      return;
    }

    debugPrint('[LyricFlow gamepad] $message');
  }

  void _logNoGamepadThrottled() {
    final now = DateTime.now();
    if (now.difference(_lastNoGamepadLog) < _noGamepadLogInterval) {
      return;
    }
    _lastNoGamepadLog = now;
    _log('SDL sees no connected gamepads');
  }
}

class _ButtonSnapshot {
  const _ButtonSnapshot({
    required this.buttonA,
    required this.buttonB,
    required this.back,
    required this.start,
    required this.dpadUp,
    required this.dpadDown,
    required this.dpadLeft,
    required this.dpadRight,
  });

  const _ButtonSnapshot.empty()
      : buttonA = false,
        buttonB = false,
        back = false,
        start = false,
        dpadUp = false,
        dpadDown = false,
        dpadLeft = false,
        dpadRight = false;

  factory _ButtonSnapshot.fromState(GamepadState state) {
    return _ButtonSnapshot(
      buttonA: state.buttonA,
      buttonB: state.buttonB,
      back: state.buttonBack,
      start: state.buttonStart,
      dpadUp: state.dpadUp,
      dpadDown: state.dpadDown,
      dpadLeft: state.dpadLeft,
      dpadRight: state.dpadRight,
    );
  }

  final bool buttonA;
  final bool buttonB;
  final bool back;
  final bool start;
  final bool dpadUp;
  final bool dpadDown;
  final bool dpadLeft;
  final bool dpadRight;
}

extension on TargetPlatform {
  bool get supportsSdlGamepads {
    return this == TargetPlatform.linux ||
        this == TargetPlatform.windows ||
        this == TargetPlatform.macOS;
  }
}
