import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tenun/tenun.dart';

import 'app_theme.dart';
import '../models/inference_metrics.dart';

class PerformanceChart extends StatefulWidget {
  final List<InferenceMetrics> history;
  final String metricType;
  final bool isDark;

  const PerformanceChart({
    super.key,
    required this.history,
    required this.metricType,
    this.isDark = false,
  });

  @override
  State<PerformanceChart> createState() => _PerformanceChartState();
}

class _PerformanceChartState extends State<PerformanceChart> {
  @override
  void initState() {
    super.initState();
    // Register core chart bundles
    coreChartsBundle.register();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.history.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: widget.isDark
              ? LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.02)
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.7),
                    Colors.white.withValues(alpha: 0.4)
                  ],
                ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No historical data available',
            style: GoogleFonts.inter(
              color: widget.isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ),
      );
    }

    final chartData = _buildChartData();
    final chartConfig = _buildChartConfig(chartData);

    return Container(
      decoration: BoxDecoration(
        gradient: widget.isDark
            ? LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.white.withValues(alpha: 0.02)
                ],
              )
            : LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.7),
                  Colors.white.withValues(alpha: 0.4)
                ],
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getMetricLabel(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white : Colors.grey[800],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [DashboardTheme.primaryBlue, DashboardTheme.secondaryPurple],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.history.length} samples',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: TenunChart(
              jsonConfig: chartConfig,
              width: double.infinity,
              height: 180,
              runtimePerformancePolicy: ChartRuntimePerformancePolicy.defaults,
            ),
          ),
          const SizedBox(height: 12),
          _buildMetricStats(),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildChartData() {
    final values = widget.history.map((m) => _getMetricValue(m)).toList();
    return [
      {
        'name': _getMetricLabel(),
        'data': values,
        'color': '#6C63FF',
        'smooth': true,
        'areaStyle': {
          'color': '#6C63FF',
          'opacity': 0.2,
        },
        'lineStyle': {
          'width': 2.5,
        },
      }
    ];
  }

  Map<String, dynamic> _buildChartConfig(List<Map<String, dynamic>> series) {
    final isDark = widget.isDark;
    final textColor = isDark ? '#AAAAAA' : '#666666';
    final gridColor = isDark ? '#333333' : '#EEEEEE';

    return {
      'type': 'line',
      'tooltip': {
        'trigger': 'axis',
        'backgroundColor': isDark ? '#2A2A3E' : '#FFFFFF',
        'borderColor': isDark ? '#333355' : '#E0E0E0',
        'borderWidth': 1,
        'textStyle': {
          'color': isDark ? '#FFFFFF' : '#333333',
          'fontSize': 12,
        },
      },
      'grid': {
        'left': '3%',
        'right': '4%',
        'bottom': '3%',
        'top': '3%',
        'containLabel': true,
        'borderColor': gridColor,
      },
      'xAxis': {
        'type': 'category',
        'boundaryGap': false,
        'axisLine': {'show': false},
        'axisTick': {'show': false},
        'axisLabel': {
          'color': textColor,
          'fontSize': 10,
          'fontWeight': 'normal',
        },
        'splitLine': {
          'show': false,
        },
        'data':
            widget.history.asMap().entries.map((e) => '#${e.key + 1}').toList(),
      },
      'yAxis': {
        'type': 'value',
        'splitLine': {
          'lineStyle': {
            'color': gridColor,
            'type': 'dashed',
            'width': 1,
          },
        },
        'axisLabel': {
          'color': textColor,
          'fontSize': 10,
        },
        'name': _getYAxisLabel(),
        'nameTextStyle': {
          'color': textColor,
          'fontSize': 10,
        },
      },
      'series': series,
    };
  }

  Widget _buildMetricStats() {
    final values = widget.history.map((m) => _getMetricValue(m)).toList();
    if (values.isEmpty) return const SizedBox.shrink();

    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;
    final latest = values.last;
    final isDark = widget.isDark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatChip(
            'Latest', latest.toStringAsFixed(1), DashboardTheme.primaryBlue, isDark),
        _buildStatChip(
            'Avg', avg.toStringAsFixed(1), DashboardTheme.secondaryPurple, isDark),
        _buildStatChip(
            'Max', max.toStringAsFixed(1), DashboardTheme.accentPink, isDark),
        _buildStatChip(
            'Min', min.toStringAsFixed(1), DashboardTheme.accentGreen, isDark),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? color.withValues(alpha: 0.2)
              : color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  double _getMetricValue(InferenceMetrics m) {
    switch (widget.metricType) {
      case 'tokenLatencyMs':
        return m.tokenLatencyMs;
      case 'generationSpeedTps':
        return m.generationSpeedTps;
      case 'nativeDecodeMs':
        return m.nativeDecodeMs;
      case 'nativeLoadMs':
        return m.nativeLoadMs;
      default:
        return m.tokenLatencyMs;
    }
  }

  String _getMetricLabel() {
    switch (widget.metricType) {
      case 'tokenLatencyMs':
        return 'Token Latency (ms)';
      case 'generationSpeedTps':
        return 'Generation Speed (t/s)';
      case 'nativeDecodeMs':
        return 'Decode Time (ms)';
      case 'nativeLoadMs':
        return 'Load Time (ms)';
      default:
        return 'Metric';
    }
  }

  String _getYAxisLabel() {
    switch (widget.metricType) {
      case 'generationSpeedTps':
        return 't/s';
      default:
        return 'ms';
    }
  }
}
