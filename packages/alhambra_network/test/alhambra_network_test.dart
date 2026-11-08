import 'package:alhambra_network/alhambra_network.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Captures log lines emitted by LoggingInterceptor.
final class _CapturingLogger {
  final List<String> lines = [];
  void call(String msg) => lines.add(msg);
}

/// Records which requests it sees and returns a configurable response.
final class _RecordingTransport {
  final List<NetworkRequest> requests = [];
  late NetworkResponse<Object?> Function(NetworkRequest) handler;

  _RecordingTransport({
    NetworkResponse<Object?> Function(NetworkRequest)? handler,
  }) {
    this.handler = handler ?? _defaultHandler;
  }

  static NetworkResponse<Object?> _defaultHandler(NetworkRequest _) =>
      const NetworkResponse<Object?>(statusCode: 200);

  Future<NetworkResponse<Object?>> call(NetworkRequest req) async {
    requests.add(req);
    return handler(req);
  }
}

/// Transport that fails [failCount] times then succeeds.
final class _FlakyTransport {
  final int failCount;
  int _calls = 0;
  int get calls => _calls;

  _FlakyTransport(this.failCount);

  Future<NetworkResponse<Object?>> call(NetworkRequest _) async {
    _calls++;
    if (_calls <= failCount) throw Exception('transient error');
    return const NetworkResponse(statusCode: 200);
  }
}

void main() {
  // -------------------------------------------------------------------------
  // 1. Request model
  // -------------------------------------------------------------------------
  group('1. Request model', () {
    test('NetworkRequest carries all fields', () {
      const req = NetworkRequest(
        method: RequestMethod.post,
        path: '/workspaces',
        headers: {'Content-Type': 'application/json'},
        query: {'org': 'acme'},
        body: {'name': 'Alpha'},
        timeout: Duration(seconds: 15),
        idempotencyKey: 'idem-abc-123',
      );

      expect(req.method, equals(RequestMethod.post));
      expect(req.path, equals('/workspaces'));
      expect(req.headers['Content-Type'], equals('application/json'));
      expect(req.query['org'], equals('acme'));
      expect((req.body as Map)['name'], equals('Alpha'));
      expect(req.timeout, equals(const Duration(seconds: 15)));
      expect(req.idempotencyKey, equals('idem-abc-123'));
    });

    test('copyWith replaces only specified fields', () {
      const base = NetworkRequest(method: RequestMethod.get, path: '/foo');
      final updated = base.copyWith(
        method: RequestMethod.put,
        headers: {'Authorization': 'Bearer tok'},
      );

      expect(updated.method, equals(RequestMethod.put));
      expect(updated.path, equals('/foo'));
      expect(updated.headers['Authorization'], equals('Bearer tok'));
    });

    test('RequestMethod enum covers all HTTP verbs', () {
      expect(RequestMethod.values, containsAll([
        RequestMethod.get,
        RequestMethod.post,
        RequestMethod.put,
        RequestMethod.patch,
        RequestMethod.delete,
        RequestMethod.head,
      ]));
    });
  });

  // -------------------------------------------------------------------------
  // 2. Response model
  // -------------------------------------------------------------------------
  group('2. Response model', () {
    test('isSuccess for 2xx', () {
      expect(const NetworkResponse<void>(statusCode: 200).isSuccess, isTrue);
      expect(const NetworkResponse<void>(statusCode: 204).isSuccess, isTrue);
      expect(const NetworkResponse<void>(statusCode: 301).isSuccess, isFalse);
    });

    test('isClientError for 4xx', () {
      expect(const NetworkResponse<void>(statusCode: 400).isClientError, isTrue);
      expect(const NetworkResponse<void>(statusCode: 404).isClientError, isTrue);
    });

    test('isServerError for 5xx', () {
      expect(const NetworkResponse<void>(statusCode: 500).isServerError, isTrue);
      expect(const NetworkResponse<void>(statusCode: 503).isServerError, isTrue);
    });

    test('isUnauthorized and isRateLimited', () {
      expect(const NetworkResponse<void>(statusCode: 401).isUnauthorized, isTrue);
      expect(const NetworkResponse<void>(statusCode: 429).isRateLimited, isTrue);
    });

    test('data decoding via decoder', () async {
      final transport = _RecordingTransport(
        handler: (_) => const NetworkResponse<Object?>(
          statusCode: 200,
          data: {'id': 'ws-1', 'name': 'Alpha'},
        ),
      );
      final client = MockNetworkClient(
        config: NetworkClientConfig(
          baseUri: Uri.parse('https://api.example.com'),
        ),
        transport: transport.call,
      );

      final response = await client.get<String>(
        '/workspaces/ws-1',
        decoder: (body) => (body as Map)['name'] as String,
      );

      expect(response.data, equals('Alpha'));
      expect(response.isSuccess, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // 3. Authentication
  // -------------------------------------------------------------------------
  group('3. Authentication', () {
    test('AuthToken carries value, type, and expiry check', () {
      const active = AuthToken(
        value: 'jwt-active',
        expiresAt: null,
      );
      expect(active.isExpired, isFalse);
      expect(active.authorizationHeaderValue, equals('Bearer jwt-active'));

      final expired = AuthToken(
        value: 'jwt-expired',
        expiresAt: DateTime(2020),
      );
      expect(expired.isExpired, isTrue);
    });

    test('StaticAuthTokenProvider returns configured token', () async {
      const token = AuthToken(value: 'static-tok');
      const provider = StaticAuthTokenProvider(token);
      expect(await provider.getToken(), equals(token));
      expect(await provider.refreshToken(), equals(token));
    });

    test('AuthInterceptor injects Authorization header', () async {
      const token = AuthToken(value: 'test-jwt');
      final provider = StaticAuthTokenProvider(token);
      final interceptor = AuthInterceptor(provider);

      const base = NetworkRequest(
        method: RequestMethod.get,
        path: '/protected',
      );
      final mutated = await interceptor.onRequest(base);

      expect(mutated.headers['Authorization'], equals('Bearer test-jwt'));
    });

    test('AuthInterceptor does not inject expired token', () async {
      final expiredToken = AuthToken(
        value: 'old-jwt',
        expiresAt: DateTime(2020),
      );
      final provider = StaticAuthTokenProvider(expiredToken);
      final interceptor = AuthInterceptor(provider);

      const base = NetworkRequest(method: RequestMethod.get, path: '/resource');
      final mutated = await interceptor.onRequest(base);

      expect(mutated.headers.containsKey('Authorization'), isFalse);
    });

    test('token propagated end-to-end via MockNetworkClient', () async {
      const token = AuthToken(value: 'e2e-bearer');
      final recording = _RecordingTransport();

      final client = MockNetworkClient(
        config: NetworkClientConfig(
          baseUri: Uri.parse('https://api.example.com'),
          interceptors: [AuthInterceptor(StaticAuthTokenProvider(token))],
        ),
        transport: recording.call,
      );

      await client.get<void>('/secure-resource');

      expect(
        recording.requests.first.headers['Authorization'],
        equals('Bearer e2e-bearer'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 4. Interceptors
  // -------------------------------------------------------------------------
  group('4. Interceptors', () {
    test('LoggingInterceptor records request and response', () async {
      final logger = _CapturingLogger();
      final recording = _RecordingTransport();

      final client = MockNetworkClient(
        config: NetworkClientConfig(
          baseUri: Uri.parse('https://api.example.com'),
          interceptors: [LoggingInterceptor(logger.call)],
        ),
        transport: recording.call,
      );

      await client.get<void>('/items');

      expect(logger.lines.any((l) => l.contains('GET')), isTrue);
      expect(logger.lines.any((l) => l.contains('200')), isTrue);
    });

    test('idempotency key logged by LoggingInterceptor', () async {
      final logger = _CapturingLogger();
      const req = NetworkRequest(
        method: RequestMethod.post,
        path: '/mutations',
        idempotencyKey: 'op-999',
      );

      final client = MockNetworkClient(
        config: NetworkClientConfig(
          baseUri: Uri.parse('https://api.example.com'),
          interceptors: [LoggingInterceptor(logger.call)],
        ),
        transport: (_) async => const NetworkResponse(statusCode: 201),
      );

      await client.send<void>(req);

      expect(
        logger.lines.any((l) => l.contains('op-999')),
        isTrue,
        reason: 'Idempotency key should appear in log',
      );
    });

    test('multiple interceptors applied in registration order on request', () async {
      final order = <String>[];

      // Interceptor A marks request, Interceptor B records next step
      NetworkInterceptor makeMarker(String name) {
        return _LambdaInterceptor(onReq: (req) async {
          order.add(name);
          return req;
        });
      }

      final client = MockNetworkClient(
        config: NetworkClientConfig(
          baseUri: Uri.parse('https://api.example.com'),
          interceptors: [makeMarker('A'), makeMarker('B'), makeMarker('C')],
        ),
        transport: (_) async => const NetworkResponse(statusCode: 200),
      );

      await client.get<void>('/test');
      expect(order, equals(['A', 'B', 'C']));
    });
  });

  // -------------------------------------------------------------------------
  // 5. Retry & Exponential Backoff
  // -------------------------------------------------------------------------
  group('5. Retry & Backoff', () {
    test('ExponentialBackoffRetryPolicy allows retry for transient errors', () {
      const policy = ExponentialBackoffRetryPolicy(maxAttempts: 3);

      expect(
        policy.shouldRetry(attempt: 0, error: Exception('net'), statusCode: 503),
        isTrue,
      );
      expect(
        policy.shouldRetry(attempt: 2, error: Exception('net'), statusCode: 503),
        isTrue,
      );
      // After maxAttempts exhausted
      expect(
        policy.shouldRetry(attempt: 3, error: Exception('net'), statusCode: 503),
        isFalse,
      );
    });

    test('ExponentialBackoffRetryPolicy blocks retry for non-retryable 4xx', () {
      const policy = ExponentialBackoffRetryPolicy();
      expect(
        policy.shouldRetry(attempt: 0, error: Exception('client'), statusCode: 400),
        isFalse,
      );
    });

    test('Exponential delay calculation', () {
      const policy = ExponentialBackoffRetryPolicy(
        maxAttempts: 5,
        initialDelay: Duration(milliseconds: 100),
        maxDelay: Duration(seconds: 10),
      );

      expect(policy.delay(attempt: 0), equals(const Duration(milliseconds: 100)));
      expect(policy.delay(attempt: 1), equals(const Duration(milliseconds: 200)));
      expect(policy.delay(attempt: 2), equals(const Duration(milliseconds: 400)));
      // Capped at maxDelay
      expect(policy.delay(attempt: 10), equals(const Duration(seconds: 10)));
    });

    test('NoRetryPolicy never retries', () {
      const policy = NoRetryPolicy();
      expect(
        policy.shouldRetry(attempt: 0, error: Exception('err')),
        isFalse,
      );
    });

    test('MockNetworkClient retries on transient failure', () async {
      final flaky = _FlakyTransport(2); // fails twice, succeeds 3rd

      final client = MockNetworkClient(
        config: NetworkClientConfig(
          baseUri: Uri.parse('https://api.example.com'),
          retryPolicy: const ExponentialBackoffRetryPolicy(
            maxAttempts: 3,
            initialDelay: Duration.zero, // fast for tests
          ),
        ),
        transport: flaky.call,
      );

      final response = await client.get<void>('/retry-test');
      expect(response.isSuccess, isTrue);
      expect(flaky.calls, equals(3));
    });
  });

  // -------------------------------------------------------------------------
  // 6. Timeout policy
  // -------------------------------------------------------------------------
  group('6. Timeout policy', () {
    test('TimeoutPolicy presets are accessible', () {
      expect(TimeoutPolicy.upload.request, equals(const Duration(minutes: 5)));
      expect(TimeoutPolicy.streaming.request, equals(const Duration(hours: 24)));
      expect(const TimeoutPolicy().request, equals(const Duration(seconds: 30)));
    });
  });

  // -------------------------------------------------------------------------
  // 7. HTTP methods via convenience wrappers
  // -------------------------------------------------------------------------
  group('7. HTTP method convenience wrappers', () {
    late _RecordingTransport recording;
    late MockNetworkClient client;

    setUp(() {
      recording = _RecordingTransport();
      client = MockNetworkClient(
        config: NetworkClientConfig(
          baseUri: Uri.parse('https://api.example.com'),
        ),
        transport: recording.call,
      );
    });

    test('GET', () async {
      await client.get<void>('/items', query: {'page': '1'});
      expect(recording.requests.first.method, equals(RequestMethod.get));
      expect(recording.requests.first.query['page'], equals('1'));
    });

    test('POST with body', () async {
      await client.post<void>('/items', body: {'name': 'test'});
      expect(recording.requests.first.method, equals(RequestMethod.post));
      expect((recording.requests.first.body as Map)['name'], equals('test'));
    });

    test('PUT with body', () async {
      await client.put<void>('/items/1', body: {'name': 'updated'});
      expect(recording.requests.first.method, equals(RequestMethod.put));
    });

    test('PATCH with body', () async {
      await client.patch<void>('/items/1', body: {'active': false});
      expect(recording.requests.first.method, equals(RequestMethod.patch));
    });

    test('DELETE', () async {
      await client.delete<void>('/items/1');
      expect(recording.requests.first.method, equals(RequestMethod.delete));
    });
  });

  // -------------------------------------------------------------------------
  // 8. WebSocket events
  // -------------------------------------------------------------------------
  group('8. WebSocket event types', () {
    test('sealed hierarchy is pattern-matchable', () {
      final events = <WebSocketEvent>[
        const WebSocketConnected(),
        const WebSocketMessage('hello'),
        const WebSocketDisconnected(code: 1000, reason: 'normal'),
        const WebSocketError('oops'),
      ];

      final labels = events.map((e) => switch (e) {
            WebSocketConnected() => 'connected',
            WebSocketMessage(:final data) => 'msg:$data',
            WebSocketDisconnected(:final code, :final reason) =>
              'disc:$code:$reason',
            WebSocketError(:final error) => 'err:$error',
          }).toList();

      expect(labels, equals([
        'connected',
        'msg:hello',
        'disc:1000:normal',
        'err:oops',
      ]));
    });
  });

  // -------------------------------------------------------------------------
  // 9. SSE event model
  // -------------------------------------------------------------------------
  group('9. SSE event model', () {
    test('SseEvent carries id, event type, and data', () {
      const evt = SseEvent(
        id: '42',
        event: 'execution.started',
        data: '{"executionId":"exec-1"}',
      );

      expect(evt.id, equals('42'));
      expect(evt.event, equals('execution.started'));
      expect(evt.data, contains('exec-1'));
    });

    test('SseEvent without optional fields', () {
      const evt = SseEvent(data: 'ping');
      expect(evt.id, isNull);
      expect(evt.event, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 10. Network error semantics
  // -------------------------------------------------------------------------
  group('10. Network error codes', () {
    test('NetworkErrorCode constants are non-empty strings', () {
      expect(NetworkErrorCode.unavailable, isNotEmpty);
      expect(NetworkErrorCode.timeout, isNotEmpty);
      expect(NetworkErrorCode.unauthorized, isNotEmpty);
      expect(NetworkErrorCode.notFound, isNotEmpty);
      expect(NetworkErrorCode.rateLimited, isNotEmpty);
      expect(NetworkErrorCode.server, isNotEmpty);
    });

    test('NetworkException carries code and message', () {
      const ex = NetworkException(
        code: NetworkErrorCode.notFound,
        message: 'Workspace not found',
        statusCode: 404,
      );
      expect(ex.code, equals('network.not_found'));
      expect(ex.statusCode, equals(404));
      expect(ex.toString(), contains('network.not_found'));
    });
  });
}

// ---------------------------------------------------------------------------
// Lambda interceptor helper
// ---------------------------------------------------------------------------
final class _LambdaInterceptor implements NetworkInterceptor {
  final Future<NetworkRequest> Function(NetworkRequest)? onReq;
  const _LambdaInterceptor({this.onReq});

  @override
  Future<NetworkRequest> onRequest(NetworkRequest request) =>
      onReq != null ? onReq!(request) : Future<NetworkRequest>.value(request);

  @override
  Future<NetworkResponse<Object?>> onResponse(
          NetworkResponse<Object?> response) async =>
      response;

  @override
  Future<Object?> onError(Object error) async => throw error;
}
