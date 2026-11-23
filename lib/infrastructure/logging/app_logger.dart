import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Logging levels for the application.
enum LogLevel { debug, info, warning, error }

/// Log entry with timestamp, level, and message.
class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  String get formatted {
    final time = timestamp.toIso8601String().substring(11, 23);
    final levelStr = level.name.toUpperCase().padRight(7);
    return '[$time] $levelStr $message';
  }
}

/// Centralized logging service for the application.
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  final List<LogEntry> _entries = [];
  final StreamController<LogEntry> _logController =
      StreamController<LogEntry>.broadcast();
  bool _enabled = true;
  LogLevel _minLevel = LogLevel.debug;

  /// Stream of log entries for UI consumption.
  Stream<LogEntry> get stream => _logController.stream;

  /// Current log entries.
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Enable or disable logging.
  set enabled(bool value) => _enabled = value;

  /// Set minimum log level.
  set minLevel(LogLevel level) => _minLevel = level;

  /// Log a debug message.
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  /// Log an info message.
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  /// Log a warning message.
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  /// Log an error message.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  /// Log an exception with stack trace.
  void exception(Object error, StackTrace stackTrace, [String? context]) {
    _log(
      LogLevel.error,
      context ?? 'Exception occurred',
      error,
      stackTrace,
    );
  }

  void _log(LogLevel level, String message, [Object? error, StackTrace? stackTrace]) {
    if (!_enabled || level.index < _minLevel.index) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    _entries.add(entry);
    if (_entries.length > 1000) {
      _entries.removeRange(0, _entries.length - 1000);
    }

    _logController.add(entry);

    // Also print to console for debugging
    if (kDebugMode) {
      print(entry.formatted);
      if (error != null) print('  Error: $error');
      if (stackTrace != null) print('  Stack: $stackTrace');
    }
  }

  /// Clear all log entries.
  void clear() {
    _entries.clear();
  }

  /// Export logs to a file.
  Future<File> exportToFile(String path) async {
    final file = File(path);
    final content = _entries.map((e) => e.formatted).join('\n');
    return file.writeAsString(content);
  }

  /// Dispose resources.
  void dispose() {
    _logController.close();
  }
}

/// Global logger instance.
final appLogger = AppLogger();
