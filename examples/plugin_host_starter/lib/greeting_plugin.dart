import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:flutter/material.dart';

/// A small compiled plugin used by the host starter example.
final class GreetingPlugin implements AlhambraPlugin {
  static const pluginId = 'example.greeting';

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: pluginId,
        name: 'Greeting Plugin',
        version: '1.0.0',
        description: 'Demonstrates Alhambra plugin contribution registration.',
      );

  @override
  Future<void> activate(PluginContext context) async {
    context.commands.register(
      const AppCommand(
        id: 'example.greeting.sayHello',
        title: 'Say hello',
        category: 'Example',
      ),
    );

    context.ui.views.register(
      ViewContribution(
        id: 'example.greeting.welcome',
        ownerId: pluginId,
        title: 'Welcome',
        defaultRegion: UiRegion.primarySidebar,
        builder: (_) => const Center(
          child: Text('Hello from an Alhambra plugin.'),
        ),
      ),
    );

    context.ui.settings.register(
      SettingsPageContribution(
        id: 'example.greeting.settings',
        ownerId: pluginId,
        title: 'Greeting',
        section: 'Example',
        builder: (_) => const Padding(
          padding: EdgeInsets.all(16),
          child: Text('There are no configurable options in this example.'),
        ),
      ),
    );
  }

  @override
  Future<void> deactivate(PluginContext context) async {
    // Release plugin-owned resources here. The host runtime also removes
    // contributions registered under this plugin's owner ID.
  }
}
