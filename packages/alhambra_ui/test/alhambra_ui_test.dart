import 'package:alhambra_services/alhambra_services.dart';
import 'package:alhambra_ui/alhambra_ui.dart';
import 'package:alhambra_workspace/alhambra_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // =========================================================================
  // 1. Theme & Design Tokens
  // =========================================================================
  group('1. Theme & Design Tokens', () {
    test('spacing tokens are consistent and ascending', () {
      expect(AlhambraSpacing.xxs, lessThan(AlhambraSpacing.xs));
      expect(AlhambraSpacing.xs, lessThan(AlhambraSpacing.sm));
      expect(AlhambraSpacing.sm, lessThan(AlhambraSpacing.md));
      expect(AlhambraSpacing.md, lessThan(AlhambraSpacing.lg));
      expect(AlhambraSpacing.lg, lessThan(AlhambraSpacing.xl));
      expect(AlhambraSpacing.xl, lessThan(AlhambraSpacing.xxl));
    });

    test('breakpoints define compact, medium, and expanded', () {
      expect(AlhambraDimensions.compactBreakpoint, equals(600.0));
      expect(AlhambraDimensions.mediumBreakpoint, equals(1024.0));
      expect(AlhambraDimensions.minTouchTarget, equals(48.0));
    });

    test('AlhambraTheme generates valid light and dark themes', () {
      final lightTheme = AlhambraTheme.light();
      final darkTheme = AlhambraTheme.dark();

      expect(lightTheme.useMaterial3, isTrue);
      expect(darkTheme.useMaterial3, isTrue);
      expect(lightTheme.brightness, equals(Brightness.light));
      expect(darkTheme.brightness, equals(Brightness.dark));
    });
  });

  // =========================================================================
  // 2. Responsive Layout & ScreenSize
  // =========================================================================
  group('2. Responsive Layout', () {
    test('ScreenSize classifies widths accurately', () {
      expect(ResponsiveLayout.classifyWidth(400), equals(ScreenSize.compact));
      expect(ResponsiveLayout.classifyWidth(599), equals(ScreenSize.compact));
      expect(ResponsiveLayout.classifyWidth(600), equals(ScreenSize.medium));
      expect(ResponsiveLayout.classifyWidth(1023), equals(ScreenSize.medium));
      expect(ResponsiveLayout.classifyWidth(1024), equals(ScreenSize.expanded));
      expect(ResponsiveLayout.classifyWidth(1920), equals(ScreenSize.expanded));
    });

    testWidgets('ResponsiveLayout renders appropriate child for width', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ResponsiveLayout(
            compact: Text('Compact View'),
            medium: Text('Medium View'),
            expanded: Text('Expanded View'),
          ),
        ),
      );

      expect(find.text('Compact View'), findsOneWidget);
      expect(find.text('Medium View'), findsNothing);

      // Resize to medium
      tester.view.physicalSize = const Size(800, 800);
      await tester.pumpAndSettle();

      expect(find.text('Medium View'), findsOneWidget);
      expect(find.text('Compact View'), findsNothing);
    });
  });

  // =========================================================================
  // 3. Navigation & Routing
  // =========================================================================
  group('3. Navigation & Routing', () {
    test('DefaultNavigationRegistry registers and retrieves sections', () {
      final registry = DefaultNavigationRegistry();
      const section = NavigationSection(
        id: 'sec-1',
        label: 'Main',
        items: [
          NavigationItem(id: 'nav-home', label: 'Home', route: '/home'),
          NavigationItem(id: 'nav-ws', label: 'Workspaces', route: '/workspaces'),
        ],
      );

      registry.register(section);
      expect(registry.sections.length, equals(1));
      expect(registry.sections.first.items.length, equals(2));

      registry.unregister('sec-1');
      expect(registry.sections.isEmpty, isTrue);
    });

    test('RouteRegistry registers and finds RouteDefinitions', () {
      final registry = DefaultRouteRegistry();
      final route = RouteDefinition(
        path: '/items',
        builder: (context, params) => const Text('Items'),
      );

      registry.register(route);
      expect(registry.find('/items'), equals(route));
      expect(registry.find('/unknown'), isNull);
    });

    testWidgets('CompositeRouteGuard requires all guards to pass', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  final guard = CompositeRouteGuard([
                    _MockGuard(true),
                    _MockGuard(false),
                  ]);
                  final allowed = await guard.canActivate(context, '/test');
                  expect(allowed, isFalse);
                },
                child: const Text('Check'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
    });
  });

  // =========================================================================
  // 4. Shell & App
  // =========================================================================
  group('4. Shell & App', () {
    testWidgets('AlhambraApp renders home content', (tester) async {
      final config = AlhambraAppConfig(
        title: 'Alhambra Test App',
        home: const Scaffold(body: Text('Hello Alhambra')),
      );

      await tester.pumpWidget(AlhambraApp(config: config));
      expect(find.text('Hello Alhambra'), findsOneWidget);
    });

    testWidgets('AppShell renders top bar title and navigation items', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final config = ShellConfig(
        title: 'Platform Shell',
        navigationSections: const [
          NavigationSection(
            id: 'general',
            label: 'General',
            items: [
              NavigationItem(id: 'home', label: 'Dashboard', icon: Icons.dashboard),
              NavigationItem(id: 'workspaces', label: 'Workspaces', icon: Icons.work),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            config: config,
            child: const Text('Shell Content'),
          ),
        ),
      );

      expect(find.text('Platform Shell'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Shell Content'), findsOneWidget);
    });
  });

  // =========================================================================
  // 5. States
  // =========================================================================
  group('5. State Components', () {
    testWidgets('LoadingState renders indicator and message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingState(message: 'Loading assets…')),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading assets…'), findsOneWidget);
    });

    testWidgets('EmptyState renders title and action button', (tester) async {
      var actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'No Workspaces Found',
              message: 'Create your first workspace to get started.',
              action: ElevatedButton(
                onPressed: () => actionTriggered = true,
                child: const Text('Create Workspace'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('No Workspaces Found'), findsOneWidget);
      expect(find.text('Create your first workspace to get started.'), findsOneWidget);

      await tester.tap(find.text('Create Workspace'));
      expect(actionTriggered, isTrue);
    });

    testWidgets('ErrorState renders error text and retry action', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(
              title: 'Failed to load data',
              message: 'Check your network connection.',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to load data'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('UnauthorizedState renders access denied view', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: UnauthorizedState()),
        ),
      );

      expect(find.text('Access Denied'), findsOneWidget);
    });
  });

  // =========================================================================
  // 6. Authorization UI
  // =========================================================================
  group('6. Authorization Gates', () {
    testWidgets('PermissionGate renders child when permission is granted', (tester) async {
      const resolver = SimpleUiAuthorizationResolver(
        permissions: {'workspace:publish'},
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthorizationScope(
            resolver: resolver,
            child: PermissionGate(
              permission: 'workspace:publish',
              fallback: Text('Hidden'),
              child: Text('Publish Allowed'),
            ),
          ),
        ),
      );

      expect(find.text('Publish Allowed'), findsOneWidget);
      expect(find.text('Hidden'), findsNothing);
    });

    testWidgets('PermissionGate renders fallback when permission is missing', (tester) async {
      const resolver = SimpleUiAuthorizationResolver(
        permissions: {'workspace:view'},
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthorizationScope(
            resolver: resolver,
            child: PermissionGate(
              permission: 'workspace:publish',
              fallback: Text('Permission Denied'),
              child: Text('Publish Allowed'),
            ),
          ),
        ),
      );

      expect(find.text('Permission Denied'), findsOneWidget);
      expect(find.text('Publish Allowed'), findsNothing);
    });

    testWidgets('RoleVisibility respects role membership', (tester) async {
      const resolver = SimpleUiAuthorizationResolver(roles: {'admin'});

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthorizationScope(
            resolver: resolver,
            child: RoleVisibility(
              roleId: 'admin',
              child: Text('Admin Panel'),
            ),
          ),
        ),
      );

      expect(find.text('Admin Panel'), findsOneWidget);
    });
  });

  // =========================================================================
  // 7. Workspace Components
  // =========================================================================
  group('7. Workspace Components', () {
    testWidgets('WorkspaceHeader displays title, status chip, and version', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkspaceHeader(
              title: 'Fiscal Policy Outlook',
              status: WorkspaceStatus.review,
              version: 3,
            ),
          ),
        ),
      );

      expect(find.text('Fiscal Policy Outlook'), findsOneWidget);
      expect(find.text('REVIEW'), findsOneWidget);
      expect(find.text('v3'), findsOneWidget);
    });

    testWidgets('WorkspaceNavigationBar switches active item', (tester) async {
      int selectedIdx = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: WorkspaceNavigationBar(
                  selectedIndex: selectedIdx,
                  onItemSelected: (idx) => setState(() => selectedIdx = idx),
                  items: const [
                    WorkspaceNavigationItem(id: 'overview', label: 'Overview'),
                    WorkspaceNavigationItem(id: 'analyses', label: 'Analyses', badgeCount: 2),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Analyses'), findsOneWidget);

      await tester.tap(find.text('Analyses'));
      await tester.pumpAndSettle();
      expect(selectedIdx, equals(1));
    });

    testWidgets('WorkspaceShell assembles header, nav, and body', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkspaceShell(
              workspaceId: WorkspaceId('ws-test'),
              title: 'Regional Economic Model',
              status: WorkspaceStatus.published,
              version: 1,
              navigationItems: [
                WorkspaceNavigationItem(id: 'data', label: 'Data Sources'),
              ],
              child: Text('Workspace Inner Content'),
            ),
          ),
        ),
      );

      expect(find.text('Regional Economic Model'), findsOneWidget);
      expect(find.text('PUBLISHED'), findsOneWidget);
      expect(find.text('Data Sources'), findsOneWidget);
      expect(find.text('Workspace Inner Content'), findsOneWidget);
    });
  });

  // =========================================================================
  // 8. Reusable UI Components
  // =========================================================================
  group('8. Components', () {
    testWidgets('AlhambraButton renders and responds to tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlhambraButton(
              onPressed: () => tapped = true,
              child: const Text('Save Changes'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Save Changes'));
      expect(tapped, isTrue);
    });

    testWidgets('AlhambraButton shows progress and disables tap when loading', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlhambraButton(
              isLoading: true,
              onPressed: () => tapped = true,
              child: const Text('Submit'),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Submit'));
      expect(tapped, isFalse);
    });

    testWidgets('AlhambraCard renders header, body, and footer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlhambraCard(
              header: Text('Card Header'),
              footer: Text('Card Footer'),
              child: Text('Card Body'),
            ),
          ),
        ),
      );

      expect(find.text('Card Header'), findsOneWidget);
      expect(find.text('Card Body'), findsOneWidget);
      expect(find.text('Card Footer'), findsOneWidget);
    });

    testWidgets('AlhambraDataTable displays columns and rows', (tester) async {
      final items = [
        {'id': '1', 'name': 'Item One', 'score': '95'},
        {'id': '2', 'name': 'Item Two', 'score': '88'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlhambraDataTable<Map<String, String>>(
              items: items,
              columns: [
                AlhambraDataColumn(
                  label: 'Name',
                  cellBuilder: (item) => Text(item['name']!),
                ),
                AlhambraDataColumn(
                  label: 'Score',
                  cellBuilder: (item) => Text(item['score']!),
                  numeric: true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('Item One'), findsOneWidget);
      expect(find.text('Item Two'), findsOneWidget);
    });

    testWidgets('AlhambraBadge displays label and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlhambraBadge(
              label: 'Verified',
              icon: Icons.check,
            ),
          ),
        ),
      );

      expect(find.text('Verified'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  // =========================================================================
  // 9. Feedback & Search
  // =========================================================================
  group('9. Feedback & Search', () {
    testWidgets('NotificationBell renders with unread count', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationBell(
              unreadCount: 4,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('4'), findsOneWidget);
      await tester.tap(find.byType(NotificationBell));
      expect(tapped, isTrue);
    });

    testWidgets('SearchResultsView displays search matches', (tester) async {
      const results = [
        SearchResult(
          resourceType: 'workspace',
          resourceId: 'ws-1',
          title: 'Macroeconomic Survey',
          description: 'Quarterly inflation metrics',
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SearchResultsView(results: results),
          ),
        ),
      );

      expect(find.text('Macroeconomic Survey'), findsOneWidget);
      expect(find.text('Quarterly inflation metrics'), findsOneWidget);
      expect(find.text('WORKSPACE'), findsOneWidget);
    });
  });

  // =========================================================================
  // 10. A2UI Foundation
  // =========================================================================
  group('10. A2UI Foundation', () {
    test('UiNode sealed hierarchy handles pattern matching', () {
      final nodes = <UiNode>[
        const TextNode('Hello'),
        const HeadingNode('Welcome', level: 1),
        const ButtonNode(label: 'Submit', action: SubmitAction(target: '/api')),
      ];

      final labels = nodes.map((n) => switch (n) {
            TextNode(:final text) => 'text:$text',
            HeadingNode(:final text, :final level) => 'h$level:$text',
            ButtonNode(:final label) => 'btn:$label',
            _ => 'other',
          }).toList();

      expect(labels, equals(['text:Hello', 'h1:Welcome', 'btn:Submit']));
    });

    testWidgets('DefaultUiNodeRenderer renders UiNode tree into widgets', (tester) async {
      const renderer = DefaultUiNodeRenderer();
      UiAction? capturedAction;

      const node = CardNode(
        title: 'Dynamic Agent Card',
        children: [
          HeadingNode('Summary Findings', level: 2),
          TextNode('Inflation trends have stabilized at 2.3%.'),
          ButtonNode(
            label: 'Confirm Analysis',
            action: ApproveAction('analysis-123'),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => renderer.render(
                context,
                node,
                onAction: (action) => capturedAction = action,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Dynamic Agent Card'), findsOneWidget);
      expect(find.text('Summary Findings'), findsOneWidget);
      expect(find.text('Inflation trends have stabilized at 2.3%.'), findsOneWidget);

      await tester.tap(find.text('Confirm Analysis'));
      expect(capturedAction, isA<ApproveAction>());
      expect((capturedAction as ApproveAction).resourceId, equals('analysis-123'));
    });
  });
}

// ---------------------------------------------------------------------------
// Test mock guard
// ---------------------------------------------------------------------------
final class _MockGuard implements RouteGuard {
  final bool allows;
  const _MockGuard(this.allows);

  @override
  Future<bool> canActivate(BuildContext context, String path) async => allows;
}
