enum AlhambraEdition {
  community,
  pro,
  enterprise;

  bool get isProOrHigher => this == AlhambraEdition.pro || this == AlhambraEdition.enterprise;
  bool get isEnterprise => this == AlhambraEdition.enterprise;

  String get displayName {
    switch (this) {
      case AlhambraEdition.community:
        return 'Community';
      case AlhambraEdition.pro:
        return 'Professional';
      case AlhambraEdition.enterprise:
        return 'Enterprise';
    }
  }
}
