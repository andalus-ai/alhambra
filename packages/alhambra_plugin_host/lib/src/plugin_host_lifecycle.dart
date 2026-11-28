import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

/// Host lifecycle states. These describe this composition object, not the
/// health state of individual plugins or the operating-system process.
enum PluginHostState {
  created,
  starting,
  running,
  stopping,
  stopped,
  failed,
}

/// A host-owned resource that must outlive plugin callbacks.
///
/// Resources are disposed in reverse registration order. The host constructs
/// and configures resources before creating [PluginHostLifecycle], ensuring
/// they are available before plugin activation begins.
final class PluginHostResource {
  final String id;
  final Future<void> Function() dispose;

  PluginHostResource({
    required this.id,
    required this.dispose,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty');
    }
  }
}

/// A resource disposal failure. Disposal continues for the remaining resources.
final class PluginHostResourceFailure {
  final String resourceId;
  final Object error;
  final StackTrace stackTrace;

  const PluginHostResourceFailure({
    required this.resourceId,
    required this.error,
    required this.stackTrace,
  });
}

/// Result of host startup, including cleanup failures after a failed startup.
final class PluginHostStartupReport {
  final bool succeeded;
  final PluginStartupBatchReport? pluginReport;
  final Object? error;
  final StackTrace? stackTrace;
  final List<PluginHostResourceFailure> resourceFailures;

  PluginHostStartupReport({
    required this.succeeded,
    this.pluginReport,
    this.error,
    this.stackTrace,
    Iterable<PluginHostResourceFailure> resourceFailures = const [],
  }) : resourceFailures =
            List<PluginHostResourceFailure>.unmodifiable(resourceFailures);
}

/// Result of host shutdown.
///
/// [resourcesDisposed] is false when plugin shutdown preflight failed. In
/// that case resources remain open because active plugins may still depend on
/// them; the caller may correct the preflight problem and call shutdown again.
final class PluginHostShutdownReport {
  final bool succeeded;
  final PluginShutdownReport? pluginReport;
  final bool resourcesDisposed;
  final List<PluginHostResourceFailure> resourceFailures;
  final Object? error;
  final StackTrace? stackTrace;

  PluginHostShutdownReport({
    required this.succeeded,
    required this.resourcesDisposed,
    this.pluginReport,
    Iterable<PluginHostResourceFailure> resourceFailures = const [],
    this.error,
    this.stackTrace,
  }) : resourceFailures =
            List<PluginHostResourceFailure>.unmodifiable(resourceFailures);
}

/// Composes plugin startup/shutdown with host-owned resource disposal.
///
/// This class deliberately does not discover plugins, create infrastructure,
/// expose health endpoints, schedule backups, or implement plugin lifecycle
/// semantics. The host supplies trusted compiled plugin instances and
/// preconstructed resources. Existing coordinators retain responsibility for
/// dependency ordering, activation rollback, and reverse-order deactivation.
final class PluginHostLifecycle {
  final PluginStartupCoordinator startupCoordinator;
  final PluginShutdownCoordinator shutdownCoordinator;
  final List<DiscoveredPlugin> discoveredPlugins;
  final Map<String, AlhambraPlugin> compiledPlugins;
  final List<PluginHostResource> resources;

  PluginHostState _state = PluginHostState.created;
  Future<PluginHostStartupReport>? _starting;
  Future<PluginHostShutdownReport>? _stopping;
  PluginHostStartupReport? _startupReport;
  PluginHostShutdownReport? _shutdownReport;
  final Set<String> _disposedResourceIds = <String>{};

  PluginHostLifecycle({
    required this.startupCoordinator,
    required this.shutdownCoordinator,
    required Iterable<DiscoveredPlugin> discoveredPlugins,
    required Map<String, AlhambraPlugin> compiledPlugins,
    Iterable<PluginHostResource> resources = const [],
  })  : discoveredPlugins =
            List<DiscoveredPlugin>.unmodifiable(discoveredPlugins),
        compiledPlugins =
            Map<String, AlhambraPlugin>.unmodifiable(compiledPlugins),
        resources = List<PluginHostResource>.unmodifiable(resources) {
    final ids = <String>{};
    for (final resource in this.resources) {
      if (!ids.add(resource.id)) {
        throw ArgumentError('Duplicate host resource ID "${resource.id}".');
      }
    }
  }

  PluginHostState get state => _state;

  Future<PluginHostStartupReport> start() {
    if (_startupReport != null) {
      return Future<PluginHostStartupReport>.value(_startupReport);
    }
    if (_state == PluginHostState.stopped ||
        _state == PluginHostState.stopping ||
        _state == PluginHostState.failed) {
      return Future<PluginHostStartupReport>.error(
        StateError('A host in state "${_state.name}" cannot be started.'),
      );
    }
    return _starting ??= _start();
  }

  Future<PluginHostStartupReport> _start() async {
    _state = PluginHostState.starting;
    try {
      final report = await startupCoordinator.start(
        discoveredPlugins: discoveredPlugins,
        compiledPlugins: compiledPlugins,
      );
      if (report.succeeded) {
        _state = PluginHostState.running;
        return _startupReport = PluginHostStartupReport(
          succeeded: true,
          pluginReport: report,
        );
      }

      final failures = await _disposeResources();
      _state = PluginHostState.failed;
      return _startupReport = PluginHostStartupReport(
        succeeded: false,
        pluginReport: report,
        error: report.error,
        stackTrace: report.stackTrace,
        resourceFailures: failures,
      );
    } catch (error, stackTrace) {
      final failures = await _disposeResources();
      _state = PluginHostState.failed;
      return _startupReport = PluginHostStartupReport(
        succeeded: false,
        error: error,
        stackTrace: stackTrace,
        resourceFailures: failures,
      );
    }
  }

  /// Stops plugins before disposing resources they may use.
  ///
  /// A shutdown preflight error means no plugin shutdown callback was safely
  /// attempted. Resources are retained in that case and this method can be
  /// called again after the host fixes the invalid discovery/dependency input.
  Future<PluginHostShutdownReport> shutdown() {
    final completed = _shutdownReport;
    if (completed != null && completed.resourcesDisposed) {
      return Future<PluginHostShutdownReport>.value(completed);
    }
    return _stopping ??= _shutdown().whenComplete(() {
      _stopping = null;
    });
  }

  Future<PluginHostShutdownReport> _shutdown() async {
    final starting = _starting;
    if (starting != null) {
      await starting;
    }
    if (_state == PluginHostState.stopped) {
      return _shutdownReport ??= PluginHostShutdownReport(
        succeeded: true,
        resourcesDisposed: true,
      );
    }

    final shouldStopPlugins = _state == PluginHostState.running;
    _state = PluginHostState.stopping;

    PluginShutdownReport? pluginReport;
    if (shouldStopPlugins) {
      try {
        pluginReport = await shutdownCoordinator.shutdown(
          discoveredPlugins: discoveredPlugins,
        );
      } catch (error, stackTrace) {
        _state = PluginHostState.failed;
        return _shutdownReport = PluginHostShutdownReport(
          succeeded: false,
          resourcesDisposed: false,
          error: error,
          stackTrace: stackTrace,
        );
      }

      // A preflight error prevents safe deactivation. Keep plugin dependencies
      // alive rather than disposing resources under potentially active plugins.
      if (pluginReport.error != null) {
        _state = PluginHostState.failed;
        return _shutdownReport = PluginHostShutdownReport(
          succeeded: false,
          pluginReport: pluginReport,
          resourcesDisposed: false,
          error: pluginReport.error,
          stackTrace: pluginReport.stackTrace,
        );
      }
    }

    final failures = await _disposeResources();
    final succeeded = (pluginReport?.succeeded ?? true) && failures.isEmpty;
    _state = succeeded ? PluginHostState.stopped : PluginHostState.failed;
    return _shutdownReport = PluginHostShutdownReport(
      succeeded: succeeded,
      pluginReport: pluginReport,
      resourcesDisposed: true,
      resourceFailures: failures,
    );
  }

  Future<List<PluginHostResourceFailure>> _disposeResources() async {
    final failures = <PluginHostResourceFailure>[];
    for (final resource in resources.reversed) {
      if (_disposedResourceIds.contains(resource.id)) continue;
      try {
        await resource.dispose();
        _disposedResourceIds.add(resource.id);
      } catch (error, stackTrace) {
        failures.add(
          PluginHostResourceFailure(
            resourceId: resource.id,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }
    return failures;
  }
}
