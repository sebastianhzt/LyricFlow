# 🎵 LyricFlow

LyricFlow is an early Flutter prototype for a lightweight local music player with a fullscreen TV-style interface.

This first phase contains the core UI, local folder scanning, metadata reading, synchronized lyrics, and real local audio playback on Linux when `libmpv` is available.

## ✨ Current Scope

- 🖥️ Fullscreen-oriented dark UI
- 📚 Mock library screen
- 💿 Now playing screen
- 🧭 Navigation between library and player
- 📁 Local folder selection
- 🎮 In-app folder browser for keyboard/gamepad navigation
- 🔎 Recursive scanning for `.flac`, `.mp3`, and `.wav`
- 🏷️ Metadata reading with filename fallback
- 🖼️ Embedded cover art display when available
- ▶️ Real play/pause and previous/next playback for local files
- 🎚️ Progress and lyric synchronization from the real audio position
- 🎤 Synchronized `.lrc` lyric parsing from files next to the song
- 🌐 Automatic synchronized lyric lookup through LRCLIB when no local `.lrc` is found
- ⌨️ Basic keyboard shortcuts:
  - Arrow keys: move focus
  - Enter: select/open
  - Escape: go back
  - Space: play/pause
- 🎮 Basic SDL gamepad input on desktop:
  - D-pad / left stick: move focus
  - Nintendo A: select/open
  - Nintendo B: go back
  - Start: play/pause

The current default face button mapping is tuned for a Nintendo Switch Pro Controller. If using an Xbox-style controller, change `GamepadInputScope.faceButtonLayout` to `GamepadFaceButtonLayout.standard`.

The desktop gamepad path uses SDL through `flutter_sdl_gamepad`, because Linux gaming stacks such as Steam Input, Proton, and many native games rely on SDL-style controller mappings. Android will use a separate native input bridge later.

## 🎮 Gamepad Diagnostics

On Bazzite/Linux, verify that the controller is visible to the system:

```sh
cat /proc/bus/input/devices | grep -A8 -i "Pro Controller"
ls -la /dev/input/event*
```

When LyricFlow runs, `GamepadInputScope` prints diagnostic lines in the debug console with the prefix:

```text
[LyricFlow gamepad]
```

If the controller appears in `/proc/bus/input/devices` but LyricFlow prints `SDL sees no connected gamepads`, the issue is likely container/sandbox device access, SDL mapping, or the native runner environment.

If SDL fails with `Failed to load dynamic library 'libSDL3.so'`, LyricFlow registers the bundled SDL library from the Flutter Linux build output before initializing the gamepad backend. Re-run:

```sh
flutter pub get
flutter run -d linux
```

If CMake complains about `/usr/bin/ninja-build`, install `ninja-build` or create a compatibility symlink to the existing `ninja` binary.

## 🔊 Audio Playback On Bazzite/Linux

LyricFlow uses `just_audio` with the `just_audio_media_kit` Linux backend. That backend needs `libmpv` at runtime. If the app logs `Cannot find libmpv`, install the mpv shared library on the system that runs the Flutter Linux app.

On Bazzite/Fedora Atomic:

```sh
rpm-ostree install mpv-libs mpv-devel
systemctl reboot
```

After rebooting, verify that `libmpv` is visible:

```sh
ldconfig -p | grep libmpv
```

If you run Flutter from a sandboxed editor or container, make sure that environment can also see the host library. Running from a host terminal is the simplest first check:

```sh
cd /home/sebas/Documentos/LyricFlow
/var/home/sebas/development/flutter/bin/flutter run -d linux
```

## 📝 Notes

The Flutter CLI was not available when this scaffold was created, so native platform runner folders were not generated. Once Flutter is installed, run:

```sh
flutter create . --platforms=linux,windows,android
flutter pub get
flutter run -d linux
```
