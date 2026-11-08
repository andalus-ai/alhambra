/// WorkspaceContext — ambient context available to all workspace screens.
///
/// Provides the workspace identity, organization boundary, lifecycle status,
/// versioning, and current sync state — everything a workspace screen needs
/// without reaching up to a global store.
final class WorkspaceContext {
  /// The workspace being displayed.
  final String workspaceId;

  /// Organization that owns this workspace (immutable for this screen).
  final String organizationId;

  /// Current lifecycle status as a string (e.g., `'DRAFT'`, `'PUBLISHED'`).
  final String? status;

  /// Current version label (e.g., `'12'`).
  final String? currentVersion;

  /// ISO-8601 string of the last server update.
  final String? lastUpdatedAt;

  const WorkspaceContext({
    required this.workspaceId,
    required this.organizationId,
    this.status,
    this.currentVersion,
    this.lastUpdatedAt,
  });

  /// Returns a copy with updated fields.
  WorkspaceContext copyWith({
    String? status,
    String? currentVersion,
    String? lastUpdatedAt,
  }) =>
      WorkspaceContext(
        workspaceId: workspaceId,
        organizationId: organizationId,
        status: status ?? this.status,
        currentVersion: currentVersion ?? this.currentVersion,
        lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      );

  @override
  String toString() =>
      'WorkspaceContext($workspaceId, org: $organizationId, status: $status)';
}

/// Lifecycle status constant strings for a workspace.
///
/// Matches the P3 workspace state machine:
/// DRAFT → REVIEW → APPROVED → PUBLISHED → SUPERSEDED → ARCHIVED
///
/// Named [WorkspaceLifecycleStatus] to avoid conflict with
/// `alhambra_workspace`'s `WorkspaceStatus` enum.
abstract final class WorkspaceLifecycleStatus {
  static const String draft = 'DRAFT';
  static const String review = 'REVIEW';
  static const String approved = 'APPROVED';
  static const String published = 'PUBLISHED';
  static const String superseded = 'SUPERSEDED';
  static const String archived = 'ARCHIVED';

  /// Human-readable label for a given status string.
  static String labelFor(String status) => switch (status.toUpperCase()) {
        'DRAFT' => 'Draft',
        'REVIEW' => 'Awaiting review',
        'APPROVED' => 'Approved',
        'PUBLISHED' => 'Published',
        'SUPERSEDED' => 'Superseded',
        'ARCHIVED' => 'Archived',
        _ => status,
      };
}
