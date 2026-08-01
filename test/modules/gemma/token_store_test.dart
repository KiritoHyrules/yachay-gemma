import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aprendo_plus/modules/gemma/token_store.dart';

/// RED phase of task 3.6 - `TokenStore` persistence seam.
///
/// The real [SharedPrefsTokenStore] is exercised against
/// shared_preferences' in-memory mock; the abstract seam guarantees the
/// service layer can read/write/clear the stored token without knowing where
/// it lives.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TokenStore - persistencia', () {
    test(
        'GIVEN a fresh SharedPrefsTokenStore '
        'WHEN read() runs '
        'THEN it returns null (no token yet)', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsTokenStore();

      final token = await store.read();

      expect(token, isNull);
    });

    test(
        'GIVEN write("hf_abc123") '
        'WHEN read() runs '
        'THEN it returns "hf_abc123" (roundtrip)', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsTokenStore();
      await store.write('hf_abc123');

      final token = await store.read();

      expect(token, 'hf_abc123');
    });

    test(
        'GIVEN a token persisted in SharedPreferences under the app key '
        'WHEN a new SharedPrefsTokenStore reads it '
        'THEN the token survives restarts (same storage key)', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsTokenStore.tokenKey: 'hf_survives_restart',
      });
      final store = SharedPrefsTokenStore();

      final token = await store.read();

      expect(token, 'hf_survives_restart');
    });

    test(
        'GIVEN write("hf_abc123") followed by clear() '
        'WHEN read() runs '
        'THEN it returns null', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsTokenStore();
      await store.write('hf_abc123');
      await store.clear();

      final token = await store.read();

      expect(token, isNull);
    });

    test(
        'GIVEN write("one") then write("two") '
        'WHEN read() runs '
        'THEN it returns "two" (write overwrites)', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsTokenStore();
      await store.write('one');
      await store.write('two');

      final token = await store.read();

      expect(token, 'two');
    });
  });
}
