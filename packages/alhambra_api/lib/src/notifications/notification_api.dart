import '../common/api_page.dart';
import '../common/api_response.dart';
import 'notification_dto.dart';

/// API contract for notification services.
abstract interface class NotificationApi {
  /// Lists notifications for the authenticated user/request.
  Future<ApiResponse<ApiPage<NotificationDto>>> list(
    NotificationListRequest request,
  );

  /// Marks a specific notification as read.
  Future<ApiResponse<void>> markRead(
    String notificationId,
  );
}
