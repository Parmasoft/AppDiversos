class AppConfig {
  static const legacySessionStorageKey = 'motorista_session_v1';
  static const homologationSessionStorageKey =
      'motorista_homologacao_session_v1';
  const AppConfig({
    required this.environment,
    required this.baseUri,
    required this.requestTimeout,
    this.readOnly = false,
  });

  const AppConfig.fromEnvironment()
    : environment = const String.fromEnvironment(
        'API_ENV',
        defaultValue: 'desenvolvimento',
      ),
      baseUri = const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:5055',
      ),
      requestTimeout = const Duration(
        seconds: int.fromEnvironment('API_TIMEOUT_SECONDS', defaultValue: 20),
      ),
      readOnly = const bool.fromEnvironment(
        'MOTORISTA_READ_ONLY',
        defaultValue: false,
      );

  final String environment;
  final String baseUri;
  final Duration requestTimeout;
  final bool readOnly;

  bool get isDevelopment => environment == 'desenvolvimento';

  bool get enableMobileBootstrap => environment == 'homologacao';

  bool get isHomologationReadOnly => environment == 'homologacao' && readOnly;

  String get sessionStorageKey => environment == 'homologacao'
      ? homologationSessionStorageKey
      : legacySessionStorageKey;
}
