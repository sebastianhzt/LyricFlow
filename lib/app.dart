import 'dart:async';

import 'package:flutter/material.dart';

import 'features/library/presentation/library_screen.dart';
import 'features/gamepad/gamepad_input_scope.dart';
import 'features/player/data/audio_player_service.dart';
import 'features/player/presentation/now_playing_screen.dart';
import 'shared/theme/app_theme.dart';

class LyricFlowApp extends StatefulWidget {
  const LyricFlowApp({super.key});

  @override
  State<LyricFlowApp> createState() => _LyricFlowAppState();
}

class _LyricFlowAppState extends State<LyricFlowApp>
    with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isShuttingDown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_shutdownAudio());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(_shutdownAudio());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = LyricFlowThemeController(
      mode: _themeMode,
      toggle: _toggleThemeMode,
    );

    return MaterialApp(
      title: 'LyricFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      routes: {
        LibraryScreen.routeName: (_) => const LibraryScreen(),
        NowPlayingScreen.routeName: (_) => const NowPlayingScreen(),
      },
      builder: (context, child) {
        return LyricFlowTheme(
          controller: controller,
          child: GamepadInputScope(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              reverseDuration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.996, end: 1).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_themeMode),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
      initialRoute: LibraryScreen.routeName,
    );
  }

  void _toggleThemeMode() {
    setState(() {
      final platformBrightness = MediaQuery.platformBrightnessOf(context);
      final effectiveMode = _themeMode == ThemeMode.system
          ? platformBrightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light
          : _themeMode;

      _themeMode =
          effectiveMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  Future<void> _shutdownAudio() async {
    if (_isShuttingDown) {
      return;
    }
    _isShuttingDown = true;
    await AudioPlayerService().dispose();
  }
}

class LyricFlowThemeController {
  const LyricFlowThemeController({
    required this.mode,
    required this.toggle,
  });

  final ThemeMode mode;
  final VoidCallback toggle;
}

class LyricFlowTheme extends InheritedWidget {
  const LyricFlowTheme({
    required this.controller,
    required super.child,
    super.key,
  });

  final LyricFlowThemeController controller;

  static LyricFlowThemeController of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<LyricFlowTheme>();
    assert(theme != null, 'LyricFlowTheme was not found in context.');
    return theme!.controller;
  }

  @override
  bool updateShouldNotify(LyricFlowTheme oldWidget) {
    return controller.mode != oldWidget.controller.mode;
  }
}
