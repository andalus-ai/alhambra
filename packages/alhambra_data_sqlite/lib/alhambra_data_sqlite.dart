/// alhambra_data_sqlite
///
/// SQLite (`sqlite3`) implementation of alhambra_data storage contracts.
/// Pure Dart — no Flutter, no code generation.
///
/// Provides:
/// - [Sqlite3Database] — implements [Database] and [DatabaseTransaction]
/// - [Sqlite3OfflineQueue] — implements [OfflineQueue]
/// - [Sqlite3LocalStore] — implements [LocalStore]
/// - [Sqlite3LocalRecordStore] — mirrors [InMemoryLocalRecordStore] API
///
/// Bootstrap example:
/// ```dart
/// final db = Sqlite3Database('alhambra.db');
/// await db.open();
///
/// final queue = Sqlite3OfflineQueue(db);
/// await queue.init();
///
/// final store = Sqlite3LocalStore(db);
/// await store.init();
///
/// final records = Sqlite3LocalRecordStore(db);
/// await records.init();
///
/// registry.register<Database>(db);
/// registry.register<OfflineQueue>(queue);
/// registry.register<LocalStore>(store);
/// ```
library alhambra_data_sqlite;

export 'src/sqlite3_database.dart';
export 'src/sqlite3_local_record_store.dart';
export 'src/sqlite3_local_store.dart';
export 'src/sqlite3_offline_queue.dart';
