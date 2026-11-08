/// Alhambra Services — generic platform service layer.
///
/// Cross-cutting capabilities consumed by all domain modules:
/// context, events, notifications, search, audit, settings, feature flags,
/// background jobs, service registry, and observability (logging, tracing, metrics, health).
///
/// Pure Dart. No Flutter. No domain-specific types.
library alhambra_services;

// Context
export 'src/context/request_context.dart';

// Events
export 'src/events/event_bus.dart';
export 'src/events/event_envelope.dart';

// Notifications
export 'src/notifications/notification.dart';
export 'src/notifications/notification_service.dart';

// Search
export 'src/search/search_service.dart';

// Audit
export 'src/audit/audit_service.dart';

// Settings
export 'src/settings/settings_service.dart';

// Feature Flags
export 'src/feature_flags/feature_flag_service.dart';

// Observability
export 'src/observability/logger.dart';
export 'src/observability/tracer.dart';
export 'src/observability/metrics.dart';
export 'src/observability/health.dart';

// Background Jobs
export 'src/jobs/job.dart';
export 'src/jobs/job_service.dart';
export 'src/jobs/job_status.dart';

// Service Registry
export 'src/registry/service_descriptor.dart';
export 'src/registry/service_registry.dart';
