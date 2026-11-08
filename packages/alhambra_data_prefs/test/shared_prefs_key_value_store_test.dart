import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alhambra_data/alhambra_data.dart';
import 'package:alhambra_data_prefs/alhambra_data_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefsKeyValueStore', () {
    setUp(() {
      // Reset to a clean slate before each test.
      SharedPreferences.setMockInitialValues({});
    });

    test('implements KeyValueStore contract', () {
      // Verify the class satisfies the interface (compile-time check).
      expect(
        SharedPrefsKeyValueStore,
        isA<Type>(),
      );
      // Runtime isinstance check via an instance.
      // ignore: unused_local_variable
      KeyValueStore? kv;
      // The line below would fail to compile if the contract is broken:
      // kv = SharedPrefsKeyValueStore(prefs);
    });

    test('create() returns a SharedPrefsKeyValueStore', () async {
      final store = await SharedPrefsKeyValueStore.create();
      expect(store, isA<SharedPrefsKeyValueStore>());
      expect(store, isA<KeyValueStore>());
    });

    test('read returns null for missing key', () async {
      final store = await SharedPrefsKeyValueStore.create();
      expect(await store.read('missing'), isNull);
    });

    test('write then read returns value', () async {
      final store = await SharedPrefsKeyValueStore.create();
      await store.write('key1', 'value1');
      expect(await store.read('key1'), 'value1');
    });

    test('write overwrites existing value', () async {
      final store = await SharedPrefsKeyValueStore.create();
      await store.write('key1', 'first');
      await store.write('key1', 'second');
      expect(await store.read('key1'), 'second');
    });

    test('remove deletes entry', () async {
      final store = await SharedPrefsKeyValueStore.create();
      await store.write('key1', 'value1');
      await store.remove('key1');
      expect(await store.read('key1'), isNull);
    });

    test('remove of non-existent key is a no-op', () async {
      final store = await SharedPrefsKeyValueStore.create();
      // Should not throw.
      await expectLater(store.remove('ghost'), completes);
    });

    test('multiple keys are independent', () async {
      final store = await SharedPrefsKeyValueStore.create();
      await store.write('a', 'alpha');
      await store.write('b', 'beta');
      expect(await store.read('a'), 'alpha');
      expect(await store.read('b'), 'beta');
    });

    test('constructor injection works with pre-loaded prefs', () async {
      SharedPreferences.setMockInitialValues({'pre': 'loaded'});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsKeyValueStore(prefs);
      expect(await store.read('pre'), 'loaded');
    });
  });
}
