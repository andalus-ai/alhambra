import 'package:flutter/material.dart';

import '../models/inference_metrics.dart';

class NativeMetricsCard extends StatelessWidget {
  final InferenceMetrics metrics;

  const NativeMetricsCard({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.memory, size: 20, color: Colors.purple),
              ),
              const SizedBox(width: 10),
              Text(
                'Native Backend Metrics',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  metrics.backend.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Load Time',
                  '${metrics.nativeLoadMs.toStringAsFixed(2)} ms',
                  Icons.timer,
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'Context Init',
                  '${metrics.contextInitMs.toStringAsFixed(2)} ms',
                  Icons.settings,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Tokenize',
                  '${metrics.nativeTokenizeMs.toStringAsFixed(2)} ms',
                  Icons.text_fields,
                  metrics.tokenizeMiss ? Colors.red : Colors.green,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'Prompt',
                  '${metrics.nativePromptMs.toStringAsFixed(2)} ms',
                  Icons.input,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Decode',
                  '${metrics.nativeDecodeMs.toStringAsFixed(2)} ms',
                  Icons.code,
                  Colors.indigo,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'Sampler',
                  '${metrics.samplerTimeMs.toStringAsFixed(2)} ms',
                  Icons.shuffle,
                  Colors.pink,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Cache',
                  '${metrics.cacheTimeMs.toStringAsFixed(2)} ms',
                  Icons.cached,
                  Colors.amber,
                  subtitle: metrics.cacheMode,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'Session',
                  metrics.sessionType,
                  Icons.power_settings_new,
                  metrics.sessionType == 'cold' ? Colors.blue : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Output',
                  '${metrics.outputBytes} B',
                  Icons.output,
                  Colors.cyan,
                  subtitle: 'Buffer: ${metrics.javaBufferBytes} B',
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'Retries',
                  metrics.retries.toString(),
                  Icons.refresh,
                  metrics.retries > 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    );
  }
}
