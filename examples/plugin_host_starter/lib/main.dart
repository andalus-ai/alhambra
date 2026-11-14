import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter/material.dart';

import 'greeting_plugin.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final pluginManager = PluginManager();
  await pluginManager.activate(GreetingPlugin());

  runApp(AlhambraPluginHostApp(pluginManager: pluginManager));
}

class AlhambraPluginHostApp extends StatelessWidget {
  const AlhambraPluginHostApp({
    required this.pluginManager,
    super.key,
  });

  final PluginManager pluginManager;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alhambra Plugin Host Starter',
      home: Scaffold(
        appBar: AppBar(title: const Text('Alhambra Plugin Host')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Greeting Plugin activated',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'The host constructed a compiled plugin and activated it '
                'through PluginManager. The plugin registered a command, '
                'a workbench view and a settings page.',
              ),
              SizedBox(height: 12),
              Text(
                'This starter demonstrates lifecycle and registration. '
                'A full host shell is responsible for rendering contributions.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
