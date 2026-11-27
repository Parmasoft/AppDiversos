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

  AppConfig copyWith({String? baseUri}) => AppConfig(
    environment: environment,
    baseUri: baseUri ?? this.baseUri,
    requestTimeout: requestTimeout,
    readOnly: readOnly,
  );

  bool get isDevelopment => environment == 'desenvolvimento';

  bool get enableMobileBootstrap => environment == 'homologacao';

  bool get isHomologationReadOnly => environment == 'homologacao' && readOnly;

  /// The sole endpoint that owned the pre-isolation session key.  Compatibility
  /// is intentionally unavailable for any configurable endpoint.
  bool get mayReadHomologationLegacySession =>
      environment == 'homologacao' &&
      baseUri.trim().toLowerCase() == 'https://motorista.parmatech.com.br';

  /// Keeps credentials from one server out of another server's session.
  String get sessionStorageKey =>
      '${environment == 'homologacao' ? homologationSessionStorageKey : legacySessionStorageKey}_$storageScope';

  /// Stable, filesystem-safe scope derived from the selected API origin.
  String get storageScope {
    var hash = 0x811c9dc5;
    for (final codeUnit in baseUri.trim().toLowerCase().codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }
}
