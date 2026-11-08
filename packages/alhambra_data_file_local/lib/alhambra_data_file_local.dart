/// Local filesystem implementation of the alhambra_data FileStore contract.
///
/// Use [LocalFileStore] to persist binary blobs under the app's documents
/// directory. In test environments prefer [InMemoryFileStore] from
/// `alhambra_data` as it requires no I/O.
library alhambra_data_file_local;

export 'src/local_file_store.dart';
