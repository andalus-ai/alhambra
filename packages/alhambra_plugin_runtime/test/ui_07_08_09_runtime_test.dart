import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

class _MockPlugin implements AlhambraPlugin {
  final PluginMetadata _meta;
  bool activated = false;

  _MockPlugin(this._meta);

  @override
  PluginMetadata get metadata => _meta;

  @override
  Future<void> activate(PluginContext context) async {
    activated = true;
  }

  @override
  Future<void> deactivate([PluginContext? context]) async {
    activated = false;
  }
}

void main() {
  group('UI-07: Runtime Scope & Registries', () {
    test('ScopeId hierarchy prevents accidental type collisions', () {
      const window = WindowId('123');
      const workspace = WorkspaceId('123');
      const session = WorkbenchSessionId('123');

      expect(window == workspace, isFalse);
      expect(window == session, isFalse);
      expect(workspace == session, isFalse);
    });

    test('ScopeRegistry registers, resolves, and disposes scopes', () async {
      final registry = ScopeRegistry();
      final appScope = ApplicationScope(const ApplicationId('app.test'));
      final winScope = WindowScope(id: const WindowId('win.1'), parent: appScope);

      registry.register(appScope);
      registry.register(winScope);

      expect(registry.contains(const WindowId('win.1')), isTrue);
      expect(registry.require<WindowScope>(const WindowId('win.1')), same(winScope));

      await registry.dispose(const WindowId('win.1'));
      expect(registry.contains(const WindowId('win.1')), isFalse);
      expect(winScope.state, ScopeState.disposed);
    });

    test('WorkbenchSessionRegistry manages session lifetimes independently', () async {
      final registry = WorkbenchSessionRegistry();
      final appScope = ApplicationScope();
      final session = WorkbenchSession(
        id: const WorkbenchSessionId('session.main'),
        windowId: const WindowId('win.1'),
        workspaceId: const WorkspaceId('ws.1'),
        parent: appScope,
      );

      registry.register(session);
      expect(registry.require(const WorkbenchSessionId('session.main')), same(session));

      await registry.dispose(const WorkbenchSessionId('session.main'));
      expect(session.state, ScopeState.disposed);
    });
  });

  group('UI-08: Capability Model, Policies & Guards', () {
    test('DefaultCapabilityResolver applies policy precedence and conditional constraints', () async {
      final enterprisePolicy = EnterpriseCapabilityPolicy(
        allowedPluginIds: {'trusted.plugin'},
        capabilityConstraints: {
          StandardCapabilities.network: [
            const CapabilityConstraint(
              type: 'allowed_hosts',
              parameters: {
                'hosts': ['api.github.com']
              },
            ),
          ],
        },
      );

      final resolver = DefaultCapabilityResolver(
        policies: [enterprisePolicy, const CommunityCapabilityPolicy()],
      );

      // Trusted plugin gets conditional grant with allowed_hosts constraint
      final grant = await resolver.resolve(
        const CapabilityRequest(capability: StandardCapabilities.network),
        const CapabilityPolicyContext(
          pluginId: 'trusted.plugin',
          pluginVersion: '1.0.0',
          applicationId: ApplicationId('app'),
        ),
      );

      expect(grant.isConditional, isTrue);
      expect(grant.constraints, isNotEmpty);

      // Untrusted plugin is denied by Enterprise policy
      final deniedGrant = await resolver.resolve(
        const CapabilityRequest(capability: StandardCapabilities.network),
        const CapabilityPolicyContext(
          pluginId: 'untrusted.plugin',
          pluginVersion: '1.0.0',
          applicationId: ApplicationId('app'),
        ),
      );

      expect(deniedGrant.isDenied, isTrue);
    });

    test('Capability Guards enforce access restrictions and record audits', () {
      final registry = InMemoryCapabilityRegistry();
      final auditLog = CapabilityAuditLog();

      // Register network capability with constraint
      registry.grant(const CapabilityGrant(
        capability: StandardCapabilities.network,
        decision: CapabilityDecision.conditional,
        constraints: [
          CapabilityConstraint(
            type: 'allowed_hosts',
            parameters: {
              'hosts': ['api.github.com']
            },
          ),
        ],
      ));

      final netGuard = NetworkCapabilityGuard(
        capabilityAccess: registry,
        auditLog: auditLog,
      );

      // Allowed host
      expect(
        () => netGuard.checkAccess(
          uri: Uri.parse('https://api.github.com/repos'),
          pluginId: 'test.plugin',
        ),
        returnsNormally,
      );

      // Disallowed host
      expect(
        () => netGuard.checkAccess(
          uri: Uri.parse('https://malicious.com/api'),
          pluginId: 'test.plugin',
        ),
        throwsA(isA<CapabilityException>()),
      );

      expect(auditLog.records.length, 2);
      expect(auditLog.records.last.decision, CapabilityDecision.denied);
    });
  });

  group('UI-09: Plugin Startup Pipeline', () {
    test('Pipeline authorizes required capabilities before activation', () async {
      final registry = InMemoryCapabilityRegistry();
      final auditLog = CapabilityAuditLog();
      final policy = EnterpriseCapabilityPolicy(
        allowedPluginIds: {'my.plugin'},
        blockedCapabilities: {StandardCapabilities.processExecute},
      );
      final resolver = DefaultCapabilityResolver(policies: [policy]);

      final pipeline = PluginStartupPipeline(
        capabilityResolver: resolver,
        auditLog: auditLog,
      );

      // 1. Valid plugin activation
      final validPlugin = _MockPlugin(
        const PluginMetadata(
          id: 'my.plugin',
          name: 'My Plugin',
          version: '1.0.0',
          capabilities: [StandardCapabilities.filesRead],
        ),
      );

      final dummyContext = RuntimePluginContext(
        pluginId: 'my.plugin',
        runtime: ExtensionRuntime(),
      );

      final result = await pipeline.run(
        plugin: validPlugin,
        context: dummyContext,
        applicationId: const ApplicationId('app'),
      );

      expect(result, isA<PluginStartupSuccess>());
      expect(validPlugin.activated, isTrue);

      // 2. Blocked capability plugin fails activation
      final blockedPlugin = _MockPlugin(
        const PluginMetadata(
          id: 'my.plugin',
          name: 'Blocked Plugin',
          version: '1.0.0',
          capabilities: [StandardCapabilities.processExecute],
        ),
      );

      final failResult = await pipeline.run(
        plugin: blockedPlugin,
        context: dummyContext,
        applicationId: const ApplicationId('app'),
      );

      expect(failResult, isA<PluginStartupFailure>());
      expect(blockedPlugin.activated, isFalse);
    });
  });
}
