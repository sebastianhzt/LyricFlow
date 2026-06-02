import 'package:flutter/material.dart';

class FloatingGamepadKeyboard extends StatefulWidget {
  const FloatingGamepadKeyboard({
    required this.onText,
    required this.onBackspace,
    required this.onSpace,
    required this.onClear,
    required this.onClose,
    super.key,
  });

  final ValueChanged<String> onText;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;
  final VoidCallback onClear;
  final VoidCallback onClose;

  static const _letterRows = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ñ'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  static const _symbolRows = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['.', ',', '-', '_', '\'', '"', '/', '&', ':', ';'],
    ['(', ')', '[', ']', '#', '+', '!', '?', '@'],
  ];

  @override
  State<FloatingGamepadKeyboard> createState() =>
      _FloatingGamepadKeyboardState();
}

class _FloatingGamepadKeyboardState extends State<FloatingGamepadKeyboard> {
  final FocusNode _firstKeyFocusNode = FocusNode();
  bool _showSymbols = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _firstKeyFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _firstKeyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 96),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color:
                  colorScheme.surface.withValues(alpha: isDark ? 0.94 : 0.97),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.42),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.16),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final row in _activeRows) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final key in row)
                            _KeyboardKey(
                              label: key,
                              focusNode: key == 'Q' ? _firstKeyFocusNode : null,
                              onPressed: () => widget.onText(key.toLowerCase()),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _KeyboardKey(
                          label: _showSymbols ? 'ABC' : '123',
                          icon: _showSymbols
                              ? Icons.text_fields_rounded
                              : Icons.numbers_rounded,
                          wide: true,
                          onPressed: _toggleKeyboardMode,
                        ),
                        _KeyboardKey(
                          label: 'Borrar',
                          icon: Icons.backspace_rounded,
                          wide: true,
                          onPressed: widget.onBackspace,
                        ),
                        _KeyboardKey(
                          label: 'Espacio',
                          icon: Icons.space_bar_rounded,
                          extraWide: true,
                          onPressed: widget.onSpace,
                        ),
                        _KeyboardKey(
                          label: 'Limpiar',
                          icon: Icons.clear_rounded,
                          wide: true,
                          onPressed: widget.onClear,
                        ),
                        _KeyboardKey(
                          label: 'Finalizar',
                          icon: Icons.done_rounded,
                          wide: true,
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<List<String>> get _activeRows {
    return _showSymbols
        ? FloatingGamepadKeyboard._symbolRows
        : FloatingGamepadKeyboard._letterRows;
  }

  void _toggleKeyboardMode() {
    setState(() {
      _showSymbols = !_showSymbols;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _firstKeyFocusNode.requestFocus();
      }
    });
  }
}

class _KeyboardKey extends StatelessWidget {
  const _KeyboardKey({
    required this.label,
    required this.onPressed,
    this.icon,
    this.focusNode,
    this.wide = false,
    this.extraWide = false,
  });

  final String label;
  final IconData? icon;
  final FocusNode? focusNode;
  final VoidCallback onPressed;
  final bool wide;
  final bool extraWide;

  @override
  Widget build(BuildContext context) {
    final width = extraWide ? 220.0 : (wide ? 118.0 : 64.0);
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: SizedBox(
        width: width,
        height: 58,
        child: icon == null
            ? FilledButton.tonal(
                focusNode: focusNode,
                onPressed: onPressed,
                style: _styleFor(colorScheme, labelStyle),
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : FilledButton.tonalIcon(
                focusNode: focusNode,
                onPressed: onPressed,
                icon: Icon(icon, size: 20),
                label: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                style: _styleFor(colorScheme, labelStyle),
              ),
      ),
    );
  }

  ButtonStyle _styleFor(
    ColorScheme colorScheme,
    TextStyle? labelStyle,
  ) {
    return FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      backgroundColor:
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.82),
      foregroundColor: colorScheme.onSurface,
      textStyle: labelStyle,
    );
  }
}
