import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'env.dart';

/// Runtime configuration loaded from `.env.dev` / `.env.prod`.
class AppConfig {
  AppConfig._({
    required this.env,
    required this.apiBaseUrl,
    required this.apiV1BaseUrl,
  });

  static AppConfig? _instance;

  static AppConfig get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('AppConfig.load() must be called before use.');
    }
    return value;
  }

  final AppEnv env;
  final String apiBaseUrl;
  final String apiV1BaseUrl;

  bool get isProd => env == AppEnv.prod;

  /// Loads dotenv asset for [env] and materializes [instance].
  static Future<AppConfig> load(AppEnv env) async {
    await dotenv.load(fileName: env.assetFile);

    final config = AppConfig._(
      env: env,
      apiBaseUrl: dotenv.get('API_BASE_URL', fallback: 'http://localhost:8000'),
      apiV1BaseUrl: dotenv.get(
        'API_V1_BASE_URL',
        fallback: 'http://localhost:8000/api/v1',
      ),
    );
    _instance = config;
    return config;
  }
}
