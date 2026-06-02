import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TogglePlaybackIntent extends Intent {
  const TogglePlaybackIntent();
}

class SeekBackwardIntent extends Intent {
  const SeekBackwardIntent();
}

class SeekForwardIntent extends Intent {
  const SeekForwardIntent();
}

class ScrubIntent extends Intent {
  const ScrubIntent(this.amount);

  final double amount;
}

class BackIntent extends Intent {
  const BackIntent();
}

class OpenSearchIntent extends Intent {
  const OpenSearchIntent();
}

class MoveFocusIntent extends Intent {
  const MoveFocusIntent(this.direction);

  final TraversalDirection direction;
}

class AppShortcuts extends StatelessWidget {
  const AppShortcuts({
    required this.child,
    this.onTogglePlayback,
    this.onSeekBackward,
    this.onSeekForward,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTogglePlayback;
  final VoidCallback? onSeekBackward;
  final VoidCallback? onSeekForward;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowUp):
            const MoveFocusIntent(TraversalDirection.up),
        LogicalKeySet(LogicalKeyboardKey.arrowDown):
            const MoveFocusIntent(TraversalDirection.down),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft):
            const MoveFocusIntent(TraversalDirection.left),
        LogicalKeySet(LogicalKeyboardKey.arrowRight):
            const MoveFocusIntent(TraversalDirection.right),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.gameButtonB): const BackIntent(),
        LogicalKeySet(LogicalKeyboardKey.gameButtonSelect): const BackIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const BackIntent(),
        LogicalKeySet(LogicalKeyboardKey.gameButtonStart):
            const TogglePlaybackIntent(),
        LogicalKeySet(LogicalKeyboardKey.gameButtonLeft1):
            const SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.gameButtonLeft2):
            const SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.gameButtonRight1):
            const SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.gameButtonRight2):
            const SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.goBack): const BackIntent(),
      },
      child: Actions(
        actions: {
          MoveFocusIntent: CallbackAction<MoveFocusIntent>(
            onInvoke: (intent) {
              FocusManager.instance.primaryFocus
                  ?.focusInDirection(intent.direction);
              return null;
            },
          ),
          TogglePlaybackIntent: CallbackAction<TogglePlaybackIntent>(
            onInvoke: (_) {
              onTogglePlayback?.call();
              return null;
            },
          ),
          SeekBackwardIntent: CallbackAction<SeekBackwardIntent>(
            onInvoke: (_) {
              final handled = Actions.maybeInvoke<SeekBackwardIntent>(
                context,
                const SeekBackwardIntent(),
              );
              if (handled != null) {
                return handled;
              }
              onSeekBackward?.call();
              return null;
            },
          ),
          SeekForwardIntent: CallbackAction<SeekForwardIntent>(
            onInvoke: (_) {
              final handled = Actions.maybeInvoke<SeekForwardIntent>(
                context,
                const SeekForwardIntent(),
              );
              if (handled != null) {
                return handled;
              }
              onSeekForward?.call();
              return null;
            },
          ),
          BackIntent: CallbackAction<BackIntent>(
            onInvoke: (_) {
              final handled = Actions.maybeInvoke<BackIntent>(
                context,
                const BackIntent(),
              );
              if (handled != null) {
                return handled;
              }
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              }
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: child,
        ),
      ),
    );
  }
}
