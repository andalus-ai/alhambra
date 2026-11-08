import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/performance_chart.dart';
import 'metric_card.dart';
import '../providers/metrics_provider.dart';
import 'native_metric_card.dart';

class MetricsDashboard extends ConsumerStatefulWidget {
  const MetricsDashboard({super.key});

  @override
  ConsumerState<MetricsDashboard> createState() => _MetricsDashboardState();
}

class _MetricsDashboardState extends ConsumerState<MetricsDashboard> {
  @override
  void initState() {
    super.initState();
    // Load initial metrics
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(updateMetricsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(metricsProvider);
    final history = ref.watch(metricsHistoryProvider);
    final autoRefresh = ref.watch(autoRefreshProvider);
    final selectedMetric = ref.watch(selectedMetricProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.speed, color: Colors.blue),
            SizedBox(width: 10),
            Text(
              'Inference Dashboard',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          if (metrics != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record,
                      size: 10, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '${metrics.totalTokens} tokens',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              autoRefresh ? Icons.pause : Icons.play_arrow,
              color: autoRefresh ? Colors.blue : Colors.grey,
            ),
            onPressed: () {
              ref.read(autoRefreshProvider.notifier).state = !autoRefresh;
              if (!autoRefresh) {
                _startAutoRefresh();
              }
            },
            tooltip: autoRefresh ? 'Pause auto-refresh' : 'Start auto-refresh',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(updateMetricsProvider),
            tooltip: 'Refresh metrics',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: metrics == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Model info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.model_training, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metrics.modelName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${metrics.device} • ${metrics.threads} threads • ctx=${metrics.contextSize} • batch=${metrics.batchSize}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'GGUF • ${metrics.backend}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Main metrics grid
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1.6,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    children: [
                      MetricCard(
                        title: 'Total Time',
                        value: metrics.totalTimeMs.toStringAsFixed(2),
                        unit: 'ms',
                        icon: Icons.timer,
                        color: Colors.blue,
                        progress: metrics.totalTimeMs / 10000,
                      ),
                      MetricCard(
                        title: 'Generate Call',
                        value: metrics.generateCallMs.toStringAsFixed(2),
                        unit: 'ms',
                        icon: Icons.play_arrow,
                        color: Colors.green,
                        progress: metrics.generateCallMs / 3000,
                      ),
                      MetricCard(
                        title: 'Generation Speed',
                        value: metrics.generationSpeedTps.toStringAsFixed(2),
                        unit: 't/s',
                        icon: Icons.speed,
                        color: Colors.orange,
                        progress: metrics.generationSpeedTps / 20,
                      ),
                      MetricCard(
                        title: 'Token Latency',
                        value: metrics.tokenLatencyMs.toStringAsFixed(2),
                        unit: 'ms',
                        icon: Icons.access_time,
                        color: Colors.purple,
                        progress: metrics.tokenLatencyMs / 200,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Native metrics
                  NativeMetricsCard(metrics: metrics),
                  const SizedBox(height: 16),

                  // Performance chart
                  PerformanceChart(
                    history: history,
                    metricType: selectedMetric,
                  ),
                  const SizedBox(height: 8),

                  // Chart controls
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildChartChip(
                            'Token Latency', 'tokenLatencyMs', selectedMetric),
                        _buildChartChip('Generation Speed',
                            'generationSpeedTps', selectedMetric),
                        _buildChartChip(
                            'Decode Time', 'nativeDecodeMs', selectedMetric),
                        _buildChartChip(
                            'Load Time', 'nativeLoadMs', selectedMetric),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Additional details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Additional Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _buildDetailChip(
                              'Context',
                              '${metrics.contextSize}',
                              Icons.aspect_ratio,
                            ),
                            _buildDetailChip(
                              'Batch',
                              '${metrics.batchSize}',
                              Icons.view_agenda,
                            ),
                            _buildDetailChip(
                              'SWA Full',
                              metrics.swaFull ? 'Yes' : 'No',
                              Icons.swap_horiz,
                            ),
                            _buildDetailChip(
                              'CPU Fallback',
                              metrics.cpuFallback ? 'Yes' : 'No',
                              Icons.warning,
                            ),
                            _buildDetailChip(
                              'Prompt Tokens',
                              '${metrics.promptTokens}',
                              Icons.input,
                            ),
                            _buildDetailChip(
                              'Sampled/Decoded',
                              '${metrics.sampledTokens}/${metrics.decodedTokens}',
                              Icons.data_usage,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildChartChip(String label, String value, String selected) {
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (_) {
          ref.read(selectedMetricProvider.notifier).state = value;
        },
        backgroundColor: Colors.grey[100],
        selectedColor: Colors.blue[100],
        checkmarkColor: Colors.blue,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildDetailChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && ref.read(autoRefreshProvider)) {
        ref.read(updateMetricsProvider);
        _startAutoRefresh();
      }
    });
  }
}
