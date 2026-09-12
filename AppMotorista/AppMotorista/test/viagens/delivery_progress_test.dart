import 'package:app_motorista/viagens/models/trip_detail.dart';
import 'package:app_motorista/viagens/utils/delivery_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pedidos pendentes ficam antes dos concluídos com ordem estável', () {
    const orders = [
      TripOrder(id: 1, status: 'E'),
      TripOrder(id: 2, status: 'P'),
      TripOrder(id: 3, status: 'E'),
      TripOrder(id: 4, status: 'P'),
    ];

    expect(ordersPendingFirst(orders).map((item) => item.id), [2, 4, 1, 3]);
  });

  test('paradas pendentes ficam antes das concluídas com ordem estável', () {
    final stops = [
      _stop(id: 1, status: 'E'),
      _stop(id: 2, status: 'P'),
      _stop(id: 3, status: 'E'),
      _stop(id: 4, status: 'P'),
    ];

    expect(stopsPendingFirst(stops).map((item) => item.id), [2, 4, 1, 3]);
  });

  test('ocorrências pendentes ficam antes das entregues com ordem estável', () {
    const occurrences = [
      ManifestOccurrence(
        id: 1,
        guid: '1',
        orderId: 10,
        productId: 1,
        type: 'C',
        code: '1',
        quantity: '1',
        status: 'E',
      ),
      ManifestOccurrence(
        id: 2,
        guid: '2',
        orderId: 10,
        productId: 2,
        type: 'C',
        code: '2',
        quantity: '1',
        status: 'P',
      ),
      ManifestOccurrence(
        id: 3,
        guid: '3',
        orderId: 10,
        productId: 3,
        type: 'C',
        code: '3',
        quantity: '1',
        status: 'E',
      ),
      ManifestOccurrence(
        id: 4,
        guid: '4',
        orderId: 10,
        productId: 4,
        type: 'C',
        code: '4',
        quantity: '1',
        status: 'P',
      ),
    ];

    expect(occurrencesPendingFirst(occurrences).map((item) => item.id), [
      2,
      4,
      1,
      3,
    ]);
  });

  test('viagem só conclui com estados oficiais de paradas e pedidos', () {
    final completed = _trip([
      _stop(id: 1, status: 'E', orderStatus: 'E'),
      _stop(id: 2, status: 'E', orderStatus: 'E'),
    ]);
    final pendingStop = _trip([
      _stop(id: 1, status: 'E', orderStatus: 'E'),
      _stop(id: 2, status: 'P', orderStatus: 'P'),
    ]);

    expect(tripIsCompleted(completed), isTrue);
    expect(tripIsCompleted(pendingStop), isFalse);
  });
}

TripStop _stop({required int id, required String status, String? orderStatus}) {
  return TripStop(
    id: id,
    plannedOrder: id,
    status: status,
    clientName: 'Cliente $id',
    city: 'Ubá',
    state: 'MG',
    address: '',
    orders: orderStatus == null
        ? const []
        : [TripOrder(id: id, status: orderStatus)],
    occurrences: const [],
  );
}

TripDetail _trip(List<TripStop> stops) {
  return TripDetail(
    manifestGuid: 'MANIFESTO',
    manifestStatus: 'L',
    loadId: 527,
    description: 'TESTE',
    driverName: 'PAULO',
    originName: 'GRAMDECOR',
    stops: stops,
    occurrenceCount: 0,
  );
}
