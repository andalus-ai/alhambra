import 'file_download.dart';
import 'file_reference.dart';
import 'file_upload.dart';

/// Contract for local, cloud, or hybrid blob/file storage.
abstract interface class FileStore {
  /// Uploads binary payload and returns a unique [FileReference].
  Future<FileReference> upload(FileUpload upload);

  /// Downloads file content for given [reference].
  Future<FileDownload> download(FileReference reference);

  /// Deletes the file asset backing [reference].
  Future<void> delete(FileReference reference);
}

/// In-memory implementation of [FileStore] for test environments.
final class InMemoryFileStore implements FileStore {
  final Map<String, List<int>> _storage = {};
  int _counter = 0;

  @override
  Future<FileReference> upload(FileUpload upload) async {
    _counter++;
    final id = 'file-$_counter';
    _storage[id] = List<int>.from(upload.bytes);

    return FileReference(
      id: id,
      name: upload.name,
      contentType: upload.contentType,
      size: upload.bytes.length,
    );
  }

  @override
  Future<FileDownload> download(FileReference reference) async {
    final bytes = _storage[reference.id];
    if (bytes == null) {
      throw StateError('File not found: ${reference.id}');
    }

    return FileDownload(
      reference: reference,
      bytes: List<int>.unmodifiable(bytes),
    );
  }

  @override
  Future<void> delete(FileReference reference) async {
    _storage.remove(reference.id);
  }
}
