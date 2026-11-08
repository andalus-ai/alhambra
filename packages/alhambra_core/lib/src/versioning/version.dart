import 'package:meta/meta.dart';

/// Semantic version value type for resources, schemas, and plugins.
@immutable
final class Version implements Comparable<Version> {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;

  const Version(
    this.major,
    this.minor,
    this.patch, [
    this.preRelease,
  ]) : assert(major >= 0, 'Major must be >= 0'),
       assert(minor >= 0, 'Minor must be >= 0'),
       assert(patch >= 0, 'Patch must be >= 0');

  /// Parses a semver string (e.g. '1.2.3' or '2.0.0-rc1').
  factory Version.parse(String text) {
    final parts = text.trim().split('-');
    final mainParts = parts[0].split('.');
    if (mainParts.length != 3) {
      throw FormatException('Invalid version format: $text');
    }
    final major = int.parse(mainParts[0]);
    final minor = int.parse(mainParts[1]);
    final patch = int.parse(mainParts[2]);
    final preRelease = parts.length > 1 ? parts.sublist(1).join('-') : null;
    return Version(major, minor, patch, preRelease);
  }

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (preRelease == null && other.preRelease != null) return 1;
    if (preRelease != null && other.preRelease == null) return -1;
    if (preRelease != null && other.preRelease != null) {
      return preRelease!.compareTo(other.preRelease!);
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Version &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          preRelease == other.preRelease;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);

  @override
  String toString() => preRelease != null ? '$major.$minor.$patch-$preRelease' : '$major.$minor.$patch';
}
