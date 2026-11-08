import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  group('UI-13: Command Contributions & Interaction Contracts', () {
    test('CommandDispatcher dispatches registered commands and honors availability', () async {
      final registry = DefaultInteractionRegistry();
      final dispatcher = DefaultCommandDispatcher(registry: registry);

      const cmdType = CommandType('editor', 'format');
      registry.registerCommand(
        const CommandDefinition(type: cmdType, title: 'Format Document'),
        handler: (cmd, ctx) async =>
            const ResourceMutationResult.ok('Formatted successfully'),
      );

      const context = InteractionContext();
      final result = await dispatcher.dispatch(
        const ResourceCommand(type: cmdType),
        context,
      );

      expect(result.success, isTrue);
      expect(result.message, 'Formatted successfully');
    });

    test('MenuModelResolver resolves and groups visible menu items', () async {
      final registry = DefaultInteractionRegistry();
      final resolver = DefaultMenuModelResolver(registry: registry);

      const cmd1 = CommandType('file', 'save');
      const cmd2 = CommandType('file', 'close');

      registry.registerCommand(
        const CommandDefinition(type: cmd1, title: 'Save File'),
      );
      registry.registerCommand(
        const CommandDefinition(type: cmd2, title: 'Close File'),
      );

      registry.registerMenu(
        const DeclarativeMenuContribution(
          id: 'menu.file.save',
          command: cmd1,
          menuId: MenuIds.file,
          priority: 10,
        ),
      );
      registry.registerMenu(
        const DeclarativeMenuContribution(
          id: 'menu.file.close',
          command: cmd2,
          menuId: MenuIds.file,
          priority: 5,
        ),
      );

      final menu = await resolver.resolve(
        MenuIds.file,
        const InteractionContext(),
      );
      expect(menu.items.length, 2);
      expect((menu.items.first as CommandMenuItem).title, 'Save File');
      expect((menu.items.last as CommandMenuItem).title, 'Close File');
    });
  });

  group('UI-14: Plugin Manifest & Dependency Resolution', () {
    test('SemanticVersion parses and compares correctly', () {
      final v1 = SemanticVersion.parse('1.4.0');
      final v2 = SemanticVersion.parse('1.10.0');
      final v3 = SemanticVersion.parse('2.0.0-beta.1');

      expect(v2 > v1, isTrue);
      expect(v3 > v2, isTrue);
    });

    test(
      'VersionConstraint evaluates caret, range, and wildcard constraints',
      () {
        final caret = VersionConstraint.parse('^1.4.0');
        expect(caret.matches(SemanticVersion.parse('1.4.0')), isTrue);
        expect(caret.matches(SemanticVersion.parse('1.9.2')), isTrue);
        expect(caret.matches(SemanticVersion.parse('2.0.0')), isFalse);

        final wildcard = VersionConstraint.parse('*');
        expect(wildcard.matches(SemanticVersion.parse('9.9.9')), isTrue);
      },
    );

    test(
      'TopologicalPluginResolver orders dependencies and detects cycles',
      () {
        final graph = PluginDependencyGraph();

        final manifestGit = PluginPackageManifest(
          id: const PluginId('git'),
          name: 'Git',
          version: SemanticVersion.parse('2.0.0'),
          hostApi: HostApiConstraint(min: SemanticVersion.parse('1.0.0')),
        );

        final manifestGithub = PluginPackageManifest(
          id: const PluginId('github'),
          name: 'GitHub',
          version: SemanticVersion.parse('1.0.0'),
          hostApi: HostApiConstraint(min: SemanticVersion.parse('1.0.0')),
          dependencies: [
            PluginDependency(
              id: const PluginId('git'),
              version: VersionConstraint.parse('^2.0.0'),
            ),
          ],
        );

        graph.add(manifestGit);
        graph.add(manifestGithub);

        final resolver = TopologicalPluginResolver(graph: graph);
        final plan = resolver.resolve();

        expect(
          plan.plugins.map((p) => p.id.value).toList(),
          equals(['git', 'github']),
        );
      },
    );

    test('TopologicalPluginResolver throws on circular dependencies', () {
      final graph = PluginDependencyGraph();

      graph.add(
        PluginPackageManifest(
          id: const PluginId('A'),
          name: 'A',
          version: SemanticVersion.parse('1.0.0'),
          hostApi: HostApiConstraint(min: SemanticVersion.parse('1.0.0')),
          dependencies: [
            PluginDependency(
              id: const PluginId('B'),
              version: const WildcardVersionConstraint(),
            ),
          ],
        ),
      );

      graph.add(
        PluginPackageManifest(
          id: const PluginId('B'),
          name: 'B',
          version: SemanticVersion.parse('1.0.0'),
          hostApi: HostApiConstraint(min: SemanticVersion.parse('1.0.0')),
          dependencies: [
            PluginDependency(
              id: const PluginId('A'),
              version: const WildcardVersionConstraint(),
            ),
          ],
        ),
      );

      final resolver = TopologicalPluginResolver(graph: graph);
      expect(
        () => resolver.resolve(),
        throwsA(isA<PluginDependencyCycleException>()),
      );
    });
  });

  group('UI-15: Capability Broker & Permission Enforcement', () {
    test(
      'DefaultCapabilityBroker evaluates policy and tracks scoped grants',
      () async {
        final policy = HierarchicalPolicyEngine(
          autoAllowedCapabilities: {'workspace.read'},
          enterpriseDenied: {'network'},
        );
        final broker = DefaultCapabilityBroker(policyEngine: policy);

        const context = CapabilityContext(
          pluginId: PluginId('github'),
          scopeKind: CapabilityScopeKind.workspace,
          scopeId: 'workspace-101',
        );

        // 1. Auto-allowed
        final readDecision = await broker.request(
          BrokerStandardCapabilities.workspaceRead,
          context,
        );
        expect(readDecision.isGranted, isTrue);
        expect(
          broker.isGranted(BrokerStandardCapabilities.workspaceRead, context),
          isTrue,
        );

        // 2. Enterprise denied
        final netDecision = await broker.request(
          BrokerStandardCapabilities.network,
          context,
        );
        expect(netDecision.isGranted, isFalse);
        expect(netDecision.type, CapabilityDecisionType.denied);

        // 3. Scope revocation
        await broker.revokeAllForScope('workspace-101');
        expect(
          broker.isGranted(BrokerStandardCapabilities.workspaceRead, context),
          isFalse,
        );
      },
    );

    test('InMemoryScopedFileSystem enforces path prefix isolation', () async {
      final fs = InMemoryScopedFileSystem(allowedPrefix: '/workspace/project');

      await fs.writeFile('lib/main.dart', 'void main() {}');
      expect(await fs.exists('lib/main.dart'), isTrue);
      expect(await fs.readFile('lib/main.dart'), 'void main() {}');
    });
  });

  group('UI-16: Extension UI Contribution Runtime', () {
    test('RelationalContributionSorter sorts before/after relations deterministically', () {
      final items = [
        const SorterItem<String>(
          id: 'b',
          data: 'B',
          hint: ContributionOrderHint(after: ContributionId('a')),
        ),
        const SorterItem<String>(id: 'a', data: 'A'),
        const SorterItem<String>(
          id: 'c',
          data: 'C',
          hint: ContributionOrderHint(after: ContributionId('b')),
        ),
      ];

      final sorted = RelationalContributionSorter.sort<String>(items);
      expect(sorted, equals(['A', 'B', 'C']));
    });

    test('ScopedContributionManager automatically unregisters contributions on scope disposal', () {
      final registry = DefaultExtensionContributionRegistry();
      final manager = ScopedContributionManager(registry: registry);

      final contrib = _TestUiContribution(
        id: const ContributionId('github.sidebar'),
        pluginId: const PluginId('github'),
      );

      manager.registerInScope('scope-view-1', contrib);
      expect(registry.find(const ContributionId('github.sidebar')), isNotNull);

      manager.disposeScope('scope-view-1');
      expect(registry.find(const ContributionId('github.sidebar')), isNull);
    });
  });
}

class _TestUiContribution implements ExtensionUiContribution {
  @override
  final ContributionId id;
  @override
  final PluginId pluginId;

  _TestUiContribution({required this.id, required this.pluginId});
}
