import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_routes.dart';
import '../../../shared/widgets/theme_mode_button.dart';
import '../../gamepad/input_shortcuts.dart';
import '../../gamepad/gamepad_input_scope.dart';
import '../../player/data/audio_player_service.dart';
import '../../player/domain/player_route_args.dart';
import '../data/library_preferences.dart';
import '../data/music_library_scanner.dart';
import '../data/song_search_service.dart';
import '../domain/library_view_mode.dart';
import '../domain/song.dart';
import 'folder_browser_dialog.dart';
import 'widgets/floating_gamepad_keyboard.dart';
import 'widgets/library_search_bar.dart';
import 'widgets/library_mini_player.dart';
import 'widgets/song_library_views.dart';
import 'widgets/view_mode_selector.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  static const routeName = AppRoutes.library;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final MusicLibraryScanner _scanner = const MusicLibraryScanner();
  final LibraryPreferences _preferences = const LibraryPreferences();
  final SongSearchService _searchService = const SongSearchService();
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Song> _songs = [];
  List<Song> _visibleSongs = [];
  String? _selectedFolder;
  String? _error;
  String _searchQuery = '';
  LibraryViewMode _viewMode = LibraryViewMode.list;
  bool _isScanning = false;
  bool _showGamepadKeyboard = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleSearchFocusChanged);
    _restoreViewMode();
    _restoreSavedFolder();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocusNode
      ..removeListener(_handleSearchFocusChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShortcuts(
      onTogglePlayback: _togglePlayback,
      child: Actions(
        actions: {
          OpenSearchIntent: CallbackAction<OpenSearchIntent>(
            onInvoke: (_) {
              _openGamepadSearch();
              return true;
            },
          ),
        },
        child: Scaffold(
          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LibraryHeader(
                        selectedFolder: _selectedFolder,
                        isScanning: _isScanning,
                        onSelectFolder: _selectAndScanFolder,
                        onRefresh: _refreshLibrary,
                      ),
                      const SizedBox(height: 28),
                      _LibraryControls(
                        searchController: _searchController,
                        searchFocusNode: _searchFocusNode,
                        viewMode: _viewMode,
                        onSearchChanged: _queueSearch,
                        onClearSearch: _clearSearch,
                        onViewModeChanged: _setViewMode,
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: _LibraryBody(
                          songs: _visibleSongs,
                          totalSongs: _songs.length,
                          query: _searchQuery,
                          viewMode: _viewMode,
                          selectedFolder: _selectedFolder,
                          error: _error,
                          isScanning: _isScanning,
                          onSongSelected: _openSong,
                        ),
                      ),
                      const LibraryMiniPlayer(),
                    ],
                  ),
                ),
              ),
              ValueListenableBuilder<bool>(
              valueListenable: GamepadInputScope.hasGamepad,
              builder: (context, hasGamepad, _) {
                final visible = hasGamepad && _showGamepadKeyboard;
                if (!visible) {
                  return const SizedBox.shrink();
                }
                return FloatingGamepadKeyboard(
                  onText: _insertSearchText,
                  onBackspace: _backspaceSearch,
                  onSpace: () => _insertSearchText(' '),
                  onClear: _clearSearch,
                  onClose: _closeGamepadKeyboard,
                );
              },
            ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectAndScanFolder() async {
    final folder = await showDialog<String>(
      context: context,
      builder: (_) => FolderBrowserDialog(initialPath: _selectedFolder),
    );
    if (folder == null) {
      return;
    }

    setState(() {
      _selectedFolder = folder;
      _isScanning = true;
      _error = null;
      _songs = [];
      _visibleSongs = [];
    });

    await _preferences.saveMusicFolder(folder);
    await _scanFolder(folder);
  }

  Future<void> _refreshLibrary() async {
    final folder = _selectedFolder;
    if (folder == null || _isScanning) {
      return;
    }

    setState(() {
      _isScanning = true;
      _error = null;
      _songs = [];
      _visibleSongs = [];
    });

    await _scanFolder(folder);
  }

  Future<void> _restoreSavedFolder() async {
    final folder = await _preferences.loadMusicFolder();
    if (!mounted || folder == null) {
      return;
    }

    setState(() {
      _selectedFolder = folder;
      _isScanning = true;
      _error = null;
    });

    await _scanFolder(folder);
  }

  Future<void> _scanFolder(String folder) async {
    try {
      final songs = await _scanner.scan(folder);
      if (!mounted) {
        return;
      }
      setState(() {
        _songs = songs;
        _visibleSongs = _searchService.filter(songs, _searchQuery);
        _isScanning = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No se pudo escanear la carpeta: $error';
        _isScanning = false;
      });
    }
  }

  Future<void> _restoreViewMode() async {
    final storedMode = await _preferences.loadViewMode();
    if (!mounted || storedMode == null) {
      return;
    }

    final mode = LibraryViewMode.values.where(
      (value) => value.name == storedMode,
    );
    if (mode.isEmpty) {
      return;
    }

    setState(() {
      _viewMode = mode.first;
    });
  }

  void _queueSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 120), () {
      _applySearch(query);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _applySearch('');
  }

  void _handleSearchFocusChanged() {
    if (!_searchFocusNode.hasFocus || !GamepadInputScope.hasGamepad.value) {
      return;
    }
    setState(() {
      _showGamepadKeyboard = true;
    });
  }

  void _openGamepadSearch() {
    GamepadInputScope.hasGamepad.value = true;
    _searchFocusNode.requestFocus();
    setState(() {
      _showGamepadKeyboard = true;
    });
  }

  void _insertSearchText(String text) {
    final value = _searchController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final nextText = value.text.replaceRange(start, end, text);
    final nextOffset = start + text.length;
    _searchController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
    _queueSearch(nextText);
  }

  void _backspaceSearch() {
    final value = _searchController.value;
    final selection = value.selection;
    if (value.text.isEmpty) {
      return;
    }

    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    if (start != end) {
      final nextText = value.text.replaceRange(start, end, '');
      _searchController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: start),
      );
      _queueSearch(nextText);
      return;
    }

    if (start == 0) {
      return;
    }

    final nextText = value.text.replaceRange(start - 1, start, '');
    _searchController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start - 1),
    );
    _queueSearch(nextText);
  }

  void _closeGamepadKeyboard() {
    setState(() {
      _showGamepadKeyboard = false;
    });
    _searchFocusNode.unfocus();
    FocusScope.of(context).nextFocus();
  }

  void _applySearch(String query) {
    if (!mounted) {
      return;
    }
    setState(() {
      _searchQuery = query;
      _visibleSongs = _searchService.filter(_songs, query);
    });
  }

  void _setViewMode(LibraryViewMode mode) {
    if (_viewMode == mode) {
      return;
    }
    setState(() {
      _viewMode = mode;
    });
    unawaited(_preferences.saveViewMode(mode.name));
  }

  void _openSong(Song song, int index) {
    Navigator.of(context).pushNamed(
      AppRoutes.nowPlaying,
      arguments: PlayerRouteArgs(
        songs: _visibleSongs,
        initialIndex: index,
      ),
    );
  }

  void _togglePlayback() {
    unawaited(_runAudioAction(_audioPlayerService.togglePlayPause));
  }

  Future<void> _runAudioAction(Future<dynamic> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('LyricFlow library audio error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.selectedFolder,
    required this.isScanning,
    required this.onSelectFolder,
    required this.onRefresh,
  });

  final String? selectedFolder;
  final bool isScanning;
  final VoidCallback onSelectFolder;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        return Flex(
          direction: compact ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment:
              compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LyricFlow',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  selectedFolder ?? 'Biblioteca local',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
            if (compact) const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ThemeModeButton(),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: 'Actualizar biblioteca',
                  onPressed:
                      selectedFolder == null || isScanning ? null : onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: isScanning ? null : onSelectFolder,
                  icon: const Icon(Icons.folder_open_rounded),
                  label:
                      Text(isScanning ? 'Escaneando' : 'Seleccionar carpeta'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LibraryControls extends StatelessWidget {
  const _LibraryControls({
    required this.searchController,
    required this.searchFocusNode,
    required this.viewMode,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onViewModeChanged,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final LibraryViewMode viewMode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<LibraryViewMode> onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final search = LibrarySearchBar(
          controller: searchController,
          focusNode: searchFocusNode,
          onChanged: onSearchChanged,
          onClear: onClearSearch,
        );
        final selector = ViewModeSelector(
          selectedMode: viewMode,
          onChanged: onViewModeChanged,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: selector),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 16),
            selector,
          ],
        );
      },
    );
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody({
    required this.songs,
    required this.totalSongs,
    required this.query,
    required this.viewMode,
    required this.selectedFolder,
    required this.error,
    required this.isScanning,
    required this.onSongSelected,
  });

  final List<Song> songs;
  final int totalSongs;
  final String query;
  final LibraryViewMode viewMode;
  final String? selectedFolder;
  final String? error;
  final bool isScanning;
  final SongSelected onSongSelected;

  @override
  Widget build(BuildContext context) {
    if (isScanning) {
      return const _LibraryMessage(
        icon: Icons.manage_search_rounded,
        title: 'Escaneando musica local',
        message: 'Leyendo archivos FLAC, MP3 y WAV...',
        showProgress: true,
      );
    }

    if (error != null) {
      return _LibraryMessage(
        icon: Icons.error_outline_rounded,
        title: 'No se pudo cargar la biblioteca',
        message: error!,
      );
    }

    if (totalSongs == 0) {
      if (selectedFolder != null) {
        return const _LibraryMessage(
          icon: Icons.search_off_rounded,
          title: 'No se encontraron canciones',
          message: 'La carpeta no contiene archivos .flac, .mp3 ni .wav.',
        );
      }

      return const _LibraryMessage(
        icon: Icons.library_music_rounded,
        title: 'Selecciona una carpeta de musica',
        message:
            'LyricFlow buscara recursivamente archivos .flac, .mp3 y .wav.',
      );
    }

    if (songs.isEmpty) {
      return _LibraryMessage(
        icon: Icons.search_off_rounded,
        title: 'No se encontraron canciones',
        message: 'No hay resultados para "$query".',
      );
    }

    return switch (viewMode) {
      LibraryViewMode.list => SongListView(
          songs: songs,
          onSongSelected: onSongSelected,
        ),
      LibraryViewMode.cards => SongCardView(
          songs: songs,
          onSongSelected: onSongSelected,
        ),
      LibraryViewMode.grid => SongGridView(
          songs: songs,
          onSongSelected: onSongSelected,
        ),
      LibraryViewMode.compact => SongCompactView(
          songs: songs,
          onSongSelected: onSongSelected,
        ),
    };
  }
}

class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
              ),
              if (showProgress) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
