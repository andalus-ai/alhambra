import 'dart:async';
import 'dart:convert';
import 'package:batik/batik.dart'
    show
        AgentAdapter,
        AgentTurnInput,
        AgentTurnOutput,
        AgentUIResponse,
        UINode,
        UISystemPromptBuilder;
import 'package:http/http.dart' as http;

/// Batik [AgentAdapter] for the Andalus AI backend.
///
/// Andalus is the Alhambra platform's intelligence engine. It accepts
/// [AgentTurnInput] and returns a [batik.AgentUIResponse] containing a
/// Batik UINode tree, which is then rendered via [BatikSurfaceView].
///
/// Wire this into any Alhambra screen that needs agent-generated UI:
/// ```dart
/// final adapter = AndalusAdapter(
///   baseUrl: 'https://andalus.example.com',
///   apiKey: 'alhambra-key',
///   organizationId: context.read<OrganizationNotifier>().current!.organizationId,
/// );
/// ```
///
/// The Andalus API is expected to be REST-compatible and return JSON in the
/// Batik [batik.AgentUIResponse] schema (with a `root` UINode tree).
class AndalusAdapter extends AgentAdapter {
  AndalusAdapter({
    required this.baseUrl,
    required this.apiKey,
    this.organizationId,
    this.workspaceId,
    this.schemaVersion = '1.0.0',
    this.maxTokens = 4096,
    this.systemPrompt,
    this.appContext,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final String? organizationId;
  final String? workspaceId;
  final String schemaVersion;
  final int maxTokens;
  final String? systemPrompt;
  final String? appContext;
  final http.Client _http;

  @override
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input) async {
    try {
      final body = json.encode({
        'userMessage': input.userMessage,
        'history': input.history
            .map((m) => {'role': m.role, 'content': m.content})
            .toList(),
        'variables': input.variables,
        'metadata': {
          ...input.metadata,
          if (organizationId != null) 'organizationId': organizationId,
          if (workspaceId != null) 'workspaceId': workspaceId,
        },
        'schemaVersion': schemaVersion,
        'maxTokens': maxTokens,
        'systemPrompt': systemPrompt ??
            UISystemPromptBuilder.build(
              appContext: appContext,
              schemaVersion: schemaVersion,
            ),
        if (input.sessionId != null) 'sessionId': input.sessionId,
      });

      final response = await _http.post(
        Uri.parse('$baseUrl/v1/intelligence/ui'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          if (organizationId != null) 'X-Organization-Id': organizationId!,
        },
        body: body,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Andalus API error ${response.statusCode}: ${response.body}',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final uiResponse = _parseResponse(data);

      return AgentTurnOutput(
        uiResponse: uiResponse,
        textResponse: uiResponse?.root is UINode
            ? null
            : data['text'] as String?,
        rawResponse: data,
      );
    } catch (e) {
      return AgentTurnOutput(error: e);
    }
  }

  @override
  AgentUIResponse? parseResponse(dynamic raw) {
    if (raw is Map<String, dynamic>) return _parseResponse(raw);
    if (raw is String) {
      try {
        return _parseResponse(json.decode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return null;
  }

  AgentUIResponse? _parseResponse(Map<String, dynamic> data) {
    try {
      // Full AgentUIResponse envelope.
      if (data.containsKey('root')) {
        return AgentUIResponse.fromJson(data);
      }
      // Bare UINode (no envelope) — wrap it.
      if (data.containsKey('type')) {
        return AgentUIResponse(
          schemaVersion: schemaVersion,
          root: UINode.fromJson(data),
          metadata: {},
        );
      }
      // Andalus-specific wrapper: { ui: {...}, text: '...' }
      if (data.containsKey('ui')) {
        final ui = data['ui'];
        if (ui is Map<String, dynamic>) {
          return AgentUIResponse.fromJson(ui);
        }
      }
    } catch (_) {}
    return null;
  }
}
