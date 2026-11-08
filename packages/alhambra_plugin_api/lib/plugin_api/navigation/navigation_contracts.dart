import '../runtime_scope/runtime_scope_contracts.dart';
import '../plugins/plugin_sdk_contracts.dart';

/// Sealed hierarchy describing user/plugin intent for navigation.
sealed class NavigationIntent {
  const NavigationIntent();
}

final class OpenResourceIntent extends NavigationIntent {
  final Uri uri;
  final Map<String, Object?> parameters;

  const OpenResourceIntent(this.uri, [this.parameters = const {}]);

  @override
  String toString() => 'OpenResourceIntent($uri)';
}

final class OpenViewIntent extends NavigationIntent {
  final ViewId viewId;
  final Map<String, Object?> parameters;

  const OpenViewIntent(this.viewId, [this.parameters = const {}]);

  @override
  String toString() => 'OpenViewIntent(${viewId.value})';
}

final class OpenCommandIntent extends NavigationIntent {
  final String commandId;
  final Map<String, Object?> arguments;

  const OpenCommandIntent(this.commandId, [this.arguments = const {}]);
}

final class OpenSettingsIntent extends NavigationIntent {
  final String? section;
  const OpenSettingsIntent([this.section]);
}

final class RevealResourceIntent extends NavigationIntent {
  final Uri uri;
  const RevealResourceIntent(this.uri);
}

final class FocusViewIntent extends NavigationIntent {
  final ViewInstanceId instanceId;
  const FocusViewIntent(this.instanceId);
}

enum NavigationOpenMode {
  reuse,
  newView,
  newGroup,
  newWindow,
  detached,
  preview,
}

final class NavigationRequest {
  final NavigationIntent intent;
  final NavigationOpenMode mode;
  final WindowId? windowId;
  final WorkbenchSessionId? sessionId;

  const NavigationRequest({
    required this.intent,
    this.mode = NavigationOpenMode.reuse,
    this.windowId,
    this.sessionId,
  });
}

final class NavigationTarget {
  final ViewId view;
  final NavigationOpenMode mode;
  final WorkspaceId? workspaceId;
  final WindowId? windowId;
  final WorkbenchSessionId? sessionId;
  final Map<String, Object?> parameters;

  const NavigationTarget({
    required this.view,
    this.mode = NavigationOpenMode.reuse,
    this.workspaceId,
    this.windowId,
    this.sessionId,
    this.parameters = const {},
  });
}

abstract interface class NavigationMatch {
  bool matches(NavigationIntent intent);
}

final class RouteId {
  final String value;
  const RouteId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteId && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class RouteDefinition {
  final RouteId id;
  final ViewId view;
  final NavigationMatch match;
  final int priority;

  const RouteDefinition({
    required this.id,
    required this.view,
    required this.match,
    this.priority = 0,
  });
}

sealed class NavigationResult {
  const NavigationResult();
}

final class NavigationSucceeded extends NavigationResult {
  final ViewInstanceId viewInstanceId;
  const NavigationSucceeded(this.viewInstanceId);
}

final class NavigationCancelled extends NavigationResult {
  const NavigationCancelled();
}

final class NavigationRejected extends NavigationResult {
  final String reason;
  const NavigationRejected(this.reason);
}

final class ViewPresentationState {
  final bool pinned;
  final bool preview;

  const ViewPresentationState({
    this.pinned = false,
    this.preview = false,
  });

  ViewPresentationState copyWith({bool? pinned, bool? preview}) =>
      ViewPresentationState(
        pinned: pinned ?? this.pinned,
        preview: preview ?? this.preview,
      );
}

final class NavigationHistoryEntry {
  final NavigationIntent intent;
  final ViewInstanceId viewInstanceId;
  final DateTime timestamp;

  NavigationHistoryEntry({
    required this.intent,
    required this.viewInstanceId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

abstract interface class NavigationResolver {
  void registerRoute(RouteDefinition route);
  void unregisterRoute(RouteId id);
  NavigationTarget? resolve(NavigationRequest request);
}

abstract interface class ViewInstanceManager {
  ViewInstanceId openInstance(NavigationTarget target, {bool isPreview = false});
  void pinInstance(ViewInstanceId id);
  void closeInstance(ViewInstanceId id);
  ViewPresentationState? getPresentationState(ViewInstanceId id);
}

abstract interface class NavigationHistory {
  NavigationHistoryEntry? get current;
  bool get canGoBack;
  bool get canGoForward;
  void push(NavigationIntent intent, ViewInstanceId viewInstanceId);
  NavigationHistoryEntry? back();
  NavigationHistoryEntry? forward();
  void clear();
}

abstract interface class NavigationService {
  Future<NavigationResult> navigate(NavigationRequest request);
  Future<NavigationResult> open(NavigationIntent intent, [NavigationOpenMode mode = NavigationOpenMode.reuse]);
}

