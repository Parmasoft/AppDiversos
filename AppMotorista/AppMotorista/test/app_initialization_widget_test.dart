import 'package:app_motorista/app.dart';
import 'package:app_motorista/auth/services/session_controller.dart';
import 'package:app_motorista/core/config/admin_access_store.dart';
import 'package:app_motorista/core/config/app_config.dart';
import 'package:app_motorista/core/config/endpoint_change_result.dart';
import 'package:app_motorista/core/network/api_client.dart';
import 'package:app_motorista/storage/app_database.dart';
import 'package:app_motorista/sync/local/outbox_local_store.dart';
import 'package:app_motorista/sync/services/outbox_sync_controller.dart';
import 'package:app_motorista/viagens/local/delivery_local_store.dart';
import 'package:app_motorista/viagens/local/trip_local_store.dart';
import 'package:app_motorista/viagens/repositories/trips_repository.dart';
import 'package:app_motorista/viagens/services/trips_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/fakes.dart';

void main() {
  sqfliteFfiInit();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'restaura uma vez e apresenta login quando não há sessão armazenada',
    (tester) async {
      final controller = _TrackingSessionController(
        repository: FakeAuthGateway(),
        storage: MemorySessionStorage(),
      );
      final database = AppDatabase(factory: databaseFactoryFfi);
      final outbox = OutboxLocalStore(database);
      final repository = TripsRepository(
        ApiClient(transport: FakeApiTransport()),
      );
      final sync = OutboxSyncController(
        sessionController: controller,
        outboxLocalStore: outbox,
        deliveryLocalStore: DeliveryLocalStore(database),
        send: (operation, accessToken) => repository.registerPersistedRead(
          operation: operation,
          accessToken: accessToken,
        ),
      );

      final app = AppMotorista(
        config: const AppConfig(
          environment: 'homologacao',
          baseUri: 'https://motorista.parmatech.com.br',
          requestTimeout: Duration(seconds: 20),
        ),
        sessionController: controller,
        tripsService: TripsService(
          repository: repository,
          sessionController: controller,
          localStore: TripLocalStore(database),
          deliveryLocalStore: DeliveryLocalStore(database),
          outboxLocalStore: outbox,
          outboxChanged: sync.outboxChanged,
        ),
        outboxSyncController: sync,
        outboxLocalStore: outbox,
        onEndpointSave: (_) async => const EndpointChangeResult.saved('salvo'),
        adminAccess: AdminAccessStore(),
      );

      await tester.pumpWidget(app);
      await tester.pump();

      expect(controller.restoreCalls, 1);
      expect(find.text('Usuário'), findsOneWidget);
      expect(find.text('Abrindo suas viagens…'), findsNothing);

      await tester.pumpWidget(app);
      await tester.pump();

      expect(controller.restoreCalls, 1);
    },
  );
}

class _TrackingSessionController extends SessionController {
  _TrackingSessionController({
    required super.repository,
    required super.storage,
  });

  int restoreCalls = 0;

  @override
  Future<void> restore() {
    restoreCalls++;
    return super.restore();
  }
}
