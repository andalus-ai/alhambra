import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

class _Package implements PluginPackageArchive {
  final List<PluginArchiveEntry> entries;
  final List<int> payload;
  final String id;

  _Package({
    this.entries = const [
      PluginArchiveEntry(
        path: 'lib/main.dart',
        kind: PluginArchiveEntryKind.file,
        declaredSizeBytes: 3,
      ),
    ],
    this.payload = const [1, 2, 3],
    this.id = 'org.example.editor',
  });

  @override
  PluginPackageManifest get manifest => PluginPackageManifest(
        id: PluginId(id),
        name: 'Example Editor',
        version: const SemanticVersion(1, 0, 0),
        hostApi: HostApiConstraint(min: const SemanticVersion(1, 0, 0)),
      );

  @override
  PluginPackageMetadata get metadata => PluginPackageMetadata(
        packageId: id,
        version: const SemanticVersion(1, 0, 0),
        contentHash: 'sha256:0000000000000000000000000000000000000000000000000000000000000000',
        formatVersion: 1,
      );

  @override
  PluginPublisher? get publisher => null;

  @override
  PluginPackageSignature? get signature => null;

  @override
  Stream<List<int>> readPayload(String path) async* {
    yield payload;
  }

  @override
  Stream<PluginArchiveEntry> listEntries() async* {
    for (final entry in entries) {
      yield entry;
    }
  }
}

class _Verifier implements PluginPackageVerifier {
  final bool valid;
  const _Verifier({this.valid = true});

  @override
  Future<PackageVerificationResult> verify(PluginPackage package) async =>
      valid
          ? const PackageVerified(PluginTrustLevel.unsigned)
          : const PackageVerificationFailed([
              VerificationIssue(code: 'BAD_PACKAGE', message: 'invalid'),
            ]);
}

class _Preflight implements PluginInstallPreflight {
  final bool fail;
  const _Preflight({this.fail = false});

  @override
  Future<void> validate(PluginPackage package) async {
    if (fail) throw StateError('preflight rejected');
  }
}

class _FileSystem implements PluginInstallFileSystem {
  final List<String> calls = [];
  final List<String> files = [];
  bool failPromote = false;

  @override
  Future<PluginInstallStaging> createStaging({
    required String operationId,
    required String pluginId,
    required String version,
  }) async {
    calls.add('createStaging');
    return PluginInstallStaging(
      operationId: operationId,
      pluginId: pluginId,
      opaqueHandle: 'stage-$operationId',
    );
  }

  @override
  Future<void> createDirectory(
    PluginInstallStaging staging,
    String relativePath,
  ) async {
    calls.add('directory:$relativePath');
  }

  @override
  Future<void> writeFile({
    required PluginInstallStaging staging,
    required String relativePath,
    required Stream<List<int>> bytes,
    required int maxBytes,
  }) async {
    calls.add('write:$relativePath');
    var count = 0;
    await for (final chunk in bytes) {
      count += chunk.length;
    }
    files.add('$relativePath:$count');
  }

  @override
  Future<String> destinationPathFor({
    required String pluginId,
    required String version,
  }) async => '/plugins/$pluginId';

  @override
  Future<void> promote(
    PluginInstallStaging staging, {
    required String destinationPath,
  }) async {
    calls.add('promote');
    if (failPromote) throw StateError('promotion failed');
  }

  @override
  Future<void> rollbackPromotion(
    PluginInstallStaging staging, {
    required String promotedPath,
  }) async {
    calls.add('rollbackPromotion');
  }

  @override
  Future<void> finalizePromotion(
    PluginInstallStaging staging, {
    required String promotedPath,
  }) async {
    calls.add('finalizePromotion');
  }

  @override
  Future<void> discardStaging(PluginInstallStaging staging) async {
    calls.add('discardStaging');
  }
}

class _Journal implements PluginInstallJournal {
  final List<PluginInstallJournalEntry> entries = [];

  @override
  Future<void> write(PluginInstallJournalEntry entry) async {
    entries.add(entry);
  }

  @override
  Future<List<PluginInstallJournalEntry>> unresolved() async =>
      entries.where((entry) =>
          entry.status != PluginInstallJournalStatus.committed &&
          entry.status != PluginInstallJournalStatus.rolledBack &&
          entry.status != PluginInstallJournalStatus.failed).toList();
}

class _FailingStore implements TransactionalInstalledPluginStore {
  @override
  Future<List<InstalledPluginRecord>> all() async => const [];

  @override
  Future<InstalledPluginRecord?> find(String pluginId) async => null;

  @override
  Future<void> remove(String pluginId) async {}

  @override
  Future<void> save(InstalledPluginRecord plugin) async {
    throw StateError('metadata store unavailable');
  }

  @override
  Future<bool> createIfAbsent(InstalledPluginRecord plugin) async {
    throw StateError('metadata store unavailable');
  }

  @override
  Future<bool> removeIfMatches(InstalledPluginRecord plugin) async => false;
}

TransactionalPluginInstaller _installer({
  _FileSystem? fileSystem,
  TransactionalInstalledPluginStore? store,
  _Journal? journal,
  PluginInstallPreflight? preflight,
  PluginInstallLimits limits = const PluginInstallLimits(),
}) {
  return TransactionalPluginInstaller(
    verifier: const _Verifier(),
    preflight: preflight ?? const _Preflight(),
    fileSystem: fileSystem ?? _FileSystem(),
    installedStore: store ?? InMemoryInstalledPluginStore(),
    journal: journal ?? _Journal(),
    limits: limits,
    operationIdFactory: () => 'op-1',
    clock: () => DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('TransactionalPluginInstaller', () {
    test('verifies, extracts, promotes and records before returning installed', () async {
      final fs = _FileSystem();
      final journal = _Journal();
      final store = InMemoryInstalledPluginStore();
      final result = await _installer(
        fileSystem: fs,
        journal: journal,
        store: store,
      ).install(_Package());

      expect(result, isA<PluginInstalled>());
      expect(result.installPath, '/plugins/org.example.editor');
      expect(fs.files, ['lib/main.dart:3']);
      expect(fs.calls, containsAllInOrder([
        'createStaging',
        'write:lib/main.dart',
        'promote',
        'finalizePromotion',
      ]));
      expect(await store.find('org.example.editor'), isNotNull);
      expect(journal.entries.last.status, PluginInstallJournalStatus.committed);
    });


    test('create-only store contract prevents concurrent installer overwrite', () async {
      final store = InMemoryInstalledPluginStore();
      final firstFs = _FileSystem();
      final secondFs = _FileSystem();
      final first = _installer(fileSystem: firstFs, store: store);
      final second = _installer(fileSystem: secondFs, store: store);

      final outcomes = await Future.wait([
        first.install(_Package()).then((_) => true, onError: (_) => false),
        second.install(_Package()).then((_) => true, onError: (_) => false),
      ]);

      expect(outcomes.where((success) => success).length, 1);
      expect(await store.all(), hasLength(1));
      expect(
        [firstFs, secondFs].where((fs) => fs.calls.contains('rollbackPromotion')).length,
        1,
      );
    });

    test('rejects path traversal before promotion and discards staging', () async {
      final fs = _FileSystem();
      final store = InMemoryInstalledPluginStore();
      await expectLater(
        _installer(fileSystem: fs, store: store).install(_Package(
          entries: const [
            PluginArchiveEntry(
              path: '../outside.dart',
              kind: PluginArchiveEntryKind.file,
            ),
          ],
        )),
        throwsA(isA<PluginInstallException>()),
      );
      expect(fs.calls, contains('discardStaging'));
      expect(fs.calls, isNot(contains('promote')));
      expect(await store.find('org.example.editor'), isNull);
    });

    test('rejects symbolic links and special archive entries', () async {
      final fs = _FileSystem();
      await expectLater(
        _installer(fileSystem: fs).install(_Package(
          entries: const [
            PluginArchiveEntry(
              path: 'lib/link.dart',
              kind: PluginArchiveEntryKind.symbolicLink,
            ),
          ],
        )),
        throwsA(isA<PluginInstallException>()),
      );
      expect(fs.calls, contains('discardStaging'));
      expect(fs.calls, isNot(contains('promote')));
    });

    test('enforces actual extracted byte limits even without declared sizes', () async {
      final fs = _FileSystem();
      await expectLater(
        _installer(
          fileSystem: fs,
          limits: const PluginInstallLimits(
            maxEntries: 10,
            maxEntryBytes: 2,
            maxTotalBytes: 10,
          ),
        ).install(_Package(
          entries: const [
            PluginArchiveEntry(
              path: 'payload.bin',
              kind: PluginArchiveEntryKind.file,
            ),
          ],
        )),
        throwsA(isA<PluginInstallException>()),
      );
      expect(fs.calls, isNot(contains('promote')));
    });

    test('runs preflight before creating staging', () async {
      final fs = _FileSystem();
      await expectLater(
        _installer(
          fileSystem: fs,
          preflight: const _Preflight(fail: true),
        ).install(_Package()),
        throwsA(isA<PluginInstallException>()),
      );
      expect(fs.calls, isEmpty);
    });


    test('rolls back even when promotion throws after its intent is journaled', () async {
      final fs = _FileSystem()..failPromote = true;
      final journal = _Journal();
      await expectLater(
        _installer(fileSystem: fs, journal: journal).install(_Package()),
        throwsA(isA<PluginInstallException>()),
      );
      expect(journal.entries.any(
        (entry) => entry.status == PluginInstallJournalStatus.promoting,
      ), isTrue);
      expect(fs.calls, contains('rollbackPromotion'));
      expect(journal.entries.last.status, PluginInstallJournalStatus.failed);
    });

    test('rolls back promotion when installed metadata persistence fails', () async {
      final fs = _FileSystem();
      await expectLater(
        _installer(fileSystem: fs, store: _FailingStore()).install(_Package()),
        throwsA(isA<PluginInstallException>()),
      );
      expect(fs.calls, contains('rollbackPromotion'));
      expect(fs.calls, isNot(contains('finalizePromotion')));
    });


    test('rejects case-insensitive duplicate paths for cross-platform safety', () async {
      final fs = _FileSystem();
      await expectLater(
        _installer(fileSystem: fs).install(_Package(
          entries: const [
            PluginArchiveEntry(
              path: 'lib/Main.dart',
              kind: PluginArchiveEntryKind.file,
            ),
            PluginArchiveEntry(
              path: 'lib/main.dart',
              kind: PluginArchiveEntryKind.file,
            ),
          ],
        )),
        throwsA(isA<PluginInstallException>()),
      );
      expect(fs.calls, isNot(contains('promote')));
    });

    test('rejects empty archives', () async {
      final fs = _FileSystem();
      await expectLater(
        _installer(fileSystem: fs).install(_Package(entries: const [])),
        throwsA(isA<PluginInstallException>()),
      );
      expect(fs.calls, isNot(contains('promote')));
    });

    test('rejects packages that do not expose an archive entry stream', () async {
      final plainPackage = _PlainPackage();
      await expectLater(
        _installer().install(plainPackage),
        throwsA(isA<PluginInstallException>()),
      );
    });
  });
}

class _PlainPackage implements PluginPackage {
  @override
  PluginPackageManifest get manifest => const PluginPackageManifest(
        id: PluginId('org.example.plain'),
        name: 'Plain',
        version: SemanticVersion(1, 0, 0),
        hostApi: HostApiConstraint(min: SemanticVersion(1, 0, 0)),
      );

  @override
  PluginPackageMetadata get metadata => const PluginPackageMetadata(
        packageId: 'org.example.plain',
        version: SemanticVersion(1, 0, 0),
        contentHash: 'sha256:0000000000000000000000000000000000000000000000000000000000000000',
        formatVersion: 1,
      );

  @override
  PluginPublisher? get publisher => null;

  @override
  PluginPackageSignature? get signature => null;

  @override
  Stream<List<int>> readPayload(String path) async* {
    yield [1];
  }
}
