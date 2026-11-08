/// Policies dictating how data requests interact with cache and network.
enum CachePolicy {
  /// Always fetch from remote network; bypass cache completely.
  networkOnly,

  /// Only fetch from local cache; never hit the network.
  cacheOnly,

  /// Use cached data if available; otherwise fetch from network and cache it.
  cacheFirst,

  /// Try network first; fall back to cached data if network fails.
  networkFirst,

  /// Return cached data immediately if present, but revalidate in background.
  staleWhileRevalidate,
}
