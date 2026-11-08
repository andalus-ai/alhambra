import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';

export 'package:sembast/sembast.dart' show Database;

/// Opens a sembast [Database] backed by an on-disk file at [path].
///
/// Uses the default [databaseFactoryIo] which is suitable for production use
/// on any Dart VM target (desktop, server, mobile via path_provider).
Future<Database> openSembastDatabase(String path) =>
    databaseFactoryIo.openDatabase(path);

/// Opens an in-memory sembast [Database] — useful for unit tests.
///
/// Passing a unique [name] per test group ensures clean isolation.
Future<Database> openSembastMemoryDatabase({String name = 'test.db'}) =>
    databaseFactoryMemory.openDatabase(name);
