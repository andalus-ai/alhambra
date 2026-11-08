import 'package:flutter/material.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'screens/settings_dialog.dart';

class SettingsPlugin implements AlhambraPlugin {
  static const pluginId = 'alhambra.core_settings';

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: pluginId,
        name: 'Alhambra Core Settings',
        version: '1.0.0',
        description: 'Core application settings (Appearance, Browser, Notifications, Privacy, Advanced)',
      );

  @override
  Future<void> activate(PluginContext context) async {
    context.ui.settings.register(
      SettingsPageContribution(
        id: 'alhambra.settings.appearance',
        ownerId: pluginId,
        title: 'Appearance',
        icon: Icons.palette_outlined,
        section: 'core',
        order: 10,
        builder: (_) => AppearanceSettingsSection(),
      ),
    );

    context.ui.settings.register(
      SettingsPageContribution(
        id: 'alhambra.settings.browser',
        ownerId: pluginId,
        title: 'Browser',
        icon: Icons.web_asset_outlined,
        section: 'core',
        order: 60,
        builder: (_) => BrowserSettingsSection(),
      ),
    );

    context.ui.settings.register(
      SettingsPageContribution(
        id: 'alhambra.settings.notifications',
        ownerId: pluginId,
        title: 'Notifications',
        icon: Icons.notifications_none_outlined,
        section: 'core',
        order: 70,
        builder: (_) => NotificationsSettingsSection(),
      ),
    );

    context.ui.settings.register(
      SettingsPageContribution(
        id: 'alhambra.settings.privacy',
        ownerId: pluginId,
        title: 'Privacy',
        icon: Icons.lock_outline,
        section: 'core',
        order: 80,
        builder: (_) => PrivacySettingsSection(),
      ),
    );

    context.ui.settings.register(
      SettingsPageContribution(
        id: 'alhambra.settings.advanced',
        ownerId: pluginId,
        title: 'Advanced',
        icon: Icons.tune_outlined,
        section: 'core',
        order: 90,
        builder: (_) => AdvancedSettingsSection(),
      ),
    );
  }

  @override
  Future<void> deactivate(PluginContext context) async {}
}
