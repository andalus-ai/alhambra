import '../common/api_request.dart';

/// Request DTO for listing notifications with pagination and filtering.
final class NotificationListRequest extends ApiRequest {
  final bool? unreadOnly;
  final String? recipientId;
  final int page;
  final int pageSize;

  const NotificationListRequest({
    this.unreadOnly,
    this.recipientId,
    this.page = 0,
    this.pageSize = 20,
    super.idempotencyKey,
  });
}

/// DTO representing an in-app notification.
final class NotificationDto {
  final String id;
  final String recipientId;
  final String title;
  final String body;
  final String type;
  final String? targetResource;
  final bool read;
  final DateTime createdAt;

  const NotificationDto({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    required this.type,
    this.targetResource,
    this.read = false,
    required this.createdAt,
  });
}
