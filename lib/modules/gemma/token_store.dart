import 'package:shared_preferences/shared_preferences.dart';

/// Persistence seam for the HuggingFace access token (OAuth or manual).
///
/// The service layer only depends on this seam; the concrete
/// [SharedPrefsTokenStore] stores the token under a fixed key in
/// shared_preferences so it survives app restarts.
abstract class TokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

/// Real [TokenStore] backed by shared_preferences.
class SharedPrefsTokenStore implements TokenStore {
  const SharedPrefsTokenStore({SharedPreferences? preferences})
      : _preferences = preferences;

  /// SharedPreferences key that holds the token. Public so tests can seed
  /// restart-survival scenarios directly.
  static const String tokenKey = 'hf_access_token';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  @override
  Future<String?> read() async {
    final prefs = await _prefs;
    return prefs.getString(tokenKey);
  }

  @override
  Future<void> write(String token) async {
    final prefs = await _prefs;
    await prefs.setString(tokenKey, token);
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(tokenKey);
  }
}
