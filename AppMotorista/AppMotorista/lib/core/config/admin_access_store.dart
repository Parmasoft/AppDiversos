import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Homologation-only gate. A secure-storage override can replace the fallback
/// without changing the application binary.
class AdminAccessStore {
  AdminAccessStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'motorista_admin_settings_password_v1';
  static const _fallbackPassword = String.fromEnvironment(
    'ADMIN_SETTINGS_PASSWORD',
    defaultValue: '123',
  );
  final FlutterSecureStorage _storage;

  Future<bool> verify(String password) async {
    final configured = await _storage.read(key: _key);
    return password ==
        (configured?.isNotEmpty == true ? configured : _fallbackPassword);
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!await verify(currentPassword) || newPassword.trim().length < 4) {
      return false;
    }
    await _storage.write(key: _key, value: newPassword);
    return true;
  }
}
