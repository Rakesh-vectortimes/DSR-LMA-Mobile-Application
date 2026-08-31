/// Which environment file to load.
enum AppEnv {
  dev,
  prod;

  static AppEnv fromName(String name) {
    switch (name.toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnv.prod;
      default:
        return AppEnv.dev;
    }
  }

  String get assetFile {
    switch (this) {
      case AppEnv.dev:
        return '.env.dev';
      case AppEnv.prod:
        return '.env.prod';
    }
  }
}
