import 'package:flutter/material.dart';

enum LibraryViewMode {
  list(Icons.view_list_rounded, 'Lista'),
  cards(Icons.view_agenda_rounded, 'Tarjetas'),
  grid(Icons.grid_view_rounded, 'Grid'),
  compact(Icons.density_small_rounded, 'Compacta');

  const LibraryViewMode(this.icon, this.label);

  final IconData icon;
  final String label;
}
