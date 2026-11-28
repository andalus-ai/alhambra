import 'dart:async';
import 'dart:io';

import 'package:alhambra_plugin_host/alhambra_plugin_host.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter/material.dart';

import 'greeting_plugin.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final pluginManager = PluginManager();
  final plugin = GreetingPlugin();
  final lifecycle = PluginHostLifecycle(
    startupCoordinator: PluginStartupCoordinator(manager: pluginManager),
    shutdownCoordinator: PluginShutdownCoordinator(manager: pluginManager),
    discoveredPlugins: [
      DiscoveredPlugin(
        manifest: const ExtensionManifest(
          id: GreetingPlugin.pluginId,
          name: 'Greeting Plugin',
          version: '1.0.0',
        ),
        directory: Directory('.'),
      ),
    ],
    compiledPlugins: {GreetingPlugin.pluginId: plugin},
  );

  final startup = await lifecycle.start();
  if (!startup.succeeded) {
    throw StateError('Alhambra host startup failed: ${startup.error}');
  }

  runApp(
    AlhambraPluginHostApp(
      pluginManager: pluginManager,
      lifecycle: lifecycle,
    ),
  );
}

class AlhambraPluginHostApp extends StatefulWidget {
  const AlhambraPluginHostApp({
    required this.pluginManager,
    required this.lifecycle,
    super.key,
  });

  final PluginManager pluginManager;
  final PluginHostLifecycle lifecycle;

  @override
  State<AlhambraPluginHostApp> createState() => _AlhambraPluginHostAppState();
}

class _AlhambraPluginHostAppState extends State<AlhambraPluginHostApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(widget.lifecycle.shutdown());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.lifecycle.shutdown());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alhambra Plugin Host Starter',
      home: Scaffold(
        appBar: AppBar(title: const Text('Alhambra Plugin Host')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Greeting Plugin activated',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'The host activated ${widget.pluginManager.activePlugins.length} '
                'compiled plugin through PluginHostLifecycle. The plugin '
                'registered a command, a workbench view and a settings page.',
              ),
              const SizedBox(height: 12),
              const Text(
                'The host lifecycle delegates plugin ordering to the runtime '
                'coordinators and disposes host resources after plugin shutdown.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
