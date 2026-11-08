import 'package:alhambra_core/alhambra_core.dart';

import '../lifecycle/workspace_lifecycle.dart';
import '../lifecycle/workspace_status.dart';
import '../model/workspace.dart';
import '../model/workspace_member.dart';
import '../model/workspace_version.dart';
import '../publication/publication_blocked.dart';
import '../publication/publish_gate.dart';
import '../repository/workspace_repository.dart';
import '../review/workspace_approval_exception.dart';
import 'workspace_service.dart';

/// Default implementation of [WorkspaceService] upholding Alhambra lifecycle,
/// four-eyes review governance, version lineage, and publication gates.
final class DefaultWorkspaceService implements WorkspaceService {
  final WorkspaceRepository _repository;
  final WorkspaceLifecycle _lifecycle;
  final List<PublishGate> _publishGates;
  final WorkspaceId Function()? _idGenerator;

  DefaultWorkspaceService({
    required WorkspaceRepository repository,
    WorkspaceLifecycle lifecycle = const WorkspaceLifecycle(),
    List<PublishGate> publishGates = const [],
    WorkspaceId Function()? idGenerator,
  })  : _repository = repository,
        _lifecycle = lifecycle,
        _publishGates = publishGates,
        _idGenerator = idGenerator;

  WorkspaceId _nextId() {
    if (_idGenerator != null) return _idGenerator!();
    return WorkspaceId('ws-${DateTime.now().microsecondsSinceEpoch}');
  }

  @override
  Future<Workspace> create({
    required OrganizationId organizationId,
    required UserId ownerId,
    required String name,
    Map<String, Object?> metadata = const {},
  }) async {
    final now = DateTime.now();
    final workspace = Workspace(
      id: _nextId(),
      organizationId: organizationId,
      name: name,
      ownerId: ownerId,
      status: WorkspaceStatus.draft,
      version: WorkspaceVersion(
        number: 1,
        createdAt: now,
        actorId: ownerId,
        description: 'Workspace created',
      ),
      members: [
        WorkspaceMember(userId: ownerId, role: WorkspaceRole.owner),
      ],
      metadata: Map.unmodifiable(metadata),
    );

    await _repository.save(workspace);
    return workspace;
  }

  @override
  Future<Workspace> get(WorkspaceId id) async {
    final ws = await _repository.find(id);
    if (ws == null) {
      throw StateError('Workspace not found: $id');
    }
    return ws;
  }

  @override
  Future<Workspace> updateMetadata({
    required WorkspaceId workspaceId,
    required UserId actorId,
    required Map<String, Object?> metadata,
  }) async {
    final current = await get(workspaceId);
    if (current.status != WorkspaceStatus.draft) {
      throw StateError(
        'Workspace can only be modified in draft status (current: ${current.status})',
      );
    }

    final newVersion = current.version.next(
      actorId: actorId,
      description: 'Metadata updated',
    );

    final updated = current.copyWith(
      version: newVersion,
      metadata: Map.unmodifiable({...current.metadata, ...metadata}),
    );

    await _repository.save(updated);
    return updated;
  }

  @override
  Future<Workspace> submitForReview({
    required WorkspaceId workspaceId,
    required UserId actorId,
  }) async {
    final current = await get(workspaceId);
    _lifecycle.requireTransition(current.status, WorkspaceStatus.review);

    final updated = current.copyWith(
      status: WorkspaceStatus.review,
      version: current.version.next(
        actorId: actorId,
        description: 'Submitted for review',
      ),
    );

    await _repository.save(updated);
    return updated;
  }

  @override
  Future<Workspace> approve({
    required WorkspaceId workspaceId,
    required UserId reviewerId,
  }) async {
    final current = await get(workspaceId);

    // Enforce Four-Eyes Rule: Owner cannot approve their own workspace
    if (current.ownerId == reviewerId) {
      throw const WorkspaceApprovalException(
        'The workspace owner cannot approve their own workspace.',
      );
    }

    _lifecycle.requireTransition(current.status, WorkspaceStatus.approved);

    final updated = current.copyWith(
      status: WorkspaceStatus.approved,
      version: current.version.next(
        actorId: reviewerId,
        description: 'Approved by $reviewerId',
      ),
    );

    await _repository.save(updated);
    return updated;
  }

  @override
  Future<Workspace> reject({
    required WorkspaceId workspaceId,
    required UserId reviewerId,
    required String reason,
  }) async {
    final current = await get(workspaceId);
    _lifecycle.requireTransition(current.status, WorkspaceStatus.draft);

    final updated = current.copyWith(
      status: WorkspaceStatus.draft,
      version: current.version.next(
        actorId: reviewerId,
        description: 'Rejected by $reviewerId: $reason',
      ),
    );

    await _repository.save(updated);
    return updated;
  }

  @override
  Future<Workspace> publish({
    required WorkspaceId workspaceId,
    required UserId actorId,
  }) async {
    final current = await get(workspaceId);
    _lifecycle.requireTransition(current.status, WorkspaceStatus.published);

    // Evaluate all registered publish gates
    final allBlockers = <String>[];
    for (final gate in _publishGates) {
      final blockers = await gate.blockers(current);
      allBlockers.addAll(blockers);
    }

    if (allBlockers.isNotEmpty) {
      throw WorkspacePublicationBlockedException(allBlockers);
    }

    final updated = current.copyWith(
      status: WorkspaceStatus.published,
      version: current.version.next(
        actorId: actorId,
        description: 'Published',
      ),
    );

    await _repository.save(updated);
    return updated;
  }

  @override
  Future<Workspace> supersede({
    required WorkspaceId workspaceId,
    required UserId actorId,
  }) async {
    final current = await get(workspaceId);
    _lifecycle.requireTransition(current.status, WorkspaceStatus.superseded);

    final updated = current.copyWith(
      status: WorkspaceStatus.superseded,
      version: current.version.next(
        actorId: actorId,
        description: 'Superseded',
      ),
    );

    await _repository.save(updated);
    return updated;
  }

  @override
  Future<Workspace> archive({
    required WorkspaceId workspaceId,
    required UserId actorId,
  }) async {
    final current = await get(workspaceId);
    _lifecycle.requireTransition(current.status, WorkspaceStatus.archived);

    final updated = current.copyWith(
      status: WorkspaceStatus.archived,
      version: current.version.next(
        actorId: actorId,
        description: 'Archived',
      ),
    );

    await _repository.save(updated);
    return updated;
  }

  @override
  Future<Workspace> deriveDraft({
    required WorkspaceId sourceWorkspaceId,
    required UserId actorId,
    required String name,
  }) async {
    final source = await get(sourceWorkspaceId);
    final now = DateTime.now();

    final derived = Workspace(
      id: _nextId(),
      organizationId: source.organizationId,
      name: name,
      ownerId: actorId,
      status: WorkspaceStatus.draft,
      version: WorkspaceVersion(
        number: 1,
        createdAt: now,
        actorId: actorId,
        description:
            'Derived from ${source.id.value} (v${source.version.number})',
      ),
      members: [
        WorkspaceMember(userId: actorId, role: WorkspaceRole.owner),
      ],
      metadata: Map.unmodifiable({
        ...source.metadata,
        'derivedFrom': {
          'workspaceId': source.id.value,
          'version': source.version.number,
        },
      }),
    );

    await _repository.save(derived);
    return derived;
  }
}
