import 'package:shared_preferences/shared_preferences.dart';

class LibraryPreferences {
  const LibraryPreferences();

  static const _musicFolderKey = 'library.music_folder';
  static const _viewModeKey = 'library.view_mode';

  Future<String?> loadMusicFolder() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_musicFolderKey);
  }

  Future<void> saveMusicFolder(String folderPath) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_musicFolderKey, folderPath);
  }

  Future<String?> loadViewMode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_viewModeKey);
  }

  Future<void> saveViewMode(String viewMode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_viewModeKey, viewMode);
  }
}
