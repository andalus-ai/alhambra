/// Application runtime environment.
enum AppEnvironment {
  development,
  staging,
  production,
  test;

  bool get isProduction => this == AppEnvironment.production;
  bool get isDevelopment => this == AppEnvironment.development;
  bool get isTest => this == AppEnvironment.test;
}
