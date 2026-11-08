/// File payload prepared for upload to a [FileStore].
final class FileUpload {
  final String name;
  final String contentType;
  final List<int> bytes;

  const FileUpload({
    required this.name,
    required this.contentType,
    required this.bytes,
  });

  int get size => bytes.length;
}
