/// Open application identity and capability descriptor for Alhambra adopters.
///
/// Unlike a closed product-category enum, this model lets any host application
/// describe its own identity and the capabilities it exposes. Values are
/// intentionally string-based so extensions can introduce capabilities
/// without changing Alhambra's core API.
///
/// This is the preferred application descriptor for new integrations. The
/// legacy [AppKind] layout hint remains available during the migration period.
class ApplicationProfile {
  final String applicationId;
  final Set<String> capabilities;
  final Set<String> layoutHints;
  final Map<String, Object?> metadata;

  const ApplicationProfile({
    required this.applicationId,
    this.capabilities = const <String>{},
    this.layoutHints = const <String>{},
    this.metadata = const <String, Object?>{},
  });

  bool hasCapability(String capability) => capabilities.contains(capability);

  bool hasAllCapabilities(Iterable<String> required) =>
      capabilities.containsAll(required);

  bool hasAnyLayoutHint(Iterable<String> hints) =>
      hints.any(layoutHints.contains);

  ApplicationProfile copyWith({
    String? applicationId,
    Set<String>? capabilities,
    Set<String>? layoutHints,
    Map<String, Object?>? metadata,
  }) =>
      ApplicationProfile(
        applicationId: applicationId ?? this.applicationId,
        capabilities: capabilities ?? this.capabilities,
        layoutHints: layoutHints ?? this.layoutHints,
        metadata: metadata ?? this.metadata,
      );
}

/// Capability requirements and non-binding hints for a layout contribution.
///
/// Required capabilities are a hard compatibility constraint. Preferred
/// hints are advisory and must never be used as an authorization boundary.
class LayoutProfileRequirements {
  final Set<String> requiredCapabilities;
  final Set<String> preferredHints;

  const LayoutProfileRequirements({
    this.requiredCapabilities = const <String>{},
    this.preferredHints = const <String>{},
  });

  bool isCompatibleWith(ApplicationProfile profile) =>
      profile.hasAllCapabilities(requiredCapabilities);

  int preferenceScore(ApplicationProfile profile) =>
      preferredHints.intersection(profile.layoutHints).length;
}
