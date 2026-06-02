import 'package:flutter/material.dart';

import '../../domain/library_view_mode.dart';

class ViewModeSelector extends StatelessWidget {
  const ViewModeSelector({
    required this.selectedMode,
    required this.onChanged,
    super.key,
  });

  final LibraryViewMode selectedMode;
  final ValueChanged<LibraryViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<LibraryViewMode>(
      showSelectedIcon: false,
      segments: [
        for (final mode in LibraryViewMode.values)
          ButtonSegment<LibraryViewMode>(
            value: mode,
            tooltip: mode.label,
            icon: Icon(mode.icon, size: 20),
          ),
      ],
      selected: {selectedMode},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
