import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import '../models/inference_metrics.dart';

class NativeMetricsAccordion extends StatefulWidget {
  final InferenceMetrics metrics;
  final bool isDark;

  const NativeMetricsAccordion({
    super.key,
    required this.metrics,
    this.isDark = false,
  });

  @override
  State<NativeMetricsAccordion> createState() => _NativeMetricsAccordionState();
}

class _NativeMetricsAccordionState extends State<NativeMetricsAccordion> {
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.7);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgColor,
            bgColor.withValues(alpha: isDark ? 0.4 : 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [DashboardTheme.secondaryPurple, DashboardTheme.accentPink],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: DashboardTheme.secondaryPurple.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.memory, size: 20, color: Colors.white),
          ),
          title: Text(
            'Native Backend Performance',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          subtitle: Text(
            '${widget.metrics.device} • ${widget.metrics.threads} threads',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  DashboardTheme.accentGreen,
                  DashboardTheme.accentGreen.withValues(alpha: 0.6)
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.metrics.backend.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  _buildMetricRow(
                    'Load Time',
                    '${widget.metrics.nativeLoadMs.toStringAsFixed(2)} ms',
                    Icons.timer,
                    Colors.orange,
                    widget.metrics.nativeLoadMs / 10000,
                  ),
                  const SizedBox(height: 8),
                  _buildMetricRow(
                    'Context Init',
                    '${widget.metrics.contextInitMs.toStringAsFixed(2)} ms',
                    Icons.settings,
                    Colors.blue,
                    widget.metrics.contextInitMs / 500,
                  ),
                  const SizedBox(height: 8),
                  _buildMetricRow(
                    'Tokenize',
                    '${widget.metrics.nativeTokenizeMs.toStringAsFixed(2)} ms',
                    Icons.text_fields,
                    widget.metrics.tokenizeMiss ? Colors.red : Colors.green,
                    widget.metrics.nativeTokenizeMs / 10,
                  ),
                  const SizedBox(height: 8),
                  _buildMetricRow(
                    'Prompt',
                    '${widget.metrics.nativePromptMs.toStringAsFixed(2)} ms',
                    Icons.input,
                    Colors.teal,
                    widget.metrics.nativePromptMs / 1000,
                  ),
                  const SizedBox(height: 8),
                  _buildMetricRow(
                    'Decode',
                    '${widget.metrics.nativeDecodeMs.toStringAsFixed(2)} ms',
                    Icons.code,
                    Colors.indigo,
                    widget.metrics.nativeDecodeMs / 5000,
                  ),
                  const SizedBox(height: 8),
                  _buildMetricRow(
                    'Sampler',
                    '${widget.metrics.samplerTimeMs.toStringAsFixed(2)} ms',
                    Icons.shuffle,
                    Colors.pink,
                    widget.metrics.samplerTimeMs / 5,
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoChip(
                          'Cache',
                          '${widget.metrics.cacheTimeMs.toStringAsFixed(2)} ms',
                          widget.metrics.cacheMode,
                          Icons.cached,
                          Colors.amber,
                        ),
                      ),
                      Expanded(
                        child: _buildInfoChip(
                          'Session',
                          widget.metrics.sessionType,
                          widget.metrics.sessionType == 'cold' ? '❄️' : '🔥',
                          Icons.power_settings_new,
                          widget.metrics.sessionType == 'cold'
                              ? Colors.blue
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoChip(
                          'Output',
                          '${widget.metrics.outputBytes} B',
                          'Buffer: ${widget.metrics.javaBufferBytes} B',
                          Icons.output,
                          Colors.cyan,
                        ),
                      ),
                      Expanded(
                        child: _buildInfoChip(
                          'Retries',
                          widget.metrics.retries.toString(),
                          widget.metrics.retries > 0 ? '⚠️' : '✅',
                          Icons.refresh,
                          widget.metrics.retries > 0
                              ? Colors.red
                              : Colors.green,
                        ),
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

  Widget _buildMetricRow(
      String label, String value, IconData icon, Color color, double progress) {
    final isDark = widget.isDark;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(
      String label, String value, String subtitle, IconData icon, Color color) {
    final isDark = widget.isDark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.08)
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? color.withValues(alpha: 0.15)
              : color.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
