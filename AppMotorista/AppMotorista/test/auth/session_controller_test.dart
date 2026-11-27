import 'package:app_motorista/auth/models/session.dart';
import 'package:app_motorista/auth/services/session_controller.dart';
import 'package:app_motorista/core/errors/api_exception.dart';
import 'package:app_motorista/storage/session_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  group('SessionController', () {
    test('login salva e autentica a sessão', () async {
      final gateway = FakeAuthGateway()..loginResult = session();
      final storage = MemorySessionStorage();
      final controller = SessionController(
        repository: gateway,
        storage: storage,
      );

      final success = await controller.login('motorista', 'senha');

      expect(success, isTrue);
      expect(controller.state, SessionState.authenticated);
      expect(storage.value?.accessToken, 'access');
      expect(storage.writes, 1);
    });

    test('restaura sessão ainda válida sem renovar', () async {
      final gateway = FakeAuthGateway();
      final storage = MemorySessionStorage(session(expiresAt: DateTime(2030)));
      final controller = SessionController(
        repository: gateway,
        storage: storage,
        now: () => DateTime(2026, 8, 25),
      );

      await controller.restore();

      expect(controller.state, SessionState.authenticated);
      expect(gateway.renewCalls, 0);
    });

    test('falha no armazenamento sai do bootstrap e informa o login', () async {
      final controller = SessionController(
        repository: FakeAuthGateway(),
        storage: _FailingSessionStorage(),
      );

      await controller.restore();

      expect(controller.state, SessionState.loggedOut);
      expect(controller.loginError, contains('restaurar a'));
    });

    test('renova sessão expirada durante a restauração', () async {
      final gateway = FakeAuthGateway()
        ..renewResult = session(
          accessToken: 'novo',
          refreshToken: 'novo-refresh',
        );
      final storage = MemorySessionStorage(
        session(expiresAt: DateTime(2026, 8, 24)),
      );
      final controller = SessionController(
        repository: gateway,
        storage: storage,
        now: () => DateTime(2026, 8, 25),
      );

      await controller.restore();

      expect(gateway.renewCalls, 1);
      expect(controller.session?.accessToken, 'novo');
      expect(controller.state, SessionState.authenticated);
    });

    test('indisponibilidade ao restaurar não apaga a sessão local', () async {
      final gateway = FakeAuthGateway()
        ..renewError = const ApiException('sem conexão');
      final original = session(expiresAt: DateTime(2026, 8, 24));
      final storage = MemorySessionStorage(original);
      final controller = SessionController(
        repository: gateway,
        storage: storage,
        now: () => DateTime(2026, 8, 25),
      );

      await controller.restore();

      expect(controller.state, SessionState.authenticated);
      expect(controller.session, same(original));
      expect(storage.value, same(original));
      expect(storage.clears, 0);
    });

    for (final statusCode in [401, 403]) {
      test('$statusCode ao renovar continua encerrando a sessão', () async {
        final gateway = FakeAuthGateway()
          ..renewError = ApiException(
            'sessão rejeitada',
            statusCode: statusCode,
          );
        final storage = MemorySessionStorage(
          session(expiresAt: DateTime(2026, 8, 24)),
        );
        final controller = SessionController(
          repository: gateway,
          storage: storage,
          now: () => DateTime(2026, 8, 25),
        );

        await controller.restore();

        expect(controller.state, SessionState.loggedOut);
        expect(controller.session, isNull);
        expect(storage.value, isNull);
      });
    }

    test('falha de rede no refresh após 401 preserva a sessão', () async {
      final gateway = FakeAuthGateway()
        ..renewError = const ApiException('sem conexão');
      final original = session();
      final storage = MemorySessionStorage(original);
      final controller = SessionController(
        repository: gateway,
        storage: storage,
        now: () => DateTime(2026, 8, 25),
      );
      await controller.restore();

      await expectLater(
        controller.authorized<void>((_) async {
          throw const ApiException('expirou', statusCode: 401);
        }),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            isNull,
          ),
        ),
      );

      expect(controller.state, SessionState.authenticated);
      expect(controller.session, same(original));
      expect(storage.value, same(original));
    });

    test('401 renova uma vez e repete a requisição', () async {
      final gateway = FakeAuthGateway()
        ..renewResult = session(accessToken: 'renovado');
      final storage = MemorySessionStorage(session());
      final controller = SessionController(
        repository: gateway,
        storage: storage,
        now: () => DateTime(2026, 8, 25),
      );
      await controller.restore();
      var requests = 0;

      final result = await controller.authorized((token) async {
        requests++;
        if (requests == 1) {
          throw const ApiException('expirou', statusCode: 401);
        }
        return token;
      });

      expect(result, 'renovado');
      expect(requests, 2);
      expect(gateway.renewCalls, 1);
    });

    test('segundo 401 encerra a sessão sem loop de refresh', () async {
      final gateway = FakeAuthGateway()
        ..renewResult = session(accessToken: 'renovado');
      final storage = MemorySessionStorage(session());
      final controller = SessionController(
        repository: gateway,
        storage: storage,
        now: () => DateTime(2026, 8, 25),
      );
      await controller.restore();
      var requests = 0;

      await expectLater(
        controller.authorized((_) async {
          requests++;
          throw const ApiException('expirou', statusCode: 401);
        }),
        throwsA(isA<ApiException>()),
      );

      expect(requests, 2);
      expect(gateway.renewCalls, 1);
      expect(controller.state, SessionState.loggedOut);
      expect(storage.value, isNull);
    });
  });
}

class _FailingSessionStorage implements SessionStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<DriverSession?> read() =>
      Future.error(StateError('secure storage unavailable'));

  @override
  Future<void> write(DriverSession session) async {}
}
