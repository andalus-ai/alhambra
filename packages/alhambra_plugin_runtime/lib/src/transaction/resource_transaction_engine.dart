import 'dart:convert';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// 3-way line-based text merge provider for plain text and source code.
class PlainTextMergeProvider implements ContentMergeProvider {
  @override
  bool supports(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.endsWith('.txt') ||
        path.endsWith('.dart') ||
        path.endsWith('.md') ||
        path.endsWith('.json') ||
        path.endsWith('.yaml') ||
        path.endsWith('.yml');
  }

  @override
  Future<MergeResult> merge({
    required ResourceSnapshot base,
    required ResourceSnapshot local,
    required ResourceSnapshot remote,
  }) async {
    final baseText = utf8.decode(base.content ?? const []);
    final localText = utf8.decode(local.content ?? const []);
    final remoteText = utf8.decode(remote.content ?? const []);

    // Fast-path: local is unchanged -> take remote
    if (localText == baseText) {
      return MergeSucceeded(utf8.encode(remoteText));
    }
    // Fast-path: remote is unchanged -> take local
    if (remoteText == baseText) {
      return MergeSucceeded(utf8.encode(localText));
    }
    // Fast-path: both changed identically
    if (localText == remoteText) {
      return MergeSucceeded(utf8.encode(localText));
    }

    // Line-by-line 3-way merge
    final baseLines = baseText.split('\n');
    final localLines = localText.split('\n');
    final remoteLines = remoteText.split('\n');

    final merged = <String>[];
    final conflicts = <MergeConflict>[];

    final maxLen = [
      baseLines.length,
      localLines.length,
      remoteLines.length,
    ].reduce((a, b) => a > b ? a : b);

    for (var i = 0; i < maxLen; i++) {
      final bLine = i < baseLines.length ? baseLines[i] : null;
      final lLine = i < localLines.length ? localLines[i] : null;
      final rLine = i < remoteLines.length ? remoteLines[i] : null;

      if (lLine == rLine) {
        if (lLine != null) merged.add(lLine);
      } else if (lLine == bLine) {
        if (rLine != null) merged.add(rLine);
      } else if (rLine == bLine) {
        if (lLine != null) merged.add(lLine);
      } else {
        // Line-level conflict
        conflicts.add(
          MergeConflict(
            offset: i,
            length: 1,
            baseChunk: bLine ?? '',
            localChunk: lLine ?? '',
            remoteChunk: rLine ?? '',
          ),
        );
      }
    }

    if (conflicts.isNotEmpty) {
      return MergeConflicted(conflicts);
    }

    return MergeSucceeded(utf8.encode(merged.join('\n')));
  }
}

/// Default in-memory resource transaction manager with atomic version validation.
class DefaultResourceTransactionManager implements ResourceTransactionManager {
  final Map<String, ResourceSnapshot> _storage = {};
  final ContentMergeProvider mergeProvider;

  DefaultResourceTransactionManager({ContentMergeProvider? mergeProvider})
    : mergeProvider = mergeProvider ?? PlainTextMergeProvider();

  void seedResource(ResourceSnapshot snapshot) {
    _storage[snapshot.uri.toString()] = snapshot;
  }

  ResourceSnapshot? getSnapshot(Uri uri) => _storage[uri.toString()];

  @override
  Future<CommitResult> commit(ResourceTransaction transaction) async {
    final key = transaction.uri.toString();
    final current = _storage[key];

    // Check version match
    if (current != null && current.version != transaction.expectedVersion) {
      return CommitConflict(current);
    }

    // Apply operations
    List<int>? newContent = current?.content;
    for (final op in transaction.operations) {
      switch (op) {
        case WriteResource(:final bytes):
          newContent = bytes;
          break;
        case DeleteResource():
          _storage.remove(key);
          return CommitSuccess(
            DocumentVersion('deleted_${DateTime.now().microsecondsSinceEpoch}'),
          );
        case RenameResource(:final from, :final to):
          final existing = _storage.remove(from.toString());
          if (existing != null) {
            final renamed = ResourceSnapshot(
              uri: to,
              version: DocumentVersion(
                'v_${DateTime.now().microsecondsSinceEpoch}',
              ),
              content: existing.content,
            );
            _storage[to.toString()] = renamed;
            return CommitSuccess(renamed.version);
          }
          break;
      }
    }

    final newVersion = DocumentVersion(
      'v_${DateTime.now().microsecondsSinceEpoch}',
    );
    _storage[key] = ResourceSnapshot(
      uri: transaction.uri,
      version: newVersion,
      content: newContent,
    );

    return CommitSuccess(newVersion);
  }
}
