import 'dart:async';

import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class DefaultNavigationResolver implements NavigationResolver {
  final List<RouteDefinition> _routes = [];

  @override
  void registerRoute(RouteDefinition route) {
    _routes.add(route);
    _routes.sort(
      (a, b) => b.priority.compareTo(a.priority),
    ); // Higher priority first
  }

  @override
  void unregisterRoute(RouteId id) {
    _routes.removeWhere((r) => r.id == id);
  }

  @override
  NavigationTarget? resolve(NavigationRequest request) {
    if (request.intent is OpenViewIntent) {
      final viewIntent = request.intent as OpenViewIntent;
      return NavigationTarget(
        view: viewIntent.viewId,
        mode: request.mode,
        windowId: request.windowId,
        sessionId: request.sessionId,
        parameters: viewIntent.parameters,
      );
    }

    for (final route in _routes) {
      if (route.match.matches(request.intent)) {
        return NavigationTarget(
          view: route.view,
          mode: request.mode,
          windowId: request.windowId,
          sessionId: request.sessionId,
        );
      }
    }

    return null;
  }
}

class DefaultViewInstanceManager implements ViewInstanceManager {
  final Map<String, ViewPresentationState> _presentationStates = {};
  final Map<String, ViewInstanceId> _activeInstancesByView = {};

  @override
  ViewInstanceId openInstance(
    NavigationTarget target, {
    bool isPreview = false,
  }) {
    if (target.mode == NavigationOpenMode.reuse) {
      final existing = _activeInstancesByView[target.view.value];
      if (existing != null) {
        return existing;
      }
    }

    final newInstanceId = ViewInstanceId(
      '${target.view.value}_${DateTime.now().millisecondsSinceEpoch}',
    );
    _activeInstancesByView[target.view.value] = newInstanceId;
    _presentationStates[newInstanceId.value] = ViewPresentationState(
      preview: isPreview || target.mode == NavigationOpenMode.preview,
      pinned: !isPreview && target.mode != NavigationOpenMode.preview,
    );

    return newInstanceId;
  }

  @override
  void pinInstance(ViewInstanceId id) {
    final current = _presentationStates[id.value];
    if (current != null) {
      _presentationStates[id.value] = current.copyWith(
        pinned: true,
        preview: false,
      );
    }
  }

  @override
  void closeInstance(ViewInstanceId id) {
    _presentationStates.remove(id.value);
    _activeInstancesByView.removeWhere((k, v) => v == id);
  }

  @override
  ViewPresentationState? getPresentationState(ViewInstanceId id) =>
      _presentationStates[id.value];
}

class DefaultNavigationHistory implements NavigationHistory {
  final List<NavigationHistoryEntry> _backStack = [];
  final List<NavigationHistoryEntry> _forwardStack = [];
  NavigationHistoryEntry? _current;

  @override
  NavigationHistoryEntry? get current => _current;
  @override
  bool get canGoBack => _backStack.isNotEmpty;
  @override
  bool get canGoForward => _forwardStack.isNotEmpty;

  @override
  void push(NavigationIntent intent, ViewInstanceId viewInstanceId) {
    if (_current != null) {
      _backStack.add(_current!);
    }
    _current = NavigationHistoryEntry(
      intent: intent,
      viewInstanceId: viewInstanceId,
    );
    _forwardStack.clear();
  }

  @override
  NavigationHistoryEntry? back() {
    if (!canGoBack) return null;
    if (_current != null) {
      _forwardStack.add(_current!);
    }
    _current = _backStack.removeLast();
    return _current;
  }

  @override
  NavigationHistoryEntry? forward() {
    if (!canGoForward) return null;
    if (_current != null) {
      _backStack.add(_current!);
    }
    _current = _forwardStack.removeLast();
    return _current;
  }

  @override
  void clear() {
    _backStack.clear();
    _forwardStack.clear();
    _current = null;
  }
}

class DefaultNavigationService implements NavigationService {
  final NavigationResolver resolver;
  final ViewInstanceManager instanceManager;
  final NavigationHistory history;

  DefaultNavigationService({
    NavigationResolver? resolver,
    ViewInstanceManager? instanceManager,
    NavigationHistory? history,
  }) : resolver = resolver ?? DefaultNavigationResolver(),
       instanceManager = instanceManager ?? DefaultViewInstanceManager(),
       history = history ?? DefaultNavigationHistory();

  @override
  Future<NavigationResult> navigate(NavigationRequest request) async {
    final target = resolver.resolve(request);
    if (target == null) {
      return NavigationRejected(
        'No matching route found for intent ${request.intent}',
      );
    }

    final instanceId = instanceManager.openInstance(
      target,
      isPreview: request.mode == NavigationOpenMode.preview,
    );

    history.push(request.intent, instanceId);
    return NavigationSucceeded(instanceId);
  }

  @override
  Future<NavigationResult> open(
    NavigationIntent intent, [
    NavigationOpenMode mode = NavigationOpenMode.reuse,
  ]) {
    return navigate(NavigationRequest(intent: intent, mode: mode));
  }
}
