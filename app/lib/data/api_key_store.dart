import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Default model for on-device mode; any OpenRouter model with structured
/// outputs works.
const String defaultModel = 'google/gemini-3.8-flash';

/// Stores the user's OpenRouter key and model choice. The key is kept in
/// Android's encrypted storage (Keystore-backed) and is only ever sent to
/// OpenRouter.
abstract interface class ApiKeyStore {
  Future<String?> readKey();
  Future<void> writeKey(String key);
  Future<void> deleteKey();
  Future<String> readModel();
  Future<void> writeModel(String model);
}

class SecureApiKeyStore implements ApiKeyStore {
  SecureApiKeyStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyName = 'openrouter_api_key';
  static const _modelName = 'openrouter_model';

  @override
  Future<String?> readKey() async {
    final v = (await _storage.read(key: _keyName))?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  @override
  Future<void> writeKey(String key) => _storage.write(key: _keyName, value: key.trim());

  @override
  Future<void> deleteKey() => _storage.delete(key: _keyName);

  @override
  Future<String> readModel() async {
    final v = (await _storage.read(key: _modelName))?.trim();
    return v == null || v.isEmpty ? defaultModel : v;
  }

  @override
  Future<void> writeModel(String model) => _storage.write(key: _modelName, value: model.trim());
}

/// In-memory store for tests and previews.
class MemoryApiKeyStore implements ApiKeyStore {
  MemoryApiKeyStore({this.key, this.model = defaultModel});

  String? key;
  String model;

  @override
  Future<String?> readKey() async => key;

  @override
  Future<void> writeKey(String k) async => key = k.trim();

  @override
  Future<void> deleteKey() async => key = null;

  @override
  Future<String> readModel() async => model;

  @override
  Future<void> writeModel(String m) async => model = m.trim();
}
