import 'package:app_motorista/viagens/models/trip_detail.dart';
import 'package:app_motorista/viagens/models/trip_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interpreta resumo de viagem', () {
    final trip = TripSummary.fromJson({
      'manifesto_guid': 'MANIFESTO',
      'carga': 59,
      'descricao': 'ENTREGA ITAPERUNA',
      'quantidade_paradas': 5,
      'quantidade_ocorrencias': 17,
      'saida_data': '2026-08-25',
    });

    expect(trip.loadId, 59);
    expect(trip.description, 'ENTREGA ITAPERUNA');
    expect(trip.stopCount, 5);
  });

  test('mantém C repetida e preserva ROLO_ID de R', () {
    final trip = TripDetail.fromJson({
      'manifesto': {'guid': 'MANIFESTO', 'status': 'L'},
      'carga': {'id': 59, 'descricao': 'ITAPERUNA'},
      'motorista': {'nome': 'Jorge'},
      'origem': {'nome_fantasia': 'GramDecor'},
      'quantidade_ocorrencias': 3,
      'paradas': [
        {
          'parada': 10,
          'ordem': {'planejada': 1},
          'status': 'P',
          'cliente': {'nome': 'JOÃO'},
          'endereco': {'cidade': 'Itaperuna', 'uf': 'RJ'},
          'pedidos': [
            {'pedido': 2631, 'status': 'P'},
          ],
          'ocorrencias': [
            {
              'ocorrencia': 1,
              'pedido': 2631,
              'produto': 100,
              'tipo': 'C',
              'codigo': 'C-IGUAL',
              'quantidade': '1.0000',
              'status': 'P',
            },
            {
              'ocorrencia': 2,
              'pedido': 2631,
              'produto': 100,
              'tipo': 'C',
              'codigo': 'C-IGUAL',
              'quantidade': '1.0000',
              'status': 'P',
            },
            {
              'ocorrencia': 3,
              'pedido': 2631,
              'produto': 101,
              'tipo': 'R',
              'codigo': 'R-55',
              'rolo_id': 55,
              'quantidade': '2.5000',
              'status': 'P',
            },
          ],
        },
      ],
    });

    final occurrences = trip.stops.single.occurrences;
    expect(occurrences, hasLength(3));
    expect(occurrences.where((item) => item.type == 'C'), hasLength(2));
    expect(occurrences.singleWhere((item) => item.type == 'R').rollId, 55);
  });
}
