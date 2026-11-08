class InferenceMetrics {
  final String modelName;
  final String backend;
  final String device;
  final int gpuLayers;
  final int threads;
  final int contextSize;
  final int batchSize;
  final int ubatchSize;
  final bool swaFull;
  final bool cpuFallback;
  final String sessionType;

  // Timing metrics
  final double openTimeMs;
  final double generateCallMs;
  final double generationSpeedTps;
  final int totalTokens;
  final double tokenLatencyMs;

  // Native metrics
  final double nativeLoadMs;
  final double contextInitMs;
  final double nativeTokenizeMs;
  final bool tokenizeMiss;
  final double nativePromptMs;
  final int promptTokens;
  final double nativeDecodeMs;
  final int sampledTokens;
  final int decodedTokens;
  final double samplerTimeMs;
  final double sessionTimeMs;
  final double cacheTimeMs;
  final String cacheMode;
  final int outputBytes;
  final int javaBufferBytes;
  final int retries;

  const InferenceMetrics({
    required this.modelName,
    required this.backend,
    required this.device,
    required this.gpuLayers,
    required this.threads,
    required this.contextSize,
    required this.batchSize,
    required this.ubatchSize,
    required this.swaFull,
    required this.cpuFallback,
    required this.sessionType,
    required this.openTimeMs,
    required this.generateCallMs,
    required this.generationSpeedTps,
    required this.totalTokens,
    required this.tokenLatencyMs,
    required this.nativeLoadMs,
    required this.contextInitMs,
    required this.nativeTokenizeMs,
    required this.tokenizeMiss,
    required this.nativePromptMs,
    required this.promptTokens,
    required this.nativeDecodeMs,
    required this.sampledTokens,
    required this.decodedTokens,
    required this.samplerTimeMs,
    required this.sessionTimeMs,
    required this.cacheTimeMs,
    required this.cacheMode,
    required this.outputBytes,
    required this.javaBufferBytes,
    required this.retries,
  });

  factory InferenceMetrics.fromJson(Map<String, dynamic> json) {
    return InferenceMetrics(
      modelName: json['modelName'] ?? 'Unknown',
      backend: json['backend'] ?? 'gguf',
      device: json['device'] ?? 'Unknown',
      gpuLayers: json['gpuLayers'] ?? -1,
      threads: json['threads'] ?? 8,
      contextSize: json['contextSize'] ?? 512,
      batchSize: json['batchSize'] ?? 512,
      ubatchSize: json['ubatchSize'] ?? 512,
      swaFull: json['swaFull'] ?? false,
      cpuFallback: json['cpuFallback'] ?? false,
      sessionType: json['sessionType'] ?? 'cold',
      openTimeMs: (json['openTimeMs'] ?? 0).toDouble(),
      generateCallMs: (json['generateCallMs'] ?? 0).toDouble(),
      generationSpeedTps: (json['generationSpeedTps'] ?? 0).toDouble(),
      totalTokens: json['totalTokens'] ?? 0,
      tokenLatencyMs: (json['tokenLatencyMs'] ?? 0).toDouble(),
      nativeLoadMs: (json['nativeLoadMs'] ?? 0).toDouble(),
      contextInitMs: (json['contextInitMs'] ?? 0).toDouble(),
      nativeTokenizeMs: (json['nativeTokenizeMs'] ?? 0).toDouble(),
      tokenizeMiss: json['tokenizeMiss'] ?? false,
      nativePromptMs: (json['nativePromptMs'] ?? 0).toDouble(),
      promptTokens: json['promptTokens'] ?? 0,
      nativeDecodeMs: (json['nativeDecodeMs'] ?? 0).toDouble(),
      sampledTokens: json['sampledTokens'] ?? 0,
      decodedTokens: json['decodedTokens'] ?? 0,
      samplerTimeMs: (json['samplerTimeMs'] ?? 0).toDouble(),
      sessionTimeMs: (json['sessionTimeMs'] ?? 0).toDouble(),
      cacheTimeMs: (json['cacheTimeMs'] ?? 0).toDouble(),
      cacheMode: json['cacheMode'] ?? 'eager-short',
      outputBytes: json['outputBytes'] ?? 0,
      javaBufferBytes: json['javaBufferBytes'] ?? 0,
      retries: json['retries'] ?? 0,
    );
  }

  // Helper method for total time
  double get totalTimeMs => openTimeMs + generateCallMs;

  // Helper for effective speed
  double get effectiveSpeedTps => totalTokens / (generateCallMs / 1000);

  Map<String, dynamic> toJson() {
    return {
      'modelName': modelName,
      'backend': backend,
      'device': device,
      'gpuLayers': gpuLayers,
      'threads': threads,
      'contextSize': contextSize,
      'batchSize': batchSize,
      'ubatchSize': ubatchSize,
      'swaFull': swaFull,
      'cpuFallback': cpuFallback,
      'sessionType': sessionType,
      'openTimeMs': openTimeMs,
      'generateCallMs': generateCallMs,
      'generationSpeedTps': generationSpeedTps,
      'totalTokens': totalTokens,
      'tokenLatencyMs': tokenLatencyMs,
      'nativeLoadMs': nativeLoadMs,
      'contextInitMs': contextInitMs,
      'nativeTokenizeMs': nativeTokenizeMs,
      'tokenizeMiss': tokenizeMiss,
      'nativePromptMs': nativePromptMs,
      'promptTokens': promptTokens,
      'nativeDecodeMs': nativeDecodeMs,
      'sampledTokens': sampledTokens,
      'decodedTokens': decodedTokens,
      'samplerTimeMs': samplerTimeMs,
      'sessionTimeMs': sessionTimeMs,
      'cacheTimeMs': cacheTimeMs,
      'cacheMode': cacheMode,
      'outputBytes': outputBytes,
      'javaBufferBytes': javaBufferBytes,
      'retries': retries,
    };
  }
}
