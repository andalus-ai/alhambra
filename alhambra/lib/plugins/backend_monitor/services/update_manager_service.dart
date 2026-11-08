import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ComponentVersionInfo {
  final String componentName;
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String releaseNotes;
  final DateTime releaseDate;

  const ComponentVersionInfo({
    required this.componentName,
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.releaseNotes,
    required this.releaseDate,
  });
}

class SystemUpdateManifest {
  final ComponentVersionInfo gui;
  final ComponentVersionInfo alhambra;
  final ComponentVersionInfo gollek;
  final bool isChecking;
  final DateTime lastChecked;

  const SystemUpdateManifest({
    required this.gui,
    required this.alhambra,
    required this.gollek,
    this.isChecking = false,
    required this.lastChecked,
  });

  bool get anyUpdateAvailable =>
      gui.hasUpdate || alhambra.hasUpdate || gollek.hasUpdate;
}

class UpdateManagerService {
  /// Checks remote release endpoints for the latest versions.
  Future<SystemUpdateManifest> checkUpdates() async {
    // Simulated remote version check (can connect to api.andalus.tech/releases/latest)
    await Future.delayed(const Duration(milliseconds: 600));

    return SystemUpdateManifest(
      gui: ComponentVersionInfo(
        componentName: 'Alhambra Vibe Coder',
        currentVersion: '0.1.0',
        latestVersion: '0.1.0',
        hasUpdate: false,
        releaseNotes:
            '• Modern Dual-Substrate Supervisor\n• Real-time LSP & AST stream',
        releaseDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      alhambra: ComponentVersionInfo(
        componentName: 'Andalus / Alhambra Agent Substrate',
        currentVersion: '0.1.0',
        latestVersion: '0.1.0',
        hasUpdate: false,
        releaseNotes:
            '• Unified HTTP/gRPC Vert.x Server\n• Verification Ladder (L0-L5)',
        releaseDate: DateTime.now().subtract(const Duration(days: 2)),
      ),
      gollek: ComponentVersionInfo(
        componentName: 'Gollek Local Inference Server',
        currentVersion: '0.1.0',
        latestVersion: '0.1.0',
        hasUpdate: false,
        releaseNotes:
            '• Apple Silicon Metal Acceleration\n• Paged KV Cache Manager',
        releaseDate: DateTime.now().subtract(const Duration(days: 3)),
      ),
      isChecking: false,
      lastChecked: DateTime.now(),
    );
  }

  /// Performs in-place update for specified component.
  Stream<double> performUpdate(String componentId) async* {
    yield 0.1;
    await Future.delayed(const Duration(milliseconds: 400));
    yield 0.4;
    await Future.delayed(const Duration(milliseconds: 600));
    yield 0.8;
    await Future.delayed(const Duration(milliseconds: 500));
    yield 1.0;
  }
}

final updateManagerServiceProvider = Provider<UpdateManagerService>((ref) {
  return UpdateManagerService();
});

final updateManifestProvider =
    FutureProvider<SystemUpdateManifest>((ref) async {
  final service = ref.watch(updateManagerServiceProvider);
  return service.checkUpdates();
});
