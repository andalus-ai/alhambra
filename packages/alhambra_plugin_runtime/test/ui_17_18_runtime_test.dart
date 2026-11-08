import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';

void main() {
  group('UI-17: Resource Transactions & 3-Way Merge', () {
    late PlainTextMergeProvider mergeProvider;
    late DefaultResourceTransactionManager txManager;

    setUp(() {
      mergeProvider = PlainTextMergeProvider();
      txManager = DefaultResourceTransactionManager(
        mergeProvider: mergeProvider,
      );
    });

    test('supports recognized plain text extensions', () {
      expect(
        mergeProvider.supports(Uri.parse('file:///src/main.dart')),
        isTrue,
      );
      expect(mergeProvider.supports(Uri.parse('file:///README.md')), isTrue);
      expect(mergeProvider.supports(Uri.parse('file:///data.json')), isTrue);
      expect(mergeProvider.supports(Uri.parse('file:///image.png')), isFalse);
    });

    test('3-way merge fast path: local changed, remote unchanged', () async {
      final base = ResourceSnapshot(
        uri: Uri.parse('file:///test.txt'),
        version: DocumentVersion('v1'),
        content: utf8.encode('Line 1\nLine 2\nLine 3'),
      );
      final local = ResourceSnapshot(
        uri: Uri.parse('file:///test.txt'),
        version: DocumentVersion('v2_local'),
        content: utf8.encode('Line 1\nLine 2 Modified\nLine 3'),
      );
      final remote = ResourceSnapshot(
        uri: Uri.parse('file:///test.txt'),
        version: DocumentVersion('v1'),
        content: utf8.encode('Line 1\nLine 2\nLine 3'),
      );

      final result = await mergeProvider.merge(
        base: base,
        local: local,
        remote: remote,
      );
      expect(result, isA<MergeSucceeded>());
      final merged = (result as MergeSucceeded).content;
      expect(utf8.decode(merged), equals('Line 1\nLine 2 Modified\nLine 3'));
    });

    test('3-way merge non-overlapping edits succeed', () async {
      final base = ResourceSnapshot(
        uri: Uri.parse('file:///test.txt'),
        version: DocumentVersion('v1'),
        content: utf8.encode('Line 1\nLine 2\nLine 3'),
      );
      final local = ResourceSnapshot(
        uri: Uri.parse('file:///test.txt'),
        version: DocumentVersion('v2_local'),
        content: utf8.encode('Line 1 Local\nLine 2\nLine 3'),
      );
      final remote = ResourceSnapshot(
        uri: Uri.parse('file:///test.txt'),
        version: DocumentVersion('v2_remote'),
        content: utf8.encode('Line 1\nLine 2\nLine 3 Remote'),
      );

      final result = await mergeProvider.merge(
        base: base,
        local: local,
        remote: remote,
      );
      expect(result, isA<MergeSucceeded>());
      final merged = (result as MergeSucceeded).content;
      expect(
        utf8.decode(merged),
        equals('Line 1 Local\nLine 2\nLine 3 Remote'),
      );
    });

    test('3-way merge overlapping edits produce conflicts', () async {
      final base = ResourceSnapshot(
        uri: Uri.parse('file:///test.txt'),
        version: DocumentVersion('v1'),
        content: utf8.encode('Line 1\nOriginal Line 2\nLine 3'),
      );
      final local = ResourceSnapshot(
        uri: Uri.parse('file:///test.txt'),
        version: DocumentVersion('v2_local'),
        content: utf8.encode('Line 1\nLocal Change 2\nLine 3'),
      );
      final remote = ResourceSnapshot(
        uri: Uri.parse('file:///test.txt'),
        version: DocumentVersion('v2_remote'),
        content: utf8.encode('Line 1\nRemote Change 2\nLine 3'),
      );

      final result = await mergeProvider.merge(
        base: base,
        local: local,
        remote: remote,
      );
      expect(result, isA<MergeConflicted>());
      final conflicts = (result as MergeConflicted).conflicts;
      expect(conflicts.length, equals(1));
      expect(conflicts.first.baseChunk, equals('Original Line 2'));
      expect(conflicts.first.localChunk, equals('Local Change 2'));
      expect(conflicts.first.remoteChunk, equals('Remote Change 2'));
    });

    test('transaction commit succeeds with expected version', () async {
      final docUri = Uri.parse('file:///workspace/sample.dart');
      final initialSnapshot = ResourceSnapshot(
        uri: docUri,
        version: DocumentVersion('v1'),
        content: utf8.encode('void main() {}'),
      );
      txManager.seedResource(initialSnapshot);

      final tx = ResourceTransaction(
        uri: docUri,
        expectedVersion: DocumentVersion('v1'),
        operations: [
          WriteResource(
            uri: docUri,
            bytes: utf8.encode('void main() { print("hello"); }'),
          ),
        ],
      );

      final commitResult = await txManager.commit(tx);
      expect(commitResult, isA<CommitSuccess>());

      final updated = txManager.getSnapshot(docUri);
      expect(updated, isNotNull);
      expect(
        utf8.decode(updated!.content!),
        equals('void main() { print("hello"); }'),
      );
    });

    test(
      'transaction commit detects conflict on stale expected version',
      () async {
        final docUri = Uri.parse('file:///workspace/sample.dart');
        final initialSnapshot = ResourceSnapshot(
          uri: docUri,
          version: DocumentVersion('v2_updated'),
          content: utf8.encode('void main() { print("fresh"); }'),
        );
        txManager.seedResource(initialSnapshot);

        final staleTx = ResourceTransaction(
          uri: docUri,
          expectedVersion: DocumentVersion('v1_stale'),
          operations: [
            WriteResource(uri: docUri, bytes: utf8.encode('stale write')),
          ],
        );

        final commitResult = await txManager.commit(staleTx);
        expect(commitResult, isA<CommitConflict>());
      },
    );
  });

  group('UI-18: Declarative Layout Engine & Tree Serialization', () {
    late LayoutSerializer serializer;
    late DefaultDeclarativeLayoutController controller;

    setUp(() {
      serializer = LayoutSerializer();
      controller = DefaultDeclarativeLayoutController();
    });

    test('initial layout state starts with placeholder', () {
      expect(controller.state.tree.root, isA<DeclarativePlaceholderNode>());
      expect(controller.state.openViews, isEmpty);
    });

    test('openView inserts layout view node and tracks openViews', () {
      final viewId = ViewInstanceId('editor_1');
      controller.openView(viewId);

      expect(controller.state.openViews, contains(viewId));
      expect(controller.state.tree.root, isA<LayoutViewNode>());
      expect(
        (controller.state.tree.root as LayoutViewNode).instanceId,
        equals(viewId),
      );
    });

    test('split creates DeclarativeSplitNode with specified direction', () {
      final view1 = ViewInstanceId('editor_1');
      controller.openView(view1);
      controller.split(view1, DeclarativeSplitDirection.vertical);

      expect(controller.state.tree.root, isA<DeclarativeSplitNode>());
      final split = controller.state.tree.root as DeclarativeSplitNode;
      expect(split.direction, equals(DeclarativeSplitDirection.vertical));
      expect(split.first, isA<LayoutViewNode>());
    });

    test('pin and unpin view updates pinnedViews set', () {
      final view1 = ViewInstanceId('editor_1');
      controller.pinView(view1);
      expect(controller.state.pinnedViews, contains(view1));

      controller.unpinView(view1);
      expect(controller.state.pinnedViews, isNot(contains(view1)));
    });

    test(
      'serialize and deserialize restores declarative layout tree faithfully',
      () {
        final view1 = ViewInstanceId('view_a');
        final view2 = ViewInstanceId('view_b');
        final originalState = DeclarativeLayoutState(
          tree: DeclarativeLayoutTree(
            root: DeclarativeSplitNode(
              direction: DeclarativeSplitDirection.horizontal,
              ratio: 0.6,
              first: LayoutViewNode(view1),
              second: DeclarativeTabNode(tabs: [view2], activeIndex: 0),
            ),
          ),
          openViews: {view1, view2},
          pinnedViews: {view1},
        );

        final jsonStr = serializer.serialize(originalState);
        final restoredState = serializer.deserialize(jsonStr);

        expect(restoredState.openViews, equals(originalState.openViews));
        expect(restoredState.pinnedViews, equals(originalState.pinnedViews));
        expect(restoredState.tree.root, isA<DeclarativeSplitNode>());

        final split = restoredState.tree.root as DeclarativeSplitNode;
        expect(split.direction, equals(DeclarativeSplitDirection.horizontal));
        expect(split.ratio, equals(0.6));
        expect(split.first, isA<LayoutViewNode>());
        expect((split.first as LayoutViewNode).instanceId, equals(view1));
        expect(split.second, isA<DeclarativeTabNode>());
        expect((split.second as DeclarativeTabNode).tabs, equals([view2]));
      },
    );

    test('ExtensionRuntime initializes with transactionManager and declarativeLayoutController', () {
      final runtime = ExtensionRuntime();
      expect(runtime.transactionManager, isNotNull);
      expect(runtime.declarativeLayoutController, isNotNull);
      expect(runtime.layoutSerializer, isNotNull);
    });
  });
}
