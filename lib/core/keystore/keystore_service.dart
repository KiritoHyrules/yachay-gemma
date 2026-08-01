import 'package:flutter/services.dart';

class KeystoreService {
  static const _channel = MethodChannel('keystore');

  KeystoreService._();

  static final KeystoreService instance = KeystoreService._();

  Future<String?> getKey() async {
    try {
      final key = await _channel.invokeMethod<String>('getKey');
      return key;
    } on MissingPluginException {
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> storeKey(String key) async {
    try {
      final result = await _channel.invokeMethod<bool>('storeKey', {'key': key});
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      return false;
    }
  }
}
