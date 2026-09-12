import '../../core/network/api_client.dart';
import '../models/session.dart';

abstract interface class AuthGateway {
  Future<DriverSession> login({
    required String username,
    required String password,
    String? device,
  });

  Future<DriverSession> renew(String refreshToken);
}

class AuthRepository implements AuthGateway {
  const AuthRepository(this._client);

  final ApiClient _client;

  @override
  Future<DriverSession> login({
    required String username,
    required String password,
    String? device,
  }) async {
    final json = await _client.postJson(
      '/api/v1/motorista/sessoes',
      body: {
        'login': username.trim(),
        'senha': password,
        if (device != null && device.isNotEmpty) 'dispositivo': device,
      },
    );
    return DriverSession.fromJson(json);
  }

  @override
  Future<DriverSession> renew(String refreshToken) async {
    final json = await _client.postJson(
      '/api/v1/motorista/sessoes/renovar',
      body: {'refresh_token': refreshToken},
    );
    return DriverSession.fromJson(json);
  }
}
