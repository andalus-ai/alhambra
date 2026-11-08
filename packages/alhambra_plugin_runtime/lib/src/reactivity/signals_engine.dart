import 'dart:async';
import 'package:alhambra_plugin_api/alhambra_plugin_api.dart';

class MutableSignalImpl<T> implements MutableSignal<T> {
  T _value;
  final _controller = StreamController<T>.broadcast(sync: true);

  MutableSignalImpl(this._value);

  @override
  T get value => _value;

  @override
  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    _controller.add(_value);
  }

  @override
  Stream<T> get changes => _controller.stream;

  void dispose() {
    _controller.close();
  }
}

class ComputedSignalImpl<T> implements ComputedSignal<T> {
  final T Function() _compute;
  final List<Signal<dynamic>> _dependencies;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final _controller = StreamController<T>.broadcast(sync: true);
  late T _cachedValue;

  ComputedSignalImpl(this._compute, this._dependencies) {
    _cachedValue = _compute();
    for (final dep in _dependencies) {
      final sub = dep.changes.listen((_) => recompute());
      _subscriptions.add(sub);
    }
  }

  @override
  T get value => _cachedValue;

  @override
  Stream<T> get changes => _controller.stream;

  @override
  void recompute() {
    final next = _compute();
    if (_cachedValue == next) return;
    _cachedValue = next;
    _controller.add(_cachedValue);
  }

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _controller.close();
  }
}

class InMemorySignalStore implements SignalStore {
  final Map<String, Signal<dynamic>> _signals = {};

  @override
  Signal<T> get<T>(SignalKey<T> key) {
    final signal = _signals[key.id];
    if (signal is! Signal<T>) {
      throw StateError('Signal "${key.id}" not found or type mismatch');
    }
    return signal;
  }

  @override
  MutableSignal<T> getOrCreateMutable<T>(SignalKey<T> key, T initialValue) {
    return _signals.putIfAbsent(
      key.id,
      () => MutableSignalImpl<T>(initialValue),
    ) as MutableSignal<T>;
  }

  @override
  ComputedSignal<T> getOrCreateComputed<T>(
    SignalKey<T> key,
    T Function() compute,
    List<Signal<dynamic>> dependencies,
  ) {
    return _signals.putIfAbsent(
      key.id,
      () => ComputedSignalImpl<T>(compute, dependencies),
    ) as ComputedSignal<T>;
  }

  @override
  void dispose() {
    for (final s in _signals.values) {
      if (s is MutableSignalImpl) s.dispose();
      if (s is ComputedSignalImpl) s.dispose();
    }
    _signals.clear();
  }
}

class _StreamEventSubscription implements EventSubscription {
  final StreamSubscription<dynamic> _sub;
  _StreamEventSubscription(this._sub);

  @override
  Future<void> cancel() => _sub.cancel();
}

class ScopedEventBus {
  final _controller = StreamController<AlhambraEvent>.broadcast();

  Stream<T> on<T extends AlhambraEvent>() {
    return _controller.stream.where((e) => e is T).cast<T>();
  }

  EventSubscription subscribe<T extends AlhambraEvent>(
    EventChannel<T> channel,
    void Function(T event) handler,
  ) {
    final sub = _controller.stream
        .where((e) => e.type == channel.id && e is T)
        .cast<T>()
        .listen(handler);
    return _StreamEventSubscription(sub);
  }

  void emit<T extends AlhambraEvent>(T event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}
