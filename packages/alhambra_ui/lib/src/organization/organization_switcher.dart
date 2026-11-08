import 'package:flutter/material.dart';
import 'organization_context.dart';

/// Dropdown widget that shows the active organization name and lets the user
/// switch between memberships.
///
/// Requires an [OrganizationNotifier] passed via [notifier].
/// On selection, calls [notifier.switchTo] and optionally invokes [onSwitch].
///
/// ```dart
/// OrganizationSwitcher(
///   notifier: orgNotifier,
///   onSwitch: (ctx) => router.go('/home'),
/// )
/// ```
class OrganizationSwitcher extends StatelessWidget {
  final OrganizationNotifier notifier;
  final void Function(OrganizationContext ctx)? onSwitch;

  const OrganizationSwitcher({
    super.key,
    required this.notifier,
    this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final current = notifier.current;
        final memberships = notifier.memberships;

        if (memberships.isEmpty) {
          return const SizedBox.shrink();
        }

        return PopupMenuButton<String>(
          tooltip: 'Switch organization',
          offset: const Offset(0, 40),
          onSelected: (orgId) {
            final switched = notifier.switchTo(orgId);
            if (switched && notifier.current != null) {
              onSwitch?.call(notifier.current!);
            }
          },
          itemBuilder: (_) => memberships
              .map(
                (m) => PopupMenuItem<String>(
                  value: m.organizationId,
                  child: Row(
                    children: [
                      if (current?.organizationId == m.organizationId)
                        const Icon(Icons.check, size: 16)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.organizationName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          child: Semantics(
            label: 'Organization: ${current?.organizationName ?? 'None'}',
            button: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  current?.organizationName ?? 'Select organization',
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
