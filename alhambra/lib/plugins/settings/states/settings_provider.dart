import 'package:flutter_riverpod/legacy.dart';
import 'package:objectbox/objectbox.dart';

import '../../../objectbox.g.dart';
import '../../../services/objectbox/object_store.dart';
import '../../../utils/logger.dart';
import '../models/app_settings_entity.dart';

// ── Public immutable view model ────────────────────────────────────────────
class AppSettings {
  // Appearance
  final String themeMode;
  final String conversationWidth;
  final String lightThemePreset;
  final String darkThemePreset;
  final bool verboseAgentChat;
  final double fontSize;

  // AI Provider
  final String aiProvider;
  final String apiKey;
  final String andalusProBaseUrl;
  final String andalusProGrpcUrl;
  final String openAiBaseUrl;
  final String anthropicBaseUrl;
  final String geminiBaseUrl;
  final String defaultModel;
  final String systemPrompt;
  final bool streamingEnabled;
  final int maxTokens;
  final double temperature;
  final bool autoSelectModel;

  // Local LLM
  final String localLlmBackend;
  final String localModelPath;
  final String localModelName;
  final int localContextSize;
  final int localGpuLayers;
  final int localThreads;
  final String ollamaBaseUrl;
  final bool localEnableGpu;

  // Agent & Security
  final String securityPreset;
  final String outsideFolderFileAccess;
  final String terminalExecutionPolicy;
  final bool sandboxMode;
  final String artifactReviewPolicy;
  final String fileAccessRulesJson;
  final String networkAccessRulesJson;
  final String terminalCommandsJson;
  final String mcpToolsJson;

  // Browser
  final String jsExecutionPolicy;
  final int browserViewportWidth;
  final int browserViewportHeight;
  final String downloadPath;
  final bool screenshotEnabled;
  final String actuationRulesJson;

  // Notifications
  final bool desktopNotifications;
  final bool soundEffects;
  final bool taskCompletionAlert;
  final bool errorAlert;

  // Privacy
  final bool telemetryEnabled;
  final bool crashReporting;
  final bool analyticsEnabled;

  // Advanced
  final String logLevel;
  final bool autoSave;
  final int autoSaveIntervalSeconds;
  final bool experimentalFeatures;
  final String proxyUrl;
  final String noProxyHosts;
  final bool sslVerification;

  const AppSettings({
    this.themeMode = 'dark',
    this.conversationWidth = 'default',
    this.lightThemePreset = 'defaultLight',
    this.darkThemePreset = 'defaultDark',
    this.verboseAgentChat = true,
    this.fontSize = 14.0,
    this.aiProvider = 'andalusPro',
    this.apiKey = '',
    this.andalusProBaseUrl = 'http://127.0.0.1:8086',
    this.andalusProGrpcUrl = '127.0.0.1:9000',
    this.openAiBaseUrl = 'https://api.openai.com/v1',
    this.anthropicBaseUrl = 'https://api.anthropic.com',
    this.geminiBaseUrl = 'https://generativelanguage.googleapis.com',
    this.defaultModel = '',
    this.systemPrompt = '',
    this.streamingEnabled = true,
    this.maxTokens = 8192,
    this.temperature = 0.7,
    this.autoSelectModel = true,
    this.localLlmBackend = 'gguf',
    this.localModelPath = '',
    this.localModelName = '',
    this.localContextSize = 4096,
    this.localGpuLayers = -1,
    this.localThreads = 0,
    this.ollamaBaseUrl = 'http://localhost:11434',
    this.localEnableGpu = true,
    this.securityPreset = 'standard',
    this.outsideFolderFileAccess = 'alwaysAsk',
    this.terminalExecutionPolicy = 'requireReview',
    this.sandboxMode = false,
    this.artifactReviewPolicy = 'alwaysAsk',
    this.fileAccessRulesJson = '[]',
    this.networkAccessRulesJson = '[]',
    this.terminalCommandsJson = '[]',
    this.mcpToolsJson = '[]',
    this.jsExecutionPolicy = 'requestReview',
    this.browserViewportWidth = 1280,
    this.browserViewportHeight = 800,
    this.downloadPath = '',
    this.screenshotEnabled = true,
    this.actuationRulesJson = '[]',
    this.desktopNotifications = true,
    this.soundEffects = false,
    this.taskCompletionAlert = true,
    this.errorAlert = true,
    this.telemetryEnabled = false,
    this.crashReporting = false,
    this.analyticsEnabled = false,
    this.logLevel = 'info',
    this.autoSave = true,
    this.autoSaveIntervalSeconds = 30,
    this.experimentalFeatures = false,
    this.proxyUrl = '',
    this.noProxyHosts = '',
    this.sslVerification = true,
  });

  AppSettings copyWith({
    String? themeMode,
    String? conversationWidth,
    String? lightThemePreset,
    String? darkThemePreset,
    bool? verboseAgentChat,
    double? fontSize,
    String? aiProvider,
    String? apiKey,
    String? andalusProBaseUrl,
    String? andalusProGrpcUrl,
    String? openAiBaseUrl,
    String? anthropicBaseUrl,
    String? geminiBaseUrl,
    String? defaultModel,
    String? systemPrompt,
    bool? streamingEnabled,
    int? maxTokens,
    double? temperature,
    bool? autoSelectModel,
    String? localLlmBackend,
    String? localModelPath,
    String? localModelName,
    int? localContextSize,
    int? localGpuLayers,
    int? localThreads,
    String? ollamaBaseUrl,
    bool? localEnableGpu,
    String? securityPreset,
    String? outsideFolderFileAccess,
    String? terminalExecutionPolicy,
    bool? sandboxMode,
    String? artifactReviewPolicy,
    String? fileAccessRulesJson,
    String? networkAccessRulesJson,
    String? terminalCommandsJson,
    String? mcpToolsJson,
    String? jsExecutionPolicy,
    int? browserViewportWidth,
    int? browserViewportHeight,
    String? downloadPath,
    bool? screenshotEnabled,
    String? actuationRulesJson,
    bool? desktopNotifications,
    bool? soundEffects,
    bool? taskCompletionAlert,
    bool? errorAlert,
    bool? telemetryEnabled,
    bool? crashReporting,
    bool? analyticsEnabled,
    String? logLevel,
    bool? autoSave,
    int? autoSaveIntervalSeconds,
    bool? experimentalFeatures,
    String? proxyUrl,
    String? noProxyHosts,
    bool? sslVerification,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      conversationWidth: conversationWidth ?? this.conversationWidth,
      lightThemePreset: lightThemePreset ?? this.lightThemePreset,
      darkThemePreset: darkThemePreset ?? this.darkThemePreset,
      verboseAgentChat: verboseAgentChat ?? this.verboseAgentChat,
      fontSize: fontSize ?? this.fontSize,
      aiProvider: aiProvider ?? this.aiProvider,
      apiKey: apiKey ?? this.apiKey,
      andalusProBaseUrl: andalusProBaseUrl ?? this.andalusProBaseUrl,
      andalusProGrpcUrl: andalusProGrpcUrl ?? this.andalusProGrpcUrl,
      openAiBaseUrl: openAiBaseUrl ?? this.openAiBaseUrl,
      anthropicBaseUrl: anthropicBaseUrl ?? this.anthropicBaseUrl,
      geminiBaseUrl: geminiBaseUrl ?? this.geminiBaseUrl,
      defaultModel: defaultModel ?? this.defaultModel,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      streamingEnabled: streamingEnabled ?? this.streamingEnabled,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      autoSelectModel: autoSelectModel ?? this.autoSelectModel,
      localLlmBackend: localLlmBackend ?? this.localLlmBackend,
      localModelPath: localModelPath ?? this.localModelPath,
      localModelName: localModelName ?? this.localModelName,
      localContextSize: localContextSize ?? this.localContextSize,
      localGpuLayers: localGpuLayers ?? this.localGpuLayers,
      localThreads: localThreads ?? this.localThreads,
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      localEnableGpu: localEnableGpu ?? this.localEnableGpu,
      securityPreset: securityPreset ?? this.securityPreset,
      outsideFolderFileAccess:
          outsideFolderFileAccess ?? this.outsideFolderFileAccess,
      terminalExecutionPolicy:
          terminalExecutionPolicy ?? this.terminalExecutionPolicy,
      sandboxMode: sandboxMode ?? this.sandboxMode,
      artifactReviewPolicy: artifactReviewPolicy ?? this.artifactReviewPolicy,
      fileAccessRulesJson: fileAccessRulesJson ?? this.fileAccessRulesJson,
      networkAccessRulesJson:
          networkAccessRulesJson ?? this.networkAccessRulesJson,
      terminalCommandsJson: terminalCommandsJson ?? this.terminalCommandsJson,
      mcpToolsJson: mcpToolsJson ?? this.mcpToolsJson,
      jsExecutionPolicy: jsExecutionPolicy ?? this.jsExecutionPolicy,
      browserViewportWidth: browserViewportWidth ?? this.browserViewportWidth,
      browserViewportHeight:
          browserViewportHeight ?? this.browserViewportHeight,
      downloadPath: downloadPath ?? this.downloadPath,
      screenshotEnabled: screenshotEnabled ?? this.screenshotEnabled,
      actuationRulesJson: actuationRulesJson ?? this.actuationRulesJson,
      desktopNotifications: desktopNotifications ?? this.desktopNotifications,
      soundEffects: soundEffects ?? this.soundEffects,
      taskCompletionAlert: taskCompletionAlert ?? this.taskCompletionAlert,
      errorAlert: errorAlert ?? this.errorAlert,
      telemetryEnabled: telemetryEnabled ?? this.telemetryEnabled,
      crashReporting: crashReporting ?? this.crashReporting,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      logLevel: logLevel ?? this.logLevel,
      autoSave: autoSave ?? this.autoSave,
      autoSaveIntervalSeconds:
          autoSaveIntervalSeconds ?? this.autoSaveIntervalSeconds,
      experimentalFeatures: experimentalFeatures ?? this.experimentalFeatures,
      proxyUrl: proxyUrl ?? this.proxyUrl,
      noProxyHosts: noProxyHosts ?? this.noProxyHosts,
      sslVerification: sslVerification ?? this.sslVerification,
    );
  }

  // Convert from Entity
  factory AppSettings.fromEntity(AppSettingsEntity e) => AppSettings(
        themeMode: e.themeMode,
        conversationWidth: e.conversationWidth,
        lightThemePreset: e.lightThemePreset,
        darkThemePreset: e.darkThemePreset,
        verboseAgentChat: e.verboseAgentChat,
        fontSize: e.fontSize,
        aiProvider: e.aiProvider,
        apiKey: e.apiKey,
        andalusProBaseUrl: e.andalusProBaseUrl,
        andalusProGrpcUrl: e.andalusProGrpcUrl,
        openAiBaseUrl: e.openAiBaseUrl,
        anthropicBaseUrl: e.anthropicBaseUrl,
        geminiBaseUrl: e.geminiBaseUrl,
        defaultModel: e.defaultModel,
        systemPrompt: e.systemPrompt,
        streamingEnabled: e.streamingEnabled,
        maxTokens: e.maxTokens,
        temperature: e.temperature,
        autoSelectModel: e.autoSelectModel,
        localLlmBackend: e.localLlmBackend,
        localModelPath: e.localModelPath,
        localModelName: e.localModelName,
        localContextSize: e.localContextSize,
        localGpuLayers: e.localGpuLayers,
        localThreads: e.localThreads,
        ollamaBaseUrl: e.ollamaBaseUrl,
        localEnableGpu: e.localEnableGpu,
        securityPreset: e.securityPreset,
        outsideFolderFileAccess: e.outsideFolderFileAccess,
        terminalExecutionPolicy: e.terminalExecutionPolicy,
        sandboxMode: e.sandboxMode,
        artifactReviewPolicy: e.artifactReviewPolicy,
        fileAccessRulesJson: e.fileAccessRulesJson,
        networkAccessRulesJson: e.networkAccessRulesJson,
        terminalCommandsJson: e.terminalCommandsJson,
        mcpToolsJson: e.mcpToolsJson,
        jsExecutionPolicy: e.jsExecutionPolicy,
        browserViewportWidth: e.browserViewportWidth,
        browserViewportHeight: e.browserViewportHeight,
        downloadPath: e.downloadPath,
        screenshotEnabled: e.screenshotEnabled,
        actuationRulesJson: e.actuationRulesJson,
        desktopNotifications: e.desktopNotifications,
        soundEffects: e.soundEffects,
        taskCompletionAlert: e.taskCompletionAlert,
        errorAlert: e.errorAlert,
        telemetryEnabled: e.telemetryEnabled,
        crashReporting: e.crashReporting,
        analyticsEnabled: e.analyticsEnabled,
        logLevel: e.logLevel,
        autoSave: e.autoSave,
        autoSaveIntervalSeconds: e.autoSaveIntervalSeconds,
        experimentalFeatures: e.experimentalFeatures,
        proxyUrl: e.proxyUrl,
        noProxyHosts: e.noProxyHosts,
        sslVerification: e.sslVerification,
      );

  // Apply to Entity
  void applyToEntity(AppSettingsEntity e) {
    e.themeMode = themeMode;
    e.conversationWidth = conversationWidth;
    e.lightThemePreset = lightThemePreset;
    e.darkThemePreset = darkThemePreset;
    e.verboseAgentChat = verboseAgentChat;
    e.fontSize = fontSize;
    e.aiProvider = aiProvider;
    e.apiKey = apiKey;
    e.andalusProBaseUrl = andalusProBaseUrl;
    e.andalusProGrpcUrl = andalusProGrpcUrl;
    e.openAiBaseUrl = openAiBaseUrl;
    e.anthropicBaseUrl = anthropicBaseUrl;
    e.geminiBaseUrl = geminiBaseUrl;
    e.defaultModel = defaultModel;
    e.systemPrompt = systemPrompt;
    e.streamingEnabled = streamingEnabled;
    e.maxTokens = maxTokens;
    e.temperature = temperature;
    e.autoSelectModel = autoSelectModel;
    e.localLlmBackend = localLlmBackend;
    e.localModelPath = localModelPath;
    e.localModelName = localModelName;
    e.localContextSize = localContextSize;
    e.localGpuLayers = localGpuLayers;
    e.localThreads = localThreads;
    e.ollamaBaseUrl = ollamaBaseUrl;
    e.localEnableGpu = localEnableGpu;
    e.securityPreset = securityPreset;
    e.outsideFolderFileAccess = outsideFolderFileAccess;
    e.terminalExecutionPolicy = terminalExecutionPolicy;
    e.sandboxMode = sandboxMode;
    e.artifactReviewPolicy = artifactReviewPolicy;
    e.fileAccessRulesJson = fileAccessRulesJson;
    e.networkAccessRulesJson = networkAccessRulesJson;
    e.terminalCommandsJson = terminalCommandsJson;
    e.mcpToolsJson = mcpToolsJson;
    e.jsExecutionPolicy = jsExecutionPolicy;
    e.browserViewportWidth = browserViewportWidth;
    e.browserViewportHeight = browserViewportHeight;
    e.downloadPath = downloadPath;
    e.screenshotEnabled = screenshotEnabled;
    e.actuationRulesJson = actuationRulesJson;
    e.desktopNotifications = desktopNotifications;
    e.soundEffects = soundEffects;
    e.taskCompletionAlert = taskCompletionAlert;
    e.errorAlert = errorAlert;
    e.telemetryEnabled = telemetryEnabled;
    e.crashReporting = crashReporting;
    e.analyticsEnabled = analyticsEnabled;
    e.logLevel = logLevel;
    e.autoSave = autoSave;
    e.autoSaveIntervalSeconds = autoSaveIntervalSeconds;
    e.experimentalFeatures = experimentalFeatures;
    e.proxyUrl = proxyUrl;
    e.noProxyHosts = noProxyHosts;
    e.sslVerification = sslVerification;
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Box<AppSettingsEntity>? get _box {
    try {
      return ObjectBoxStore().store.box<AppSettingsEntity>();
    } catch (_) {
      return null;
    }
  }

  void _load() {
    try {
      final box = _box;
      if (box == null) return;
      final existing = box.getAll();
      if (existing.isNotEmpty) {
        state = AppSettings.fromEntity(existing.first);
        logDebug('Settings loaded from ObjectBox');
      }
    } catch (e) {
      logDebug('Settings load error: $e');
    }
  }

  Future<void> _save() async {
    try {
      final box = _box;
      if (box == null) return;
      final existing = box.getAll();
      final entity = existing.isNotEmpty ? existing.first : AppSettingsEntity();
      state.applyToEntity(entity);
      box.put(entity);
    } catch (e) {
      logDebug('Settings save error: $e');
    }
  }

  Future<void> update(AppSettings Function(AppSettings) updater) async {
    state = updater(state);
    await _save();
  }

  // Convenience helpers
  Future<void> setThemeMode(String v) =>
      update((s) => s.copyWith(themeMode: v));
  Future<void> setConversationWidth(String v) =>
      update((s) => s.copyWith(conversationWidth: v));
  Future<void> setLightThemePreset(String v) =>
      update((s) => s.copyWith(lightThemePreset: v));
  Future<void> setDarkThemePreset(String v) =>
      update((s) => s.copyWith(darkThemePreset: v));
  Future<void> setVerboseAgentChat(bool v) =>
      update((s) => s.copyWith(verboseAgentChat: v));
  Future<void> setFontSize(double v) => update((s) => s.copyWith(fontSize: v));
  Future<void> setAiProvider(String v) =>
      update((s) => s.copyWith(aiProvider: v));
  Future<void> setApiKey(String v) => update((s) => s.copyWith(apiKey: v));
  Future<void> setAndalusProBaseUrl(String v) =>
      update((s) => s.copyWith(andalusProBaseUrl: v));
  Future<void> setAndalusProGrpcUrl(String v) =>
      update((s) => s.copyWith(andalusProGrpcUrl: v));
  Future<void> setOpenAiBaseUrl(String v) =>
      update((s) => s.copyWith(openAiBaseUrl: v));
  Future<void> setAnthropicBaseUrl(String v) =>
      update((s) => s.copyWith(anthropicBaseUrl: v));
  Future<void> setGeminiBaseUrl(String v) =>
      update((s) => s.copyWith(geminiBaseUrl: v));
  Future<void> setDefaultModel(String v) =>
      update((s) => s.copyWith(defaultModel: v));
  Future<void> setSystemPrompt(String v) =>
      update((s) => s.copyWith(systemPrompt: v));
  Future<void> setStreamingEnabled(bool v) =>
      update((s) => s.copyWith(streamingEnabled: v));
  Future<void> setMaxTokens(int v) => update((s) => s.copyWith(maxTokens: v));
  Future<void> setTemperature(double v) =>
      update((s) => s.copyWith(temperature: v));
  Future<void> setAutoSelectModel(bool v) =>
      update((s) => s.copyWith(autoSelectModel: v));
  Future<void> setLocalLlmBackend(String v) =>
      update((s) => s.copyWith(localLlmBackend: v));
  Future<void> setLocalModelPath(String v) =>
      update((s) => s.copyWith(localModelPath: v));
  Future<void> setLocalModelName(String v) =>
      update((s) => s.copyWith(localModelName: v));
  Future<void> setLocalContextSize(int v) =>
      update((s) => s.copyWith(localContextSize: v));
  Future<void> setLocalGpuLayers(int v) =>
      update((s) => s.copyWith(localGpuLayers: v));
  Future<void> setLocalThreads(int v) =>
      update((s) => s.copyWith(localThreads: v));
  Future<void> setOllamaBaseUrl(String v) =>
      update((s) => s.copyWith(ollamaBaseUrl: v));
  Future<void> setLocalEnableGpu(bool v) =>
      update((s) => s.copyWith(localEnableGpu: v));
  Future<void> setSecurityPreset(String v) =>
      update((s) => s.copyWith(securityPreset: v));
  Future<void> setOutsideFolderFileAccess(String v) =>
      update((s) => s.copyWith(outsideFolderFileAccess: v));
  Future<void> setTerminalExecutionPolicy(String v) =>
      update((s) => s.copyWith(terminalExecutionPolicy: v));
  Future<void> setSandboxMode(bool v) =>
      update((s) => s.copyWith(sandboxMode: v));
  Future<void> setArtifactReviewPolicy(String v) =>
      update((s) => s.copyWith(artifactReviewPolicy: v));
  Future<void> setJsExecutionPolicy(String v) =>
      update((s) => s.copyWith(jsExecutionPolicy: v));
  Future<void> setBrowserViewportWidth(int v) =>
      update((s) => s.copyWith(browserViewportWidth: v));
  Future<void> setBrowserViewportHeight(int v) =>
      update((s) => s.copyWith(browserViewportHeight: v));
  Future<void> setDownloadPath(String v) =>
      update((s) => s.copyWith(downloadPath: v));
  Future<void> setScreenshotEnabled(bool v) =>
      update((s) => s.copyWith(screenshotEnabled: v));
  Future<void> setDesktopNotifications(bool v) =>
      update((s) => s.copyWith(desktopNotifications: v));
  Future<void> setSoundEffects(bool v) =>
      update((s) => s.copyWith(soundEffects: v));
  Future<void> setTaskCompletionAlert(bool v) =>
      update((s) => s.copyWith(taskCompletionAlert: v));
  Future<void> setErrorAlert(bool v) =>
      update((s) => s.copyWith(errorAlert: v));
  Future<void> setTelemetryEnabled(bool v) =>
      update((s) => s.copyWith(telemetryEnabled: v));
  Future<void> setCrashReporting(bool v) =>
      update((s) => s.copyWith(crashReporting: v));
  Future<void> setAnalyticsEnabled(bool v) =>
      update((s) => s.copyWith(analyticsEnabled: v));
  Future<void> setLogLevel(String v) => update((s) => s.copyWith(logLevel: v));
  Future<void> setAutoSave(bool v) => update((s) => s.copyWith(autoSave: v));
  Future<void> setAutoSaveIntervalSeconds(int v) =>
      update((s) => s.copyWith(autoSaveIntervalSeconds: v));
  Future<void> setExperimentalFeatures(bool v) =>
      update((s) => s.copyWith(experimentalFeatures: v));
  Future<void> setProxyUrl(String v) => update((s) => s.copyWith(proxyUrl: v));
  Future<void> setNoProxyHosts(String v) =>
      update((s) => s.copyWith(noProxyHosts: v));
  Future<void> setSslVerification(bool v) =>
      update((s) => s.copyWith(sslVerification: v));

  Future<void> resetToDefaults() async {
    state = const AppSettings();
    await _save();
  }
}

// ── Provider ───────────────────────────────────────────────────────────────
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);
