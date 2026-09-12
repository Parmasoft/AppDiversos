import 'package:app_motorista/auth/services/session_controller.dart';
import 'package:app_motorista/viagens/models/delivery_read_result.dart';
import 'package:app_motorista/viagens/models/trip_detail.dart';
import 'package:app_motorista/viagens/models/trip_summary.dart';
import 'package:app_motorista/viagens/screens/trips_screen.dart';
import 'package:app_motorista/viagens/services/trips_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets(
    'dados salvos permitem navegar até ocorrências sem comunicação remota',
    (tester) async {
      final gateway = _SavedTripsGateway();
      final sessionController = SessionController(
        repository: FakeAuthGateway(),
        storage: MemorySessionStorage(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TripsScreen(
            sessionController: sessionController,
            tripsService: gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sem conexão — usando dados salvos.'), findsOneWidget);
      await tester.tap(find.text('ABRIR VIAGEM'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Viagem'), findsOneWidget);
      expect(find.text('Sem conexão — usando dados salvos.'), findsOneWidget);
      await tester.tap(find.text('ABRIR PARADA').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ABRIR PEDIDO').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Pedido'), findsOneWidget);
      expect(find.byKey(const ValueKey('occurrence-card-C-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('occurrence-card-C-2')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('occurrence-card-R-22')),
        300,
      );
      expect(
        find.byKey(const ValueKey('occurrence-card-R-22')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('occurrence-card-R-22')));
      await tester.pumpAndSettle();
      expect(find.text('Rolo'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(gateway.registerReadCalls, 0);
    },
  );
}

class _SavedTripsGateway implements TripsGateway, OfflineDataStatus {
  int registerReadCalls = 0;

  @override
  bool get listUsesSavedData => true;

  @override
  bool tripUsesSavedData(String manifestGuid) => true;

  @override
  Future<List<TripSummary>> list() async => const [
    TripSummary(
      manifestGuid: 'MANIFEST-1',
      loadId: 527,
      description: 'VIAGEM OFFLINE',
      stopCount: 1,
      occurrenceCount: 3,
    ),
  ];

  @override
  Future<TripDetail> get(String manifestGuid) async => _trip();

  @override
  Future<DeliveryReadResult> registerRead({
    required String manifestGuid,
    required int stopId,
    required int orderId,
    required String code,
  }) async {
    registerReadCalls++;
    throw StateError('Leitura não faz parte deste teste offline.');
  }
}

TripDetail _trip() {
  return const TripDetail(
    manifestGuid: 'MANIFEST-1',
    manifestStatus: 'L',
    loadId: 527,
    description: 'VIAGEM OFFLINE',
    driverName: 'PAULO',
    originName: 'GRAMDECOR',
    occurrenceCount: 3,
    stops: [
      TripStop(
        id: 20,
        plannedOrder: 1,
        status: 'P',
        clientName: 'CLIENTE OFFLINE',
        city: 'UBÁ',
        state: 'MG',
        address: 'RUA TESTE, 20',
        orders: [TripOrder(id: 200, status: 'P')],
        occurrences: [
          ManifestOccurrence(
            id: 1,
            guid: 'C-1',
            orderId: 200,
            productId: 1001,
            type: 'C',
            code: 'CODIGO-C-REPETIDO',
            quantity: '1.0000',
            status: 'P',
          ),
          ManifestOccurrence(
            id: 2,
            guid: 'C-2',
            orderId: 200,
            productId: 1001,
            type: 'C',
            code: 'CODIGO-C-REPETIDO',
            quantity: '1.0000',
            status: 'P',
          ),
          ManifestOccurrence(
            id: 3,
            guid: 'R-22',
            orderId: 200,
            productId: 1002,
            type: 'R',
            code: 'ROLO-22',
            quantity: '2.5000',
            status: 'P',
            rollId: 22,
          ),
        ],
      ),
    ],
  );
}
