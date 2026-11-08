import '../common/api_response.dart';
import 'file_dto.dart';

/// API contract for file upload, retrieval, and download sessions.
abstract interface class FileApi {
  /// Initiates an upload session, returning pre-signed URLs or upload endpoints.
  Future<ApiResponse<FileUploadSessionDto>> createUpload(
    CreateFileUploadRequest request,
  );

  /// Retrieves metadata for a file.
  Future<ApiResponse<FileDto>> get(
    String fileId,
  );

  /// Requests a temporary download link for a file.
  Future<ApiResponse<FileDownloadDto>> createDownload(
    String fileId,
  );
}
