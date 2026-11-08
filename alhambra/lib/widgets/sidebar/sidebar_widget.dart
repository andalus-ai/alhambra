import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_project/alhambra_plugin_project.dart';
import '../../theme/app_colors.dart';
import 'connection_indicator.dart';
import '../../plugins/backend_monitor/screens/backend_monitor_dialog.dart';
import '../../plugins/backend_monitor/screens/enterprise_compliance_dialog.dart';
import '../../plugins/dashboard/widgets/metric_dashboard.dart';
import '../../plugins/settings/screens/settings_dialog.dart';

/// Left rail: project switcher, new-session button, history/scheduled
/// shortcuts, pinned sessions, then a collapsible session tree per project.
class SidebarWidget extends ConsumerWidget {
  final double? width;
  const SidebarWidget({super.key, this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: width,
      color: AppTheme.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const ProjectSwitcher(),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(child: NewProjectButton()),
                SizedBox(width: 8),
                Expanded(child: NewSessionButton()),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const _SidebarNavItem(
            icon: Icons.history,
            label: 'Conversation History',
          ),
          const _SidebarNavItem(
            icon: Icons.schedule,
            label: 'Scheduled Tasks',
          ),
          const SizedBox(height: 16),
          const SidebarProjectSection(),
          const Divider(height: 1),
          const ConnectionIndicator(),
          _SidebarNavItem(
            icon: Icons.dns_rounded,
            label: 'Backend Infrastructure',
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const BackendMonitorDialog(),
              );
            },
          ),
          _SidebarNavItem(
            icon: Icons.verified_user_rounded,
            label: 'Enterprise Compliance',
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const EnterpriseComplianceDialog(),
              );
            },
          ),
          _SidebarNavItem(
            icon: Icons.bar_chart,
            label: 'Metrics Dashboard',
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const Dialog(
                  child: SizedBox(
                    width: 900,
                    height: 700,
                    child: MetricsDashboard(),
                  ),
                ),
              );
            },
          ),
          _SidebarNavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (_) => const SettingsDialog(),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _SidebarNavItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
