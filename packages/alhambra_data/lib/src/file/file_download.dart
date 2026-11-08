import 'file_reference.dart';

/// File payload downloaded from a [FileStore].
final class FileDownload {
  final FileReference reference;
  final List<int> bytes;

  const FileDownload({
    required this.reference,
    required this.bytes,
  });

  int get size => bytes.length;
}
