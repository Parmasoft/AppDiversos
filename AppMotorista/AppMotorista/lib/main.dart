import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/repositories/auth_repository.dart';
import 'auth/services/session_controller.dart';
import 'core/config/admin_access_store.dart';
import 'core/config/api_endpoint.dart';
import 'core/config/api_endpoint_store.dart';
import 'core/config/app_config.dart';
import 'core/config/endpoint_change_result.dart';
import 'core/network/api_client.dart';
import 'core/network/api_health_checker.dart';
import 'core/network/http_api_transport.dart';
import 'storage/app_database.dart';
import 'storage/fallback_session_storage.dart';
import 'storage/secure_session_storage.dart';
import 'storage/session_storage.dart';
import 'sync/local/outbox_local_store.dart';
import 'sync/services/outbox_sync_controller.dart';
import 'viagens/local/delivery_local_store.dart';
import 'viagens/local/trip_local_store.dart';
import 'viagens/repositories/trips_repository.dart';
import 'viagens/services/trips_service.dart';
import 'viagens/services/trip_state_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AppBootstrap());
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  final _endpointStore = SecureApiEndpointStore();
  final _adminAccess = AdminAccessStore();
  _Runtime? _runtime;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    const defaults = AppConfig.fromEnvironment();
    final stored = await _endpointStore.read(allowHttp: defaults.isDevelopment);
    final endpoint =
        stored ??
        ApiEndpoint.parse(defaults.baseUri, allowHttp: defaults.isDevelopment);
    if (!mounted) return;
    setState(
      () => _runtime = _createRuntime(
        defaults.copyWith(baseUri: endpoint.baseUri),
      ),
    );
  }

  _Runtime _createRuntime(AppConfig config) {
    final apiClient = ApiClient(
      transport: HttpApiTransport(
        baseUri: config.baseUri,
        timeout: config.requestTimeout,
      ),
    );
    final appDatabase = AppDatabase(
      databaseFileName: 'app_motorista_${config.storageScope}.db',
    );
    final SessionStorage scopedStorage = FlutterSecureSessionStorage(
      sessionKey: config.sessionStorageKey,
    );
    final SessionStorage sessionStorage =
        config.mayReadHomologationLegacySession
        ? FallbackSessionStorage(
            primary: scopedStorage,
            fallback: FlutterSecureSessionStorage(
              sessionKey: AppConfig.homologationSessionStorageKey,
            ),
          )
        : scopedStorage;
    final sessionController = SessionController(
      repository: AuthRepository(apiClient),
      storage: sessionStorage,
    );
    final outbox = OutboxLocalStore(appDatabase);
    final tripStore = TripLocalStore(appDatabase);
    final tripState = TripStateController(
      scope: config.storageScope,
      activeDriverGuid: () => sessionController.session?.driver.guid,
      readSnapshot: ({required driverGuid, required manifestGuid}) => tripStore
          .readSnapshot(driverGuid: driverGuid, manifestGuid: manifestGuid),
      pendingStopIds: ({required driverGuid, required manifestGuid}) => outbox
          .pendingStopIds(driverGuid: driverGuid, manifestGuid: manifestGuid),
      pendingOrderIds:
          ({required driverGuid, required manifestGuid, required stopId}) =>
              outbox.pendingOrderIds(
                driverGuid: driverGuid,
                manifestGuid: manifestGuid,
                stopId: stopId,
              ),
    );
    final tripsRepository = TripsRepository(apiClient);
    final sync = OutboxSyncController(
      sessionController: sessionController,
      outboxLocalStore: outbox,
      deliveryLocalStore: DeliveryLocalStore(appDatabase),
      send: (operation, accessToken) => tripsRepository.registerPersistedRead(
        operation: operation,
        accessToken: accessToken,
      ),
      serverReachabilityProbe: () async =>
          (await ApiHealthChecker().check(config.baseUri)).ok,
      onManifestStateCommitted: (driverGuid, manifestGuid) =>
          tripState.publish(driverGuid: driverGuid, manifestGuid: manifestGuid),
    );
    return _Runtime(
      config: config,
      sessionController: sessionController,
      outbox: outbox,
      sync: sync,
      tripState: tripState,
      trips: TripsService(
        repository: tripsRepository,
        sessionController: sessionController,
        localStore: tripStore,
        deliveryLocalStore: DeliveryLocalStore(appDatabase),
        outboxLocalStore: outbox,
        outboxChanged: sync.outboxChanged,
        tripStateController: tripState,
        readOnly: config.readOnly,
      ),
    );
  }

  Future<EndpointChangeResult> _saveEndpoint(ApiEndpoint endpoint) async {
    final current = _runtime!;
    if (endpoint.baseUri == current.config.baseUri) {
      return const EndpointChangeResult.saved('Este endereço já está em uso.');
    }
    final pending = await current.outbox.pendingCount();
    if (pending > 0) {
      return const EndpointChangeResult.blocked(
        'Há leituras pendentes neste servidor. Sincronize-as antes de trocar a API.',
      );
    }
    await _endpointStore.write(endpoint);
    if (!mounted) {
      return const EndpointChangeResult.blocked(
        'Aplicativo não está mais ativo.',
      );
    }
    setState(
      () => _runtime = _createRuntime(
        current.config.copyWith(baseUri: endpoint.baseUri),
      ),
    );
    return const EndpointChangeResult.saved(
      'Endereço salvo. A sessão e os dados offline deste servidor permanecem isolados.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _runtime;
    if (runtime == null) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return AppMotorista(
      key: ValueKey(runtime.config.baseUri),
      config: runtime.config,
      sessionController: runtime.sessionController,
      tripsService: runtime.trips,
      tripStateController: runtime.tripState,
      outboxSyncController: runtime.sync,
      outboxLocalStore: runtime.outbox,
      onEndpointSave: _saveEndpoint,
      adminAccess: _adminAccess,
    );
  }
}

class _Runtime {
  const _Runtime({
    required this.config,
    required this.sessionController,
    required this.outbox,
    required this.sync,
    required this.trips,
    required this.tripState,
  });

  final AppConfig config;
  final SessionController sessionController;
  final OutboxLocalStore outbox;
  final OutboxSyncController sync;
  final TripsService trips;
  final TripStateController tripState;
}
