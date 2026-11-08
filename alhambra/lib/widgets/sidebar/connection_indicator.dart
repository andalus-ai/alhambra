import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/connection_provider.dart';
import '../../theme/app_colors.dart';

/// Small status row in the sidebar footer showing the (simulated)
/// connection to the agent backend. Tapping it while connected triggers
/// a brief demo reconnect cycle; tapping while offline retries.
class ConnectionIndicator extends ConsumerWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    final notifier = ref.read(connectionStatusProvider.notifier);

    final (color, label, spinning) = switch (status) {
      ConnectionStatus.connecting => (AppTheme.textMuted, 'Connecting…', true),
      ConnectionStatus.connected => (AppTheme.accentGreen, 'Connected', false),
      ConnectionStatus.reconnecting => (
          AppTheme.accentAmber,
          'Reconnecting…',
          true
        ),
      ConnectionStatus.offline => (const Color(0xFFE0554C), 'Offline', false),
    };

    return InkWell(
      onTap: status == ConnectionStatus.connected
          ? notifier.simulateHiccup
          : status == ConnectionStatus.offline
              ? notifier.retry
              : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            if (spinning)
              SizedBox(
                width: 9,
                height: 9,
                child:
                    CircularProgressIndicator(strokeWidth: 1.5, color: color),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            if (status == ConnectionStatus.offline) ...[
              const SizedBox(width: 6),
              const Text('· Retry',
                  style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      decoration: TextDecoration.underline)),
            ],
          ],
        ),
      ),
    );
  }
}
