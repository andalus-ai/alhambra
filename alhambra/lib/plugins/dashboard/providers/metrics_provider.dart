import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../objectbox.g.dart';
import '../models/inference_metrics.dart';
import '../../../services/objectbox/object_store.dart';
import '../models/metrics_entry.dart';

final metricsProvider = StateProvider<InferenceMetrics?>((ref) => null);

// Provider for metrics history
final metricsHistoryProvider =
    StateProvider<List<InferenceMetrics>>((ref) => []);

// Provider for auto-refresh toggle
final autoRefreshProvider = StateProvider<bool>((ref) => false);

// Provider for selected metric for chart
final selectedMetricProvider = StateProvider<String>((ref) => 'tokenLatencyMs');

// Simulated metrics update (replace with actual API call)
final metricsServiceProvider = Provider((ref) => MetricsService());

final metricsPeriodProvider =
    StateProvider<String>((ref) => 'all'); // 'today','week','month','all'

class MetricsService {
  Future<List<InferenceMetrics>> fetchMetricsHistory(
      {DateTime? from, DateTime? to}) async {
    final box = ObjectBoxStore().metricsBox;
    QueryBuilder<MetricsEntry> query;

    if (from != null && to != null) {
      query = box.query(MetricsEntry_.timestamp.betweenDate(from, to))
        ..order(MetricsEntry_.timestamp, flags: Order.descending);
    } else {
      query = box.query()
        ..order(MetricsEntry_.timestamp, flags: Order.descending);
    }

    final entries = query.build().find();
    return entries
        .map((e) => InferenceMetrics(
              modelName: e.modelName,
              backend: e.backend,
              device: e.device,
              gpuLayers: e.gpuLayers,
              threads: e.threads,
              contextSize: e.contextSize,
              batchSize: 512,
              ubatchSize: 512,
              swaFull: false,
              cpuFallback: false,
              sessionType: e.sessionType,
              openTimeMs: e.openTimeMs,
              generateCallMs: e.generateCallMs,
              generationSpeedTps: e.generationSpeedTps,
              totalTokens: e.totalTokens,
              tokenLatencyMs: e.tokenLatencyMs,
              nativeLoadMs: e.nativeLoadMs,
              contextInitMs: 0,
              nativeTokenizeMs: e.nativeTokenizeMs,
              tokenizeMiss: false,
              nativePromptMs: e.nativePromptMs,
              promptTokens: e.promptTokens,
              nativeDecodeMs: e.nativeDecodeMs,
              sampledTokens: e.sampledTokens,
              decodedTokens: e.decodedTokens,
              samplerTimeMs: 0,
              sessionTimeMs: 0,
              cacheTimeMs: 0,
              cacheMode: e.cacheMode,
              outputBytes: e.outputBytes,
              javaBufferBytes: 0,
              retries: 0,
            ))
        .toList();
  }
}

// Provider for updating metrics
final updateMetricsProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(metricsServiceProvider);
  final historyData = await service.fetchMetricsHistory();

  if (historyData.isNotEmpty) {
    ref.read(metricsProvider.notifier).state = historyData.first;
    ref.read(metricsHistoryProvider.notifier).state = historyData;
  }
});
