class DeliveryReadResult {
  const DeliveryReadResult({
    required this.result,
    required this.responseCode,
    required this.message,
    required this.replay,
    this.operationId,
    this.occurrenceGuid,
    this.type,
    this.orderId,
    this.pendingOrder,
    this.pendingStop,
    this.awaitingSync = false,
  });

  final String result;
  final String responseCode;
  final String message;
  final bool replay;
  final int? operationId;
  final String? occurrenceGuid;
  final String? type;
  final int? orderId;
  final int? pendingOrder;
  final int? pendingStop;
  final bool awaitingSync;

  bool get isAccepted => result == 'ACEITA';
  bool get isConflict => result == 'CONFLITO';

  factory DeliveryReadResult.fromJson(Map<String, dynamic> json) {
    return DeliveryReadResult(
      result: json['resultado']?.toString().trim().toUpperCase() ?? '',
      responseCode:
          json['codigo_resposta']?.toString().trim().toUpperCase() ?? '',
      message: json['mensagem']?.toString().trim() ?? '',
      operationId: _optionalInteger(json['operacao']),
      occurrenceGuid: _optionalString(json['ocorrencia_guid']),
      type: _optionalString(json['tipo']),
      orderId: _optionalInteger(json['pedido']),
      pendingOrder: _optionalInteger(json['pendentes_pedido']),
      pendingStop: _optionalInteger(json['pendentes_parada']),
      replay: _boolean(json['replay']),
    );
  }

  Map<String, Object?> toJson() => {
    'resultado': result,
    'codigo_resposta': responseCode,
    'mensagem': message,
    'operacao': operationId,
    'ocorrencia_guid': occurrenceGuid,
    'tipo': type,
    'pedido': orderId,
    'pendentes_pedido': pendingOrder,
    'pendentes_parada': pendingStop,
    'replay': replay,
  };
}

int? _optionalInteger(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

bool _boolean(Object? value) {
  return value == true || value == 1 || value?.toString().toUpperCase() == 'S';
}
