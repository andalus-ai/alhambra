import 'package:alhambra_core/alhambra_core.dart';

/// Notification channels available to the platform.
enum NotificationChannel {
  inApp,
  push,
  email,
  sms,
  webhook,
}

/// A platform notification directed at a specific user.
///
/// Notifications are distinct from domain events: events say "something happened";
/// notifications say "something happened that [recipientId] should know about."
final class Notification {
  final String id;
  final UserId recipientId;
  final String title;
  final String message;
  final String? type;
  final DateTime createdAt;
  final bool isRead;
  final NotificationChannel channel;
  final Map<String, Object?> metadata;

  const Notification({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.message,
    this.type,
    required this.createdAt,
    this.isRead = false,
    this.channel = NotificationChannel.inApp,
    this.metadata = const {},
  });

  Notification copyWith({bool? isRead}) => Notification(
        id: id,
        recipientId: recipientId,
        title: title,
        message: message,
        type: type,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        channel: channel,
        metadata: metadata,
      );

  @override
  String toString() =>
      'Notification($id, recipient: $recipientId, title: $title, read: $isRead)';
}
