import 'package:app_motorista/storage/fallback_session_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  test('recupera a sessão antiga apenas quando a chave atual está vazia', () async {
    final primary = MemorySessionStorage();
    final legacy = MemorySessionStorage(session(accessToken: 'legado'));
    final storage = FallbackSessionStorage(primary: primary, fallback: legacy);

    final restored = await storage.read();

    expect(restored?.accessToken, 'legado');
    expect(primary.value?.accessToken, 'legado');
    expect(primary.writes, 1);
  });

  test('logout explícito apaga a sessão isolada e a chave anterior', () async {
    final primary = MemorySessionStorage(session(accessToken: 'nova'));
    final legacy = MemorySessionStorage(session(accessToken: 'legada'));
    final storage = FallbackSessionStorage(primary: primary, fallback: legacy);

    await storage.clear();

    expect(primary.value, isNull);
    expect(legacy.value, isNull);
  });
}
