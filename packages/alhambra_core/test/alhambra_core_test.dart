import 'package:test/test.dart';
import 'package:alhambra_core/alhambra_core.dart';

void main() {
  group('AlhambraId Tests', () {
    test('AlhambraId equality and stringification', () {
      const id1 = AlhambraId('id-123');
      const id2 = AlhambraId('id-123');
      const id3 = AlhambraId('id-456');

      expect(id1, equals(id2));
      expect(id1.hashCode, equals(id2.hashCode));
      expect(id1, isNot(equals(id3)));
      expect(id1.toString(), 'id-123');
    });

    test('Specialized IDs are distinct types', () {
      const wId = WorkspaceId('123');
      const uId = UserId('123');
      const oId = OrganizationId('123');
      const eId = ExecutionId('123');

      expect(wId.value, '123');
      expect(uId.value, '123');
      expect(oId.value, '123');
      expect(eId.value, '123');

      // Different types with same value must not be equal
      expect(wId == uId, isFalse);
      expect(oId == eId, isFalse);
    });
  });

  group('Result Tests', () {
    test('Success value wrapping and unfolding', () {
      const result = Result<int>.success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.errorOrNull, isNull);

      final mapped = result.map((v) => 'Value: $v');
      expect(mapped.valueOrNull, 'Value: 42');

      final folded = result.fold(
        onSuccess: (v) => v * 2,
        onFailure: (err) => 0,
      );
      expect(folded, 84);
    });

    test('Failure error wrapping and propagation', () {
      const error = AlhambraError(
        code: ErrorCode.notFound,
        message: 'Resource not found',
      );
      const result = Result<int>.failure(error);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.errorOrNull?.code, ErrorCode.notFound);

      final mapped = result.map((v) => 'Value: $v');
      expect(mapped.isFailure, isTrue);
      expect(mapped.errorOrNull?.code, ErrorCode.notFound);

      final folded = result.fold(
        onSuccess: (v) => v * 2,
        onFailure: (err) => -1,
      );
      expect(folded, -1);
    });
  });

  group('Resource and Metadata Tests', () {
    test('ResourceMetadata versioning and copyWith', () {
      final now = DateTime.utc(2026, 10, 1);
      final meta = ResourceMetadata(
        id: const WorkspaceId('ws-1'),
        createdAt: now,
        updatedAt: now,
        createdBy: 'user-alice',
        version: 1,
      );

      expect(meta.id.value, 'ws-1');
      expect(meta.version, 1);

      final updated = meta.copyWith(
        version: 2,
        updatedBy: 'user-bob',
      );
      expect(updated.version, 2);
      expect(updated.updatedBy, 'user-bob');
      expect(updated.createdBy, 'user-alice');
    });

    test('Generic Metadata container key access and copyWith', () {
      const meta = Metadata({
        'environment': 'production',
        'rate_limit': 100,
        'enabled': true,
      });

      expect(meta.get<String>('environment'), 'production');
      expect(meta.get<int>('rate_limit'), 100);
      expect(meta.get<bool>('enabled'), isTrue);
      expect(meta.get<String>('nonexistent'), isNull);

      final updated = meta.copyWith({'rate_limit': 200});
      expect(updated.get<int>('rate_limit'), 200);
      expect(updated.get<String>('environment'), 'production');
    });
  });

  group('Pagination, Filter, and Sort Tests', () {
    test('Pagination offset calculation', () {
      const p1 = Pagination(page: 1, pageSize: 20);
      expect(p1.offset, 0);

      const p2 = Pagination(page: 3, pageSize: 15);
      expect(p2.offset, 30);
    });

    test('Page metrics and mapping', () {
      final page = Page<int>(
        items: [1, 2, 3],
        page: 1,
        pageSize: 3,
        hasNext: true,
        totalCount: 10,
      );

      expect(page.items.length, 3);
      expect(page.totalPages, 4);
      expect(page.isFirst, isTrue);
      expect(page.isLast, isFalse);

      final strPage = page.map((i) => 'Item $i');
      expect(strPage.items, ['Item 1', 'Item 2', 'Item 3']);
    });

    test('Filter predicates', () {
      const f1 = Filter.equals('status', 'active');
      expect(f1.operator, FilterOperator.equals);
      expect(f1.field, 'status');
      expect(f1.value, 'active');

      const f2 = Filter.contains('name', 'project');
      expect(f2.operator, FilterOperator.contains);
    });

    test('Sort direction', () {
      const sortAsc = Sort('createdAt');
      expect(sortAsc.direction, SortDirection.ascending);

      const sortDesc = Sort.desc('updatedAt');
      expect(sortDesc.direction, SortDirection.descending);
    });
  });

  group('Command, Query, and Event Tests', () {
    test('CommandHandler executes and returns Result', () async {
      final handler = _TestCommandHandler();
      final res = await handler.handle(_TestCommand('hello'));
      expect(res.isSuccess, isTrue);
      expect(res.valueOrNull, 'Echo: hello');
    });

    test('QueryHandler executes and returns Result', () async {
      final handler = _TestQueryHandler();
      final res = await handler.handle(_TestQuery(10));
      expect(res.isSuccess, isTrue);
      expect(res.valueOrNull, 20);
    });

    test('DomainEvent contract representation', () {
      final event = _SampleDomainEvent(DateTime.now());
      expect(event.type, 'sample.created');
      expect(event.occurredAt, isNotNull);
    });
  });

  group('Versioning Tests', () {
    test('Version parsing and semantic ordering', () {
      final v1 = Version.parse('1.0.0');
      final v2 = Version.parse('1.2.0');
      final v3 = Version.parse('2.0.0-beta');

      expect(v1.major, 1);
      expect(v1.minor, 0);
      expect(v1.patch, 0);

      expect(v1.compareTo(v2), lessThan(0));
      expect(v2.compareTo(v1), greaterThan(0));
      expect(v2.compareTo(v3), lessThan(0));
      expect(v1.toString(), '1.0.0');
      expect(v3.toString(), '2.0.0-beta');
    });
  });
}

class _TestCommand implements Command<String> {
  final String text;
  const _TestCommand(this.text);
}

class _TestCommandHandler implements CommandHandler<_TestCommand, String> {
  @override
  Future<Result<String>> handle(_TestCommand command) async {
    return Result.success('Echo: ${command.text}');
  }
}

class _TestQuery implements Query<int> {
  final int number;
  const _TestQuery(this.number);
}

class _TestQueryHandler implements QueryHandler<_TestQuery, int> {
  @override
  Future<Result<int>> handle(_TestQuery query) async {
    return Result.success(query.number * 2);
  }
}

class _SampleDomainEvent implements DomainEvent {
  @override
  final DateTime occurredAt;

  @override
  final String type = 'sample.created';

  _SampleDomainEvent(this.occurredAt);
}
