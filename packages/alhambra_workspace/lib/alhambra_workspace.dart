/// Alhambra Workspace — generic workspace model, lifecycle state machine,
/// immutable versioning, review & four-eyes approval, publication gates, and repository.
///
/// Decoupled from application-specific knowledge, models, and execution bindings.
library alhambra_workspace;

// Model
export 'src/model/workspace_id.dart';
export 'src/model/workspace.dart';
export 'src/model/workspace_member.dart';
export 'src/model/workspace_version.dart';

// Lifecycle
export 'src/lifecycle/workspace_status.dart';
export 'src/lifecycle/workspace_transition.dart';
export 'src/lifecycle/workspace_lifecycle.dart';

// Review
export 'src/review/review_decision.dart';
export 'src/review/review.dart';
export 'src/review/workspace_approval_exception.dart';

// Publication
export 'src/publication/publish_gate.dart';
export 'src/publication/publication_blocked.dart';

// Repository
export 'src/repository/workspace_repository.dart';
export 'src/repository/in_memory_workspace_repository.dart';

// Service
export 'src/service/workspace_service.dart';
export 'src/service/default_workspace_service.dart';
