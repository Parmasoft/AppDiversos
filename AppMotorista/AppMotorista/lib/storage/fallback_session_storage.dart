import '../auth/models/session.dart';
import 'session_storage.dart';

/// Compatibility reader for the former secure-storage key of the official
/// GramDecor homologation endpoint. It never accepts data from another
/// endpoint; the caller enables it only for that exact origin.
///
/// A recovered session is immediately written under the current isolated key.
/// Logout clears both keys, so an explicit logout can never be undone by the
/// fallback on the next launch.
class FallbackSessionStorage implements SessionStorage {
  FallbackSessionStorage({required SessionStorage primary, required SessionStorage fallback})
      : _primary = primary,
        _fallback = fallback;

  final SessionStorage _primary;
  final SessionStorage _fallback;

  @override
  Future<DriverSession?> read() async {
    final current = await _primary.read();
    if (current != null) return current;
    final legacy = await _fallback.read();
    if (legacy != null) await _primary.write(legacy);
    return legacy;
  }

  @override
  Future<void> write(DriverSession session) => _primary.write(session);

  @override
  Future<void> clear() async {
    await _primary.clear();
    await _fallback.clear();
  }
}
