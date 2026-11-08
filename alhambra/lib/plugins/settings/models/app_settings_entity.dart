import 'package:objectbox/objectbox.dart';

@Entity()
class AppSettingsEntity {
  @Id()
  int id = 0;

  // ── Appearance ────────────────────────────────────────────────
  String themeMode = 'dark'; // 'light' | 'dark' | 'system'
  String conversationWidth =
      'default'; // 'narrow' | 'default' | 'wide' | 'full'
  String lightThemePreset = 'defaultLight';
  String darkThemePreset = 'defaultDark';
  bool verboseAgentChat = true;
  double fontSize = 14.0;

  // ── AI Provider ───────────────────────────────────────────────
  String aiProvider =
      'andalusPro'; // 'andalusPro' | 'openai' | 'anthropic' | 'gemini' | 'local'
  String apiKey = '';
  String andalusProBaseUrl = 'http://127.0.0.1:8086';
  String andalusProGrpcUrl = '127.0.0.1:9000';
  String openAiBaseUrl = 'https://api.openai.com/v1';
  String anthropicBaseUrl = 'https://api.anthropic.com';
  String geminiBaseUrl = 'https://generativelanguage.googleapis.com';
  String defaultModel = '';
  String systemPrompt = '';
  bool streamingEnabled = true;
  int maxTokens = 8192;
  double temperature = 0.7;
  bool autoSelectModel = true;

  // ── Local LLM ─────────────────────────────────────────────────
  String localLlmBackend = 'gguf'; // 'gguf' | 'mlx' | 'llamacpp' | 'ollama'
  String localModelPath = '';
  String localModelName = '';
  int localContextSize = 4096;
  int localGpuLayers = -1; // -1 = auto
  int localThreads = 0; // 0 = auto
  String ollamaBaseUrl = 'http://localhost:11434';
  bool localEnableGpu = true;

  // ── Agent & Security ──────────────────────────────────────────
  String securityPreset = 'standard'; // 'custom' | 'standard' | 'strict'
  String outsideFolderFileAccess =
      'alwaysAsk'; // 'alwaysAsk' | 'allowAll' | 'denyAll' | 'allowList'
  String terminalExecutionPolicy =
      'requireReview'; // 'requireReview' | 'autoApprove' | 'autoDeny'
  bool sandboxMode = false;
  String artifactReviewPolicy =
      'alwaysAsk'; // 'alwaysAsk' | 'autoApprove' | 'autoDeny'
  // Stored as JSON strings for list data
  String fileAccessRulesJson = '[]';
  String networkAccessRulesJson = '[]';
  String terminalCommandsJson = '[]';
  String mcpToolsJson = '[]';

  // ── Browser ───────────────────────────────────────────────────
  String jsExecutionPolicy =
      'requestReview'; // 'requestReview' | 'autoApprove' | 'autoDeny'
  int browserViewportWidth = 1280;
  int browserViewportHeight = 800;
  String downloadPath = '';
  bool screenshotEnabled = true;
  String actuationRulesJson = '[]';

  // ── Notifications ─────────────────────────────────────────────
  bool desktopNotifications = true;
  bool soundEffects = false;
  bool taskCompletionAlert = true;
  bool errorAlert = true;

  // ── Privacy & Telemetry ───────────────────────────────────────
  bool telemetryEnabled = false;
  bool crashReporting = false;
  bool analyticsEnabled = false;

  // ── Advanced ──────────────────────────────────────────────────
  String logLevel = 'info'; // 'debug' | 'info' | 'warn' | 'error'
  bool autoSave = true;
  int autoSaveIntervalSeconds = 30;
  bool experimentalFeatures = false;
  String proxyUrl = '';
  String noProxyHosts = '';
  bool sslVerification = true;

  AppSettingsEntity();
}
