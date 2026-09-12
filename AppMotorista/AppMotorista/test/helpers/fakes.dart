import 'package:app_motorista/auth/models/session.dart';
import 'package:app_motorista/auth/repositories/auth_repository.dart';
import 'package:app_motorista/core/network/api_transport.dart';
import 'package:app_motorista/storage/session_storage.dart';

class FakeApiTransport implements ApiTransport {
  final List<ApiResponse> responses = [];
  String? lastMethod;
  String? lastPath;
  Map<String, String>? lastHeaders;
  Object? lastBody;

  @override
  Future<ApiResponse> send({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  }) async {
    lastMethod = method;
    lastPath = path;
    lastHeaders = headers;
    lastBody = body;
    return responses.removeAt(0);
  }
}

class MemorySessionStorage implements SessionStorage {
  MemorySessionStorage([this.value]);

  DriverSession? value;
  int writes = 0;
  int clears = 0;

  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }

  @override
  Future<DriverSession?> read() async => value;

  @override
  Future<void> write(DriverSession session) async {
    writes++;
    value = session;
  }
}

class FakeAuthGateway implements AuthGateway {
  DriverSession? loginResult;
  DriverSession? renewResult;
  Object? loginError;
  Object? renewError;
  int loginCalls = 0;
  int renewCalls = 0;

  @override
  Future<DriverSession> login({
    required String username,
    required String password,
    String? device,
  }) async {
    loginCalls++;
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<DriverSession> renew(String refreshToken) async {
    renewCalls++;
    if (renewError != null) throw renewError!;
    return renewResult!;
  }
}

DriverSession session({
  String accessToken = 'access',
  String refreshToken = 'refresh',
  DateTime? expiresAt,
}) {
  return DriverSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    accessExpiresAt: expiresAt ?? DateTime(2030),
    driver: const DriverIdentity(guid: 'DRIVER-GUID', name: 'Jorge'),
  );
}
