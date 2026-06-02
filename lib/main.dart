import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'app.dart';
import 'features/player/data/audio_backend.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache
    ..maximumSize = 36
    ..maximumSizeBytes = 32 << 20;
  try {
    JustAudioMediaKit.ensureInitialized(linux: true, windows: false);
    AudioBackend.markAvailable();
  } catch (error, stackTrace) {
    AudioBackend.markUnavailable(error);
    debugPrint('LyricFlow audio backend unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const LyricFlowApp());
}
