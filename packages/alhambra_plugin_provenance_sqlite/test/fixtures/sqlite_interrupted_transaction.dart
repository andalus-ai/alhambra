import 'dart:async';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sq;

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('Expected database path.');
  }
  final database = sq.sqlite3.open(args.single);
  try {
    database.execute('BEGIN IMMEDIATE');
    database.execute(
      'INSERT INTO alhambra_crash_probe (probe_id) VALUES (?)',
      ['uncommitted-process-write'],
    );
    stdout.writeln('READY');
    await stdout.flush();
    await Completer<void>().future;
  } finally {
    database.dispose();
  }
}
