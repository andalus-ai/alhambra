import 'dart:io';

import 'package:alhambra_data/alhambra_data.dart';
import 'package:alhambra_data_file_local/alhambra_data_file_local.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmpDir;
  late LocalFileStore store;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('alhambra_file_test_');
    store = LocalFileStore(tmpDir);
  });

  tearDown(() {
    if (tmpDir.existsSync()) {
      tmpDir.deleteSync(recursive: true);
    }
  });

  group('upload', () {
    test('creates file and returns reference with correct metadata', () async {
      final upload = FileUpload(
        name: 'hello.txt',
        contentType: 'text/plain',
        bytes: [72, 101, 108, 108, 111], // "Hello"
      );

      final ref = await store.upload(upload);

      expect(ref.name, equals('hello.txt'));
      expect(ref.contentType, equals('text/plain'));
      expect(ref.size, equals(5));
      expect(ref.id, isNotEmpty);
    });

    test('actually writes the file to disk', () async {
      final bytes = [1, 2, 3, 4, 5];
      final upload = FileUpload(
        name: 'data.bin',
        contentType: 'application/octet-stream',
        bytes: bytes,
      );

      final ref = await store.upload(upload);

      final file = File('${tmpDir.path}/${ref.id}/${ref.name}');
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync().toList(), equals(bytes));
    });
  });

  group('download', () {
    test('returns correct bytes after upload', () async {
      final originalBytes = [10, 20, 30, 40, 50];
      final upload = FileUpload(
        name: 'sample.bin',
        contentType: 'application/octet-stream',
        bytes: originalBytes,
      );

      final ref = await store.upload(upload);
      final download = await store.download(ref);

      expect(download.bytes.toList(), equals(originalBytes));
      expect(download.reference, equals(ref));
    });

    test('throws StateError when file does not exist', () async {
      final ghostRef = FileReference(
        id: 'nonexistent_id',
        name: 'ghost.txt',
        contentType: 'text/plain',
        size: 0,
      );

      await expectLater(
        () => store.download(ghostRef),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('delete', () {
    test('file is no longer downloadable after delete', () async {
      final upload = FileUpload(
        name: 'to_delete.txt',
        contentType: 'text/plain',
        bytes: [65, 66, 67], // "ABC"
      );

      final ref = await store.upload(upload);

      // Verify file exists before delete
      final download = await store.download(ref);
      expect(download.bytes.toList(), equals([65, 66, 67]));

      // Delete and confirm it's gone
      await store.delete(ref);
      await expectLater(
        () => store.download(ref),
        throwsA(isA<StateError>()),
      );
    });

    test('delete of non-existent reference does not throw', () async {
      final ghostRef = FileReference(
        id: 'nonexistent_id',
        name: 'ghost.txt',
        contentType: 'text/plain',
        size: 0,
      );

      // Should complete without throwing
      await expectLater(store.delete(ghostRef), completes);
    });
  });

  group('multiple files', () {
    test('each upload gets a unique id with no collisions', () async {
      const count = 10;
      final refs = <FileReference>[];

      for (var i = 0; i < count; i++) {
        final ref = await store.upload(FileUpload(
          name: 'file_$i.txt',
          contentType: 'text/plain',
          bytes: [i],
        ));
        refs.add(ref);
      }

      final ids = refs.map((r) => r.id).toSet();
      expect(ids.length, equals(count), reason: 'All ids must be unique');
    });

    test('downloading one file does not affect another', () async {
      final refA = await store.upload(FileUpload(
        name: 'a.bin',
        contentType: 'application/octet-stream',
        bytes: [1, 2, 3],
      ));
      final refB = await store.upload(FileUpload(
        name: 'b.bin',
        contentType: 'application/octet-stream',
        bytes: [4, 5, 6],
      ));

      final dlA = await store.download(refA);
      final dlB = await store.download(refB);

      expect(dlA.bytes.toList(), equals([1, 2, 3]));
      expect(dlB.bytes.toList(), equals([4, 5, 6]));
    });
  });

  group('InMemoryFileStore fallback', () {
    test('upload returns a reference with correct metadata', () async {
      final memStore = InMemoryFileStore();
      final upload = FileUpload(
        name: 'mem.txt',
        contentType: 'text/plain',
        bytes: [77, 69, 77], // "MEM"
      );

      final ref = await memStore.upload(upload);

      expect(ref.name, equals('mem.txt'));
      expect(ref.contentType, equals('text/plain'));
      expect(ref.size, equals(3));
    });

    test('download returns correct bytes after upload', () async {
      final memStore = InMemoryFileStore();
      final bytes = [9, 8, 7, 6];
      final ref = await memStore.upload(FileUpload(
        name: 'data.bin',
        contentType: 'application/octet-stream',
        bytes: bytes,
      ));

      final download = await memStore.download(ref);
      expect(download.bytes.toList(), equals(bytes));
    });

    test('delete removes file from in-memory store', () async {
      final memStore = InMemoryFileStore();
      final ref = await memStore.upload(FileUpload(
        name: 'temp.txt',
        contentType: 'text/plain',
        bytes: [1],
      ));

      await memStore.delete(ref);

      await expectLater(
        () => memStore.download(ref),
        throwsA(isA<StateError>()),
      );
    });

    test('InMemoryFileStore satisfies FileStore contract', () {
      // Static type check: InMemoryFileStore must be assignable to FileStore
      final FileStore fs = InMemoryFileStore();
      expect(fs, isA<FileStore>());
    });

    test('LocalFileStore satisfies FileStore contract', () {
      final FileStore fs = LocalFileStore(tmpDir);
      expect(fs, isA<FileStore>());
    });
  });
}
