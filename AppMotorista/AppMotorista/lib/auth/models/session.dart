class DriverIdentity {
  const DriverIdentity({required this.guid, required this.name});

  final String guid;
  final String name;

  factory DriverIdentity.fromJson(Map<String, dynamic> json) {
    return DriverIdentity(
      guid: json['guid']?.toString() ?? '',
      name: json['nome']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'guid': guid, 'nome': name};
}

class DriverSession {
  const DriverSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.driver,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DriverIdentity driver;

  factory DriverSession.fromJson(Map<String, dynamic> json) {
    final driverJson = json['motorista'];
    if (driverJson is! Map<String, dynamic>) {
      throw const FormatException('Motorista ausente na sessão.');
    }
    return DriverSession(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      accessExpiresAt: DateTime.parse(json['access_expires_at'].toString()),
      driver: DriverIdentity.fromJson(driverJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'access_expires_at': accessExpiresAt.toIso8601String(),
    'motorista': driver.toJson(),
  };
}
