import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';
import 'license/edition.dart';

/// Configuration descriptor for customizing the agnostic Workbench Platform.
class WorkbenchPlatformConfig {
  /// The user-facing application name.
  final String appName;

  /// Edition (Community / Pro / Enterprise).
  final AlhambraEdition edition;

  /// Default workspace layout mode ID (defaults to 'default').
  final String defaultModeId;

  /// Initial workspace modes registered in the platform.
  final List<WorkspaceMode> initialModes;

  /// Domain plugin packs loaded by the platform (e.g. specialized domain packs, workflows, analytics).
  final List<AlhambraPlugin> pluginPacks;

  /// Optional custom branding header widget builder.
  final Widget Function(BuildContext context)? brandingBuilder;

  const WorkbenchPlatformConfig({
    this.appName = 'Alhambra Workbench',
    this.edition = AlhambraEdition.community,
    this.defaultModeId = 'default',
    this.initialModes = const [],
    this.pluginPacks = const [],
    this.brandingBuilder,
  });

  WorkbenchPlatformConfig copyWith({
    String? appName,
    AlhambraEdition? edition,
    String? defaultModeId,
    List<WorkspaceMode>? initialModes,
    List<AlhambraPlugin>? pluginPacks,
    Widget Function(BuildContext context)? brandingBuilder,
  }) {
    return WorkbenchPlatformConfig(
      appName: appName ?? this.appName,
      edition: edition ?? this.edition,
      defaultModeId: defaultModeId ?? this.defaultModeId,
      initialModes: initialModes ?? this.initialModes,
      pluginPacks: pluginPacks ?? this.pluginPacks,
      brandingBuilder: brandingBuilder ?? this.brandingBuilder,
    );
  }
}

/// Provider exposing the active Workbench platform configuration.
final workbenchPlatformConfigProvider = Provider<WorkbenchPlatformConfig>((ref) {
  return const WorkbenchPlatformConfig();
});
