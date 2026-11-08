import 'dart:convert';

import 'package:alhambra_network/alhambra_network.dart';
import 'package:alhambra_network_dio/alhambra_network_dio.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

// ── Mock HTTP adapter ───────────────────────────────────────────────────────

class _MockAdapter implements HttpClientAdapter {
  final int statusCode;
  final Object body;

  _MockAdapter({this.statusCode = 200, this.body = const <String, Object?>{}});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final encoded = jsonEncode(body);
    return ResponseBody.fromString(
      encoded,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// ── Helpers ─────────────────────────────────────────────────────────────────

DioNetworkClient _client({
  int statusCode = 200,
  Object body = const <String, Object?>{},
  List<NetworkInterceptor> interceptors = const [],
}) {
  final client = DioNetworkClient(
    NetworkClientConfig(
      baseUri: Uri.parse('https://test.example.com'),
      interceptors: interceptors,
    ),
  );
  client.dio.httpClientAdapter = _MockAdapter(statusCode: statusCode, body: body);
  return client;
}

// ── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('DioNetworkClient', () {
    test('implements NetworkClient contract', () {
      expect(_client(), isA<NetworkClient>());
    });

    test('GET returns 200 with decoded body', () async {
      final c = _client(body: {'id': '123', 'name': 'Workspace'});
      final resp = await c.get<Map<String, dynamic>>(
        '/workspaces/123',
        decoder: (b) => (b as Map).cast<String, dynamic>(),
      );
      expect(resp.statusCode, 200);
      expect(resp.isSuccess, isTrue);
      expect(resp.data!['id'], '123');
    });

    test('POST sends body and returns created response', () async {
      final c = _client(statusCode: 201, body: {'id': 'new-1'});
      final resp = await c.post<Map<String, dynamic>>(
        '/workspaces',
        body: {'name': 'New Workspace'},
        decoder: (b) => (b as Map).cast<String, dynamic>(),
      );
      expect(resp.statusCode, 201);
      expect(resp.data!['id'], 'new-1');
    });

    test('404 maps to isClientError', () async {
      final c = _client(statusCode: 404);
      final resp = await c.get<Object?>('/missing');
      expect(resp.isClientError, isTrue);
      expect(resp.isSuccess, isFalse);
    });

    test('500 maps to isServerError', () async {
      final c = _client(statusCode: 500);
      final resp = await c.get<Object?>('/boom');
      expect(resp.isServerError, isTrue);
    });

    test('401 maps to isUnauthorized', () async {
      final c = _client(statusCode: 401);
      final resp = await c.get<Object?>('/protected');
      expect(resp.isUnauthorized, isTrue);
    });

    test('Idempotency-Key header is injected', () async {
      String? capturedKey;
      final c = _client();
      c.dio.interceptors.add(InterceptorsWrapper(
        onRequest: (opts, handler) {
          capturedKey = opts.headers['Idempotency-Key'] as String?;
          handler.next(opts);
        },
      ));
      await c.send<Object?>(const NetworkRequest(
        method: RequestMethod.post,
        path: '/ops',
        idempotencyKey: 'key-abc',
      ));
      expect(capturedKey, 'key-abc');
    });

    test('NetworkInterceptor.onRequest is called', () async {
      bool called = false;
      final interceptor = _TestInterceptor(onReq: (r) {
        called = true;
        return r;
      });
      final c = _client(interceptors: [interceptor]);
      await c.get<Object?>('/test');
      expect(called, isTrue);
    });

    test('PUT convenience method works', () async {
      final c = _client(body: {'updated': true});
      final resp = await c.put<Map<String, dynamic>>(
        '/items/1',
        body: {'name': 'Updated'},
        decoder: (b) => (b as Map).cast<String, dynamic>(),
      );
      expect(resp.isSuccess, isTrue);
    });

    test('DELETE convenience method works', () async {
      final c = _client(statusCode: 204, body: '');
      final resp = await c.delete<Object?>('/items/1');
      expect(resp.statusCode, 204);
    });

    test('MockNetworkClient (InMemory fallback) still works', () async {
      // Verify the abstraction-package fallback is unchanged
      final mock = MockNetworkClient(
        config: NetworkClientConfig(baseUri: Uri.parse('https://example.com')),
        transport: (_) async =>
            const NetworkResponse<Object?>(statusCode: 200, data: 'hello'),
      );
      final resp = await mock.get<String>('/test',
          decoder: (b) => b as String);
      expect(resp.statusCode, 200);
      expect(resp.data, 'hello');
    });
  });
}

// ── Test interceptor ─────────────────────────────────────────────────────────

final class _TestInterceptor extends BaseInterceptor {
  final NetworkRequest Function(NetworkRequest) onReq;
  const _TestInterceptor({required this.onReq});

  @override
  Future<NetworkRequest> onRequest(NetworkRequest request) async =>
      onReq(request);
}
