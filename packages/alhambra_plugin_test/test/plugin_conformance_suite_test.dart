import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_test/alhambra_plugin_test.dart';
import 'package:flutter_test/flutter_test.dart';

final class _LifecyclePlugin implements AlhambraPlugin {
  _LifecyclePlugin({this.failActivation = false, this.failDeactivation = false});
  final bool failActivation;
  final bool failDeactivation;
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'example.lifecycle', name: 'Lifecycle plugin', version: '1.2.3',
    capabilities: [CapabilityId('example.read')],
  );
  @override
  Future<void> activate(PluginContext context) async {
    context.commands.register(const AppCommand(
      id: 'example.lifecycle.command', title: 'Lifecycle command', category: 'Example'));
    if (failActivation) throw StateError('activation failure');
  }
  @override
  Future<void> deactivate(PluginContext context) async {
    if (failDeactivation) throw StateError('deactivation failure');
  }
}

void main() {
  const suite = PluginConformanceSuite();
  group('metadata conformance', () {
    test('accepts valid metadata without imposing a version grammar', () {
      final result = suite.validateMetadata(const PluginMetadata(
        id: 'example.plugin', name: 'Example', version: 'release-candidate',
        capabilities: [CapabilityId('example.read')]));
      expect(result.isConformant, isTrue);
    });
    test('reports blank/untrimmed fields and duplicate capabilities', () {
      final result = suite.validateMetadata(const PluginMetadata(
        id: ' example.plugin ', name: ' ', version: '',
        capabilities: [CapabilityId('example.read'), CapabilityId('example.read'), CapabilityId(' ')]));
      expect(result.issues.map((i) => i.code), containsAll([
        'metadata.id.untrimmed', 'metadata.name.empty', 'metadata.version.empty',
        'metadata.capability.duplicate', 'metadata.capability.empty']));
    });
    test('detects duplicate plugin IDs in selected plugin set', () {
      final result = suite.validatePluginSet(const [
        PluginMetadata(id: 'example.plugin', name: 'One', version: '1'),
        PluginMetadata(id: 'example.plugin', name: 'Two', version: '2')]);
      expect(result.issues.map((i) => i.code), contains('plugin.id.duplicate'));
    });
  });
  group('lifecycle conformance', () {
    test('passes activation and cleanup round trip', () async {
      final result = await suite.verifyLifecycle(_LifecyclePlugin());
      expect(result.isConformant, isTrue, reason: result.issues.toString());
    });
    test('reports activation failure after partial contribution registration', () async {
      final result = await suite.verifyLifecycle(_LifecyclePlugin(failActivation: true));
      expect(result.issues.map((i) => i.code), contains('lifecycle.activation.failed'));
      expect(result.issues.map((i) => i.code), isNot(contains('lifecycle.cleanup.contributions')));
    });
    test('reports deactivation failure even when host cleanup succeeds', () async {
      final result = await suite.verifyLifecycle(_LifecyclePlugin(failDeactivation: true));
      expect(result.issues.map((i) => i.code), contains('lifecycle.deactivation.failed'));
      expect(result.issues.map((i) => i.code), isNot(contains('lifecycle.cleanup.contributions')));
    });
  });
}
