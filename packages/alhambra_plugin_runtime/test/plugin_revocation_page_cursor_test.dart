import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final secret = List<int>.generate(32, (index) => index + 1);

  test('cursor round-trips and binds scope, family, filters and page size', () {
    final codec = PluginRevocationPageCursorCodec(secret);
    final query = PluginRevocationJournalPageQuery(
      scopeId: 'tenant-blue',
      pageSize: 25,
      statuses: {PluginRevocationJournalStatus.failed},
    );
    final snapshot = DateTime.utc(2026, 11, 16, 1);
    final last = DateTime.utc(2026, 11, 15, 23);
    final token = codec.encode(
      family: 'journal',
      query: query,
      filters: ['failed'],
      snapshotAt: snapshot,
      lastAt: last,
      lastId: 'operation-1',
    );
    final position = codec.decode(
      token: token,
      family: 'journal',
      query: query,
      filters: ['failed'],
    );
    expect(position.snapshotAt, snapshot);
    expect(position.lastAt, last);
    expect(position.lastId, 'operation-1');

    expect(
      () => codec.decode(
        token: token,
        family: 'outbox',
        query: query,
        filters: ['failed'],
      ),
      throwsA(isA<PluginRevocationInvalidCursorException>()),
    );
    expect(
      () => codec.decode(
        token: token,
        family: 'journal',
        query: PluginRevocationJournalPageQuery(
          scopeId: 'tenant-red',
          pageSize: 25,
          statuses: {PluginRevocationJournalStatus.failed},
        ),
        filters: ['failed'],
      ),
      throwsA(isA<PluginRevocationInvalidCursorException>()),
    );
    expect(
      () => codec.decode(
        token: token,
        family: 'journal',
        query: PluginRevocationJournalPageQuery(
          scopeId: 'tenant-blue',
          pageSize: 25,
          statuses: {PluginRevocationJournalStatus.completed},
        ),
        filters: ['completed'],
      ),
      throwsA(isA<PluginRevocationInvalidCursorException>()),
    );
  });

  test('tampered token and undersized signing key fail closed', () {
    expect(
      () => PluginRevocationPageCursorCodec([1, 2, 3]),
      throwsArgumentError,
    );
    final codec = PluginRevocationPageCursorCodec(secret);
    final query = PluginRevocationOutboxPageQuery(scopeId: 'tenant-blue');
    final token = codec.encode(
      family: 'outbox',
      query: query,
      filters: const [],
      snapshotAt: DateTime.utc(2026, 11, 16),
      lastAt: DateTime.utc(2026, 11, 15),
      lastId: 'event-1',
    );
    expect(
      () => codec.decode(
        token: '${token}tampered',
        family: 'outbox',
        query: query,
        filters: const [],
      ),
      throwsA(isA<PluginRevocationInvalidCursorException>()),
    );
  });
}
