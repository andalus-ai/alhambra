/// Alhambra Data — local storage, secure store, database, cache,
/// connectivity monitoring, offline mutation queue, sync engine, and file persistence.
///
/// P12: adds Repository abstraction, hardened SyncOperation, LocalRecord,
/// MutationResult, ConflictInfo, SyncContext, SyncScheduler.
///
/// Pure Dart foundation decoupled from Flutter, UI frameworks, or domain semantics.
library alhambra_data;

// Storage
export 'src/storage/key_value_store.dart';
export 'src/storage/local_store.dart';
export 'src/storage/secure_store.dart';
export 'src/storage/database.dart';

// Cache
export 'src/cache/cache.dart';
export 'src/cache/cache_entry.dart';
export 'src/cache/cache_policy.dart';
export 'src/cache/memory_cache.dart';

// Connectivity
export 'src/connectivity/connectivity_status.dart';
export 'src/connectivity/connectivity.dart';

// Repository abstraction
export 'src/repository/repository.dart';

// Sync
export 'src/sync/sync_operation.dart';
export 'src/sync/sync_status.dart';
export 'src/sync/offline_queue.dart';
export 'src/sync/sync_engine.dart';
export 'src/sync/conflict_resolver.dart';
export 'src/sync/conflict_info.dart';
export 'src/sync/local_record.dart';
export 'src/sync/mutation_result.dart';
export 'src/sync/sync_context.dart';
export 'src/sync/sync_scheduler.dart';

// File
export 'src/file/file_reference.dart';
export 'src/file/file_upload.dart';
export 'src/file/file_download.dart';
export 'src/file/file_store.dart';
