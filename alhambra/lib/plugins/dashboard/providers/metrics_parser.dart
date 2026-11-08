import '../models/inference_metrics.dart';

class MetricsParser {
  /// Parses a raw metrics string block into an InferenceMetrics object.
  static InferenceMetrics parse(String rawMetrics, String fallbackModelName) {
    // Basic defaults
    String backend = 'gguf';
    String device = 'Unknown';
    int gpuLayers = -1;
    int threads = 8;
    int contextSize = 512;
    int batchSize = 512;
    int ubatchSize = 512;
    bool swaFull = false;
    bool cpuFallback = false;
    String sessionType = 'cold';

    double openTimeMs = 0;
    double generateCallMs = 0;
    double generationSpeedTps = 0;
    int totalTokens = 0;
    double tokenLatencyMs = 0;

    double nativeLoadMs = 0;
    double contextInitMs = 0;
    double nativeTokenizeMs = 0;
    bool tokenizeMiss = false;
    double nativePromptMs = 0;
    int promptTokens = 0;
    double nativeDecodeMs = 0;
    int sampledTokens = 0;
    int decodedTokens = 0;
    double samplerTimeMs = 0;
    double sessionTimeMs = 0;
    double cacheTimeMs = 0;
    String cacheMode = 'eager-short';
    int outputBytes = 0;
    int javaBufferBytes = 0;
    int retries = 0;

    // Split into lines for regex matching
    final lines = rawMetrics.split('\n');

    for (final line in lines) {
      if (line.contains('open time')) {
        openTimeMs = _parseDouble(line, r'=\s*([\d,.]+)\s*ms');
      } else if (line.contains('generate call')) {
        generateCallMs = _parseDouble(line, r'=\s*([\d,.]+)\s*ms');
      } else if (line.contains('generation') && !line.contains('Speed')) {
        generationSpeedTps = _parseDouble(line, r'=\s*([\d,.]+)\s*t/s');
        totalTokens = _parseInt(line, r'\((\d+)\s*tokens\)');
      } else if (line.contains('token latency')) {
        tokenLatencyMs = _parseDouble(line, r'=\s*([\d,.]+)\s*ms/token');
      } else if (line.contains('native backend')) {
        final backendMatch =
            RegExp(r'=\s*([^\(]+)\s*\((.*?)\)').firstMatch(line);
        if (backendMatch != null) {
          backend = backendMatch.group(1)?.trim() ?? backend;
          device = backendMatch.group(2)?.trim() ?? device;
        }
        gpuLayers = _parseInt(line, r'gpuLayers=(-?\d+)');
        threads = _parseInt(line, r'threads=(\d+)');
        contextSize = _parseInt(line, r'ctx=(\d+)');
        batchSize = _parseInt(line, r'batch=(\d+)');
        ubatchSize = _parseInt(line, r'ubatch=(\d+)');
      } else if (line.contains('native load')) {
        nativeLoadMs = _parseDouble(line, r'=\s*([\d,.]+)\s*ms');
        contextInitMs = _parseDouble(line, r'context init =\s*([\d,.]+)\s*ms');
      } else if (line.contains('native tokenize')) {
        nativeTokenizeMs = _parseDouble(line, r'=\s*([\d,.]+)\s*ms');
        tokenizeMiss = line.contains('(miss)');
      } else if (line.contains('native prompt')) {
        nativePromptMs = _parseDouble(line, r'=\s*([\d,.]+)\s*ms');
        promptTokens = _parseInt(line, r'\((\d+)\s*tokens\)');
      } else if (line.contains('native decode')) {
        nativeDecodeMs = _parseDouble(line, r'=\s*([\d,.]+)\s*ms');
        sampledTokens = _parseInt(line, r'\((\d+)\s*sampled');
        decodedTokens = _parseInt(line, r',\s*(\d+)\s*decoded\)');
      } else if (line.contains('native sampler')) {
        samplerTimeMs = _parseDouble(line, r',\s*([\d,.]+)\s*ms');
      } else if (line.contains('native session')) {
        sessionTimeMs = _parseDouble(line, r',\s*([\d,.]+)\s*ms');
        final sessionMatch = RegExp(r'=\s*([^\(,]+)').firstMatch(line);
        if (sessionMatch != null) {
          sessionType = sessionMatch.group(1)?.trim() ?? sessionType;
        }
      } else if (line.contains('native cache')) {
        cacheTimeMs = _parseDouble(line, r',\s*([\d,.]+)\s*ms');
        final modeMatch = RegExp(r'\(([^)]+)\)').firstMatch(line);
        if (modeMatch != null) {
          cacheMode = modeMatch.group(1)?.trim() ?? cacheMode;
        }
      } else if (line.contains('native output')) {
        outputBytes = _parseInt(line, r'=\s*(\d+)\s*bytes');
        javaBufferBytes = _parseInt(line, r'java buffer =\s*(\d+)\s*bytes');
        retries = _parseInt(line, r'retries =\s*(\d+)');
      }
    }

    return InferenceMetrics(
      modelName: fallbackModelName,
      backend: backend,
      device: device,
      gpuLayers: gpuLayers,
      threads: threads,
      contextSize: contextSize,
      batchSize: batchSize,
      ubatchSize: ubatchSize,
      swaFull: swaFull,
      cpuFallback: cpuFallback,
      sessionType: sessionType,
      openTimeMs: openTimeMs,
      generateCallMs: generateCallMs,
      generationSpeedTps: generationSpeedTps,
      totalTokens: totalTokens,
      tokenLatencyMs: tokenLatencyMs,
      nativeLoadMs: nativeLoadMs,
      contextInitMs: contextInitMs,
      nativeTokenizeMs: nativeTokenizeMs,
      tokenizeMiss: tokenizeMiss,
      nativePromptMs: nativePromptMs,
      promptTokens: promptTokens,
      nativeDecodeMs: nativeDecodeMs,
      sampledTokens: sampledTokens,
      decodedTokens: decodedTokens,
      samplerTimeMs: samplerTimeMs,
      sessionTimeMs: sessionTimeMs,
      cacheTimeMs: cacheTimeMs,
      cacheMode: cacheMode,
      outputBytes: outputBytes,
      javaBufferBytes: javaBufferBytes,
      retries: retries,
    );
  }

  static double _parseDouble(String line, String pattern) {
    final match = RegExp(pattern).firstMatch(line);
    if (match != null && match.groupCount >= 1) {
      final str = match.group(1)!.replaceAll(',', '.');
      return double.tryParse(str) ?? 0.0;
    }
    return 0.0;
  }

  static int _parseInt(String line, String pattern) {
    final match = RegExp(pattern).firstMatch(line);
    if (match != null && match.groupCount >= 1) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }
}
