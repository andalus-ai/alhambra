import 'package:alhambra_plugin_runtime/alhambra_plugin_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('scoped revocation page query contracts', () {
    test('requires a non-empty scope', () {
      expect(
        () => PluginRevocationJournalPageQuery(scopeId: ' '),
        throwsArgumentError,
      );
    });

    test('enforces bounded page sizes', () {
      expect(
        () => PluginRevocationJournalPageQuery(scopeId: 'tenant-a', pageSize: 0),
        throwsArgumentError,
      );
      expect(
        () => PluginRevocationOutboxPageQuery(
          scopeId: 'tenant-a',
          pageSize: pluginRevocationMaxPageSize + 1,
        ),
        throwsArgumentError,
      );
      expect(
        PluginRevocationOperatorActionPageQuery(
          scopeId: 'tenant-a',
          pageSize: pluginRevocationMaxPageSize,
        ).pageSize,
        pluginRevocationMaxPageSize,
      );
    });

    test('uses inclusive lower and exclusive upper time bounds', () {
      final from = DateTime.utc(2026, 11, 1);
      final to = DateTime.utc(2026, 11, 2);
      final query = PluginRevocationJournalPageQuery(
        scopeId: 'tenant-a',
        fromInclusive: from,
        toExclusive: to,
      );
      expect(query.fromInclusive, from);
      expect(query.toExclusive, to);
      expect(
        () => PluginRevocationJournalPageQuery(
          scopeId: 'tenant-a',
          fromInclusive: to,
          toExclusive: from,
        ),
        throwsArgumentError,
      );
      expect(
        () => PluginRevocationJournalPageQuery(
          scopeId: 'tenant-a',
          fromInclusive: from,
          toExclusive: from,
        ),
        throwsArgumentError,
      );
    });

    test('copies filter sets to prevent caller mutation', () {
      final statuses = <PluginRevocationJournalStatus>{
        PluginRevocationJournalStatus.failed,
      };
      final query = PluginRevocationJournalPageQuery(
        scopeId: 'tenant-a',
        statuses: statuses,
      );
      statuses.add(PluginRevocationJournalStatus.pending);
      expect(query.statuses, {PluginRevocationJournalStatus.failed});
    });

    test('rejects malformed oversized cursors', () {
      expect(
        () => PluginRevocationOutboxPageQuery(
          scopeId: 'tenant-a',
          cursor: '',
        ),
        throwsArgumentError,
      );
      expect(
        () => PluginRevocationOutboxPageQuery(
          scopeId: 'tenant-a',
          cursor: 'x' * 4097,
        ),
        throwsArgumentError,
      );
    });

    test('page results are immutable and expose continuation state', () {
      final items = <int>[1, 2];
      final page = PluginRevocationScopedPage<int>(
        items: items,
        nextCursor: 'opaque-token',
        snapshotAt: DateTime.utc(2026, 11, 15),
      );
      items.add(3);
      expect(page.items, [1, 2]);
      expect(page.hasMore, isTrue);
      expect(
        () => page.items.add(4),
        throwsUnsupportedError,
      );
      expect(
        PluginRevocationScopedPage<int>(
          items: const [],
          nextCursor: null,
          snapshotAt: DateTime.utc(2026, 11, 15),
        ).hasMore,
        isFalse,
      );
    });
  });
}
