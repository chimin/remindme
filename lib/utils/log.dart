import 'dart:developer' as dev;

void logError(String message, Object? error, StackTrace? stackTrace) {
  dev.log(
    message,
    error: error,
    stackTrace: stackTrace,
    level: 1000,
  );
}
