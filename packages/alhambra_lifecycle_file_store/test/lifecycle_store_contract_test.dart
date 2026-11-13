import 'dart:io';

import 'package:alhambra_lifecycle_file_store/alhambra_lifecycle_file_store.dart';
import 'package:alhambra_lifecycle_store_test/alhambra_lifecycle_store_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('alhambra-jsonl-contract-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  defineCompositionLifecycleEventStoreContractTests(
    name: 'JSONL',
    createStore: () async => JsonlCompositionLifecycleEventStore(
      file: File('${directory.path}/events.jsonl'),
    ),
    disposeStore: (_) async {},
  );
}
