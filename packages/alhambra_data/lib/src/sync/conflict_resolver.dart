/// Strategy contract for reconciling conflicting local and remote states.
abstract interface class ConflictResolver<T> {
  Future<T> resolve(T local, T remote);
}

/// Simple resolver that always prefers the remote/server version.
final class ServerWinsResolver<T> implements ConflictResolver<T> {
  const ServerWinsResolver();

  @override
  Future<T> resolve(T local, T remote) async => remote;
}

/// Simple resolver that always prefers the local/client version.
final class ClientWinsResolver<T> implements ConflictResolver<T> {
  const ClientWinsResolver();

  @override
  Future<T> resolve(T local, T remote) async => local;
}

/// Resolver that chooses based on timestamp extractor functions.
final class TimestampConflictResolver<T> implements ConflictResolver<T> {
  final DateTime Function(T item) timestampOf;

  const TimestampConflictResolver(this.timestampOf);

  @override
  Future<T> resolve(T local, T remote) async {
    final localTime = timestampOf(local);
    final remoteTime = timestampOf(remote);
    return localTime.isAfter(remoteTime) ? local : remote;
  }
}
