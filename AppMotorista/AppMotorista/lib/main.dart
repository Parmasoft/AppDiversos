import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/repositories/auth_repository.dart';
import 'auth/services/session_controller.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/network/http_api_transport.dart';
import 'storage/app_database.dart';
import 'storage/secure_session_storage.dart';
import 'sync/local/outbox_local_store.dart';
import 'sync/services/outbox_sync_controller.dart';
import 'viagens/local/delivery_local_store.dart';
import 'viagens/local/trip_local_store.dart';
import 'viagens/repositories/trips_repository.dart';
import 'viagens/services/trips_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const config = AppConfig.fromEnvironment();
  final apiClient = ApiClient(
    transport: HttpApiTransport(
      baseUri: config.baseUri,
      timeout: config.requestTimeout,
    ),
  );
  final sessionController = SessionController(
    repository: AuthRepository(apiClient),
    storage: FlutterSecureSessionStorage(sessionKey: config.sessionStorageKey),
  );
  final appDatabase = AppDatabase();
  final outboxLocalStore = OutboxLocalStore(appDatabase);
  final deliveryLocalStore = DeliveryLocalStore(appDatabase);
  final tripsRepository = TripsRepository(apiClient);
  final outboxSyncController = OutboxSyncController(
    sessionController: sessionController,
    outboxLocalStore: outboxLocalStore,
    deliveryLocalStore: deliveryLocalStore,
    send: (operation, accessToken) => tripsRepository.registerPersistedRead(
      operation: operation,
      accessToken: accessToken,
    ),
  );
  final tripsService = TripsService(
    repository: tripsRepository,
    sessionController: sessionController,
    localStore: TripLocalStore(appDatabase),
    deliveryLocalStore: deliveryLocalStore,
    outboxLocalStore: outboxLocalStore,
    outboxChanged: outboxSyncController.outboxChanged,
    readOnly: config.readOnly,
  );

  runApp(
    AppMotorista(
      config: config,
      sessionController: sessionController,
      tripsService: tripsService,
      outboxSyncController: outboxSyncController,
    ),
  );
  sessionController.restore();
}
