import 'dart:io';

import 'package:alhambra_data/alhambra_data.dart';
import 'package:path_provider/path_provider.dart';

/// Local filesystem [FileStore] implementation.
///
/// Files are stored in a flat directory under the app's documents folder:
/// `<documentsDir>/alhambra_files/<id>/<name>`
///
/// The [id] is a timestamp-based string combined with a counter to avoid
/// collisions within the same millisecond.
final class LocalFileStore implements FileStore {
  final Directory _root;
  int _counter = 0;

  LocalFileStore(this._root);

  /// Creates a [LocalFileStore] rooted at
  /// `<getApplicationDocumentsDirectory()>/alhambra_files`.
  static Future<LocalFileStore> create() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory('${docs.path}/alhambra_files');
    await root.create(recursive: true);
    return LocalFileStore(root);
  }

  @override
  Future<FileReference> upload(FileUpload upload) async {
    _counter++;
    final id = '${DateTime.now().millisecondsSinceEpoch}_$_counter';
    final dir = Directory('${_root.path}/$id');
    await dir.create(recursive: true);
    final file = File('${dir.path}/${upload.name}');
    await file.writeAsBytes(upload.bytes);
    return FileReference(
      id: id,
      name: upload.name,
      contentType: upload.contentType,
      size: upload.bytes.length,
    );
  }

  @override
  Future<FileDownload> download(FileReference reference) async {
    final file = File('${_root.path}/${reference.id}/${reference.name}');
    if (!file.existsSync()) {
      throw StateError('File not found: ${reference.id}/${reference.name}');
    }
    final bytes = await file.readAsBytes();
    return FileDownload(reference: reference, bytes: bytes);
  }

  @override
  Future<void> delete(FileReference reference) async {
    final dir = Directory('${_root.path}/${reference.id}');
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }
}
