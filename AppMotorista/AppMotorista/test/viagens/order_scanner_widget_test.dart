import 'package:app_motorista/viagens/models/delivery_read_result.dart';
import 'package:app_motorista/viagens/models/trip_detail.dart';
import 'package:app_motorista/viagens/screens/order_screen.dart';
import 'package:app_motorista/viagens/services/trips_service.dart';
import 'package:app_motorista/viagens/utils/delivery_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('operação normal não possui TextField nem abre teclado virtual', (
    tester,
  ) async {
    final gateway = _FakeGateway();

    await tester.pumpWidget(_app(gateway));

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Ler etiqueta com câmera'), findsOneWidget);
    expect(find.textContaining('Leitor físico pronto'), findsOneWidget);
  });

  testWidgets('leitura aceita com pendência permanece no Pedido', (
    tester,
  ) async {
    final gateway = _FakeGateway()..results.add(_accepted('OC-1'));
    await tester.pumpWidget(_app(gateway));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyC, character: 'C');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2, character: '2');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(gateway.codes, ['C12']);
    expect(find.text('Entrega registrada.'), findsOneWidget);
    expect(find.text('PEDIDO 123'), findsOneWidget);
    final pendingProduct = find.text('Produto 11', skipOffstage: false);
    final deliveredProduct = find.text('Produto 10', skipOffstage: false);
    expect(
      tester.getTopLeft(pendingProduct).dy,
      lessThan(tester.getTopLeft(deliveredProduct).dy),
    );
    final deliveredCard = tester.widget<Card>(
      find.byKey(
        const ValueKey('occurrence-card-OC-1'),
        skipOffstage: false,
      ),
    );
    expect(deliveredCard.color, completedDeliveryColor);
    expect(find.text('Entregue', skipOffstage: false), findsOneWidget);
  });

  testWidgets('câmera devolve o código ao mesmo fluxo de entrega', (
    tester,
  ) async {
    final gateway = _FakeGateway()..results.add(_accepted('OC-1'));
    await tester.pumpWidget(
      _app(gateway, cameraReader: (_) async => 'R00000000000000001'),
    );

    await tester.tap(find.text('Ler etiqueta com câmera'));
    await tester.pumpAndSettle();

    expect(gateway.codes, ['R00000000000000001']);
    expect(find.text('Entrega registrada.'), findsOneWidget);
  });
}

Widget _app(
  _FakeGateway gateway, {
  Future<String?> Function(BuildContext context)? cameraReader,
}) {
  return MaterialApp(
    home: OrderScreen(
      manifestGuid: 'MANIFESTO',
      stopId: 7,
      order: const TripOrder(id: 123, status: 'P'),
      occurrences: const [
        ManifestOccurrence(
          id: 1,
          guid: 'OC-1',
          orderId: 123,
          productId: 10,
          type: 'C',
          code: 'C12',
          quantity: '1',
          status: 'P',
        ),
        ManifestOccurrence(
          id: 2,
          guid: 'OC-2',
          orderId: 123,
          productId: 11,
          type: 'C',
          code: 'C13',
          quantity: '1',
          status: 'P',
        ),
      ],
      tripsService: gateway,
      cameraReader: cameraReader,
    ),
  );
}

DeliveryReadResult _accepted(String occurrenceGuid) {
  return DeliveryReadResult(
    result: 'ACEITA',
    responseCode: 'OK',
    message: 'Entrega registrada.',
    replay: false,
    occurrenceGuid: occurrenceGuid,
    orderId: 123,
    pendingOrder: 1,
    pendingStop: 1,
  );
}

class _FakeGateway implements DeliveryGateway {
  final List<DeliveryReadResult> results = [];
  final List<String> codes = [];

  @override
  Future<TripDetail> get(String manifestGuid) {
    throw StateError('Atualização não esperada.');
  }

  @override
  Future<DeliveryReadResult> registerRead({
    required String manifestGuid,
    required int stopId,
    required int orderId,
    required String code,
  }) async {
    codes.add(code);
    return results.removeAt(0);
  }
}
