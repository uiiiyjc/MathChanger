import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/retention_policy.dart';

/// Connection details for the vision API the user points the app at.
///
/// Nothing here is baked into the build: the key is entered by the user in the
/// settings screen and stored in the platform keystore, so a shared APK never
/// carries somebody else's credentials.
class AiSettings {
  const AiSettings({
    this.apiKey = '',
    this.endpoint = defaultEndpoint,
    this.model = defaultModel,
  });

  static const String defaultEndpoint =
      'https://api.openai.com/v1/chat/completions';
  static const String defaultModel = 'gpt-4o-mini';

  final String apiKey;
  final String endpoint;
  final String model;

  bool get isConfigured => apiKey.trim().isNotEmpty;
}

/// Reads and writes on-device settings against secure storage.
///
/// Falls back to `--dart-define` values when the user has not saved anything
/// yet, which keeps the developer workflow from the first iteration working.
class SettingsService {
  SettingsService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _keyApiKey = 'math_ai_api_key';
  static const String _keyEndpoint = 'math_ai_endpoint';
  static const String _keyModel = 'math_ai_model';
  static const String _keyRetentionDays = 'retention_days';

  // Compile-time fallbacks. `String.fromEnvironment` requires literal names,
  // hence the repetition rather than a lookup helper.
  static const String _fallbackApiKey =
      String.fromEnvironment('MATH_AI_API_KEY');
  static const String _fallbackEndpoint = String.fromEnvironment(
    'MATH_AI_ENDPOINT',
    defaultValue: AiSettings.defaultEndpoint,
  );
  static const String _fallbackModel = String.fromEnvironment(
    'MATH_AI_MODEL',
    defaultValue: AiSettings.defaultModel,
  );

  final FlutterSecureStorage _storage;

  Future<AiSettings> load() async {
    final storedKey = await _storage.read(key: _keyApiKey);
    final storedEndpoint = await _storage.read(key: _keyEndpoint);
    final storedModel = await _storage.read(key: _keyModel);

    return AiSettings(
      apiKey: storedKey ?? _fallbackApiKey,
      endpoint: storedEndpoint ?? _fallbackEndpoint,
      model: storedModel ?? _fallbackModel,
    );
  }

  Future<void> save(AiSettings settings) async {
    final endpoint = settings.endpoint.trim();
    final model = settings.model.trim();

    await _storage.write(key: _keyApiKey, value: settings.apiKey.trim());
    await _storage.write(
      key: _keyEndpoint,
      value: endpoint.isEmpty ? AiSettings.defaultEndpoint : endpoint,
    );
    await _storage.write(
      key: _keyModel,
      value: model.isEmpty ? AiSettings.defaultModel : model,
    );
  }

  /// Always returns a value inside the supported range, even if the stored
  /// string was corrupted or written by an older build.
  Future<RetentionPolicy> loadRetentionPolicy() async {
    final raw = await _storage.read(key: _keyRetentionDays);
    final parsed = int.tryParse(raw ?? '');
    if (parsed == null) return const RetentionPolicy();
    return RetentionPolicy.clamped(parsed);
  }

  Future<void> saveRetentionPolicy(RetentionPolicy policy) async {
    final safe = RetentionPolicy.clamped(policy.days);
    await _storage.write(
      key: _keyRetentionDays,
      value: safe.days.toString(),
    );
  }

  /// Wipes the stored credentials. History data is untouched - that is the
  /// cleanup screen's job.
  Future<void> clear() async {
    await _storage.delete(key: _keyApiKey);
    await _storage.delete(key: _keyEndpoint);
    await _storage.delete(key: _keyModel);
  }
}
