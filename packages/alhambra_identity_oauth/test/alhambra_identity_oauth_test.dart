import 'package:alhambra_data/alhambra_data.dart';
import 'package:alhambra_identity_oauth/alhambra_identity_oauth.dart';
import 'package:alhambra_network/alhambra_network.dart';
import 'package:test/test.dart';

// ── Test helpers ──────────────────────────────────────────────────────────────

/// Creates an OAuthTokenProvider backed by an InMemorySecureStore.
OAuthTokenProvider _provider({
  TokenRefreshCallback? onRefresh,
  AuthToken? initial,
  String? initialRefreshToken,
}) {
  final store = InMemorySecureStore();
  final tokenStore = SecureTokenStore(store);

  if (initial != null) {
    // Seed synchronously via InMemory store
    store.write(TokenKeys.accessToken, initial.value);
    store.write(TokenKeys.tokenType, initial.tokenType);
    if (initial.expiresAt != null) {
      store.write(
          TokenKeys.expiresAt, initial.expiresAt!.toIso8601String());
    }
    if (initialRefreshToken != null) {
      store.write(TokenKeys.refreshToken, initialRefreshToken);
    }
  }

  return OAuthTokenProvider(
    store: tokenStore,
    onRefresh: onRefresh ??
        (_) async => null, // default: refresh fails (no network)
  );
}

AuthToken _validToken({Duration expiresIn = const Duration(hours: 1)}) =>
    AuthToken(
      value: 'access-token-123',
      tokenType: 'Bearer',
      expiresAt: DateTime.now().add(expiresIn),
    );

AuthToken _expiredToken() => AuthToken(
      value: 'old-access-token',
      tokenType: 'Bearer',
      expiresAt: DateTime.now().subtract(const Duration(seconds: 10)),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('SecureTokenStore', () {
    late InMemorySecureStore secure;
    late SecureTokenStore tokenStore;

    setUp(() {
      secure = InMemorySecureStore();
      tokenStore = SecureTokenStore(secure);
    });

    test('save and load round-trips access token', () async {
      final token = _validToken();
      await tokenStore.save(token, refreshToken: 'refresh-xyz');

      final loaded = await tokenStore.load();
      expect(loaded, isNotNull);
      expect(loaded!.value, token.value);
      expect(loaded.tokenType, 'Bearer');
      expect(loaded.expiresAt, isNotNull);
    });

    test('save persists refresh token separately', () async {
      await tokenStore.save(_validToken(), refreshToken: 'rt-abc');
      expect(await tokenStore.loadRefreshToken(), 'rt-abc');
    });

    test('load returns null when no token stored', () async {
      expect(await tokenStore.load(), isNull);
    });

    test('clear removes all stored tokens', () async {
      await tokenStore.save(_validToken(), refreshToken: 'rt-1');
      await tokenStore.clear();
      expect(await tokenStore.load(), isNull);
      expect(await tokenStore.loadRefreshToken(), isNull);
    });

    test('saveOrganizationId and loadOrganizationId round-trip', () async {
      await tokenStore.saveOrganizationId('org-A');
      expect(await tokenStore.loadOrganizationId(), 'org-A');
    });

    test('expiresAt is null when not stored', () async {
      final tokenWithoutExpiry = const AuthToken(value: 'tok');
      await tokenStore.save(tokenWithoutExpiry);
      final loaded = await tokenStore.load();
      expect(loaded!.expiresAt, isNull);
    });
  });

  group('OAuthTokenProvider', () {
    test('getToken returns stored valid token', () async {
      final p = _provider(initial: _validToken());
      final token = await p.getToken();
      expect(token, isNotNull);
      expect(token!.value, 'access-token-123');
      p.dispose();
    });

    test('getToken returns null when no token stored', () async {
      final p = _provider();
      expect(await p.getToken(), isNull);
      p.dispose();
    });

    test('getToken triggers refresh when token is expired', () async {
      final newToken = AuthToken(
        value: 'new-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final p = _provider(
        initial: _expiredToken(),
        initialRefreshToken: 'rt-valid',
        onRefresh: (_) async => (token: newToken, refreshToken: 'rt-new'),
      );

      final token = await p.getToken();
      expect(token?.value, 'new-token');
      p.dispose();
    });

    test('getToken returns null when refresh fails (no refresh token)', () async {
      final p = _provider(initial: _expiredToken());
      expect(await p.getToken(), isNull);
      p.dispose();
    });

    test('refreshToken clears and emits unauthenticated when callback returns null',
        () async {
      final states = <AuthState>[];
      final p = _provider(
        initial: _validToken(),
        initialRefreshToken: 'rt-will-fail',
        onRefresh: (_) async => null,
      );
      p.authStateChanges.listen(states.add);

      final result = await p.refreshToken();
      await Future<void>.delayed(Duration.zero);

      expect(result, isNull);
      expect(states, contains(AuthState.unauthenticated));
      p.dispose();
    });

    test('setTokens saves tokens and emits authenticated', () async {
      final states = <AuthState>[];
      final p = _provider();
      p.authStateChanges.listen(states.add);

      await p.setTokens(_validToken(), refreshToken: 'rt-new');
      await Future<void>.delayed(Duration.zero);

      expect(states, contains(AuthState.authenticated));
      expect(await p.isAuthenticated, isTrue);
      p.dispose();
    });

    test('logout clears tokens and emits unauthenticated', () async {
      final states = <AuthState>[];
      final p = _provider(initial: _validToken());
      p.authStateChanges.listen(states.add);

      await p.logout();
      await Future<void>.delayed(Duration.zero);

      expect(states, contains(AuthState.unauthenticated));
      expect(await p.isAuthenticated, isFalse);
      p.dispose();
    });

    test('isAuthenticated returns false when no token', () async {
      final p = _provider();
      expect(await p.isAuthenticated, isFalse);
      p.dispose();
    });

    test('implements AuthTokenProvider interface', () {
      final p = _provider();
      expect(p, isA<AuthTokenProvider>());
      p.dispose();
    });

    test('StaticAuthTokenProvider (InMemory fallback) still works', () async {
      const token = AuthToken(value: 'static-token');
      const provider = StaticAuthTokenProvider(token);
      expect(await provider.getToken(), token);
      expect(await provider.refreshToken(), token);
    });

    test('authStateChanges is a broadcast stream', () {
      final p = _provider();
      expect(p.authStateChanges.isBroadcast, isTrue);
      p.dispose();
    });
  });
}
