import 'dart:async';

/// Metadata carried by all structured events.
final class EventMetadata {
  final String eventId;
  final DateTime timestamp;
  final String? source;
  final String? correlationId;

  EventMetadata({
    String? eventId,
    DateTime? timestamp,
    this.source,
    this.correlationId,
  }) : eventId = eventId ?? 'evt_${DateTime.now().microsecondsSinceEpoch}',
       timestamp = timestamp ?? DateTime.now();
}

/// Base contract for all typed application & plugin events.
abstract interface class AlhambraEvent {
  String get type;
  EventMetadata get metadata;
}

/// Typed event channel for scoped subscriptions.
final class EventChannel<T extends AlhambraEvent> {
  final String id;

  const EventChannel(this.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventChannel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'EventChannel<$T>($id)';
}

/// Subscription handle with lifecycle cancellation.
abstract interface class EventSubscription {
  Future<void> cancel();
}

/// Observable state primitive.
abstract interface class Signal<T> {
  T get value;
  Stream<T> get changes;
}

/// Writable signal accessible only to state owners.
abstract interface class MutableSignal<T> implements Signal<T> {
  set value(T newValue);
}

/// Derived signal that automatically updates when upstream dependencies change.
abstract interface class ComputedSignal<T> implements Signal<T> {
  void recompute();
}

/// Strongly typed key for signals in a signal store.
final class SignalKey<T> {
  final String id;

  const SignalKey(this.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignalKey && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SignalKey<$T>($id)';
}

/// Scoped container for observable signals.
abstract interface class SignalStore {
  Signal<T> get<T>(SignalKey<T> key);
  MutableSignal<T> getOrCreateMutable<T>(SignalKey<T> key, T initialValue);
  ComputedSignal<T> getOrCreateComputed<T>(
    SignalKey<T> key,
    T Function() compute,
    List<Signal<dynamic>> dependencies,
  );
  void dispose();
}
