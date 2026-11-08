import '../plugins/plugin_sdk_contracts.dart';

/// State of a resource transaction.
enum ResourceTransactionState {
  pending,
  validating,
  committing,
  committed,
  conflicted,
  failed,
  cancelled,
}

/// Abstract operation applied in a resource transaction.
sealed class ResourceOperation {
  const ResourceOperation();
}

final class WriteResource extends ResourceOperation {
  final Uri uri;
  final List<int> bytes;

  const WriteResource({
    required this.uri,
    required this.bytes,
  });
}

final class DeleteResource extends ResourceOperation {
  final Uri uri;
  const DeleteResource(this.uri);
}

final class RenameResource extends ResourceOperation {
  final Uri from;
  final Uri to;

  const RenameResource({
    required this.from,
    required this.to,
  });
}

/// Opaque document version identifier (e.g. mtime, hash, ETag, git SHA).
final class DocumentVersion {
  final String value;
  const DocumentVersion(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentVersion &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

enum VersionRelation {
  same,
  newer,
  older,
  unknown,
}

/// Point-in-time snapshot of a resource.
final class ResourceSnapshot {
  final Uri uri;
  final DocumentVersion version;
  final List<int>? content;

  const ResourceSnapshot({
    required this.uri,
    required this.version,
    this.content,
  });
}

/// Conflict description when base, local, and remote snapshots diverge.
final class DocumentConflict {
  final Uri uri;
  final ResourceSnapshot base;
  final ResourceSnapshot local;
  final ResourceSnapshot remote;

  const DocumentConflict({
    required this.uri,
    required this.base,
    required this.local,
    required this.remote,
  });
}

/// Strategy for resolving concurrent mutations.
enum MergeStrategy {
  manual,
  preferLocal,
  preferRemote,
  threeWay,
  custom,
}

final class MergeConflict {
  final int offset;
  final int length;
  final String baseChunk;
  final String localChunk;
  final String remoteChunk;

  const MergeConflict({
    required this.offset,
    required this.length,
    required this.baseChunk,
    required this.localChunk,
    required this.remoteChunk,
  });
}

sealed class MergeResult {
  const MergeResult();
}

final class MergeSucceeded extends MergeResult {
  final List<int> content;
  const MergeSucceeded(this.content);
}

final class MergeConflicted extends MergeResult {
  final List<MergeConflict> conflicts;
  const MergeConflicted(this.conflicts);
}

/// Provider-neutral interface for merging file contents.
abstract interface class ContentMergeProvider {
  bool supports(Uri uri);
  Future<MergeResult> merge({
    required ResourceSnapshot base,
    required ResourceSnapshot local,
    required ResourceSnapshot remote,
  });
}

/// Result of committing a resource transaction.
sealed class CommitResult {
  const CommitResult();
}

final class CommitSuccess extends CommitResult {
  final DocumentVersion version;
  const CommitSuccess(this.version);
}

final class CommitConflict extends CommitResult {
  final ResourceSnapshot current;
  const CommitConflict(this.current);
}

final class CommitFailed extends CommitResult {
  final String reason;
  const CommitFailed(this.reason);
}

/// Transaction bundle containing one or more resource operations.
final class ResourceTransaction {
  final List<ResourceOperation> operations;
  final DocumentVersion expectedVersion;
  final Uri uri;

  const ResourceTransaction({
    required this.uri,
    required this.operations,
    required this.expectedVersion,
  });
}

/// Manager interface for executing transactions with optimistic concurrency control.
abstract interface class ResourceTransactionManager {
  Future<CommitResult> commit(ResourceTransaction transaction);
}
