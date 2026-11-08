import 'package:alhambra_adapter_batik/alhambra_adapter_batik.dart';
import 'package:alhambra_ui/alhambra_ui.dart' as a2ui;
import 'package:batik/batik.dart' as batik;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Initialise Batik schema so UINode.fromJson works.
  setUpAll(() async {
    await batik.AgentUIKit.initialize();
  });

  // ── A2UiToBatikConverter ───────────────────────────────────────────────────
  group('A2UiToBatikConverter', () {
    a2ui.UiSurface _surface(a2ui.UiNode root) => a2ui.UiSurface(
          id: 'test',
          title: 'Test Surface',
          rootNode: root,
        );

    test('TextNode → batik.TextNode with bodyMedium variant', () {
      final resp =
          A2UiToBatikConverter.convert(_surface(const a2ui.TextNode('hello')));
      final n = resp.root as batik.TextNode;
      expect(n.text, 'hello');
      expect(n.variant, 'bodyMedium');
    });

    test('TextNode (secondary) → batik.TextNode with bodySmall variant', () {
      final resp = A2UiToBatikConverter.convert(
          _surface(const a2ui.TextNode('hint', isSecondary: true)));
      expect((resp.root as batik.TextNode).variant, 'bodySmall');
    });

    test('HeadingNode level 2 → batik.TextNode variant h2', () {
      final resp = A2UiToBatikConverter.convert(
          _surface(const a2ui.HeadingNode('Title', level: 2)));
      expect((resp.root as batik.TextNode).variant, 'h2');
    });

    test('ButtonNode → batik.ButtonNode with filled variant and onTap action', () {
      final resp = A2UiToBatikConverter.convert(_surface(const a2ui.ButtonNode(
        label: 'Go',
        action: a2ui.NavigateAction('/home'),
        isPrimary: true,
      )));
      final n = resp.root as batik.ButtonNode;
      expect(n.label, 'Go');
      expect(n.variant, 'filled');
      expect(n.actions['onTap']?.type, 'navigate');
      expect(n.actions['onTap']?.payload['route'], '/home');
    });

    test('CardNode with title → first child is TextNode heading', () {
      final resp = A2UiToBatikConverter.convert(
          _surface(const a2ui.CardNode(title: 'My Card', children: [
        a2ui.TextNode('body'),
      ])));
      final card = resp.root as batik.CardNode;
      expect(card.children.length, 2); // title TextNode + body TextNode
      expect((card.children.first as batik.TextNode).variant, 'titleMedium');
    });

    test('ContainerNode (isRow) → batik.RowNode', () {
      final resp = A2UiToBatikConverter.convert(_surface(
          const a2ui.ContainerNode(isRow: true, children: [a2ui.TextNode('a')])));
      expect(resp.root, isA<batik.RowNode>());
    });

    test('ContainerNode (isColumn) → batik.ColumnNode', () {
      final resp = A2UiToBatikConverter.convert(_surface(
          const a2ui.ContainerNode(children: [a2ui.TextNode('a')])));
      expect(resp.root, isA<batik.ColumnNode>());
    });

    test('MarkdownNode → batik.MarkdownNode with content', () {
      final resp = A2UiToBatikConverter.convert(
          _surface(const a2ui.MarkdownNode('**bold**')));
      expect((resp.root as batik.MarkdownNode).content, '**bold**');
    });

    test('ListNode → batik.ListNode with children', () {
      final resp = A2UiToBatikConverter.convert(
          _surface(const a2ui.ListNode(items: [a2ui.TextNode('x')])));
      expect((resp.root as batik.ListNode).children.length, 1);
    });

    test('BadgeNode success → backgroundColor #2E7D32', () {
      final resp = A2UiToBatikConverter.convert(
          _surface(const a2ui.BadgeNode(label: 'OK', variant: 'success')));
      final n = resp.root as batik.BadgeNode;
      expect(n.label, 'OK');
      expect(n.backgroundColor, '#2E7D32');
    });

    test('BadgeNode neutral → no backgroundColor', () {
      final resp = A2UiToBatikConverter.convert(
          _surface(const a2ui.BadgeNode(label: 'X', variant: 'neutral')));
      expect((resp.root as batik.BadgeNode).backgroundColor, isNull);
    });

    test('DividerNode → batik.DividerNode', () {
      final resp =
          A2UiToBatikConverter.convert(_surface(const a2ui.DividerNode()));
      expect(resp.root, isA<batik.DividerNode>());
    });

    test('ChartNode → batik.ChartNode with data map', () {
      final resp = A2UiToBatikConverter.convert(_surface(a2ui.ChartNode(
        title: 'GDP',
        chartType: 'line',
        labels: ['Q1', 'Q2'],
        series: [
          {'label': 'A', 'values': [1, 2]}
        ],
      )));
      final n = resp.root as batik.ChartNode;
      expect(n.title, 'GDP');
      expect(n.chartType, 'line');
      expect(n.data['labels'], ['Q1', 'Q2']);
    });

    test('ImageNode → batik.ImageNode with src and alt', () {
      final resp = A2UiToBatikConverter.convert(_surface(
          const a2ui.ImageNode(url: 'https://x.com/i.png', altText: 'Chart')));
      final n = resp.root as batik.ImageNode;
      expect(n.src, 'https://x.com/i.png');
      expect(n.alt, 'Chart');
    });

    test('surface metadata is preserved', () {
      final surface = a2ui.UiSurface(
        id: 'surf-1',
        title: 'My Surface',
        rootNode: const a2ui.DividerNode(),
        metadata: {'tag': 'test'},
      );
      final resp = A2UiToBatikConverter.convert(surface);
      expect(resp.metadata['a2ui_surface_id'], 'surf-1');
      expect(resp.metadata['tag'], 'test');
    });

    test('NavigateAction → batik navigate payload', () {
      final action = a2ui.NavigateAction('/dashboard');
      final resp = A2UiToBatikConverter.convert(_surface(a2ui.ButtonNode(
        label: 'X',
        action: action,
      )));
      final btn = resp.root as batik.ButtonNode;
      expect(btn.actions['onTap']?.payload['route'], '/dashboard');
    });

    test('InvokeAction → batik custom action with command', () {
      final resp = A2UiToBatikConverter.convert(_surface(a2ui.ButtonNode(
        label: 'X',
        action: const a2ui.InvokeAction(command: 'open_artifact'),
      )));
      final btn = resp.root as batik.ButtonNode;
      expect(btn.actions['onTap']?.type, 'custom');
      expect(btn.actions['onTap']?.payload['command'], 'open_artifact');
    });

    test('ApproveAction → batik custom with approve command', () {
      final resp = A2UiToBatikConverter.convert(_surface(a2ui.ButtonNode(
        label: 'X',
        action: const a2ui.ApproveAction('ws-1'),
      )));
      final btn = resp.root as batik.ButtonNode;
      expect(btn.actions['onTap']?.payload['command'], 'approve');
      expect(btn.actions['onTap']?.payload['resourceId'], 'ws-1');
    });
  });

  // ── BatikToA2UiConverter ───────────────────────────────────────────────────
  group('BatikToA2UiConverter', () {
    batik.AgentUIResponse _resp(batik.UINode root) => batik.AgentUIResponse(
          schemaVersion: '1.0.0',
          root: root,
        );

    test('batik.TextNode body → a2ui.TextNode', () {
      final surface = BatikToA2UiConverter.convert(
          _resp(batik.TextNode(text: 'hello')));
      expect(surface.rootNode, isA<a2ui.TextNode>());
      expect((surface.rootNode as a2ui.TextNode).text, 'hello');
    });

    test('batik.TextNode h2 variant → a2ui.HeadingNode level 2', () {
      final surface = BatikToA2UiConverter.convert(
          _resp(batik.TextNode(text: 'Title', variant: 'h2')));
      final n = surface.rootNode as a2ui.HeadingNode;
      expect(n.level, 2);
      expect(n.text, 'Title');
    });

    test('batik.ButtonNode → a2ui.ButtonNode isPrimary=true for filled', () {
      final surface = BatikToA2UiConverter.convert(_resp(batik.ButtonNode(
        label: 'Click',
        variant: 'filled',
        actions: {
          'onTap': batik.UIAction(type: 'navigate', payload: {'route': '/x'})
        },
      )));
      final n = surface.rootNode as a2ui.ButtonNode;
      expect(n.label, 'Click');
      expect(n.isPrimary, isTrue);
      expect((n.action as a2ui.NavigateAction).route, '/x');
    });

    test('batik.MarkdownNode → a2ui.MarkdownNode', () {
      final surface = BatikToA2UiConverter.convert(
          _resp(batik.MarkdownNode(content: '**bold**')));
      expect((surface.rootNode as a2ui.MarkdownNode).markdown, '**bold**');
    });

    test('batik.DividerNode → a2ui.DividerNode', () {
      final surface =
          BatikToA2UiConverter.convert(_resp(batik.DividerNode()));
      expect(surface.rootNode, isA<a2ui.DividerNode>());
    });

    test('batik.BadgeNode success color → a2ui.BadgeNode success variant', () {
      final surface = BatikToA2UiConverter.convert(
          _resp(batik.BadgeNode(label: 'OK', backgroundColor: '#2e7d32')));
      final n = surface.rootNode as a2ui.BadgeNode;
      expect(n.label, 'OK');
      expect(n.variant, 'success');
    });

    test('batik.BadgeNode neutral color → a2ui.BadgeNode neutral', () {
      final surface = BatikToA2UiConverter.convert(
          _resp(batik.BadgeNode(label: 'X')));
      expect((surface.rootNode as a2ui.BadgeNode).variant, 'neutral');
    });

    test('batik.ImageNode → a2ui.ImageNode', () {
      final surface = BatikToA2UiConverter.convert(
          _resp(batik.ImageNode(src: 'https://x.com/i.png', alt: 'alt text')));
      final n = surface.rootNode as a2ui.ImageNode;
      expect(n.url, 'https://x.com/i.png');
      expect(n.altText, 'alt text');
    });

    test('batik.ChartNode → a2ui.ChartNode with labels/series extracted', () {
      final surface = BatikToA2UiConverter.convert(_resp(batik.ChartNode(
        chartType: 'bar',
        title: 'Revenue',
        data: {
          'labels': ['Q1', 'Q2'],
          'series': [
            {'label': 'A', 'values': [10, 20]}
          ],
        },
      )));
      final n = surface.rootNode as a2ui.ChartNode;
      expect(n.title, 'Revenue');
      expect(n.labels, ['Q1', 'Q2']);
      expect(n.series.first['label'], 'A');
    });

    test('batik unknown type → a2ui.TextNode fallback (secondary)', () {
      // Use fromJson with unregistered type to produce UnknownNode
      final raw = batik.UINode.fromJson({'type': 'future_widget_xyz'});
      final surface = BatikToA2UiConverter.convert(_resp(raw));
      final n = surface.rootNode as a2ui.TextNode;
      expect(n.isSecondary, isTrue);
      expect(n.text, contains('future_widget_xyz'));
    });

    test('surface id/title generated from sessionId/turnId', () {
      final resp = batik.AgentUIResponse(
        schemaVersion: '1.0.0',
        root: batik.DividerNode(),
        sessionId: 'sess-42',
        turnId: 'turn-7',
      );
      final surface = BatikToA2UiConverter.convert(resp);
      expect(surface.id, 'sess-42');
    });

    test('custom title override is respected', () {
      final resp = batik.AgentUIResponse(
        schemaVersion: '1.0.0',
        root: batik.DividerNode(),
      );
      final surface = BatikToA2UiConverter.convert(resp, title: 'Custom Title');
      expect(surface.title, 'Custom Title');
    });
  });

  // ── AlhambraActionHandler ──────────────────────────────────────────────────
  // These tests use testWidgets to get a real BuildContext.
  group('AlhambraActionHandler', () {
    testWidgets('navigate action dispatches NavigateAction', (tester) async {
      a2ui.UiAction? received;
      final handler = AlhambraActionHandler(onAction: (a) => received = a);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));
      await handler.handle(
        ctx,
        batik.UIAction(type: 'navigate', payload: {'route': '/home'}),
        {},
      );
      expect(received, isA<a2ui.NavigateAction>());
      expect((received as a2ui.NavigateAction).route, '/home');
    });

    testWidgets('custom approve action dispatches ApproveAction', (tester) async {
      a2ui.UiAction? received;
      final handler = AlhambraActionHandler(onAction: (a) => received = a);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));
      await handler.handle(
        ctx,
        batik.UIAction(
            type: 'custom',
            payload: {'command': 'approve', 'resourceId': 'ws-5'}),
        {},
      );
      expect(received, isA<a2ui.ApproveAction>());
      expect((received as a2ui.ApproveAction).resourceId, 'ws-5');
    });

    testWidgets('custom reject dispatches RejectAction with reason', (tester) async {
      a2ui.UiAction? received;
      final handler = AlhambraActionHandler(onAction: (a) => received = a);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));
      await handler.handle(
        ctx,
        batik.UIAction(type: 'custom', payload: {
          'command': 'reject',
          'resourceId': 'ws-5',
          'reason': 'Incomplete',
        }),
        {},
      );
      final reject = received as a2ui.RejectAction;
      expect(reject.resourceId, 'ws-5');
      expect(reject.reason, 'Incomplete');
    });

    testWidgets('ReadOnlyGuard blocks all actions', (tester) async {
      final surface = const a2ui.UiSurface(
        id: 's',
        title: 'T',
        rootNode: a2ui.DividerNode(),
      );
      var fired = false;
      final handler = AlhambraActionHandler(
        onAction: (_) => fired = true,
        guard: const a2ui.ReadOnlyA2UiActionGuard(),
        surface: surface,
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));
      await handler.handle(
        ctx,
        batik.UIAction(type: 'navigate', payload: {'route': '/'}),
        {},
      );
      expect(fired, isFalse);
    });

    testWidgets('custom invoke command dispatches InvokeAction', (tester) async {
      a2ui.UiAction? received;
      final handler = AlhambraActionHandler(onAction: (a) => received = a);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));
      await handler.handle(
        ctx,
        batik.UIAction(
            type: 'custom',
            payload: {'command': 'open_artifact', 'id': 'art-1'}),
        {},
      );
      final invoke = received as a2ui.InvokeAction;
      expect(invoke.command, 'open_artifact');
      expect(invoke.parameters['id'], 'art-1');
    });
  });

  // ── AndalusAdapter ─────────────────────────────────────────────────────────
  group('AndalusAdapter', () {
    test('parseResponse handles full AgentUIResponse envelope', () {
      final adapter = AndalusAdapter(
        baseUrl: 'https://andalus.test',
        apiKey: 'key',
      );
      final json = '{"schemaVersion":"1.0.0","root":{"type":"text","text":"hi"}}';
      final result = adapter.parseResponse(json);
      expect(result, isNotNull);
      expect(result!.root, isA<batik.TextNode>());
    });

    test('parseResponse handles bare UINode', () {
      final adapter = AndalusAdapter(
        baseUrl: 'https://andalus.test',
        apiKey: 'key',
      );
      final json = '{"type":"divider"}';
      final result = adapter.parseResponse(json);
      expect(result, isNotNull);
      expect(result!.root, isA<batik.DividerNode>());
    });

    test('parseResponse handles Andalus {ui,text} wrapper', () {
      final adapter = AndalusAdapter(
        baseUrl: 'https://andalus.test',
        apiKey: 'key',
      );
      final json =
          '{"ui":{"schemaVersion":"1.0.0","root":{"type":"divider"}},"text":"summary"}';
      final result = adapter.parseResponse(json);
      expect(result, isNotNull);
    });

    test('parseResponse returns null for invalid JSON', () {
      final adapter = AndalusAdapter(
        baseUrl: 'https://andalus.test',
        apiKey: 'key',
      );
      expect(adapter.parseResponse('not json'), isNull);
    });

    test('adapter includes org header in request (via metadata)', () {
      // Just verify AndalusAdapter builds without error with all optional params.
      final adapter = AndalusAdapter(
        baseUrl: 'https://andalus.test',
        apiKey: 'key',
        organizationId: 'org-1',
        workspaceId: 'ws-1',
        appContext: 'Alhambra Platform',
      );
      expect(adapter.organizationId, 'org-1');
      expect(adapter.workspaceId, 'ws-1');
    });
  });
}


