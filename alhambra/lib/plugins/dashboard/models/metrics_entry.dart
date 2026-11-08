import 'package:objectbox/objectbox.dart';

@Entity()
class MetricsEntry {
  @Id()
  int id = 0;

  // Timestamps for date-range queries
  @Property(type: PropertyType.date)
  DateTime timestamp;

  // Session context
  String sessionId;
  String modelName;
  String backend;
  String device;

  // Performance
  double generationSpeedTps;
  int totalTokens;
  double tokenLatencyMs;
  double openTimeMs;
  double generateCallMs;

  // Native metrics
  double nativeLoadMs;
  double nativePromptMs;
  double nativeDecodeMs;
  double nativeTokenizeMs;
  String cacheMode;
  String sessionType;
  int promptTokens;
  int sampledTokens;
  int decodedTokens;
  int gpuLayers;
  int threads;
  int contextSize;
  int outputBytes;

  MetricsEntry({
    this.id = 0,
    required this.timestamp,
    this.sessionId = '',
    this.modelName = 'Unknown',
    this.backend = 'gguf',
    this.device = 'Unknown',
    this.generationSpeedTps = 0,
    this.totalTokens = 0,
    this.tokenLatencyMs = 0,
    this.openTimeMs = 0,
    this.generateCallMs = 0,
    this.nativeLoadMs = 0,
    this.nativePromptMs = 0,
    this.nativeDecodeMs = 0,
    this.nativeTokenizeMs = 0,
    this.cacheMode = 'cold',
    this.sessionType = 'cold',
    this.promptTokens = 0,
    this.sampledTokens = 0,
    this.decodedTokens = 0,
    this.gpuLayers = -1,
    this.threads = 8,
    this.contextSize = 512,
    this.outputBytes = 0,
  });

  /// Convert from InferenceMetrics
  factory MetricsEntry.fromInferenceMetrics(Map<String, dynamic> m,
      {String sessionId = ''}) {
    return MetricsEntry(
      timestamp: DateTime.now(),
      sessionId: sessionId,
      modelName: m['modelName'] ?? 'Unknown',
      backend: m['backend'] ?? 'gguf',
      device: m['device'] ?? 'Unknown',
      generationSpeedTps: (m['generationSpeedTps'] ?? 0).toDouble(),
      totalTokens: m['totalTokens'] ?? 0,
      tokenLatencyMs: (m['tokenLatencyMs'] ?? 0).toDouble(),
      openTimeMs: (m['openTimeMs'] ?? 0).toDouble(),
      generateCallMs: (m['generateCallMs'] ?? 0).toDouble(),
      nativeLoadMs: (m['nativeLoadMs'] ?? 0).toDouble(),
      nativePromptMs: (m['nativePromptMs'] ?? 0).toDouble(),
      nativeDecodeMs: (m['nativeDecodeMs'] ?? 0).toDouble(),
      nativeTokenizeMs: (m['nativeTokenizeMs'] ?? 0).toDouble(),
      cacheMode: m['cacheMode'] ?? 'cold',
      sessionType: m['sessionType'] ?? 'cold',
      promptTokens: m['promptTokens'] ?? 0,
      sampledTokens: m['sampledTokens'] ?? 0,
      decodedTokens: m['decodedTokens'] ?? 0,
      gpuLayers: m['gpuLayers'] ?? -1,
      threads: m['threads'] ?? 8,
      contextSize: m['contextSize'] ?? 512,
      outputBytes: m['outputBytes'] ?? 0,
    );
  }
}
