import 'package:alhambra_ui/alhambra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── ViewState ──────────────────────────────────────────────────────────────
  group('ViewState', () {
    test('Loading.isLoading is true', () {
      const s = Loading<String>();
      expect(s.isLoading, isTrue);
      expect(s.isReady, isFalse);
      expect(s.isFailed, isFalse);
      expect(s.dataOrNull, isNull);
    });

    test('Ready.isReady is true, dataOrNull returns value', () {
      const s = Ready<int>(42);
      expect(s.isReady, isTrue);
      expect(s.isLoading, isFalse);
      expect(s.dataOrNull, 42);
    });

    test('Failed.isFailed is true', () {
      final s = Failed<String>(Exception('boom'));
      expect(s.isFailed, isTrue);
      expect(s.dataOrNull, isNull);
    });

    test('when() dispatches correctly', () {
      const loading = Loading<String>();
      final result = loading.when(
        loading: () => 'loading',
        ready: (d) => 'ready:$d',
        failed: (e) => 'failed',
      );
      expect(result, 'loading');
    });

    test('when() ready branch receives data', () {
      const ready = Ready<String>('hello');
      final result = ready.when(
        loading: () => '',
        ready: (d) => d,
        failed: (_) => '',
      );
      expect(result, 'hello');
    });

    test('when() failed branch receives error', () {
      final failed = Failed<String>(42);
      final result = failed.when(
        loading: () => -1,
        ready: (_) => -1,
        failed: (e) => e as int,
      );
      expect(result, 42);
    });
  });

  // ── UiSyncState ────────────────────────────────────────────────────────────
  group('UiSyncState', () {
    test('all states have non-empty labels', () {
      for (final s in UiSyncState.values) {
        expect(s.label, isNotEmpty);
      }
    });

    test('synced label is "Synced"', () {
      expect(UiSyncState.synced.label, 'Synced');
    });

    test('pending label is "Saved locally"', () {
      expect(UiSyncState.pending.label, 'Saved locally');
    });
  });

  // ── OrganizationContext ────────────────────────────────────────────────────
  group('OrganizationContext', () {
    test('equality by organizationId', () {
      const a = OrganizationContext(organizationId: 'org-1', organizationName: 'Alpha');
      const b = OrganizationContext(organizationId: 'org-1', organizationName: 'Alpha Renamed');
      expect(a, equals(b));
    });

    test('different ids are not equal', () {
      const a = OrganizationContext(organizationId: 'org-1', organizationName: 'Alpha');
      const b = OrganizationContext(organizationId: 'org-2', organizationName: 'Beta');
      expect(a, isNot(equals(b)));
    });
  });

  // ── OrganizationNotifier ───────────────────────────────────────────────────
  group('OrganizationNotifier', () {
    final memberships = [
      const OrganizationMembership(organizationId: 'org-A', organizationName: 'Alpha'),
      const OrganizationMembership(organizationId: 'org-B', organizationName: 'Beta'),
    ];

    test('initial current is null', () {
      final n = OrganizationNotifier(memberships: memberships);
      expect(n.current, isNull);
    });

    test('switchTo valid id sets current and increments generationKey', () {
      final n = OrganizationNotifier(memberships: memberships);
      final gen0 = n.generationKey;
      final ok = n.switchTo('org-A');
      expect(ok, isTrue);
      expect(n.current?.organizationId, 'org-A');
      expect(n.current?.organizationName, 'Alpha');
      expect(n.generationKey, gen0 + 1);
    });

    test('switchTo unknown id returns false, no change', () {
      final n = OrganizationNotifier(memberships: memberships);
      n.switchTo('org-A');
      final gen = n.generationKey;
      final ok = n.switchTo('org-UNKNOWN');
      expect(ok, isFalse);
      expect(n.current?.organizationId, 'org-A'); // unchanged
      expect(n.generationKey, gen); // not incremented
    });

    test('clear resets current and increments generationKey', () {
      final n = OrganizationNotifier(memberships: memberships);
      n.switchTo('org-A');
      final gen = n.generationKey;
      n.clear();
      expect(n.current, isNull);
      expect(n.generationKey, gen + 1);
    });

    test('switchTo notifies listeners', () {
      final n = OrganizationNotifier(memberships: memberships);
      var notified = false;
      n.addListener(() => notified = true);
      n.switchTo('org-B');
      expect(notified, isTrue);
    });

    test('setMemberships replaces list', () {
      final n = OrganizationNotifier();
      n.setMemberships(memberships);
      expect(n.memberships.length, 2);
    });

    test('switching between orgs increments generationKey each time', () {
      final n = OrganizationNotifier(memberships: memberships);
      n.switchTo('org-A');
      final g1 = n.generationKey;
      n.switchTo('org-B');
      final g2 = n.generationKey;
      expect(g2, g1 + 1);
    });
  });

  // ── UiActionState ──────────────────────────────────────────────────────────
  group('UiActionState', () {
    test('.active() is visible and enabled', () {
      const s = UiActionState.active();
      expect(s.visible, isTrue);
      expect(s.enabled, isTrue);
      expect(s.disabledReason, isNull);
    });

    test('.disabled() is visible but not enabled', () {
      const s = UiActionState.disabled('Waiting for approval');
      expect(s.visible, isTrue);
      expect(s.enabled, isFalse);
      expect(s.disabledReason, 'Waiting for approval');
    });

    test('.hidden() is neither visible nor enabled', () {
      const s = UiActionState.hidden();
      expect(s.visible, isFalse);
      expect(s.enabled, isFalse);
    });
  });

  // ── UiError / UiErrorClass ─────────────────────────────────────────────────
  group('UiError', () {
    test('classifyHttpError: 401 → unauthenticated', () {
      expect(classifyHttpError(401), UiErrorClass.unauthenticated);
    });

    test('classifyHttpError: 403 → authorization', () {
      expect(classifyHttpError(403), UiErrorClass.authorization);
    });

    test('classifyHttpError: 404 → notFound', () {
      expect(classifyHttpError(404), UiErrorClass.notFound);
    });

    test('classifyHttpError: 409 → conflict', () {
      expect(classifyHttpError(409), UiErrorClass.conflict);
    });

    test('classifyHttpError: 500 → server', () {
      expect(classifyHttpError(500), UiErrorClass.server);
    });

    test('authorization error: headline does not expose status code', () {
      final e = UiError.fromHttpStatus(403);
      expect(e.headline, isNot(contains('403')));
      expect(e.headline, contains("permission"));
    });

    test('network error isRetryable', () {
      final e = UiError.network();
      expect(e.isRetryable, isTrue);
    });

    test('authorization error is NOT retryable', () {
      const e = UiError(UiErrorClass.authorization);
      expect(e.isRetryable, isFalse);
    });

    test('all error classes have non-empty headline and guidance', () {
      for (final c in UiErrorClass.values) {
        expect(c.headline, isNotEmpty);
        expect(c.guidance, isNotEmpty);
      }
    });
  });

  // ── WorkspaceContext ───────────────────────────────────────────────────────
  group('WorkspaceContext', () {
    const ctx = WorkspaceContext(
      workspaceId: 'ws-1',
      organizationId: 'org-A',
      status: 'DRAFT',
      currentVersion: '3',
    );

    test('fields are accessible', () {
      expect(ctx.workspaceId, 'ws-1');
      expect(ctx.organizationId, 'org-A');
      expect(ctx.status, 'DRAFT');
      expect(ctx.currentVersion, '3');
    });

    test('copyWith updates fields', () {
      final updated = ctx.copyWith(status: 'PUBLISHED', currentVersion: '4');
      expect(updated.status, 'PUBLISHED');
      expect(updated.currentVersion, '4');
      expect(updated.workspaceId, 'ws-1'); // unchanged
    });

    test('WorkspaceLifecycleStatus.labelFor maps all known statuses', () {
      for (final s in [
        WorkspaceLifecycleStatus.draft,
        WorkspaceLifecycleStatus.review,
        WorkspaceLifecycleStatus.approved,
        WorkspaceLifecycleStatus.published,
        WorkspaceLifecycleStatus.superseded,
        WorkspaceLifecycleStatus.archived,
      ]) {
        expect(WorkspaceLifecycleStatus.labelFor(s), isNotEmpty);
      }
    });

    test('WorkspaceLifecycleStatus.labelFor unknown returns input', () {
      expect(WorkspaceLifecycleStatus.labelFor('CUSTOM'), 'CUSTOM');
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────
  group('OfflineBanner widget', () {
    testWidgets('renders when isOffline=true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(isOffline: true),
          ),
        ),
      );
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('is invisible when isOffline=false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(isOffline: false),
          ),
        ),
      );
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });
  });

  group('SyncIndicator widget', () {
    Widget wrap(UiSyncState state) => MaterialApp(
          home: Scaffold(body: SyncIndicator(state: state)),
        );

    testWidgets('synced shows check icon', (tester) async {
      await tester.pumpWidget(wrap(UiSyncState.synced));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('conflict shows warning icon', (tester) async {
      await tester.pumpWidget(wrap(UiSyncState.conflict));
      await tester.pump();
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('syncing shows progress indicator', (tester) async {
      await tester.pumpWidget(wrap(UiSyncState.syncing));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('NavigationRegistry', () {
    test('register and retrieve sections', () {
      final registry = DefaultNavigationRegistry();
      registry.register(NavigationSection(
        id: 'main',
        label: 'Main',
        items: [
          const NavigationItem(id: 'home', label: 'Home', route: '/home'),
        ],
      ));
      expect(registry.sections.length, 1);
      expect(registry.sections.first.id, 'main');
    });

    test('re-registering same id replaces section', () {
      final registry = DefaultNavigationRegistry();
      registry.register(NavigationSection(
        id: 'main',
        label: 'Main',
        items: [const NavigationItem(id: 'home', label: 'Home', route: '/home')],
      ));
      registry.register(NavigationSection(
        id: 'main',
        label: 'Main',
        items: [const NavigationItem(id: 'home2', label: 'Home2', route: '/home2')],
      ));
      expect(registry.sections.length, 1);
      expect(registry.sections.first.items.first.id, 'home2');
    });

    test('unregister removes section', () {
      final registry = DefaultNavigationRegistry();
      registry.register(NavigationSection(
        id: 'main',
        label: 'Main',
        items: [],
      ));
      registry.unregister('main');
      expect(registry.sections, isEmpty);
    });
  });

  group('ShellController', () {
    test('initial selectedIndex is 0', () {
      final c = ShellController();
      expect(c.state.selectedIndex, 0);
      c.dispose();
    });

    test('selectIndex updates state', () {
      final c = ShellController();
      c.selectIndex(2);
      expect(c.state.selectedIndex, 2);
      c.dispose();
    });

    test('toggleSidebar flips isSidebarExpanded', () {
      final c = ShellController();
      expect(c.state.isSidebarExpanded, isTrue);
      c.toggleSidebar();
      expect(c.state.isSidebarExpanded, isFalse);
      c.dispose();
    });

    test('selectIndex same index does not notify', () {
      final c = ShellController();
      var count = 0;
      c.addListener(() => count++);
      c.selectIndex(0); // already 0
      expect(count, 0);
      c.dispose();
    });
  });
}
