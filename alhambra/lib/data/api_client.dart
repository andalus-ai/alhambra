import 'dart:convert';
import 'package:http/http.dart' as http;

/// Centralised HTTP client for the andalus-pro runtime REST API.
/// All API calls go through here so the base URL is configurable in one place.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  static const String baseUrl = 'http://localhost:8086';
  static const String tenantId = 'default-tenant';

  ApiClient._internal();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Tenant-Id': tenantId,
      };

  Future<dynamic> get(String path) async {
    final res = await http
        .get(Uri.parse('$baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    _assertOk(res);
    return jsonDecode(res.body);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 15));
    _assertOk(res);
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final res = await http
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 15));
    _assertOk(res);
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  /// Returns a stream of JSON-decoded objects from a Server-Sent Events endpoint.
  Stream<Map<String, dynamic>> sse(String path) async* {
    final req = http.Request('GET', Uri.parse('$baseUrl$path'));
    _headers.forEach((k, v) => req.headers[k] = v);
    req.headers['Accept'] = 'text/event-stream';

    final client = http.Client();
    final response = await client.send(req);
    final stream =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in stream) {
      if (line.startsWith('data:')) {
        final data = line.substring(5).trim();
        if (data.isNotEmpty && data != '[DONE]') {
          try {
            yield jsonDecode(data) as Map<String, dynamic>;
          } catch (_) {}
        }
      }
    }
    client.close();
  }

  void _assertOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API error ${res.statusCode}: ${res.body}');
    }
  }
}

final apiClient = ApiClient();
