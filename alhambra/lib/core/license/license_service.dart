import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'edition.dart';

class LicenseInfo {
  final AlhambraEdition edition;
  final String? organization;
  final String? licenseKey;
  final DateTime? expiresAt;
  final Set<String> activeFeatures;

  const LicenseInfo({
    this.edition = AlhambraEdition.community,
    this.organization,
    this.licenseKey,
    this.expiresAt,
    this.activeFeatures = const {},
  });

  bool hasFeature(String feature) => activeFeatures.contains(feature);

  LicenseInfo copyWith({
    AlhambraEdition? edition,
    String? organization,
    String? licenseKey,
    DateTime? expiresAt,
    Set<String>? activeFeatures,
  }) {
    return LicenseInfo(
      edition: edition ?? this.edition,
      organization: organization ?? this.organization,
      licenseKey: licenseKey ?? this.licenseKey,
      expiresAt: expiresAt ?? this.expiresAt,
      activeFeatures: activeFeatures ?? this.activeFeatures,
    );
  }
}

class LicenseNotifier extends Notifier<LicenseInfo> {
  @override
  LicenseInfo build() {
    return const LicenseInfo(
      edition: AlhambraEdition.pro,
      activeFeatures: {
        'alhambra.feature.governance',
        'alhambra.feature.audit',
        'alhambra.feature.analytics',
        'alhambra.feature.collaboration',
        'alhambra.feature.admin',
      },
    );
  }

  void switchEdition(AlhambraEdition edition) {
    state = state.copyWith(
      edition: edition,
      activeFeatures: edition.isProOrHigher
          ? {
              'alhambra.feature.governance',
              'alhambra.feature.audit',
              'alhambra.feature.analytics',
              'alhambra.feature.collaboration',
              'alhambra.feature.admin',
            }
          : {},
    );
  }
}

final licenseProvider = NotifierProvider<LicenseNotifier, LicenseInfo>(
  () => LicenseNotifier(),
);
