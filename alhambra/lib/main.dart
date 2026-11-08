import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tenun/registry/bundle_core.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'screens/main_home_screen.dart';
import 'theme/app_colors.dart';
import 'core/license/edition.dart';
import 'core/license/license_service.dart';
import 'providers/module_manager_provider.dart';

class _NoProxyOverrides extends HttpOverrides {
  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    if (url.host == '127.0.0.1' ||
        url.host == 'localhost' ||
        url.host == '::1') {
      return 'DIRECT';
    }
    return super.findProxyFromEnvironment(url, environment);
  }
}

Future<void> _initHiveStorage(AlhambraEdition edition) async {
  Directory storageDir;
  try {
    final appSupport = await getApplicationSupportDirectory();
    storageDir = Directory('${appSupport.path}/alhambra/${edition.name}');
  } catch (_) {
    final home = Platform.environment['HOME'] ?? '.';
    storageDir = Directory('$home/.alhambra/storage/${edition.name}');
  }

  if (!storageDir.existsSync()) {
    storageDir.createSync(recursive: true);
  }

  // Clean any orphaned lock files from prior ungraceful shutdowns
  try {
    for (final entity in storageDir.listSync()) {
      if (entity is File && entity.path.endsWith('.lock')) {
        try {
          entity.deleteSync();
        } catch (_) {}
      }
    }
  } catch (_) {}

  await Hive.initFlutter(storageDir.path);

  try {
    await Hive.openBox('alhambra_prefs');
  } catch (_) {
    File('${storageDir.path}/alhambra_prefs.lock').deleteSync();
    await Hive.openBox('alhambra_prefs');
  }

  try {
    await Hive.openBox('alhambra_sessions');
  } catch (_) {
    File('${storageDir.path}/alhambra_sessions.lock').deleteSync();
    await Hive.openBox('alhambra_sessions');
  }

  try {
    await Hive.openBox('alhambra_chat_history');
  } catch (_) {
    File('${storageDir.path}/alhambra_chat_history.lock').deleteSync();
    await Hive.openBox('alhambra_chat_history');
  }
}

Future<void> runAlhambraApp({
  AlhambraEdition edition = AlhambraEdition.community,
  List<AlhambraPlugin> additionalPlugins = const [],
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  coreChartsBundle.register();

  await _initHiveStorage(edition);
  HttpOverrides.global = _NoProxyOverrides();

  final container = ProviderContainer(
    overrides: [
      injectedProPluginsProvider.overrideWithValue(additionalPlugins),
    ],
  );

  final licenseNotifier = container.read(licenseProvider.notifier);
  licenseNotifier.switchEdition(edition);

  // Eagerly trigger plugin managers to load built-in and edition plugins
  container.read(pluginManagerProvider);
  container.read(proPluginHostProvider);

  runApp(UncontrolledProviderScope(
    container: container,
    child: const AlhambraApp(),
  ));
}

void main() async {
  await runAlhambraApp(edition: AlhambraEdition.community);
}

class AlhambraApp extends StatelessWidget {
  const AlhambraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alhambra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const MainHomeScreen(),
    );
  }
}
