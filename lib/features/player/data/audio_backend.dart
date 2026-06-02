class AudioBackend {
  const AudioBackend._();

  static bool isAvailable = false;
  static Object? initializationError;

  static void markAvailable() {
    isAvailable = true;
    initializationError = null;
  }

  static void markUnavailable(Object error) {
    isAvailable = false;
    initializationError = error;
  }
}
