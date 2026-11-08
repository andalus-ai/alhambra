import 'package:alhambra_core/alhambra_core.dart';

import '../model/workspace.dart';

/// Service contract managing workspace lifecycle, review, publication, and derivation.
abstract interface class WorkspaceService {
  /// Creates a new workspace in [WorkspaceStatus.draft] state (version 1).
  Future<Workspace> create({
    required OrganizationId organizationId,
    required UserId ownerId,
    required String name,
    Map<String, Object?> metadata = const {},
  });

  /// Retrieves the latest state of the workspace with [id].
  Future<Workspace> get(WorkspaceId id);

  /// Updates workspace metadata (only allowed in draft state), producing a new version.
  Future<Workspace> updateMetadata({
    required WorkspaceId workspaceId,
    required UserId actorId,
    required Map<String, Object?> metadata,
  });

  /// Transitions workspace from DRAFT to REVIEW.
  Future<Workspace> submitForReview({
    required WorkspaceId workspaceId,
    required UserId actorId,
  });

  /// Approves the workspace in REVIEW state (enforces four-eyes rule: reviewer cannot be owner).
  Future<Workspace> approve({
    required WorkspaceId workspaceId,
    required UserId reviewerId,
  });

  /// Rejects the workspace in REVIEW state, reverting it to DRAFT.
  Future<Workspace> reject({
    required WorkspaceId workspaceId,
    required UserId reviewerId,
    required String reason,
  });

  /// Publishes an APPROVED workspace, evaluating all registered [PublishGate]s.
  Future<Workspace> publish({
    required WorkspaceId workspaceId,
    required UserId actorId,
  });

  /// Marks a PUBLISHED workspace as SUPERSEDED.
  Future<Workspace> supersede({
    required WorkspaceId workspaceId,
    required UserId actorId,
  });

  /// Archives a workspace from valid states (DRAFT, PUBLISHED, SUPERSEDED).
  Future<Workspace> archive({
    required WorkspaceId workspaceId,
    required UserId actorId,
  });

  /// Derives an independent, new DRAFT workspace from an existing workspace.
  Future<Workspace> deriveDraft({
    required WorkspaceId sourceWorkspaceId,
    required UserId actorId,
    required String name,
  });
}
