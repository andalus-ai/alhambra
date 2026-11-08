import '../capabilities/capabilities_models.dart';
import '../plugins/plugin_sdk_contracts.dart';

/// Semantic version representation: major.minor.patch[-prerelease].
final class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;

  const SemanticVersion(
    this.major,
    this.minor,
    this.patch, [
    this.prerelease = const [],
  ]);

  static SemanticVersion parse(String text) {
    final clean = text.trim();
    final preIndex = clean.indexOf('-');
    String mainPart = preIndex != -1 ? clean.substring(0, preIndex) : clean;
    List<String> preParts = preIndex != -1
        ? clean.substring(preIndex + 1).split('.').where((s) => s.isNotEmpty).toList()
        : const [];

    final segments = mainPart.split('.');
    if (segments.length < 3) {
      throw FormatException('Invalid semantic version: $text');
    }
    final maj = int.parse(segments[0]);
    final min = int.parse(segments[1]);
    final pat = int.parse(segments[2]);
    return SemanticVersion(maj, min, pat, preParts);
  }

  static SemanticVersion? tryParse(String text) {
    try {
      return parse(text);
    } catch (_) {
      return null;
    }
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (prerelease.isEmpty && other.prerelease.isNotEmpty) return 1;
    if (prerelease.isNotEmpty && other.prerelease.isEmpty) return -1;
    return prerelease.join('.').compareTo(other.prerelease.join('.'));
  }

  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;
  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator <(SemanticVersion other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          prerelease.join('.') == other.prerelease.join('.');

  @override
  int get hashCode => Object.hash(major, minor, patch, prerelease.join('.'));

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    if (prerelease.isNotEmpty) return '$base-${prerelease.join('.')}';
    return base;
  }
}

/// Abstract version constraint.
abstract interface class VersionConstraint {
  bool matches(SemanticVersion version);
  static VersionConstraint parse(String expr) {
    final clean = expr.trim();
    if (clean == '*' || clean == 'any') return const WildcardVersionConstraint();
    if (clean.startsWith('^')) {
      final base = SemanticVersion.parse(clean.substring(1));
      return CaretVersionConstraint(base);
    }
    if (clean.startsWith('>=')) {
      final base = SemanticVersion.parse(clean.substring(2));
      return RangeVersionConstraint(min: base, includeMin: true);
    }
    final exact = SemanticVersion.tryParse(clean);
    if (exact != null) return ExactVersionConstraint(exact);
    return const WildcardVersionConstraint();
  }
}

final class WildcardVersionConstraint implements VersionConstraint {
  const WildcardVersionConstraint();
  @override
  bool matches(SemanticVersion version) => true;
  @override
  String toString() => '*';
}

final class ExactVersionConstraint implements VersionConstraint {
  final SemanticVersion expected;
  const ExactVersionConstraint(this.expected);
  @override
  bool matches(SemanticVersion version) => version == expected;
  @override
  String toString() => expected.toString();
}

final class RangeVersionConstraint implements VersionConstraint {
  final SemanticVersion? min;
  final SemanticVersion? max;
  final bool includeMin;
  final bool includeMax;

  const RangeVersionConstraint({
    this.min,
    this.max,
    this.includeMin = true,
    this.includeMax = false,
  });

  @override
  bool matches(SemanticVersion version) {
    if (min != null) {
      final comp = version.compareTo(min!);
      if (includeMin && comp < 0) return false;
      if (!includeMin && comp <= 0) return false;
    }
    if (max != null) {
      final comp = version.compareTo(max!);
      if (includeMax && comp > 0) return false;
      if (!includeMax && comp >= 0) return false;
    }
    return true;
  }

  @override
  String toString() => '>=${min ?? '0.0.0'} <${max ?? 'infinity'}';
}

final class CaretVersionConstraint implements VersionConstraint {
  final SemanticVersion base;
  const CaretVersionConstraint(this.base);

  @override
  bool matches(SemanticVersion version) {
    if (version < base) return false;
    if (base.major > 0) {
      return version.major == base.major;
    } else if (base.minor > 0) {
      return version.major == 0 && version.minor == base.minor;
    } else {
      return version.major == 0 && version.minor == 0 && version.patch == base.patch;
    }
  }

  @override
  String toString() => '^$base';
}

/// Dependency declared by a plugin.
final class PluginDependency {
  final PluginId id;
  final VersionConstraint version;
  final bool optional;

  const PluginDependency({
    required this.id,
    required this.version,
    this.optional = false,
  });
}

/// Host API compatibility constraints.
final class HostApiConstraint {
  final SemanticVersion min;
  final SemanticVersion? max;

  const HostApiConstraint({
    required this.min,
    this.max,
  });

  bool isCompatible(SemanticVersion hostVersion) {
    if (hostVersion < min) return false;
    if (max != null && hostVersion >= max!) return false;
    return true;
  }
}

/// Edition requirements.
final class EditionConstraint {
  final String minimumEdition;
  const EditionConstraint({this.minimumEdition = 'community'});
}

/// Supported operating systems.
final class PlatformConstraint {
  final List<String> supportedPlatforms;
  const PlatformConstraint({this.supportedPlatforms = const ['macos', 'linux', 'windows']});

  bool supports(String platform) =>
      supportedPlatforms.contains(platform.toLowerCase());
}

/// Origin source of a plugin.
enum PluginSource {
  bundled,
  user,
  workspace,
  managed,
  development,
}

/// Complete declarative metadata for a plugin package.
final class PluginPackageManifest {
  final PluginId id;
  final String name;
  final SemanticVersion version;
  final HostApiConstraint hostApi;
  final List<PluginDependency> dependencies;
  final List<PluginDependency> optionalDependencies;
  final List<CapabilityRequest> capabilities;
  final EditionConstraint? edition;
  final PlatformConstraint? platform;
  final PluginSource source;

  const PluginPackageManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.hostApi,
    this.dependencies = const [],
    this.optionalDependencies = const [],
    this.capabilities = const [],
    this.edition,
    this.platform,
    this.source = PluginSource.user,
  });
}

/// Compatibility diagnostic issues.
final class CompatibilityIssue {
  final String code;
  final String message;
  final bool isFatal;

  const CompatibilityIssue({
    required this.code,
    required this.message,
    this.isFatal = true,
  });
}

final class CompatibilityResult {
  final bool compatible;
  final List<CompatibilityIssue> issues;

  const CompatibilityResult({
    required this.compatible,
    this.issues = const [],
  });

  const CompatibilityResult.ok()
      : compatible = true,
        issues = const [];
}

/// Locked resolved plugin state for reproducibility.
final class LockedPlugin {
  final PluginId id;
  final SemanticVersion version;
  final PluginSource source;
  final String? integrityHash;

  const LockedPlugin({
    required this.id,
    required this.version,
    required this.source,
    this.integrityHash,
  });
}

final class PluginLockfile {
  final int schemaVersion;
  final Map<String, LockedPlugin> plugins;

  const PluginLockfile({
    this.schemaVersion = 1,
    this.plugins = const {},
  });
}
