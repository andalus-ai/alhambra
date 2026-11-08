import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../log/services/log_file_service.dart';
import '../../../utils/logger.dart';

enum BackendStatus {
  stopped,
  starting,
  running,
  error,
}

enum ServerType {
  alhambra,
  gollek,
  frontend,
}

class SingleServerState {
  final String name;
  final String description;
  final BackendStatus status;
  final int? pid;
  final DateTime? startedAt;
  final String? lastError;
  final List<String> logs;

  const SingleServerState({
    this.name = '',
    this.description = '',
    this.status = BackendStatus.stopped,
    this.pid,
    this.startedAt,
    this.lastError,
    this.logs = const [],
  });

  Duration get uptime =>
      startedAt != null ? DateTime.now().difference(startedAt!) : Duration.zero;

  SingleServerState copyWith({
    String? name,
    String? description,
    BackendStatus? status,
    int? pid,
    DateTime? startedAt,
    String? lastError,
    List<String>? logs,
  }) {
    return SingleServerState(
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      pid: pid ?? this.pid,
      startedAt: startedAt ?? this.startedAt,
      lastError: lastError ?? this.lastError,
      logs: logs ?? this.logs,
    );
  }
}

class BackendState {
  final SingleServerState alhambra;
  final SingleServerState gollek;
  final SingleServerState frontend;
  final List<String> logs;
  final String activeLogTab; // 'all', 'alhambra', 'gollek', 'frontend'

  const BackendState({
    this.alhambra = const SingleServerState(
      name: 'Alhambra Platform',
      description: 'Autonomous Coding Agent & Workflow Substrate',
    ),
    this.gollek = const SingleServerState(
      name: 'Gollek Inference',
      description: 'High-Performance Local Neural LLM Engine',
    ),
    this.frontend = const SingleServerState(
      name: 'Alhambra Vibe Coder',
      description: 'Desktop Studio & Extensible IDE Shell',
      status: BackendStatus.running,
    ),
    this.logs = const [],
    this.activeLogTab = 'all',
  });

  bool get isAnyRunning =>
      alhambra.status == BackendStatus.running ||
      gollek.status == BackendStatus.running;

  bool get isAllRunning =>
      alhambra.status == BackendStatus.running &&
      gollek.status == BackendStatus.running;

  BackendStatus get status => overallStatus;

  BackendStatus get overallStatus {
    if (alhambra.status == BackendStatus.error ||
        gollek.status == BackendStatus.error) {
      return BackendStatus.error;
    }
    if (alhambra.status == BackendStatus.starting ||
        gollek.status == BackendStatus.starting) {
      return BackendStatus.starting;
    }
    if (alhambra.status == BackendStatus.running ||
        gollek.status == BackendStatus.running) {
      return BackendStatus.running;
    }
    return BackendStatus.stopped;
  }

  BackendState copyWith({
    BackendStatus? status,
    SingleServerState? alhambra,
    SingleServerState? gollek,
    SingleServerState? frontend,
    List<String>? logs,
    String? activeLogTab,
  }) {
    return BackendState(
      alhambra: alhambra ??
          (status != null ? this.alhambra.copyWith(status: status) : this.alhambra),
      gollek: gollek ?? this.gollek,
      frontend: frontend ?? this.frontend,
      logs: logs ?? this.logs,
      activeLogTab: activeLogTab ?? this.activeLogTab,
    );
  }
}

/// Lightweight parser for .env / .env.local configuration files.
class DotEnvLoader {
  static final Map<String, String> _envVars = {};
  static bool _loaded = false;

  static void ensureLoaded() {
    if (_loaded) return;
    _loaded = true;

    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';

    final probeDirs = <Directory>[
      Directory.current.absolute,
      File(Platform.resolvedExecutable).parent.absolute,
    ];

    final candidateLocations = <String>[
      '${Directory.current.path}/.env',
      '${Directory.current.path}/.env.local',
      '${Directory.current.path}/.env.development',
      '${Directory.current.path}/.env.production',
      '$home/.alhambra/.env',
      '$home/.andalus/.env',
    ];

    for (final startDir in probeDirs) {
      Directory current = startDir;
      for (int i = 0; i < 6; i++) {
        candidateLocations.add('${current.path}/.env');
        candidateLocations.add('${current.path}/.env.local');
        candidateLocations.add('${current.path}/.env.development');
        if (current.parent.path == current.path) break;
        current = current.parent;
      }
    }

    for (final loc in candidateLocations) {
      final file = File(loc);
      if (file.existsSync()) {
        try {
          final lines = file.readAsLinesSync();
          for (final rawLine in lines) {
            final line = rawLine.trim();
            if (line.isEmpty || line.startsWith('#')) continue;
            final idx = line.indexOf('=');
            if (idx > 0) {
              final key = line.substring(0, idx).trim();
              var val = line.substring(idx + 1).trim();
              if ((val.startsWith('"') && val.endsWith('"')) ||
                  (val.startsWith("'") && val.endsWith("'"))) {
                val = val.substring(1, val.length - 1);
              }
              _envVars.putIfAbsent(key, () => val);
            }
          }
        } catch (_) {}
      }
    }
  }

  static String? get(String key) {
    ensureLoaded();
    return Platform.environment[key] ?? _envVars[key];
  }

  static Map<String, String> getAll() {
    ensureLoaded();
    return Map.unmodifiable(_envVars);
  }
}

/// Dynamic Workspace & Path Resolver without hardcoded paths.
class DynamicPathResolver {
  static String? _cachedWorkspaceRoot;

  static String get homeDir =>
      DotEnvLoader.get('HOME') ?? Platform.environment['USERPROFILE'] ?? '';

  static String expandPath(String path) {
    if (path.startsWith('~/')) {
      final home = homeDir;
      return home.isNotEmpty ? '$home/${path.substring(2)}' : path;
    } else if (path == '~') {
      return homeDir;
    }
    return path;
  }

  /// Automatically discovers the root of the andalus-platform repository.
  static String resolveWorkspaceRoot() {
    if (_cachedWorkspaceRoot != null &&
        Directory(_cachedWorkspaceRoot!).existsSync()) {
      return _cachedWorkspaceRoot!;
    }

    // 1. Check environment variables & .env
    for (final envKey in [
      'ANDALUS_SOURCE_PATH',
      'ANDALUS_HOME',
      'PROJECT_ROOT',
      'WORKSPACE_ROOT',
      'ALHAMBRA_SOURCE_PATH',
      'ALHAMBRA_HOME'
    ]) {
      final val = DotEnvLoader.get(envKey);
      if (val != null && val.trim().isNotEmpty) {
        final expanded = expandPath(val.trim());
        if (Directory(expanded).existsSync()) {
          _cachedWorkspaceRoot = expanded;
          return expanded;
        }
      }
    }

    // 2. Walk up directory tree from current working directory & executable
    final probeDirs = <Directory>[
      Directory.current.absolute,
      File(Platform.resolvedExecutable).parent.absolute,
    ];

    for (final startDir in probeDirs) {
      Directory current = startDir;
      while (true) {
        final familiesDir = Directory('${current.path}/Families');
        final projectsDir = Directory('${current.path}/Projects');
        final andalusProjectsDir =
            Directory('${current.path}/Andalus-Projects');
        if (familiesDir.existsSync() &&
            (projectsDir.existsSync() || andalusProjectsDir.existsSync())) {
          _cachedWorkspaceRoot = current.path;
          return current.path;
        }

        if (Directory('${current.path}/Community/Backend/alhambra-api')
                .existsSync() ||
            Directory('${current.path}/Backend/alhambra-api').existsSync()) {
          Directory cand = current;
          for (int i = 0; i < 4; i++) {
            if (cand.parent.path == cand.path) break;
            cand = cand.parent;
            if (Directory('${cand.path}/Families').existsSync() ||
                Directory('${cand.path}/Projects').existsSync()) {
              _cachedWorkspaceRoot = cand.path;
              return cand.path;
            }
          }
        }

        if (current.parent.path == current.path) break;
        current = current.parent;
      }
    }

    // 3. Fallback dynamically relative to user's home directory
    final home = homeDir;
    if (home.isNotEmpty) {
      final commonRelativePaths = [
        '$home/Workspace/workkayys/Products/Andalus/andalus-platform',
        '$home/Workspace/Andalus/andalus-platform',
        '$home/Workspace/andalus-platform',
        '$home/Projects/andalus-platform',
        '$home/andalus-platform',
        '$home/.andalus',
      ];
      for (final p in commonRelativePaths) {
        if (Directory(p).existsSync()) {
          _cachedWorkspaceRoot = p;
          return p;
        }
      }
    }

    return Directory.current.absolute.path;
  }

  static String resolveAlhambraApiDir() {
    // 1. Explicit environment / .env configuration
    final explicit = DotEnvLoader.get('ALHAMBRA_SOURCE_PATH') ??
        DotEnvLoader.get('ALHAMBRA_HOME');
    if (explicit != null && Directory(expandPath(explicit)).existsSync()) {
      final exp = expandPath(explicit);
      if (Directory('$exp/Community/Backend/alhambra-api').existsSync()) {
        return '$exp/Community/Backend/alhambra-api';
      }
      if (Directory('$exp/Backend/alhambra-api').existsSync()) {
        return '$exp/Backend/alhambra-api';
      }
      if (Directory('$exp/alhambra-api').existsSync()) {
        return '$exp/alhambra-api';
      }
      return exp;
    }

    final root = resolveWorkspaceRoot();
    final candidates = [
      '$root/Projects/Andalus-Agents/AlhambraCoder/Community/Backend/alhambra-api',
      '$root/Projects/Andalus-Agents/AlhambraCoder/Backend/alhambra-api',
      '$root/Projects/Andalus-Agents/Alhambra/Community/Backend/alhambra-api',
      '$root/Projects/Andalus-Agents/Alhambra/Backend/alhambra-api',
      '$root/Andalus-Projects/Andalus-Agents/AlhambraCoder/Community/Backend/alhambra-api',
      '$root/Andalus-Projects/Andalus-Agents/AlhambraCoder/Backend/alhambra-api',
      '$root/Andalus-Projects/Andalus-Agents/Alhambra/Community/Backend/alhambra-api',
      '$root/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-api',
      '$root/Andalus-Agents/AlhambraCoder/Backend/alhambra-api',
      '$root/Andalus-Agents/Alhambra/Backend/alhambra-api',
      '$root/Community/Backend/alhambra-api',
      '$root/Backend/alhambra-api',
      '$root/alhambra-api',
      '${Directory.current.path}/../../../../AlhambraCoder/Community/Backend/alhambra-api',
      '${Directory.current.path}/../../AlhambraCoder/Community/Backend/alhambra-api',
      '${Directory.current.path}/../Community/Backend/alhambra-api',
      '${Directory.current.path}/../Backend/alhambra-api',
      '$homeDir/.andalus/bin',
      '$homeDir/.alhambra/bin',
    ];

    for (final c in candidates) {
      if (Directory(c).existsSync()) return Directory(c).absolute.path;
    }
    return candidates.first;
  }

  static String resolveGollekDir() {
    final explicit = DotEnvLoader.get('GOLLEK_SOURCE_PATH') ??
        DotEnvLoader.get('GOLLEK_HOME');
    if (explicit != null && Directory(expandPath(explicit)).existsSync()) {
      return expandPath(explicit);
    }

    final root = resolveWorkspaceRoot();
    final candidates = [
      '$root/Families/gollek',
      '$root/Projects/gollek',
      '$root/gollek',
      '${Directory.current.path}/../../../../Families/gollek',
      '$homeDir/.gollek',
    ];

    for (final c in candidates) {
      if (Directory(c).existsSync()) return Directory(c).absolute.path;
    }
    return candidates.first;
  }
}

class BackendProcessNotifier extends Notifier<BackendState> {
  Process? _alhambraProcess;
  Process? _gollekProcess;

  @override
  BackendState build() {
    DotEnvLoader.ensureLoaded();

    registerFrontendLogListener((level, message, formattedLine) {
      _appendLog('[$level] $message', ServerType.frontend);
    });

    final recent = getRecentFrontendLogs();
    final initialFrontendLogs = List<String>.from(recent);
    final initialLogs = List<String>.from(recent);

    final initialState = BackendState(
      frontend: const SingleServerState(
        name: 'Alhambra Vibe Coder',
        description: 'Desktop Studio & Extensible IDE Shell',
        status: BackendStatus.running,
      ).copyWith(logs: initialFrontendLogs),
      logs: initialLogs,
    );

    Future.microtask(probeServers);
    return initialState;
  }

  Future<void> probeServers() async {
    try {
      final alhambraRunning =
          await _isPortListening(8085) || await _isPortListening(9000);
      if (alhambraRunning && state.alhambra.status != BackendStatus.running) {
        state = state.copyWith(
          alhambra: state.alhambra.copyWith(
            status: BackendStatus.running,
            startedAt: state.alhambra.startedAt ?? DateTime.now(),
          ),
        );
        _appendLog('ℹ️ [Alhambra] Online and listening on HTTP 8085 / gRPC 9000',
            ServerType.alhambra);
      } else if (!alhambraRunning &&
          state.alhambra.status == BackendStatus.running &&
          _alhambraProcess == null) {
        state = state.copyWith(
          alhambra:
              state.alhambra.copyWith(status: BackendStatus.stopped, pid: null),
        );
      }

      final gollekRunning = await _isPortListening(9131) ||
          await _isPortListening(8080) ||
          await _isPortListening(8082);
      if (gollekRunning && state.gollek.status != BackendStatus.running) {
        state = state.copyWith(
          gollek: state.gollek.copyWith(
            status: BackendStatus.running,
            startedAt: state.gollek.startedAt ?? DateTime.now(),
          ),
        );
        _appendLog('ℹ️ [Gollek] Online and listening on gRPC 9131 / HTTP 8080',
            ServerType.gollek);
      } else if (!gollekRunning &&
          state.gollek.status == BackendStatus.running &&
          _gollekProcess == null) {
        state = state.copyWith(
          gollek:
              state.gollek.copyWith(status: BackendStatus.stopped, pid: null),
        );
      }
    } catch (_) {}
  }

  Future<bool> _isPortListening(int port) async {
    try {
      final res = await Process.run(
        'sh',
        ['-c', 'lsof -n -P -tiTCP:$port -sTCP:LISTEN 2>/dev/null'],
      );
      return res.stdout.toString().trim().isNotEmpty;
    } catch (_) {
      try {
        final socket = await Socket.connect('127.0.0.1', port,
            timeout: const Duration(milliseconds: 300));
        socket.destroy();
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // ── Alhambra Service Controls ───────────────────────────────────────────────

  Future<void> startAlhambra() async {
    if (_alhambraProcess != null ||
        state.alhambra.status == BackendStatus.running) {
      return;
    }

    state = state.copyWith(
      alhambra: state.alhambra.copyWith(status: BackendStatus.starting, logs: []),
    );
    _appendLog(
        '🚀 Launching Alhambra Agent & Substrate Backend...', ServerType.alhambra);

    try {
      final alhambraDir = DynamicPathResolver.resolveAlhambraApiDir();
      final scriptFile = File('$alhambraDir/start-local.sh');
      final binaryFile = File('$alhambraDir/andalus');
      final jarFile = File('$alhambraDir/target/quarkus-app/quarkus-run.jar');

      String executable;
      List<String> arguments;
      String workingDir = alhambraDir;

      if (scriptFile.existsSync()) {
        executable = '/bin/bash';
        arguments = [scriptFile.path];
      } else if (binaryFile.existsSync()) {
        executable = binaryFile.path;
        arguments = [];
      } else if (jarFile.existsSync()) {
        executable = 'java';
        arguments = [
          '-Dquarkus.http.port=8085',
          '-Dquarkus.grpc.server.port=9000',
          '-jar',
          jarFile.path
        ];
      } else {
        final mvnPath = await _resolveExecutable('mvn');
        executable = mvnPath ?? 'mvn';
        arguments = ['quarkus:dev', '-Dquarkus.http.port=8085'];
      }

      if (!Directory(workingDir).existsSync()) {
        throw Exception('Alhambra backend directory not found: $workingDir\n'
            'Please ensure AlhambraCoder is checked out under Projects/Andalus-Agents/AlhambraCoder/Community/Backend/alhambra-api.');
      }

      _appendLog('• Working Directory: $workingDir', ServerType.alhambra);
      _appendLog(
          '• Command: $executable ${arguments.join(' ')}', ServerType.alhambra);

      final env = _buildEnvironment();

      _alhambraProcess = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDir,
        environment: env,
      );

      final pid = _alhambraProcess!.pid;
      state = state.copyWith(
        alhambra: state.alhambra.copyWith(
          pid: pid,
          startedAt: DateTime.now(),
        ),
      );

      _alhambraProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _appendLog(line, ServerType.alhambra);
        if (state.alhambra.status == BackendStatus.starting &&
            (line.contains('Listening on: http://localhost:8085') ||
                line.contains('8085') ||
                line.contains('Installed features:'))) {
          state = state.copyWith(
            alhambra: state.alhambra.copyWith(status: BackendStatus.running),
          );
        }
      });

      _alhambraProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _appendLog(line, ServerType.alhambra);
      });

      _alhambraProcess!.exitCode.then((code) {
        _alhambraProcess = null;
        _appendLog(
            'Alhambra backend process exited with code $code', ServerType.alhambra);
        if (code != 0 && code != 143) {
          state = state.copyWith(
            alhambra: state.alhambra.copyWith(
              status: BackendStatus.error,
              lastError: 'Exited with code $code',
              pid: null,
            ),
          );
        } else {
          state = state.copyWith(
            alhambra: state.alhambra.copyWith(
              status: BackendStatus.stopped,
              pid: null,
            ),
          );
        }
      });
    } catch (e, stack) {
      _alhambraProcess = null;
      _appendLog(
          '❌ Failed to start Alhambra backend: $e\n$stack', ServerType.alhambra);
      state = state.copyWith(
        alhambra: state.alhambra.copyWith(
          status: BackendStatus.error,
          lastError: e.toString(),
          pid: null,
        ),
      );
    }
  }

  Future<void> stopAlhambra() async {
    _appendLog(
        '🛑 Stopping Alhambra Agent & Substrate Backend...', ServerType.alhambra);
    if (_alhambraProcess != null) {
      _alhambraProcess!.kill();
      _alhambraProcess = null;
    }
    try {
      await Process.run('sh', [
        '-c',
        'lsof -n -P -tiTCP:8085,9000 -sTCP:LISTEN | xargs kill -9 2>/dev/null'
      ]);
    } catch (_) {}
    state = state.copyWith(
      alhambra: state.alhambra.copyWith(status: BackendStatus.stopped, pid: null),
    );
  }

  Future<void> restartAlhambra() async {
    await stopAlhambra();
    await Future.delayed(const Duration(milliseconds: 500));
    await startAlhambra();
  }

  // ── Gollek Service Controls ───────────────────────────────────────────────

  Future<void> startGollek() async {
    if (_gollekProcess != null ||
        state.gollek.status == BackendStatus.running) {
      return;
    }

    state = state.copyWith(
      gollek: state.gollek.copyWith(status: BackendStatus.starting, logs: []),
    );
    _appendLog('🧠 Launching Gollek Inference Server...', ServerType.gollek);

    try {
      final root = DynamicPathResolver.resolveWorkspaceRoot();
      final gollekDir = DynamicPathResolver.resolveGollekDir();

      final scriptCandidates = [
        '$root/Projects/Andalus-Agents/AlhambraCoder/Community/Backend/start-gollek.sh',
        '$root/Projects/Andalus-Agents/AlhambraCoder/Backend/start-gollek.sh',
        '$root/Projects/Andalus-Agents/Alhambra/Community/Backend/start-gollek.sh',
        '$root/Projects/Andalus-Agents/Alhambra/Backend/start-gollek.sh',
        '$root/Andalus-Projects/Andalus-Agents/AlhambraCoder/Community/Backend/start-gollek.sh',
        '$root/Andalus-Projects/Andalus-Agents/AlhambraCoder/Backend/start-gollek.sh',
        '$root/Andalus-Projects/Andalus-Agents/Alhambra/Community/Backend/start-gollek.sh',
        '$root/Andalus-Projects/Andalus-Agents/Alhambra/Backend/start-gollek.sh',
        '$gollekDir/scripts/run-dev-server.sh',
        '$gollekDir/start-dev-server.sh',
      ];

      File? scriptFile;
      for (final p in scriptCandidates) {
        if (File(p).existsSync()) {
          scriptFile = File(p);
          break;
        }
      }

      String executable;
      List<String> arguments;
      String workDir;

      if (scriptFile != null) {
        executable = '/bin/bash';
        arguments = [scriptFile.path];
        workDir = scriptFile.parent.path;
      } else {
        final jarFile = File('$gollekDir/ui/gollek-cli/build/gollek.jar');
        final binaryFile =
            File('${DynamicPathResolver.homeDir}/.gollek/bin/gollek');

        if (binaryFile.existsSync()) {
          executable = binaryFile.path;
          arguments = [];
          workDir = binaryFile.parent.path;
        } else if (jarFile.existsSync()) {
          executable = 'java';
          arguments = [
            '--enable-native-access=ALL-UNNAMED',
            '--add-modules=jdk.incubator.vector',
            '-XX:MaxDirectMemorySize=24g',
            '-jar',
            jarFile.path,
            'serve',
            '--rest',
            '--port=8080',
            '--enable-cpu',
          ];
          workDir = gollekDir;
        } else if (File('$gollekDir/gradlew').existsSync()) {
          executable = './gradlew';
          arguments = [':ui:gollek-cli:quarkusDev', '--console=plain'];
          workDir = gollekDir;
        } else {
          _appendLog(
              '❌ Gollek: no start-gollek.sh, no gollek.jar, no gradlew found.',
              ServerType.gollek);
          _appendLog(
              '   Please build Gollek or run automatic setup from onboarding dialog.',
              ServerType.gollek);
          return;
        }
      }

      _appendLog('• Working Directory: $workDir', ServerType.gollek);
      _appendLog(
          '• Command: $executable ${arguments.join(' ')}', ServerType.gollek);

      final env = _buildEnvironment();

      _gollekProcess = await Process.start(
        executable,
        arguments,
        workingDirectory: Directory(workDir).existsSync() ? workDir : null,
        environment: env,
      );

      final pid = _gollekProcess!.pid;
      state = state.copyWith(
        gollek: state.gollek.copyWith(
          pid: pid,
          startedAt: DateTime.now(),
        ),
      );

      _gollekProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _appendLog(line, ServerType.gollek);
        if (state.gollek.status == BackendStatus.starting &&
            (line.contains('8080') ||
                line.contains('Listening') ||
                line.contains('Started') ||
                line.contains('Serving HTTP'))) {
          state = state.copyWith(
            gollek: state.gollek.copyWith(status: BackendStatus.running),
          );
        }
      });

      _gollekProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _appendLog(line, ServerType.gollek);
      });

      _gollekProcess!.exitCode.then((code) {
        _gollekProcess = null;
        _appendLog('Gollek inference process exited with code $code',
            ServerType.gollek);
        if (code != 0 && code != 143) {
          state = state.copyWith(
            gollek: state.gollek.copyWith(
              status: BackendStatus.error,
              lastError: 'Exited with code $code',
              pid: null,
            ),
          );
        } else {
          state = state.copyWith(
            gollek: state.gollek.copyWith(
              status: BackendStatus.stopped,
              pid: null,
            ),
          );
        }
      });
    } catch (e, stack) {
      _gollekProcess = null;
      _appendLog(
          '❌ Failed to start Gollek server: $e\n$stack', ServerType.gollek);
      state = state.copyWith(
        gollek: state.gollek.copyWith(
          status: BackendStatus.error,
          lastError: e.toString(),
          pid: null,
        ),
      );
    }
  }

  Future<void> stopGollek() async {
    _appendLog('🛑 Stopping Gollek Inference Server...', ServerType.gollek);
    if (_gollekProcess != null) {
      _gollekProcess!.kill();
      _gollekProcess = null;
    }
    try {
      await Process.run('sh', [
        '-c',
        'lsof -n -P -tiTCP:8080,8082,9090,9131 -sTCP:LISTEN | xargs kill -9 2>/dev/null'
      ]);
    } catch (_) {}
    state = state.copyWith(
      gollek: state.gollek.copyWith(status: BackendStatus.stopped, pid: null),
    );
  }

  Future<void> restartGollek() async {
    await stopGollek();
    await Future.delayed(const Duration(milliseconds: 500));
    await startGollek();
  }

  // ── Master Controls (Ordered Boot Sequence) ──────────────────────────────

  Future<void> startAll() async {
    _appendLog('⚙️ Initiating dual-backend startup sequence...', null);

    if (state.alhambra.status != BackendStatus.running) {
      _appendLog('▶️ Starting Alhambra Agent Platform (:8085 / :9000)...',
          ServerType.alhambra);
      await startAlhambra();
    }

    if (state.gollek.status != BackendStatus.running) {
      _appendLog('▶️ Starting Gollek Inference Substrate (:8080)...',
          ServerType.gollek);
      unawaited(startGollek());
    }
  }

  Future<void> stopAll() async {
    _appendLog('🛑 Stopping all active backend services...', null);
    await Future.wait([stopAlhambra(), stopGollek()]);
  }

  Future<void> startBackend() => startAll();

  Future<void> stopBackend() => stopAll();

  void setActiveLogTab(String tab) {
    state = state.copyWith(activeLogTab: tab);
  }

  void clearLogs([ServerType? type]) {
    if (type == null) {
      state = state.copyWith(
        logs: [],
        alhambra: state.alhambra.copyWith(logs: []),
        gollek: state.gollek.copyWith(logs: []),
        frontend: state.frontend.copyWith(logs: []),
      );
    } else if (type == ServerType.alhambra) {
      state = state.copyWith(
        alhambra: state.alhambra.copyWith(logs: []),
      );
    } else if (type == ServerType.gollek) {
      state = state.copyWith(
        gollek: state.gollek.copyWith(logs: []),
      );
    } else if (type == ServerType.frontend) {
      state = state.copyWith(
        frontend: state.frontend.copyWith(logs: []),
      );
    }
  }

  Future<String?> _resolveExecutable(String name) async {
    try {
      final res = await Process.run('which', [name]);
      if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
        return res.stdout.toString().trim();
      }
    } catch (_) {}

    final standardPaths = [
      '/opt/homebrew/bin/$name',
      '/usr/local/bin/$name',
      '/usr/bin/$name',
      '${DynamicPathResolver.homeDir}/.local/bin/$name',
    ];
    for (final p in standardPaths) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }

  Map<String, String> _buildEnvironment() {
    final home = DynamicPathResolver.homeDir;
    final systemPath =
        Platform.environment['PATH'] ?? '/usr/bin:/bin:/usr/sbin:/sbin';
    final path =
        '/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$home/.local/bin:$home/.cargo/bin:$systemPath';
    final javaHome = DotEnvLoader.get('JAVA_HOME') ??
        Platform.environment['JAVA_HOME'] ??
        (Directory('/Library/Java/JavaVirtualMachines/graalvm-25.jdk/Contents/Home')
                .existsSync()
            ? '/Library/Java/JavaVirtualMachines/graalvm-25.jdk/Contents/Home'
            : (Directory(
                        '/Library/Java/JavaVirtualMachines/jdk-28.jdk/Contents/Home')
                    .existsSync()
                ? '/Library/Java/JavaVirtualMachines/jdk-28.jdk/Contents/Home'
                : null));
    final env = <String, String>{
      ...DotEnvLoader.getAll(),
      'HOME': home,
      'USER':
          DotEnvLoader.get('USER') ?? Platform.environment['USER'] ?? 'user',
      'PATH': path,
      if (javaHome != null) 'JAVA_HOME': javaHome,
      if (DotEnvLoader.get('GGUF_CONTEXT_SIZE') != null)
        'GGUF_CONTEXT_SIZE': DotEnvLoader.get('GGUF_CONTEXT_SIZE')!,
      if (DotEnvLoader.get('ALHAMBRA_MODE') != null)
        'ALHAMBRA_MODE': DotEnvLoader.get('ALHAMBRA_MODE')!,
    };
    return env;
  }

  void _appendLog(String text, ServerType? origin) {
    final lines = text.split('\n');
    for (final rawLine in lines) {
      if (rawLine.trim().isEmpty) continue;
      String prefix;
      if (origin == ServerType.alhambra) {
        prefix = 'Alhambra';
      } else if (origin == ServerType.gollek) {
        prefix = 'Gollek';
      } else if (origin == ServerType.frontend) {
        prefix = 'Alhambra UI';
      } else {
        prefix = '';
      }

      final formattedLine = origin != null ? '[$prefix] $rawLine' : rawLine;

      logRaw(formattedLine);
      LogFileService.logServer(formattedLine);

      final newLogs = List<String>.from(state.logs)..add(formattedLine);
      if (newLogs.length > 1500) {
        newLogs.removeRange(0, newLogs.length - 1500);
      }

      SingleServerState? updatedAlhambra;
      SingleServerState? updatedGollek;
      SingleServerState? updatedFrontend;

      if (origin == ServerType.alhambra) {
        final alhambraLogs = List<String>.from(state.alhambra.logs)..add(rawLine);
        if (alhambraLogs.length > 1000) {
          alhambraLogs.removeRange(0, alhambraLogs.length - 1000);
        }
        updatedAlhambra = state.alhambra.copyWith(logs: alhambraLogs);
      } else if (origin == ServerType.gollek) {
        final gollekLogs = List<String>.from(state.gollek.logs)..add(rawLine);
        if (gollekLogs.length > 1000) {
          gollekLogs.removeRange(0, gollekLogs.length - 1000);
        }
        updatedGollek = state.gollek.copyWith(logs: gollekLogs);
      } else if (origin == ServerType.frontend) {
        final frontendLogs = List<String>.from(state.frontend.logs)
          ..add(rawLine);
        if (frontendLogs.length > 1000) {
          frontendLogs.removeRange(0, frontendLogs.length - 1000);
        }
        updatedFrontend = state.frontend.copyWith(logs: frontendLogs);
      }

      state = state.copyWith(
        logs: newLogs,
        alhambra: updatedAlhambra,
        gollek: updatedGollek,
        frontend: updatedFrontend,
      );
    }
  }
}

final backendProcessProvider =
    NotifierProvider<BackendProcessNotifier, BackendState>(
  () => BackendProcessNotifier(),
);
