import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class _SamplePlugin implements AlhambraPlugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'sample.plugin',
    name: 'Sample Plugin',
    version: '1.0.0',
  );

  @override
  Future<void> activate(PluginContext context) async {
    context.commands.register(
      AppCommand(id: 'sample.hello', title: 'Sample: Hello', action: (_) {}),
    );

    context.ui.views.register(
      ViewContribution(
        id: 'sample.view',
        ownerId: metadata.id,
        title: 'Sample View',
        preferredPlacement: ViewPlacement.sidebar,
        builder: (_) => const SizedBox(),
      ),
    );

    context.ui.activityBar.register(
      ActivityBarContribution(
        id: 'sample.activity',
        ownerId: metadata.id,
        label: 'Sample',
        icon: Icons.extension,
        defaultViewId: 'sample.view',
      ),
    );
  }

  @override
  Future<void> deactivate(PluginContext context) async {}
}

void main() {
  test('AljabrPlugin contracts and metadata can be instantiated', () {
    final plugin = _SamplePlugin();
    expect(plugin.metadata.id, 'sample.plugin');
    expect(plugin.metadata.name, 'Sample Plugin');
    expect(plugin.metadata.version, '1.0.0');
  });

  test('ContextKey and ContextSnapshot store and retrieve typed values', () {
    final builder = ContextBuilder();
    builder.set(CoreContextKeys.workspaceName, 'Andalus Platform');
    builder.set(CoreContextKeys.gitBranch, 'main');

    final snapshot = builder.build();
    expect(snapshot.get(CoreContextKeys.workspaceName), 'Andalus Platform');
    expect(snapshot.get(CoreContextKeys.gitBranch), 'main');
    expect(snapshot.get(CoreContextKeys.filePath), isNull);
  });

  test('LayoutPluginRegistry registers, looks up, and activates plugins', () {
    final registry = LayoutPluginRegistry();

    final testPlugin = _DummyLayoutPlugin();
    registry.register(testPlugin);

    expect(registry.all.length, 1);
    expect(registry.find('test.layout'), isNotNull);
    expect(registry.find('test.layout')?.metadata.name, 'Test Layout');

    registry.activate('test.layout');
    expect(registry.active?.metadata.id, 'test.layout');

    registry.unregister('test.layout');
    expect(registry.find('test.layout'), isNull);
    expect(registry.active, isNull);
  });

  test('LayoutSlotConfig provides slot overrides and fallbacks', () {
    final config = LayoutSlotConfig({
      LayoutSlot.sidebar: (context) => const SizedBox(),
    });

    expect(config.has(LayoutSlot.sidebar), isTrue);
    expect(config.has(LayoutSlot.activityBar), isFalse);
    expect(config.override(LayoutSlot.sidebar), isNotNull);
    expect(config.override(LayoutSlot.activityBar), isNull);
  });
}

class _DummyLayoutPlugin extends LayoutPlugin {
  @override
  LayoutPluginMetadata get metadata => const LayoutPluginMetadata(
        id: 'test.layout',
        name: 'Test Layout',
        description: 'Test layout for unit testing',
        icon: Icons.dashboard,
        suitableFor: {AppKind.custom},
      );

  @override
  Widget build(
    BuildContext context, {
    required ScreenClass screenClass,
    required AppKind appKind,
    required LayoutSlotConfig slots,
  }) {
    return const SizedBox();
  }
}

