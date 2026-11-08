import 'package:alhambra_coding_core/alhambra_coding_core.dart';

class AgentSettings {
  final SecurityPreset securityPreset;
  final FileAccessPolicy outsideFoldersFileAccess;
  final TerminalExecutionPolicy terminalCommandAutoExecution;
  final bool enableSandboxMode;
  final ArtifactReviewPolicy artifactReviewPolicy;

  const AgentSettings({
    required this.securityPreset,
    required this.outsideFoldersFileAccess,
    required this.terminalCommandAutoExecution,
    required this.enableSandboxMode,
    required this.artifactReviewPolicy,
  });

  AgentSettings copyWith({
    SecurityPreset? securityPreset,
    FileAccessPolicy? outsideFoldersFileAccess,
    TerminalExecutionPolicy? terminalCommandAutoExecution,
    bool? enableSandboxMode,
    ArtifactReviewPolicy? artifactReviewPolicy,
  }) {
    return AgentSettings(
      securityPreset: securityPreset ?? this.securityPreset,
      outsideFoldersFileAccess:
          outsideFoldersFileAccess ?? this.outsideFoldersFileAccess,
      terminalCommandAutoExecution:
          terminalCommandAutoExecution ?? this.terminalCommandAutoExecution,
      enableSandboxMode: enableSandboxMode ?? this.enableSandboxMode,
      artifactReviewPolicy: artifactReviewPolicy ?? this.artifactReviewPolicy,
    );
  }
}
