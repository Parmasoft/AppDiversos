import '../auth/models/session.dart';

abstract interface class SessionStorage {
  Future<DriverSession?> read();

  Future<void> write(DriverSession session);

  Future<void> clear();
}
