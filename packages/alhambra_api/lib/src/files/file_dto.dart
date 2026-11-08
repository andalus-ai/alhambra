import '../common/api_request.dart';

/// Request DTO for initiating a controlled file upload session.
final class CreateFileUploadRequest extends ApiRequest {
  final String fileName;
  final String mimeType;
  final int byteSize;
  final String? workspaceId;

  const CreateFileUploadRequest({
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    this.workspaceId,
    super.idempotencyKey,
  });
}

/// DTO representing an upload session with upload target and credentials.
final class FileUploadSessionDto {
  final String sessionId;
  final String uploadUrl;
  final String fileId;
  final DateTime expiresAt;
  final Map<String, String> headers;

  const FileUploadSessionDto({
    required this.sessionId,
    required this.uploadUrl,
    required this.fileId,
    required this.expiresAt,
    this.headers = const {},
  });
}

/// DTO representing metadata for a stored file.
final class FileDto {
  final String id;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final String? workspaceId;
  final DateTime createdAt;
  final String? sha256;

  const FileDto({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    this.workspaceId,
    required this.createdAt,
    this.sha256,
  });
}

/// DTO representing a temporary download URL and its expiry for a file.
final class FileDownloadDto {
  final String fileId;
  final String downloadUrl;
  final DateTime expiresAt;
  final int byteSize;

  const FileDownloadDto({
    required this.fileId,
    required this.downloadUrl,
    required this.expiresAt,
    required this.byteSize,
  });
}
