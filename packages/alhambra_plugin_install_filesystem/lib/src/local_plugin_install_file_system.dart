import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'package:path/path.dart' as p;

/// Local-disk implementation of the fenced transactional installation
/// filesystem contract.
///
/// The root must be on one local filesystem: staging and destination promotion
/// use Directory.rename. Per-operation lock directories serialize processes.
/// A lock that remains after a crash is intentionally not auto-stolen; the host
/// must reconcile ownership before removing it.
final class LocalPluginInstallFileSystem
    implements FencedPluginInstallFileSystem {
  static const _stateDirectoryName = '.alhambra-install-state';
  static const _ownerFileName = '.alhambra-install-owner.json';

  final String rootPath;
  final Duration lockWait;
  late final String _stateRoot;
  late final String _stagingRoot;
  late final String _pluginRoot;
  late final String _lockRoot;
  late final String _operationRoot;

  LocalPluginInstallFileSystem({
    required Directory rootDirectory,
    this.lockWait = const Duration(seconds: 2),
  }) : rootPath = p.normalize(rootDirectory.absolute.path) {
    if (lockWait <= Duration.zero) {
      throw ArgumentError.value(lockWait, 'lockWait', 'Must be positive.');
    }
    _stateRoot = p.join(rootPath, _stateDirectoryName);
    _stagingRoot = p.join(_stateRoot, 'staging');
    _pluginRoot = p.join(rootPath, 'plugins');
    _lockRoot = p.join(_stateRoot, 'locks');
    _operationRoot = p.join(_stateRoot, 'operations');
  }

  Future<void> initialize() async {
    await Directory(rootPath).create(recursive: true);
    await _assertNoSymlink(rootPath);
    for (final path in [_stateRoot, _stagingRoot, _pluginRoot, _lockRoot, _operationRoot]) {
      await Directory(path).create(recursive: true);
      await _assertNoSymlink(path);
    }
  }

  String _key(String operationId) {
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(operationId, 'operationId', 'Must not be empty.');
    }
    return base64Url.encode(utf8.encode(operationId)).replaceAll('=', '');
  }

  String _statePath(String operationId) =>
      p.join(_operationRoot, '${_key(operationId)}.json');

  String _stagingPath(String operationId) =>
      p.join(_stagingRoot, _key(operationId));

  String _lockPath(String operationId) =>
      p.join(_lockRoot, _key(operationId));

  Future<void> _assertNoSymlink(String path) async {
    final normalized = p.normalize(path);
    if (!p.isWithin(rootPath, normalized) && normalized != rootPath) {
      throw FileSystemException('Path escaped installation root.', path);
    }
    var cursor = rootPath;
    final relative = p.relative(normalized, from: rootPath);
    for (final segment in (relative == '.' ? <String>[] : p.split(relative))) {
      cursor = p.join(cursor, segment);
      final type = await FileSystemEntity.type(cursor, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw FileSystemException('Symbolic links are not permitted.', cursor);
      }
    }
  }

  Future<T> _withLock<T>(String operationId, Future<T> Function() action) async {
    await initialize();
    final lock = Directory(_lockPath(operationId));
    try {
      await lock.create();
    } on FileSystemException {
      throw StateError('Installation operation is locked; inspect the owner and reconcile before retrying.');
    }
    try {
      return await action();
    } finally {
      // A crash leaves the lock behind. Only the process that created this
      // lock reaches this finally block and removes it.
      if (await lock.exists()) await lock.delete();
    }
  }

  Future<Map<String, Object?>> _readState(String operationId) async {
    final file = File(_statePath(operationId));
    if (!await file.exists()) {
      return <String, Object?>{
        'operationId': operationId,
        'fencingToken': 0,
      };
    }
    await _assertNoSymlink(file.path);
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> || decoded['operationId'] != operationId) {
      throw StateError('Installation operation metadata is corrupt or mismatched.');
    }
    return Map<String, Object?>.from(decoded);
  }

  Future<void> _writeState(Map<String, Object?> state) async {
    final operationId = state['operationId']! as String;
    final target = File(_statePath(operationId));
    final temporary = File('${target.path}.tmp');
    await _assertNoSymlink(target.parent.path);
    if (await temporary.exists()) await temporary.delete();
    await temporary.writeAsString(jsonEncode(state), flush: true);
    await temporary.rename(target.path);
  }

  Future<void> _requireFence(String operationId, int token) async {
    if (token < 1) throw StateError('A positive fencing token is required.');
    final state = await _readState(operationId);
    if (state['fencingToken'] != token) {
      throw StateError('Filesystem mutation rejected: stale or unregistered fencing token.');
    }
  }

  @override
  Future<bool> advanceFence({
    required String operationId,
    required int fencingToken,
  }) =>
      _withLock(operationId, () async {
        if (fencingToken < 1) throw ArgumentError.value(fencingToken, 'fencingToken');
        final state = await _readState(operationId);
        final current = state['fencingToken']! as int;
        if (fencingToken < current) return false;
        if (fencingToken == current) return true;
        state['fencingToken'] = fencingToken;
        state['updatedAt'] = DateTime.now().toUtc().toIso8601String();
        await _writeState(state);
        return true;
      });

  @override
  Future<PluginInstallStaging> createStaging({
    required String operationId,
    required String pluginId,
    required String version,
    int fencingToken = 0,
  }) =>
      _withLock(operationId, () async {
        if (fencingToken > 0) await _requireFence(operationId, fencingToken);
        _validateSegment(pluginId, 'pluginId');
        _validateSegment(version, 'version');
        final path = _stagingPath(operationId);
        await _assertNoSymlink(path);
        if (await Directory(path).exists()) {
          throw StateError('Staging already exists for this operation.');
        }
        await Directory(path).create();
        final state = await _readState(operationId);
        state.addAll({
          'pluginId': pluginId,
          'version': version,
          'stagingPath': path,
          'destinationPath': p.join(_pluginRoot, pluginId, version),
          'phase': 'staging',
        });
        await _writeState(state);
        return PluginInstallStaging(
          operationId: operationId,
          pluginId: pluginId,
          opaqueHandle: _key(operationId),
          fencingToken: fencingToken,
        );
      });

  String _resolveStaging(PluginInstallStaging staging) {
    if (staging.opaqueHandle != _key(staging.operationId)) {
      throw StateError('Staging handle does not belong to this operation.');
    }
    return _stagingPath(staging.operationId);
  }

  String _safeRelative(String raw) {
    if (raw.isEmpty || raw.contains('\\') || raw.contains('\u0000') ||
        p.isAbsolute(raw) || RegExp(r'^[a-zA-Z]:').hasMatch(raw)) {
      throw ArgumentError.value(raw, 'relativePath', 'Unsafe relative path.');
    }
    final normalized = p.normalize(raw);
    if (normalized == '.' || normalized == '..' ||
        normalized.startsWith('..${p.separator}') ||
        p.split(normalized).any((part) => part == '..' || part == '.' || part.isEmpty)) {
      throw ArgumentError.value(raw, 'relativePath', 'Path traversal is not permitted.');
    }
    if (p.split(normalized).any((part) => part == _ownerFileName)) {
      throw ArgumentError.value(raw, 'relativePath', 'Path uses reserved installation metadata name.');
    }
    return normalized;
  }

  @override
  Future<void> createDirectory(PluginInstallStaging staging, String relativePath) =>
      _withLock(staging.operationId, () async {
        await _requireFence(staging.operationId, staging.fencingToken);
        final relative = _safeRelative(relativePath);
        final root = _resolveStaging(staging);
        final target = p.join(root, relative);
        await _assertNoSymlink(target);
        await Directory(target).create(recursive: true);
      });

  @override
  Future<void> writeFile({
    required PluginInstallStaging staging,
    required String relativePath,
    required Stream<List<int>> bytes,
    required int maxBytes,
  }) =>
      _withLock(staging.operationId, () async {
        await _requireFence(staging.operationId, staging.fencingToken);
        if (maxBytes < 1) throw ArgumentError.value(maxBytes, 'maxBytes');
        final relative = _safeRelative(relativePath);
        final root = _resolveStaging(staging);
        final target = p.join(root, relative);
        await _assertNoSymlink(target);
        await Directory(p.dirname(target)).create(recursive: true);
        await _assertNoSymlink(target);
        final file = File(target);
        if (await file.exists()) throw StateError('Refusing to overwrite an existing staged file.');
        final handle = await file.open(mode: FileMode.writeOnly);
        var total = 0;
        try {
          await for (final chunk in bytes) {
            total += chunk.length;
            if (total > maxBytes) throw StateError('Staged file exceeded configured size limit.');
            await handle.writeFrom(chunk);
          }
          await handle.flush();
        } catch (_) {
          await handle.close();
          if (await file.exists()) await file.delete();
          rethrow;
        }
        await handle.close();
      });

  @override
  Future<String> destinationPathFor({
    required String pluginId,
    required String version,
  }) async {
    _validateSegment(pluginId, 'pluginId');
    _validateSegment(version, 'version');
    await initialize();
    return p.join(_pluginRoot, pluginId, version);
  }

  static void _validateSegment(String value, String name) {
    if (value.trim().isEmpty || value == '.' || value == '..' ||
        value.contains('/') || value.contains('\\') || value.contains('\u0000')) {
      throw ArgumentError.value(value, name, 'Must be one safe path segment.');
    }
  }

  Future<void> _writeOwnerMarker(String destination, PluginInstallStaging staging) async {
    final marker = File(p.join(destination, _ownerFileName));
    await marker.writeAsString(jsonEncode({
      'operationId': staging.operationId,
      'fencingToken': staging.fencingToken,
      'pluginId': staging.pluginId,
    }), flush: true);
  }

  Future<bool> _hasOwnerMarker(String destination, String operationId, int token) async {
    final marker = File(p.join(destination, _ownerFileName));
    if (!await marker.exists()) return false;
    try {
      final data = jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
      return data['operationId'] == operationId && data['fencingToken'] == token;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> promote(PluginInstallStaging staging, {required String destinationPath}) =>
      _withLock(staging.operationId, () async {
        await _requireFence(staging.operationId, staging.fencingToken);
        final expected = await destinationPathFor(
          pluginId: staging.pluginId,
          version: (await _readState(staging.operationId))['version']! as String,
        );
        if (p.normalize(destinationPath) != p.normalize(expected)) {
          throw StateError('Destination path does not match the operation-owned destination.');
        }
        final source = _resolveStaging(staging);
        await _assertNoSymlink(source);
        await _assertNoSymlink(p.dirname(expected));
        await Directory(p.dirname(expected)).create(recursive: true);
        if (await Directory(expected).exists() || await File(expected).exists()) {
          throw StateError('Refusing to overwrite an existing plugin destination.');
        }
        await _writeOwnerMarker(source, staging);
        await Directory(source).rename(expected);
        final state = await _readState(staging.operationId);
        state['phase'] = 'promoted';
        state['destinationPath'] = expected;
        await _writeState(state);
      });

  @override
  Future<void> rollbackPromotion(PluginInstallStaging staging, {required String promotedPath}) =>
      _withLock(staging.operationId, () async {
        await _requireFence(staging.operationId, staging.fencingToken);
        final state = await _readState(staging.operationId);
        final expected = state['destinationPath'] as String?;
        if (expected == null || p.normalize(promotedPath) != p.normalize(expected)) {
          throw StateError('Rollback path does not match operation metadata.');
        }
        if (!await Directory(expected).exists()) return;
        if (!await _hasOwnerMarker(expected, staging.operationId, staging.fencingToken)) {
          throw StateError('Cannot roll back a destination without matching ownership evidence.');
        }
        await Directory(expected).delete(recursive: true);
        state['phase'] = 'rolledBack';
        await _writeState(state);
      });

  @override
  Future<void> finalizePromotion(PluginInstallStaging staging, {required String promotedPath}) =>
      _withLock(staging.operationId, () async {
        await _requireFence(staging.operationId, staging.fencingToken);
        final state = await _readState(staging.operationId);
        final expected = state['destinationPath'] as String?;
        if (expected == null || p.normalize(promotedPath) != p.normalize(expected) ||
            !await Directory(expected).exists() ||
            !await _hasOwnerMarker(expected, staging.operationId, staging.fencingToken)) {
          throw StateError('Cannot finalize a destination not owned by this operation.');
        }
        final marker = File(p.join(expected, _ownerFileName));
        await marker.delete();
        state['phase'] = 'finalized';
        state['finalizedAt'] = DateTime.now().toUtc().toIso8601String();
        await _writeState(state);
      });

  @override
  Future<void> discardStaging(PluginInstallStaging staging) =>
      _withLock(staging.operationId, () async {
        await _requireFence(staging.operationId, staging.fencingToken);
        final path = _resolveStaging(staging);
        if (await Directory(path).exists()) {
          await _assertNoSymlink(path);
          await Directory(path).delete(recursive: true);
        }
        final state = await _readState(staging.operationId);
        state['phase'] = 'discarded';
        await _writeState(state);
      });

  @override
  Future<PluginInstallRecoverySnapshot> inspectOperation({
    required String operationId,
    required String pluginId,
    required String? stagingHandle,
    required String? destinationPath,
  }) async {
    await initialize();
    final state = await _readState(operationId);
    final stagingPath = _stagingPath(operationId);
    final stageExists = await Directory(stagingPath).exists();
    final destination = destinationPath ?? state['destinationPath'] as String?;
    var destinationExists = false;
    var owned = false;
    if (destination != null) {
      final expected = state['destinationPath'] as String?;
      if (expected == null || p.normalize(destination) != p.normalize(expected)) {
        return const PluginInstallRecoverySnapshot(
          stagingExists: false,
          destinationExists: false,
          destinationOwnedByOperation: false,
          rollbackAvailable: false,
        );
      }
      destinationExists = await Directory(destination).exists();
      owned = destinationExists && await _hasOwnerMarker(
        destination,
        operationId,
        state['fencingToken']! as int,
      );
    }
    final token = state['fencingToken']! as int;
    final rollback = destinationExists && owned &&
        (state['phase'] == 'promoted' || state['phase'] == 'promoting');
    return PluginInstallRecoverySnapshot(
      stagingExists: stageExists,
      destinationExists: destinationExists,
      destinationOwnedByOperation: owned,
      rollbackAvailable: rollback,
    );
  }
}
