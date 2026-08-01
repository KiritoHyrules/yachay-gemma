import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'model_installer.dart' show TokenProvider;
import 'token_store.dart';

/// HuggingFace OAuth 2.0 with PKCE (S256) for the gated Gemma model download
/// (REQ-02 gemma-model-download). PKCE lets a mobile app authenticate without
/// a client secret: the client proves possession of the code_verifier.
///
/// App credentials are our own (ADR-2): the client_id below must match the
/// OAuth app registered in HuggingFace for the Aprendo+ redirect URI. Never
/// copy credentials from the reference project.
const String kHfClientId = 'com.aprendoplus.app';
const String kHfRedirectUri = 'com.aprendoplus.app://oauthredirect';
const String kHfAuthEndpoint = 'https://huggingface.co/oauth/authorize';
const String kHfTokenEndpoint = 'https://huggingface.co/oauth/token';
const String kHfScope = 'openid profile read-repos';

/// SharedPreferences key for the short-lived PKCE code verifier. Public so
/// tests can inspect the persisted verifier / single-use cleanup.
const String kHfVerifierKey = 'hf_pkce_verifier';

/// Real [TokenProvider]: a manual token persisted in the [TokenStore] wins;
/// otherwise the app can drive the PKCE browser flow and exchange the
/// returned authorization code. When both fail, [getAccessToken] returns
/// `null` and the download service degrades with an actionable error.
class HuggingFaceOAuth implements TokenProvider {
  HuggingFaceOAuth({
    required TokenStore store,
    http.Client? client,
    String clientId = kHfClientId,
    String redirectUri = kHfRedirectUri,
    String authEndpoint = kHfAuthEndpoint,
    String tokenEndpoint = kHfTokenEndpoint,
    String scope = kHfScope,
  })  : _store = store,
        _client = client ?? http.Client(),
        _clientId = clientId,
        _redirectUri = redirectUri,
        _authEndpoint = authEndpoint,
        _tokenEndpoint = tokenEndpoint,
        _scope = scope;

  final TokenStore _store;
  final http.Client _client;
  final String _clientId;
  final String _redirectUri;
  final String _authEndpoint;
  final String _tokenEndpoint;
  final String _scope;

  /// TokenProvider seam: manual token (or a previously obtained OAuth token)
  /// wins with zero network; `null` means "not authenticated yet".
  @override
  Future<String?> getAccessToken() => _store.read();

  /// 32 random bytes, base64url-encoded without padding. Public for tests.
  static String generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// S256 challenge: base64url(SHA256(verifier)) without padding. Public for
  /// tests to assert the verifier/challenge relationship.
  static String generateCodeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Builds the HuggingFace authorize URL with PKCE params. The code verifier
  /// is persisted before returning so [exchangeCodeForToken] can prove
  /// possession later — even if the deep-link callback arrives in a fresh
  /// process (Android intent path).
  Future<String> generateAuthUrl() async {
    final verifier = generateCodeVerifier();
    final challenge = generateCodeChallenge(verifier);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kHfVerifierKey, verifier);

    final params = <String, String>{
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'scope': _scope,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    };
    final query = params.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$_authEndpoint?$query';
  }

  /// Exchanges the authorization code for an access token. On success the
  /// token is persisted in the [TokenStore] and the single-use verifier is
  /// removed. Returns `null` when the verifier is missing or the endpoint
  /// rejects the exchange.
  Future<String?> exchangeCodeForToken(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final verifier = prefs.getString(kHfVerifierKey);
    if (verifier == null) return null; // flow never started

    try {
      final response = await _client.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'code': code,
          'redirect_uri': _redirectUri,
          'grant_type': 'authorization_code',
          'code_verifier': verifier,
        },
      );
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      if (token == null || token.isEmpty) return null;

      await _store.write(token);
      await prefs.remove(kHfVerifierKey); // single-use verifier
      return token;
    } on Exception {
      return null; // network failure -> degrade, never crash
    }
  }

  /// Full PKCE browser flow: opens the authorize page in the system browser
  /// (Custom Tabs on Android) and captures the `com.aprendoplus.app` redirect.
  /// Returns the access token or `null` if the user cancels / the exchange
  /// fails. Platform plugin call; unit tests cover the seam methods instead.
  Future<String?> authenticateViaBrowser() async {
    try {
      final authUrl = await generateAuthUrl();
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: 'com.aprendoplus.app',
      );
      final code = Uri.parse(result).queryParameters['code'];
      if (code == null || code.isEmpty) return null;
      return exchangeCodeForToken(code);
    } on Exception {
      return null;
    }
  }
}
