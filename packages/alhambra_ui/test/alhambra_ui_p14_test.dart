import 'package:alhambra_ui/alhambra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── A2UiCodec — round-trip serialization ───────────────────────────────────
  group('A2UiCodec - P13 base node round-trips', () {
    UiSurface _surface(UiNode root) => UiSurface(
          id: 'test',
          title: 'Test',
          rootNode: root,
        );

    test('TextNode round-trips', () {
      final s = _surface(const TextNode('hello', isSecondary: true));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final node = decoded.rootNode as TextNode;
      expect(node.text, 'hello');
      expect(node.isSecondary, isTrue);
    });

    test('HeadingNode round-trips', () {
      final s = _surface(const HeadingNode('Title', level: 2));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final node = decoded.rootNode as HeadingNode;
      expect(node.text, 'Title');
      expect(node.level, 2);
    });

    test('ButtonNode with NavigateAction round-trips', () {
      final s = _surface(const ButtonNode(
        label: 'Go',
        action: NavigateAction('/home'),
      ));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final node = decoded.rootNode as ButtonNode;
      expect(node.label, 'Go');
      expect((node.action as NavigateAction).route, '/home');
    });

    test('TableNode round-trips', () {
      final s = _surface(const TableNode(
        headers: ['A', 'B'],
        rows: [
          ['1', '2'],
          ['3', '4'],
        ],
      ));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final node = decoded.rootNode as TableNode;
      expect(node.headers, ['A', 'B']);
      expect(node.rows[1], ['3', '4']);
    });

    test('ContainerNode with children round-trips', () {
      final s = _surface(const ContainerNode(children: [
        TextNode('a'),
        TextNode('b'),
      ]));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final node = decoded.rootNode as ContainerNode;
      expect(node.children.length, 2);
    });
  });

  group('A2UiCodec - P14 extended node round-trips', () {
    UiSurface _surface(UiNode root) => UiSurface(
          id: 'p14',
          title: 'P14 Test',
          rootNode: root,
        );

    test('MarkdownNode round-trips', () {
      final s = _surface(const MarkdownNode('**bold** text'));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      expect((decoded.rootNode as MarkdownNode).markdown, '**bold** text');
    });

    test('ListNode round-trips (ordered)', () {
      final s = _surface(const ListNode(
        items: [TextNode('item 1'), TextNode('item 2')],
        ordered: true,
      ));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final node = decoded.rootNode as ListNode;
      expect(node.ordered, isTrue);
      expect(node.items.length, 2);
    });

    test('BadgeNode round-trips', () {
      final s = _surface(const BadgeNode(label: 'PUBLISHED', variant: 'success'));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final node = decoded.rootNode as BadgeNode;
      expect(node.label, 'PUBLISHED');
      expect(node.variant, 'success');
    });

    test('DividerNode round-trips', () {
      final s = _surface(const DividerNode());
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      expect(decoded.rootNode, isA<DividerNode>());
    });

    test('MetadataRowNode round-trips', () {
      final s = _surface(const MetadataRowNode(label: 'Status', value: 'DRAFT'));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final node = decoded.rootNode as MetadataRowNode;
      expect(node.label, 'Status');
      expect(node.value, 'DRAFT');
    });

    test('ChartNode round-trips', () {
      final s = _surface(ChartNode(
        title: 'GDP Growth',
        chartType: 'line',
        labels: ['2022', '2023', '2024'],
        series: [
          {'label': 'Series A', 'values': [1.2, 2.3, 3.1]},
        ],
      ));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final node = decoded.rootNode as ChartNode;
      expect(node.title, 'GDP Growth');
      expect(node.chartType, 'line');
      expect(node.labels, ['2022', '2023', '2024']);
    });

    test('ArtifactNode round-trips', () {
      final s = _surface(const ArtifactNode(
        artifactId: 'art-1',
        title: 'Analysis',
        displayHint: 'table',
      ));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final node = decoded.rootNode as ArtifactNode;
      expect(node.artifactId, 'art-1');
      expect(node.displayHint, 'table');
    });

    test('ProvenanceNode round-trips with confidence', () {
      final s = _surface(const ProvenanceNode(
        evidenceId: 'ev-1',
        citation: 'IMF World Economic Outlook 2024',
        confidence: 0.87,
      ));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final node = decoded.rootNode as ProvenanceNode;
      expect(node.evidenceId, 'ev-1');
      expect(node.confidence, closeTo(0.87, 0.001));
    });

    test('ImageNode round-trips', () {
      final s = _surface(const ImageNode(
        url: 'https://example.com/chart.png',
        altText: 'GDP chart',
        maxHeight: 300,
      ));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final node = decoded.rootNode as ImageNode;
      expect(node.url, 'https://example.com/chart.png');
      expect(node.altText, 'GDP chart');
      expect(node.maxHeight, 300);
    });

    test('toJson / fromJson string round-trip', () {
      final original = UiSurface(
        id: 'json-test',
        title: 'JSON Round-trip',
        rootNode: const ContainerNode(children: [
          HeadingNode('Hello P14', level: 1),
          MarkdownNode('**bold** content'),
          BadgeNode(label: 'INFO', variant: 'info'),
        ]),
      );
      final json = A2UiCodec.toJson(original);
      final decoded = A2UiCodec.fromJson(json);
      expect(decoded.id, original.id);
      expect(decoded.title, original.title);
      final root = decoded.rootNode as ContainerNode;
      expect(root.children.length, 3);
      expect(root.children[0], isA<HeadingNode>());
      expect(root.children[1], isA<MarkdownNode>());
      expect(root.children[2], isA<BadgeNode>());
    });

    test('unknown _type degrades to TextNode', () {
      final json = {
        'id': 's',
        'title': 'T',
        'rootNode': {'_type': 'future_node_type', 'data': 'x'},
        'metadata': <String, Object?>{},
      };
      final decoded = A2UiCodec.decode(json);
      expect(decoded.rootNode, isA<TextNode>());
      final t = decoded.rootNode as TextNode;
      expect(t.text, contains('future_node_type'));
      expect(t.isSecondary, isTrue);
    });
  });

  // ── A2UiCodec — action round-trips ────────────────────────────────────────
  group('A2UiCodec - action round-trips', () {
    ButtonNode _btn(UiAction action) =>
        ButtonNode(label: 'X', action: action);
    UiSurface _s(UiAction a) =>
        UiSurface(id: 's', title: 't', rootNode: _btn(a));

    test('SubmitAction round-trips', () {
      final s = _s(const SubmitAction(
          target: 'forms/feedback', payload: {'rating': 5}));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final action = (decoded.rootNode as ButtonNode).action as SubmitAction;
      expect(action.target, 'forms/feedback');
      expect(action.payload['rating'], 5);
    });

    test('InvokeAction round-trips', () {
      final s = _s(const InvokeAction(
          command: 'open_artifact', parameters: {'id': 'art-1'}));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final action = (decoded.rootNode as ButtonNode).action as InvokeAction;
      expect(action.command, 'open_artifact');
    });

    test('ApproveAction round-trips', () {
      final s = _s(const ApproveAction('ws-99'));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final action =
          (decoded.rootNode as ButtonNode).action as ApproveAction;
      expect(action.resourceId, 'ws-99');
    });

    test('RejectAction round-trips with reason', () {
      final s = _s(const RejectAction('ws-99', reason: 'Incomplete'));
      final decoded = A2UiCodec.decode(A2UiCodec.encode(s));
      final action =
          (decoded.rootNode as ButtonNode).action as RejectAction;
      expect(action.reason, 'Incomplete');
    });
  });

  // ── A2UiActionGuard ────────────────────────────────────────────────────────
  group('DefaultA2UiActionGuard', () {
    final guard = const DefaultA2UiActionGuard();
    final surface = const UiSurface(
      id: 's',
      title: 'T',
      rootNode: DividerNode(),
    );

    test('permits NavigateAction', () {
      expect(guard.permits(surface, const NavigateAction('/home')), isTrue);
    });

    test('permits allowed InvokeAction', () {
      expect(
        guard.permits(surface, const InvokeAction(command: 'open_artifact')),
        isTrue,
      );
    });

    test('blocks unknown InvokeAction command', () {
      expect(
        guard.permits(
            surface, const InvokeAction(command: 'delete_everything')),
        isFalse,
      );
    });

    test('blocks internal SubmitAction target', () {
      expect(
        guard.permits(
            surface, const SubmitAction(target: '_internal/do_something')),
        isFalse,
      );
    });

    test('permits normal SubmitAction target', () {
      expect(
        guard.permits(surface, const SubmitAction(target: 'forms/feedback')),
        isTrue,
      );
    });

    test('denyReason is non-null for blocked actions', () {
      final reason = guard.denyReason(
          surface, const InvokeAction(command: 'rm_rf'));
      expect(reason, isNotNull);
      expect(reason, contains('rm_rf'));
    });
  });

  group('ReadOnlyA2UiActionGuard', () {
    const guard = ReadOnlyA2UiActionGuard();
    const surface = UiSurface(id: 's', title: 'T', rootNode: DividerNode());

    test('blocks all actions', () {
      for (final action in [
        const NavigateAction('/home'),
        const RefreshAction(),
        const ApproveAction('x'),
      ]) {
        expect(guard.permits(surface, action), isFalse);
      }
    });
  });

  // ── IntelligenceResultSurface ──────────────────────────────────────────────
  group('IntelligenceResultSurface', () {
    test('success surface has success badge', () {
      final surface = IntelligenceResultSurface.from(
        surfaceId: 'r1',
        title: 'Analysis Complete',
        success: true,
        summary: 'GDP grew by 2.3% in Q3.',
      );
      final root = surface.rootNode as ContainerNode;
      expect(root.children.first, isA<BadgeNode>());
      expect((root.children.first as BadgeNode).variant, 'success');
    });

    test('failed surface has error badge', () {
      final surface = IntelligenceResultSurface.from(
        surfaceId: 'r2',
        title: 'Analysis Failed',
        success: false,
        errorMessage: 'Timeout',
      );
      final root = surface.rootNode as ContainerNode;
      expect((root.children.first as BadgeNode).variant, 'error');
    });

    test('artifacts produce ArtifactNodes', () {
      final surface = IntelligenceResultSurface.from(
        surfaceId: 'r3',
        title: 'With Artifacts',
        success: true,
        artifacts: [
          const ArtifactSummary(id: 'a1', title: 'GDP Table', displayHint: 'table'),
        ],
      );
      final root = surface.rootNode as ContainerNode;
      final artifactNodes =
          root.children.whereType<ArtifactNode>().toList();
      expect(artifactNodes.length, 1);
      expect(artifactNodes.first.artifactId, 'a1');
    });

    test('evidence produces ProvenanceNodes', () {
      final surface = IntelligenceResultSurface.from(
        surfaceId: 'r4',
        title: 'With Evidence',
        success: true,
        evidence: [
          const EvidenceSummary(
              id: 'ev-1',
              citation: 'IMF 2024',
              confidence: 0.9),
        ],
      );
      final root = surface.rootNode as ContainerNode;
      final provNodes =
          root.children.whereType<ProvenanceNode>().toList();
      expect(provNodes.first.confidence, closeTo(0.9, 0.001));
    });

    test('warnings produce a ListNode', () {
      final surface = IntelligenceResultSurface.from(
        surfaceId: 'r5',
        title: 'Warnings',
        success: true,
        warnings: ['Data gap in 2020', 'Provisional estimates used'],
      );
      final root = surface.rootNode as ContainerNode;
      final listNode = root.children.whereType<ListNode>().first;
      expect(listNode.items.length, 2);
    });

    test('metadata includes success and artifactCount', () {
      final surface = IntelligenceResultSurface.from(
        surfaceId: 'r6',
        title: 'Meta',
        success: true,
        artifacts: [const ArtifactSummary(id: 'a', title: 'T')],
      );
      expect(surface.metadata['success'], isTrue);
      expect(surface.metadata['artifactCount'], 1);
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────
  group('UiSurfaceView + DefaultUiNodeRenderer P14 widgets', () {
    const renderer = DefaultUiNodeRenderer();

    Widget wrap(UiNode node) => MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => renderer.render(ctx, node),
            ),
          ),
        );

    testWidgets('BadgeNode renders label', (tester) async {
      await tester.pumpWidget(
          wrap(const BadgeNode(label: 'PUBLISHED', variant: 'success')));
      expect(find.text('PUBLISHED'), findsOneWidget);
    });

    testWidgets('DividerNode renders Divider', (tester) async {
      await tester.pumpWidget(wrap(const DividerNode()));
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('MetadataRowNode renders label and value', (tester) async {
      await tester.pumpWidget(
          wrap(const MetadataRowNode(label: 'Status', value: 'DRAFT')));
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('DRAFT'), findsOneWidget);
    });

    testWidgets('ListNode renders items with bullets', (tester) async {
      await tester.pumpWidget(wrap(const ListNode(
        items: [TextNode('Alpha'), TextNode('Beta')],
      )));
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('•'), findsWidgets);
    });

    testWidgets('MarkdownNode renders text content', (tester) async {
      await tester.pumpWidget(wrap(const MarkdownNode('Hello **world**')));
      expect(find.text('Hello **world**'), findsOneWidget);
    });

    testWidgets('UiSurfaceView blocks disallowed action via guard', (tester) async {
      final surface = const UiSurface(
        id: 's',
        title: 'T',
        rootNode: ButtonNode(
          label: 'Danger',
          action: InvokeAction(command: 'rm_rf'),
        ),
      );
      var actionFired = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UiSurfaceView(
            surface: surface,
            guard: const DefaultA2UiActionGuard(),
            onAction: (_) => actionFired = true,
          ),
        ),
      ));
      await tester.tap(find.text('Danger'));
      await tester.pump();
      expect(actionFired, isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('UiSurfaceView dispatches allowed action', (tester) async {
      final surface = const UiSurface(
        id: 's',
        title: 'T',
        rootNode: ButtonNode(
          label: 'Navigate',
          action: NavigateAction('/home'),
        ),
      );
      UiAction? received;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UiSurfaceView(
            surface: surface,
            guard: const DefaultA2UiActionGuard(),
            onAction: (a) => received = a,
          ),
        ),
      ));
      await tester.tap(find.text('Navigate'));
      await tester.pump();
      expect(received, isA<NavigateAction>());
    });
  });
}
