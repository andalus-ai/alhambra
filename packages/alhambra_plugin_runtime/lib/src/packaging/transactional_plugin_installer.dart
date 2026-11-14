import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

/// Structured failure from a transactional package installation.
final class PluginInstallException implements Exception {
  final String code;
  final String message;
  final bool reconciliationRequired;

  const PluginInstallException(
    this.code,
    this.message, {
    this.reconciliationRequired = false,
  });

  @override
  String toString() => 'PluginInstallException($code): $message';
}

/// Coordinates verification, preflight, isolated extraction, reversible
/// promotion and installed-record persistence.
///
/// This is a saga across host adapters, not a distributed atomic transaction.
/// A durable journal lets the host reconcile interruptions between side effects.
final class TransactionalPluginInstaller {
  final PluginPackageVerifier verifier;
  final PluginInstallPreflight preflight;
  final PluginInstallFileSystem fileSystem;
  final TransactionalInstalledPluginStore installedStore;
  final PluginInstallJournal journal;
  final PluginInstallLimits limits;
  final DateTime Function() clock;
  final String Function()? operationIdFactory;
  int _operationSequence = 0;

  final Map<String, Future<void>> _tails = {};

  TransactionalPluginInstaller({
    required this.verifier,
    required this.preflight,
    required this.fileSystem,
    required this.installedStore,
    required this.journal,
    this.limits = const PluginInstallLimits(),
    DateTime Function()? clock,
    String Function()? operationIdFactory,
  })  : clock = clock ?? DateTime.now,
        operationIdFactory = operationIdFactory;

  /// Installs only archive-capable packages. Compiled plugin activation is a
  /// separate host-controlled operation and is never performed here.
  Future<PluginInstalled> install(PluginPackage package) {
    final pluginId = package.manifest.id.value;
    if (pluginId.trim().isEmpty) {
      return Future<PluginInstalled>.error(
        const PluginInstallException('INVALID_PLUGIN_ID', 'Plugin ID is empty.'),
      );
    }
    return _serialize(pluginId, () => _install(package));
  }

  Future<PluginInstalled> _install(PluginPackage package) async {
    if (package is! PluginPackageArchive) {
      throw const PluginInstallException(
        'ARCHIVE_INTERFACE_REQUIRED',
        'Transactional installation requires a PluginPackageArchive adapter.',
      );
    }

    final pluginId = package.manifest.id.value;
    final version = package.manifest.version.toString();
    final operationId = operationIdFactory?.call() ??
        'plugin-install-${DateTime.now().toUtc().microsecondsSinceEpoch}-${++_operationSequence}';
    if (operationId.trim().isEmpty) {
      throw const PluginInstallException(
        'INVALID_OPERATION_ID',
        'Operation ID factory returned an empty value.',
      );
    }

    PluginInstallStaging? staging;
    String? promotedPath;
    var recordCreateAttempted = false;
    InstalledPluginRecord? candidateRecord;
    var promotionAttempted = false;

    Future<void> record(PluginInstallJournalStatus status, {
      String? failureCode,
    }) => journal.write(PluginInstallJournalEntry(
      operationId: operationId,
      pluginId: pluginId,
      version: version,
      status: status,
      updatedAt: clock().toUtc(),
      stagingHandle: staging?.opaqueHandle,
      promotedPath: promotedPath,
      failureCode: failureCode,
    ));

    try {
      await record(PluginInstallJournalStatus.verificationStarted);
      final verification = await verifier.verify(package);
      if (verification is! PackageVerified) {
        final codes = verification is PackageVerificationFailed
            ? verification.issues.map((issue) => issue.code).join(',')
            : 'UNKNOWN_VERIFICATION_FAILURE';
        throw PluginInstallException(
          'PACKAGE_VERIFICATION_FAILED',
          'Package verification failed: $codes',
        );
      }
      await record(PluginInstallJournalStatus.verified);

      await preflight.validate(package);

      final existing = await installedStore.find(pluginId);
      if (existing != null) {
        throw PluginInstallException(
          'PLUGIN_ALREADY_INSTALLED',
          'Plugin "$pluginId" is already installed; use an explicit upgrade transaction.',
        );
      }

      final stagingHandle = await fileSystem.createStaging(
        operationId: operationId,
        pluginId: pluginId,
        version: version,
      );
      staging = stagingHandle;
      await record(PluginInstallJournalStatus.stagingCreated);

      await record(PluginInstallJournalStatus.extracting);
      var entryCount = 0;
      var totalBytes = 0;
      final seenPaths = <String, PluginArchiveEntryKind>{};

      await for (final entry in package.listEntries()) {
        entryCount++;
        if (entryCount > limits.maxEntries) {
          throw const PluginInstallException(
            'ARCHIVE_ENTRY_LIMIT',
            'Package contains more entries than the configured limit.',
          );
        }

        final relativePath = _validateArchivePath(entry.path);
        final pathKey = relativePath.toLowerCase();
        if (seenPaths.containsKey(pathKey)) {
          throw PluginInstallException(
            'DUPLICATE_ARCHIVE_PATH',
            'Package contains duplicate path "$relativePath".',
          );
        }
        final segments = relativePath.split('/');
        for (var i = 1; i < segments.length; i++) {
          final parent = segments.take(i).join('/').toLowerCase();
          if (seenPaths[parent] == PluginArchiveEntryKind.file) {
            throw PluginInstallException(
              'ARCHIVE_PATH_COLLISION',
              'Archive path "$relativePath" is nested below file "$parent".',
            );
          }
        }
        if (entry.kind == PluginArchiveEntryKind.file &&
            seenPaths.keys.any((path) => path.startsWith('$pathKey/'))) {
          throw PluginInstallException(
            'ARCHIVE_PATH_COLLISION',
            'File "$relativePath" conflicts with an existing child path.',
          );
        }
        seenPaths[pathKey] = entry.kind;

        switch (entry.kind) {
          case PluginArchiveEntryKind.symbolicLink:
          case PluginArchiveEntryKind.other:
            throw PluginInstallException(
              'UNSUPPORTED_ARCHIVE_ENTRY',
              'Links and special files are not permitted: "$relativePath".',
            );
          case PluginArchiveEntryKind.directory:
            if (entry.declaredSizeBytes != null &&
                entry.declaredSizeBytes != 0) {
              throw PluginInstallException(
                'INVALID_DIRECTORY_SIZE',
                'Directory "$relativePath" declares a non-zero size.',
              );
            }
            await fileSystem.createDirectory(stagingHandle, relativePath);
            break;
          case PluginArchiveEntryKind.file:
            final declared = entry.declaredSizeBytes;
            if (declared != null &&
                (declared < 0 || declared > limits.maxEntryBytes)) {
              throw PluginInstallException(
                'ARCHIVE_ENTRY_SIZE_LIMIT',
                'File "$relativePath" exceeds the configured size limit.',
              );
            }
            var actualEntryBytes = 0;
            final bounded = _boundedBytes(
              package.readPayload(entry.path),
              onChunk: (length) {
                actualEntryBytes += length;
                totalBytes += length;
                if (actualEntryBytes > limits.maxEntryBytes) {
                  throw const PluginInstallException(
                    'ARCHIVE_ENTRY_SIZE_LIMIT',
                    'Extracted file exceeds the configured size limit.',
                  );
                }
                if (totalBytes > limits.maxTotalBytes) {
                  throw const PluginInstallException(
                    'ARCHIVE_TOTAL_SIZE_LIMIT',
                    'Extracted package exceeds the configured total size limit.',
                  );
                }
              },
            );
            await fileSystem.writeFile(
              staging: stagingHandle,
              relativePath: relativePath,
              bytes: bounded,
              maxBytes: limits.maxEntryBytes,
            );
            if (declared != null && actualEntryBytes != declared) {
              throw PluginInstallException(
                'ARCHIVE_SIZE_MISMATCH',
                'File "$relativePath" does not match its declared size.',
              );
            }
            break;
        }
      }

      if (entryCount == 0) {
        throw const PluginInstallException(
          'EMPTY_PACKAGE_ARCHIVE',
          'Package archive contains no entries.',
        );
      }

      final destinationPath = await fileSystem.destinationPathFor(
        pluginId: pluginId,
        version: version,
      );
      promotedPath = destinationPath;
      if (destinationPath.trim().isEmpty) {
        throw const PluginInstallException(
          'INVALID_INSTALL_DESTINATION',
          'Filesystem adapter returned an empty install destination.',
        );
      }
      await record(PluginInstallJournalStatus.promoting);
      promotionAttempted = true;
      await fileSystem.promote(stagingHandle, destinationPath: destinationPath);
      await record(PluginInstallJournalStatus.promoted);

      final installRecord = InstalledPluginRecord(
        id: pluginId,
        version: package.manifest.version,
        contentHash: package.metadata.contentHash,
        publisher: package.publisher,
        installedAt: clock().toUtc(),
        installPath: destinationPath,
      );
      candidateRecord = installRecord;
      recordCreateAttempted = true;
      final created = await installedStore.createIfAbsent(installRecord);
      if (!created) {
        recordCreateAttempted = false;
        throw PluginInstallException(
          'PLUGIN_ALREADY_INSTALLED',
          'Plugin "$pluginId" was installed concurrently.',
        );
      }
      await record(PluginInstallJournalStatus.installedRecordSaved);

      await fileSystem.finalizePromotion(stagingHandle, promotedPath: destinationPath);
      await record(PluginInstallJournalStatus.committed);

      return PluginInstalled(
        pluginId: pluginId,
        version: package.manifest.version,
        installPath: destinationPath,
      );
    } catch (error, stackTrace) {
      final failure = error is PluginInstallException
          ? error
          : PluginInstallException(
              'INSTALL_FAILED',
              'Plugin installation failed.',
            );

      try {
        await record(PluginInstallJournalStatus.rollingBack,
            failureCode: failure.code);
        if (promotionAttempted && promotedPath != null && staging != null) {
          await fileSystem.rollbackPromotion(
            staging,
            promotedPath: promotedPath,
          );
        } else if (staging != null) {
          await fileSystem.discardStaging(staging);
        }
        if (recordCreateAttempted && candidateRecord != null) {
          await installedStore.removeIfMatches(candidateRecord);
        }
        await record(PluginInstallJournalStatus.rolledBack,
            failureCode: failure.code);
      } catch (_) {
        try {
          await record(PluginInstallJournalStatus.needsReconciliation,
              failureCode: failure.code);
        } catch (_) {
          // The durable journal itself may be unavailable. Preserve primary failure.
        }
        Error.throwWithStackTrace(
          PluginInstallException(
            failure.code,
            failure.message,
            reconciliationRequired: true,
          ),
          stackTrace,
        );
      }

      try {
        await record(PluginInstallJournalStatus.failed,
            failureCode: failure.code);
      } catch (_) {
        // Preserve the original failure if journaling is unavailable.
      }
      Error.throwWithStackTrace(failure, stackTrace);
    }
  }

  static String _validateArchivePath(String rawPath) {
    if (rawPath.isEmpty ||
        rawPath.contains('\\') ||
        rawPath.contains('\u0000') ||
        rawPath.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(rawPath)) {
      throw PluginInstallException(
        'UNSAFE_ARCHIVE_PATH',
        'Archive path "$rawPath" is absolute or contains forbidden characters.',
      );
    }
    final normalized = rawPath.endsWith('/')
        ? rawPath.substring(0, rawPath.length - 1)
        : rawPath;
    final segments = normalized.split('/');
    if (normalized.isEmpty ||
        segments.any((segment) =>
            segment.isEmpty || segment == '.' || segment == '..')) {
      throw PluginInstallException(
        'UNSAFE_ARCHIVE_PATH',
        'Archive path "$rawPath" contains an invalid path segment.',
      );
    }
    return segments.join('/');
  }

  static Stream<List<int>> _boundedBytes(
    Stream<List<int>> source, {
    required void Function(int length) onChunk,
  }) async* {
    await for (final chunk in source) {
      onChunk(chunk.length);
      yield chunk;
    }
  }

  Future<T> _serialize<T>(
    String pluginId,
    Future<T> Function() operation,
  ) async {
    final previous = _tails[pluginId] ?? Future<void>.value();
    final release = Completer<void>();
    _tails[pluginId] = release.future;
    await previous;
    try {
      return await operation();
    } finally {
      release.complete();
      if (identical(_tails[pluginId], release.future)) {
        _tails.remove(pluginId);
      }
    }
  }
}
