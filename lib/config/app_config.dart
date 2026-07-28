// config/app_config.dart
class AppConfig {
  // Pinata credentials are supplied at build/run time, never hardcoded here.
  // Run with: flutter run --dart-define-from-file=env.json
  // (copy env.json.example to env.json and fill in real values; env.json is gitignored)
  static const String pinataApiKey = String.fromEnvironment('PINATA_API_KEY');
  static const String pinataSecretKey =
      String.fromEnvironment('PINATA_SECRET_KEY');

  // Falls back to mock IPFS automatically when no Pinata key is supplied
  // (see the emptiness checks in ipfs_service.dart), so this only needs to
  // force mock mode on explicitly, e.g. --dart-define=USE_MOCK_SERVICES=true
  static const bool useMockServices =
      bool.fromEnvironment('USE_MOCK_SERVICES');
}
