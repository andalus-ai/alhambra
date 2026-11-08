import 'package:alhambra_core/alhambra_core.dart';
import 'notification.dart';

/// Platform notification service.
///
/// All domains produce [Notification]s via this contract — no domain
/// implements its own notification infrastructure.
abstract interface class NotificationService {
  /// Sends [notification] to its recipient via the configured channel.
  Future<void> send(Notification notification);

  /// Lists notifications for [recipientId], newest first.
  Future<List<Notification>> list({
    required UserId recipientId,
    bool unreadOnly = false,
  });

  /// Marks a single notification as read.
  Future<void> markRead(String notificationId);

  /// Marks all notifications for [recipientId] as read.
  Future<void> markAllRead(UserId recipientId);
}

// ---------------------------------------------------------------------------
// In-memory implementation
// ---------------------------------------------------------------------------

/// In-memory [NotificationService] for tests and local development.
final class InMemoryNotificationService implements NotificationService {
  final _store = <String, Notification>{};

  @override
  Future<void> send(Notification notification) async {
    _store[notification.id] = notification;
  }

  @override
  Future<List<Notification>> list({
    required UserId recipientId,
    bool unreadOnly = false,
  }) async {
    return _store.values
        .where((n) =>
            n.recipientId == recipientId &&
            (!unreadOnly || !n.isRead))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> markRead(String notificationId) async {
    final n = _store[notificationId];
    if (n != null) _store[notificationId] = n.copyWith(isRead: true);
  }

  @override
  Future<void> markAllRead(UserId recipientId) async {
    for (final entry in _store.entries.toList()) {
      if (entry.value.recipientId == recipientId && !entry.value.isRead) {
        _store[entry.key] = entry.value.copyWith(isRead: true);
      }
    }
  }
}
