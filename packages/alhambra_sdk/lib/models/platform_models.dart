enum ProcessState { stopped, starting, running, error }

class PlatformEnvironment {
  final String os;
  final String arch;
  final String userHome;
  final String appDataDir;

  const PlatformEnvironment({
    required this.os,
    required this.arch,
    required this.userHome,
    required this.appDataDir,
  });
}

class BackendBinaryInfo {
  final String name;
  final String version;
  final String localPath;
  final bool isInstalled;

  const BackendBinaryInfo({
    required this.name,
    required this.version,
    required this.localPath,
    this.isInstalled = false,
  });
}
