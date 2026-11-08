import 'dart:io';

enum LogLevel { info, warning, error }

enum LogScope { designer, server }

class LogFileService {
  static List<Directory> _logsDirs(LogScope scope) {
    final name = scope == LogScope.designer ? 'designer' : 'server';
    return _candidateHomeDirectories()
        .map((home) => Directory('$home/.andalus/logs/$name'))
        .toList();
  }

  static Future<void> logSnackbar(
    String message, {
    required LogLevel level,
    String source = 'designer',
    Object? error,
    StackTrace? stackTrace,
  }) async {
    try {
      final logsDir = _logsDirs(LogScope.designer).first;
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      final now = DateTime.now();
      final yyyy = now.year.toString().padLeft(4, '0');
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');
      final logFile = File('${logsDir.path}/designer-$yyyy-$mm-$dd.log');

      final levelText = level.name.toUpperCase();
      final buffer = StringBuffer()
        ..write('[${now.toIso8601String()}] ')
        ..write('[$levelText] ')
        ..write('[$source] ')
        ..writeln(message);

      if (error != null) {
        buffer.writeln('  error: $error');
      }
      if (stackTrace != null) {
        buffer.writeln('  stackTrace: $stackTrace');
      }

      await logFile.writeAsString(buffer.toString(), mode: FileMode.append);
    } catch (_) {
      // Logging must never break UI flow.
    }
  }

  static Future<void> logServer(String message) async {
    try {
      final logsDir = _logsDirs(LogScope.server).first;
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }
      final logFile = File('${logsDir.path}/server.log');
      await logFile.writeAsString('$message\n', mode: FileMode.append);
    } catch (_) {}
  }

  static Future<List<File>> listLogFiles({required LogScope scope}) async {
    final files = <File>[];
    final explicitlyKnown = <File>{};

    for (final filePath in _explicitLogFileCandidates(scope)) {
      final candidate = File(filePath);
      try {
        if (await candidate.exists()) {
          explicitlyKnown.add(candidate);
        }
      } catch (_) {
        // Ignore inaccessible file path candidate.
      }
    }

    for (final logsDir in _logsDirs(scope)) {
      bool exists = false;
      try {
        exists = await logsDir.exists();
      } catch (_) {
        // Skip directories that cannot be accessed in current sandbox mode.
        continue;
      }
      if (!exists) {
        continue;
      }
      try {
        final entities = await logsDir.list().toList();
        files.addAll(
          entities.whereType<File>().where((f) => f.path.endsWith('.log')),
        );
      } catch (_) {
        // If listing fails (sandbox/entitlement), fall back to known filenames.
        for (final basename in _knownLogBasenames(scope)) {
          final fallback = File('${logsDir.path}/$basename');
          try {
            if (await fallback.exists()) {
              explicitlyKnown.add(fallback);
            }
          } catch (_) {
            // Ignore inaccessible fallback candidate.
          }
        }
      }
    }

    files.addAll(explicitlyKnown);

    files.sort((a, b) {
      DateTime aModified = DateTime.fromMillisecondsSinceEpoch(0);
      DateTime bModified = DateTime.fromMillisecondsSinceEpoch(0);
      try {
        aModified = a.statSync().modified;
      } catch (_) {}
      try {
        bModified = b.statSync().modified;
      } catch (_) {}
      final byModified = bModified.compareTo(aModified);
      if (byModified != 0) return byModified;

      final aName = a.path.split(Platform.pathSeparator).last;
      final bName = b.path.split(Platform.pathSeparator).last;
      return bName.compareTo(aName);
    });
    // De-duplicate by absolute path
    final seen = <String>{};
    return files.where((f) => seen.add(f.absolute.path)).toList();
  }

  static Future<String> readLogFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  static Future<void> clearLogFiles({required LogScope scope}) async {
    final files = await listLogFiles(scope: scope);
    for (final file in files) {
      await file.delete();
    }
  }

  static Future<int> cleanupLegacyCloudSaveErrorLogs() async {
    final files = await listLogFiles(scope: LogScope.designer);
    var removedEntries = 0;

    for (final file in files) {
      final original = await file.readAsString();
      if (original.trim().isEmpty) continue;

      final lines = original.split('\n');
      final kept = <String>[];
      var skippingLegacyBlock = false;

      for (final line in lines) {
        final isLegacyStart =
            line.contains('[ERROR] [appbar] Save cloud failed (') &&
                line.contains(
                  'Ensure local control API supports POST /api/v1/projects.',
                );

        if (isLegacyStart) {
          skippingLegacyBlock = true;
          removedEntries++;
          continue;
        }

        if (skippingLegacyBlock) {
          // Keep skipping until a new timestamped log entry starts.
          final isNewLogEntry = line.startsWith('[');
          if (!isNewLogEntry) {
            continue;
          }
          skippingLegacyBlock = false;
        }

        kept.add(line);
      }

      final next = kept.join('\n');
      if (next != original) {
        await file.writeAsString(next);
      }
    }

    return removedEntries;
  }

  static String _resolveHomeDirectory() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      return env['USERPROFILE'] ?? Directory.current.path;
    }
    return env['HOME'] ?? Directory.current.path;
  }

  static List<String> _candidateHomeDirectories() {
    final env = Platform.environment;
    final homes = <String>{};
    final resolved = _resolveHomeDirectory();
    if (resolved.isNotEmpty) homes.add(resolved);

    final explicitHome = env['HOME'];
    if (explicitHome != null && explicitHome.isNotEmpty) {
      homes.add(explicitHome);
    }
    final userProfile = env['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) {
      homes.add(userProfile);
    }
    final user = env['USER'];
    if (Platform.isMacOS && user != null && user.isNotEmpty) {
      homes.add('/Users/$user');
    }
    return homes.toList();
  }

  static Iterable<String> _knownLogBasenames(LogScope scope) {
    if (scope == LogScope.server) {
      return const [
        'server.log',
        'cloud-projects.json',
        'cloud-project-executions.json',
        'cloud-project-execution-events.json',
      ];
    }
    return const ['designer.log'];
  }

  static Iterable<String> _explicitLogFileCandidates(LogScope scope) sync* {
    final env = Platform.environment;

    if (scope == LogScope.server) {
      final logFilePath = env['ANDALUS_LOG_FILE_PATH'];
      if (logFilePath != null && logFilePath.trim().isNotEmpty) {
        yield logFilePath.trim();
      }
      final logDir = env['ANDALUS_SERVER_LOG_DIR'];
      if (logDir != null && logDir.trim().isNotEmpty) {
        final normalizedDir = logDir.trim().replaceAll('\\', '/');
        for (final basename in _knownLogBasenames(scope)) {
          yield '$normalizedDir/$basename';
        }
      }
    }

    for (final home in _candidateHomeDirectories()) {
      final normalizedHome = home.replaceAll('\\', '/');
      final logsSubdir = scope == LogScope.server ? 'server' : 'designer';
      for (final basename in _knownLogBasenames(scope)) {
        yield '$normalizedHome/.andalus/logs/$logsSubdir/$basename';
      }
    }
  }
}
