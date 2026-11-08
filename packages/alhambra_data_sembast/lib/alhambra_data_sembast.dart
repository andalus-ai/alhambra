/// Alhambra Data — Sembast (pure-Dart) implementation of storage contracts.
///
/// Provides persistent implementations of [KeyValueStore], [LocalStore],
/// [OfflineQueue], and a [SembastLocalRecordStore], all backed by the sembast
/// embedded document database.
///
/// Typical usage:
/// ```dart
/// import 'package:alhambra_data_sembast/alhambra_data_sembast.dart';
///
/// final db = await openSembastDatabase('/path/to/app.db');
/// final kv = SembastKeyValueStore(db);
/// await kv.write('token', 'abc123');
/// ```
library alhambra_data_sembast;

export 'src/sembast_database_factory.dart';
export 'src/sembast_key_value_store.dart';
export 'src/sembast_local_store.dart';
export 'src/sembast_local_record_store.dart';
export 'src/sembast_offline_queue.dart';
