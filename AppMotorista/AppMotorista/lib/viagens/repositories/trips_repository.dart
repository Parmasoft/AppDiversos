import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../sync/models/outbox_operation.dart';
import '../models/delivery_read_result.dart';
import '../models/trip_detail.dart';
import '../models/trip_summary.dart';

class TripsRepository {
  const TripsRepository(this._client);

  final ApiClient _client;

  Future<List<TripSummary>> list(String accessToken) async {
    final json = await _client.getJson(
      '/api/v1/motorista/viagens',
      accessToken: accessToken,
    );
    final values = json['viagens'];
    if (values is! List) {
      throw const FormatException('Lista de viagens inválida.');
    }
    return List.unmodifiable(
      values.whereType<Map<String, dynamic>>().map(TripSummary.fromJson),
    );
  }

  Future<TripDetail> get(String manifestGuid, String accessToken) async {
    final json = await _client.getJson(
      '/api/v1/motorista/viagens/$manifestGuid',
      accessToken: accessToken,
    );
    return TripDetail.fromJson(json);
  }

  Future<DeliveryReadResult> registerRead({
    required String manifestGuid,
    required int stopId,
    required int orderId,
    required String operationGuid,
    required String occurrenceGuid,
    required String code,
    required DateTime deviceDateTime,
    required int timezoneOffsetMinutes,
    required String accessToken,
  }) async {
    final json = await _client.postJson(
      '/api/v1/motorista/viagens/$manifestGuid/paradas/$stopId/'
      'pedidos/$orderId/leituras',
      accessToken: accessToken,
      acceptedStatusCodes: const {409},
      body: <String, Object>{
        'operacao_guid': operationGuid,
        'occurrence_guid': occurrenceGuid,
        'codigo': code,
        'data_hora_aparelho': deviceDateTime.toIso8601String(),
        'fuso_minutos': timezoneOffsetMinutes,
      },
    );
    return DeliveryReadResult.fromJson(json);
  }

  Future<DeliveryReadResult> registerPersistedRead({
    required OutboxOperation operation,
    required String accessToken,
  }) async {
    if (operation.operationType != 'delivery_read' ||
        (operation.payloadVersion != 1 && operation.payloadVersion != 2)) {
      throw const FormatException('Tipo ou versão de operação inválida.');
    }
    final decoded = jsonDecode(operation.payloadJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Payload persistido inválido.');
    }
    final persistedGuid = decoded['operacao_guid']?.toString().trim() ?? '';
    if (persistedGuid.toUpperCase() != operation.operationGuid.toUpperCase()) {
      throw const FormatException(
        'UUID do payload diverge da operação persistida.',
      );
    }
    if (operation.payloadVersion == 2) {
      final persistedOccurrenceGuid =
          decoded['occurrence_guid']?.toString().trim() ?? '';
      final localOccurrenceGuid = operation.occurrenceGuid?.trim() ?? '';
      if (persistedOccurrenceGuid.isEmpty ||
          localOccurrenceGuid.isEmpty ||
          persistedOccurrenceGuid.toUpperCase() !=
              localOccurrenceGuid.toUpperCase()) {
        throw const FormatException(
          'Ocorrência do payload diverge da operação persistida.',
        );
      }
    }
    final json = await _client.postPersistedJson(
      '/api/v1/motorista/viagens/${operation.manifestGuid}/paradas/'
      '${operation.stopId}/pedidos/${operation.orderId}/leituras',
      accessToken: accessToken,
      acceptedStatusCodes: const {409},
      jsonBody: operation.payloadJson,
    );
    return DeliveryReadResult.fromJson(json);
  }
}
