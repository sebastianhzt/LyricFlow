import 'dart:io';

import 'package:flutter/material.dart';

import '../../gamepad/input_shortcuts.dart';

class FolderBrowserDialog extends StatefulWidget {
  const FolderBrowserDialog({
    this.initialPath,
    super.key,
  });

  final String? initialPath;

  @override
  State<FolderBrowserDialog> createState() => _FolderBrowserDialogState();
}

class _FolderBrowserDialogState extends State<FolderBrowserDialog> {
  late Directory _currentDirectory;
  List<Directory> _directories = [];
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentDirectory = Directory(_initialPath());
    _loadDirectories();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppShortcuts(
      child: Dialog.fullscreen(
        backgroundColor: colorScheme.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      autofocus: true,
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seleccionar carpeta',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentDirectory.path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.64),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(_currentDirectory.path);
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Usar esta carpeta'),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Expanded(child: _buildBody(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _FolderBrowserMessage(
        icon: Icons.lock_outline_rounded,
        title: 'No se pudo abrir la carpeta',
        message: _error!,
      );
    }

    final entries = [
      if (_currentDirectory.parent.path != _currentDirectory.path)
        _FolderEntry.parent(_currentDirectory.parent),
      ..._directories.map(_FolderEntry.directory),
    ];

    if (entries.isEmpty) {
      return const _FolderBrowserMessage(
        icon: Icons.folder_off_rounded,
        title: 'Carpeta vacia',
        message: 'Puedes usar esta carpeta o volver a un nivel anterior.',
      );
    }

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _FolderTile(
          entry: entry,
          autofocus: index == 0,
          onPressed: () => _openDirectory(entry.directory),
        );
      },
    );
  }

  Future<void> _openDirectory(Directory directory) async {
    setState(() {
      _currentDirectory = directory;
      _isLoading = true;
      _error = null;
      _directories = [];
    });
    await _loadDirectories();
  }

  Future<void> _loadDirectories() async {
    try {
      final exists = await _currentDirectory.exists();
      if (!exists) {
        throw const FileSystemException('La carpeta no existe');
      }

      final directories = <Directory>[];
      await for (final entity in _currentDirectory.list(followLinks: false)) {
        if (entity is Directory && !_isHidden(entity)) {
          directories.add(entity);
        }
      }

      directories.sort((a, b) {
        return _displayName(a).toLowerCase().compareTo(
              _displayName(b).toLowerCase(),
            );
      });

      if (!mounted) {
        return;
      }
      setState(() {
        _directories = directories;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
        _isLoading = false;
      });
    }
  }

  String _initialPath() {
    final requestedPath = widget.initialPath;
    if (requestedPath != null && Directory(requestedPath).existsSync()) {
      return requestedPath;
    }

    final home = Platform.environment['HOME'];
    if (home != null) {
      final music = Directory('$home/Music');
      if (music.existsSync()) {
        return music.path;
      }
      final musicEs = Directory('$home/Música');
      if (musicEs.existsSync()) {
        return musicEs.path;
      }
      return home;
    }

    return Directory.current.path;
  }

  bool _isHidden(Directory directory) {
    return _displayName(directory).startsWith('.');
  }
}

class _FolderEntry {
  const _FolderEntry({
    required this.directory,
    required this.isParent,
  });

  factory _FolderEntry.directory(Directory directory) {
    return _FolderEntry(directory: directory, isParent: false);
  }

  factory _FolderEntry.parent(Directory directory) {
    return _FolderEntry(directory: directory, isParent: true);
  }

  final Directory directory;
  final bool isParent;
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.entry,
    required this.autofocus,
    required this.onPressed,
  });

  final _FolderEntry entry;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
              borderRadius: BorderRadius.circular(12),
              color: focused
                  ? colorScheme.primary.withValues(alpha: 0.16)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
              border: Border.all(
                color: focused
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.34),
                width: focused ? 2.5 : 1,
              ),
              boxShadow: [
                if (focused)
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.26),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPressed,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Icon(
                      entry.isParent
                          ? Icons.drive_folder_upload_rounded
                          : Icons.folder_rounded,
                      size: 32,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        entry.isParent
                            ? 'Subir un nivel'
                            : _displayName(entry.directory),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FolderBrowserMessage extends StatelessWidget {
  const _FolderBrowserMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 58, color: colorScheme.primary),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.66),
                ),
          ),
        ],
      ),
    );
  }
}

String _displayName(Directory directory) {
  final normalized = directory.path.replaceAll(RegExp(r'/+$'), '');
  if (normalized.isEmpty || normalized == '/') {
    return '/';
  }
  final segments = normalized.split(Platform.pathSeparator);
  return segments.last.isEmpty ? normalized : segments.last;
}
