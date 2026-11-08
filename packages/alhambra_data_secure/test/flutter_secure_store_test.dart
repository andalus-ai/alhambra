import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:alhambra_data/alhambra_data.dart';
import 'package:alhambra_data_secure/alhambra_data_secure.dart';

// ---------------------------------------------------------------------------
// Fake FlutterSecureStorage for testing (avoids platform-channel calls)
// ---------------------------------------------------------------------------
class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _map = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _map[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _map.remove(key);
    } else {
      _map[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _map.remove(key);
  }
}

void main() {
  group('FlutterSecureStoreAdapter', () {
    late _FakeSecureStorage fakeStorage;
    late FlutterSecureStoreAdapter adapter;

    setUp(() {
      fakeStorage = _FakeSecureStorage();
      adapter = FlutterSecureStoreAdapter(fakeStorage);
    });

    test('implements SecureStore contract', () {
      expect(adapter, isA<SecureStore>());
    });

    test('read returns null for missing key', () async {
      expect(await adapter.read('missing'), isNull);
    });

    test('write then read returns value', () async {
      await adapter.write('token', 'abc123');
      expect(await adapter.read('token'), 'abc123');
    });

    test('write overwrites existing value', () async {
      await adapter.write('token', 'old');
      await adapter.write('token', 'new');
      expect(await adapter.read('token'), 'new');
    });

    test('remove deletes entry', () async {
      await adapter.write('token', 'abc123');
      await adapter.remove('token');
      expect(await adapter.read('token'), isNull);
    });

    test('remove of non-existent key is a no-op', () async {
      await expectLater(adapter.remove('ghost'), completes);
    });

    test('multiple keys are independent', () async {
      await adapter.write('a', 'alpha');
      await adapter.write('b', 'beta');
      expect(await adapter.read('a'), 'alpha');
      expect(await adapter.read('b'), 'beta');
    });

    test('default constructor compiles (FlutterSecureStorage const)', () {
      // Ensures the default const constructor path compiles.
      // Cannot call platform channels in test, so just verify type.
      const a = FlutterSecureStoreAdapter();
      expect(a, isA<SecureStore>());
    });
  });
}
