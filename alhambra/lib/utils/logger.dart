import 'dart:io';
import 'package:flutter/material.dart';

File? _logFile;
IOSink? _logSink;

void _initLogger() {
  if (_logSink != null) return;
  try {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      final dir = Directory('$home/.andalus/logs');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _logFile = File('${dir.path}/alhambra.log');
      _logSink = _logFile!.openWrite(mode: FileMode.append);
    }
  } catch (e) {
    debugPrint('Failed to initialize file logger: $e');
  }
}

typedef FrontendLogListener = void Function(
    String level, String message, String formattedLine);

final List<FrontendLogListener> _listeners = [];
final List<String> _recentFrontendLogs = [];
const int _maxLogBufferSize = 500;

void registerFrontendLogListener(FrontendLogListener listener) {
  if (!_listeners.contains(listener)) {
    _listeners.add(listener);
  }
}

void unregisterFrontendLogListener(FrontendLogListener listener) {
  _listeners.remove(listener);
}

List<String> getRecentFrontendLogs() => List.unmodifiable(_recentFrontendLogs);

void _dispatchLog(String level, String message) {
  final now = DateTime.now();
  final timestamp =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
  final formattedLine = '$timestamp [$level] [Alhambra UI] $message';

  _recentFrontendLogs.add(formattedLine);
  if (_recentFrontendLogs.length > _maxLogBufferSize) {
    _recentFrontendLogs.removeRange(
        0, _recentFrontendLogs.length - _maxLogBufferSize);
  }

  for (final listener in List<FrontendLogListener>.from(_listeners)) {
    try {
      listener(level, message, formattedLine);
    } catch (_) {}
  }
}

void _writeToFile(String level, String message) {
  _initLogger();
  _dispatchLog(level, message);
  if (_logSink == null) return;

  try {
    final now = DateTime.now();
    final timestamp =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    final formattedMessage = '$timestamp [$level] alhambra_gui: $message';

    _logSink!.writeln(formattedMessage);
  } catch (e) {
    debugPrint('Failed to write to log sink: $e');
    try {
      _logSink?.close();
    } catch (_) {}
    _logSink = null;
  }
}

void logRaw(String message) {
  _initLogger();
  if (_logSink == null) return;

  try {
    _logSink!.writeln(message);
  } catch (e) {
    debugPrint('Failed to write raw to log sink: $e');
    try {
      _logSink?.close();
    } catch (_) {}
    _logSink = null;
  }
}

void logPrint(String message, [dynamic name, String? s]) {
  debugPrint('[INFO]: $message');
  _writeToFile('INFO', message);
}

void logInfo(String message) {
  debugPrint('[INFO]: $message');
  _writeToFile('INFO', message);
}

void logError(String message) {
  debugPrint('[ERROR]: $message');
  _writeToFile('ERROR', message);
}

void logDebug(String message) {
  debugPrint('[DEBUG]: $message');
  _writeToFile('DEBUG', message);
}

void logWarning(String message) {
  debugPrint('[WARNING]: $message');
  _writeToFile('WARNING', message);
}

void logFatal(String message) {
  debugPrint('[FATAL]: $message');
  _writeToFile('FATAL', message);
}

void logTrace(String message) {
  debugPrint('[TRACE]: $message');
  _writeToFile('TRACE', message);
}
