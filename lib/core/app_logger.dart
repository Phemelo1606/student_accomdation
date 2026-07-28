import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Thin wrapper around dart:developer's log() so call sites read like
/// print() but respect log levels and get stripped from release builds.
class AppLogger {
  static void log(Object? message, {String name = 'app'}) {
    if (kDebugMode) {
      developer.log(message.toString(), name: name);
    }
  }

  static void error(Object? message,
      {String name = 'app', Object? error, StackTrace? stackTrace}) {
    developer.log(
      message.toString(),
      name: name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
