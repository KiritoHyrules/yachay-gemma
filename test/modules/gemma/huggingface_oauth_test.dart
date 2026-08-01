import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aprendo_plus/modules/gemma/huggingface_oauth.dart';
import 'package:aprendo_plus/modules/gemma/token_store.dart';

/// RED phase of task 3.6 - `HuggingFaceOAuth` PKCE flow (REQ-02 of
/// gemma-model-download: gated access resolved via OAuth PKCE or manual
/// token; when both fail the service gets `null` and degrades).
///
/// The network seam is `MockClient` (no real HTTP); the persistence seam is
/// the real [SharedPrefsTokenStore] over shared_preferences' in-memory mock.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HuggingFaceOAuth - PKCE S256 verifier/challenge', () {
    test(
        'GIVEN generateCodeVerifier() '
        'WHEN invoked '
        'THEN it returns 32 bytes base64url-encoded without padding', () {
      final verifier = HuggingFaceOAuth.generateCodeVerifier();

      expect(verifier, isNotEmpty);
      expect(verifier.contains('='), isFalse);
      expect(verifier.contains('+'), isFalse);
      expect(verifier.contains('/'), isFalse);
      // 32 bytes -> 43 base64url chars (no padding).
      expect(utf8.encode(verifier).length, 43);
    });

    test(
        'GIVEN a code verifier '
        'WHEN generateCodeChallenge() runs '
        'THEN it returns the S256 challenge: base64url(SHA256(verifier)) '
        'without padding, different from the verifier', () {
      final verifier = HuggingFaceOAuth.generateCodeVerifier();
      final challenge = HuggingFaceOAuth.generateCodeChallenge(verifier);

      expect(challenge, isNotEmpty);
      expect(challenge.contains('='), isFalse);
      expect(challenge, isNot(verifier));
      // Deterministic: same verifier always yields the same challenge.
      expect(
        HuggingFaceOAuth.generateCodeChallenge(verifier),
        challenge,
      );
    });
  });

  group('HuggingFaceOAuth - auth URL (PKCE params)', () {
    test(
        'GIVEN an OAuth instance '
        'WHEN generateAuthUrl() runs '
        'THEN it returns the HF authorize endpoint with client_id, '
        'redirect_uri com.aprendoplus.app://oauthredirect, response_type=code, '
        'scope and the S256 challenge', () async {
      SharedPreferences.setMockInitialValues({});
      final oauth = HuggingFaceOAuth(store: SharedPrefsTokenStore());

      final url = Uri.parse(await oauth.generateAuthUrl());

      expect(url.scheme, 'https');
      expect(url.host, 'huggingface.co');
      expect(url.path, '/oauth/authorize');
      expect(url.queryParameters['client_id'], kHfClientId);
      expect(
        url.queryParameters['redirect_uri'],
        'com.aprendoplus.app://oauthredirect',
      );
      expect(url.queryParameters['response_type'], 'code');
      expect(url.queryParameters['code_challenge_method'], 'S256');
      expect(url.queryParameters['scope'], isNotEmpty);
      expect(url.queryParameters['code_challenge'], isNotEmpty);
      // Challenge in the URL must match the S256 challenge of the persisted
      // verifier: a malicious middle-man cannot precompute it.
      final persisted =
          (await SharedPreferences.getInstance()).getString(kHfVerifierKey);
      expect(persisted, isNotNull);
      expect(
        url.queryParameters['code_challenge'],
        HuggingFaceOAuth.generateCodeChallenge(persisted!),
      );
    });
  });

  group('HuggingFaceOAuth - exchange code -> token', () {
    test(
        'GIVEN a 200 response from the token endpoint '
        'WHEN exchangeCodeForToken(code) runs after generateAuthUrl() '
        'THEN it returns the access token and persists it via TokenStore',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsTokenStore();
      late Uri requestedUri;
      String? requestedBody;
      final oauth = HuggingFaceOAuth(
        store: store,
        client: MockClient((request) async {
          requestedUri = request.url;
          requestedBody = request.body;
          return http.Response(
            json.encode({
              'access_token': 'hf_oauth_token_123',
              'expires_in': 3600,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final authUrl = await oauth.generateAuthUrl();
      final persistedVerifier =
          (await SharedPreferences.getInstance()).getString(kHfVerifierKey);
      expect(persistedVerifier, isNotNull);

      final token = await oauth.exchangeCodeForToken('auth_code_xyz');

      expect(token, 'hf_oauth_token_123');
      expect(await store.read(), 'hf_oauth_token_123');
      expect(requestedUri.toString(), kHfTokenEndpoint);
      expect(requestedBody, contains('grant_type=authorization_code'));
      expect(requestedBody, contains('code=auth_code_xyz'));
      expect(
        requestedBody,
        contains('client_id=${Uri.encodeQueryComponent(kHfClientId)}'),
      );
      // The verifier used in the exchange matches the one from the auth URL.
      expect(requestedBody, contains('code_verifier=$persistedVerifier'));
      // Verifier is single-use: cleaned up after a successful exchange.
      expect(
        (await SharedPreferences.getInstance()).getString(kHfVerifierKey),
        isNull,
      );
    });

    test(
        'GIVEN no prior generateAuthUrl() (no persisted verifier) '
        'WHEN exchangeCodeForToken(code) runs '
        'THEN it returns null and never calls the token endpoint', () async {
      SharedPreferences.setMockInitialValues({});
      var networkCalls = 0;
      final store = SharedPrefsTokenStore();
      final oauth = HuggingFaceOAuth(
        store: store,
        client: MockClient((request) async {
          networkCalls++;
          return http.Response('{}', 200);
        }),
      );

      final token = await oauth.exchangeCodeForToken('some_code');

      expect(token, isNull);
      expect(networkCalls, 0);
      expect(await store.read(), isNull);
    });

    test(
        'GIVEN a 400 response from the token endpoint '
        'WHEN exchangeCodeForToken(code) runs after generateAuthUrl() '
        'THEN it returns null and the store stays empty', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsTokenStore();
      final oauth = HuggingFaceOAuth(
        store: store,
        client: MockClient(
          (request) async => http.Response('{"error":"invalid_grant"}', 400),
        ),
      );
      await oauth.generateAuthUrl();

      final token = await oauth.exchangeCodeForToken('bad_code');

      expect(token, isNull);
      expect(await store.read(), isNull);
    });
  });

  group('HuggingFaceOAuth - token manual y degradado (REQ-02)', () {
    test(
        'GIVEN a manual token persisted in the TokenStore '
        'WHEN getAccessToken() runs '
        'THEN it returns the manual token without any network flow', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsTokenStore();
      await store.write('hf_manual_token');
      var networkCalls = 0;
      final oauth = HuggingFaceOAuth(
        store: store,
        client: MockClient((request) async {
          networkCalls++;
          return http.Response('{}', 200);
        }),
      );

      final token = await oauth.getAccessToken();

      expect(token, 'hf_manual_token');
      expect(networkCalls, 0);
    });

    test(
        'GIVEN an empty store and a token endpoint that rejects the exchange '
        'WHEN the OAuth flow completes with an error response '
        'THEN no token is persisted, exchange returns null and '
        'getAccessToken() returns null (both flows fail -> service degrades)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsTokenStore();
      final oauth = HuggingFaceOAuth(
        store: store,
        client: MockClient(
          (request) async => http.Response('{"error":"denied"}', 403),
        ),
      );
      await oauth.generateAuthUrl();

      final exchanged = await oauth.exchangeCodeForToken('denied_code');

      expect(exchanged, isNull);
      expect(await store.read(), isNull);
      expect(await oauth.getAccessToken(), isNull);
    });
  });
}
