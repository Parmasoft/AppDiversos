class TripDetail {
  const TripDetail({
    required this.manifestGuid,
    required this.manifestStatus,
    required this.loadId,
    required this.description,
    required this.driverName,
    required this.originName,
    required this.stops,
    required this.occurrenceCount,
    this.departureDate,
    this.departureTime,
  });

  final String manifestGuid;
  final String manifestStatus;
  final int loadId;
  final String description;
  final String driverName;
  final String originName;
  final List<TripStop> stops;
  final int occurrenceCount;
  final String? departureDate;
  final String? departureTime;

  factory TripDetail.fromJson(Map<String, dynamic> json) {
    final manifest = _map(json['manifesto']);
    final load = _map(json['carga']);
    final driver = _map(json['motorista']);
    final origin = _map(json['origem']);
    final rawStops = json['paradas'];
    return TripDetail(
      manifestGuid: manifest['guid']?.toString() ?? '',
      manifestStatus: manifest['status']?.toString() ?? '',
      loadId: _integer(load['id']),
      description: load['descricao']?.toString().trim() ?? '',
      driverName: driver['nome']?.toString().trim() ?? '',
      originName: origin['nome_fantasia']?.toString().trim() ?? '',
      departureDate: load['saida_data']?.toString(),
      departureTime: load['saida_hora']?.toString(),
      occurrenceCount: _integer(json['quantidade_ocorrencias']),
      stops: rawStops is List
          ? List.unmodifiable(
              rawStops.whereType<Map<String, dynamic>>().map(TripStop.fromJson),
            )
          : const [],
    );
  }
}

class TripStop {
  const TripStop({
    required this.id,
    required this.plannedOrder,
    required this.status,
    required this.clientName,
    required this.city,
    required this.state,
    required this.address,
    required this.orders,
    required this.occurrences,
  });

  final int id;
  final int plannedOrder;
  final String status;
  final String clientName;
  final String city;
  final String state;
  final String address;
  final List<TripOrder> orders;
  final List<ManifestOccurrence> occurrences;

  factory TripStop.fromJson(Map<String, dynamic> json) {
    final order = _map(json['ordem']);
    final client = _map(json['cliente']);
    final address = _map(json['endereco']);
    final rawOrders = json['pedidos'];
    final rawOccurrences = json['ocorrencias'];
    return TripStop(
      id: _integer(json['parada']),
      plannedOrder: _integer(order['planejada']),
      status: json['status']?.toString() ?? '',
      clientName: client['nome']?.toString().trim() ?? '',
      city: address['cidade']?.toString().trim() ?? '',
      state: address['uf']?.toString().trim() ?? '',
      address: _formatAddress(address),
      orders: _uniqueOrders(rawOrders),
      occurrences: rawOccurrences is List
          ? List.unmodifiable(
              rawOccurrences.whereType<Map<String, dynamic>>().map(
                ManifestOccurrence.fromJson,
              ),
            )
          : const [],
    );
  }

  List<ManifestOccurrence> occurrencesFor(int orderId) {
    return List.unmodifiable(
      occurrences.where((occurrence) => occurrence.orderId == orderId),
    );
  }

  int pendingFor(int orderId) {
    return occurrencesFor(orderId).where((item) => item.isPending).length;
  }

  int deliveredFor(int orderId) {
    return occurrencesFor(orderId).where((item) => item.isDelivered).length;
  }
}

class TripOrder {
  const TripOrder({required this.id, required this.status});

  final int id;
  final String status;

  factory TripOrder.fromJson(Map<String, dynamic> json) {
    return TripOrder(
      id: _integer(json['pedido']),
      status: json['status']?.toString() ?? '',
    );
  }

  TripOrder copyWith({String? status}) {
    return TripOrder(id: id, status: status ?? this.status);
  }
}

class ManifestOccurrence {
  const ManifestOccurrence({
    required this.id,
    required this.guid,
    required this.orderId,
    required this.productId,
    required this.type,
    required this.code,
    required this.quantity,
    required this.status,
    this.rollId,
  });

  final int id;
  final String guid;
  final int orderId;
  final int productId;
  final String type;
  final String code;
  final String quantity;
  final String status;
  final int? rollId;

  bool get isPending => status == 'P';
  bool get isDelivered => status == 'E';

  factory ManifestOccurrence.fromJson(Map<String, dynamic> json) {
    final rawRoll = json['rolo_id'];
    return ManifestOccurrence(
      id: _integer(json['ocorrencia']),
      guid: json['guid']?.toString() ?? '',
      orderId: _integer(json['pedido']),
      productId: _integer(json['produto']),
      type: json['tipo']?.toString() ?? '',
      code: json['codigo']?.toString() ?? '',
      rollId: rawRoll == null ? null : _integer(rawRoll),
      quantity: json['quantidade']?.toString() ?? '0',
      status: json['status']?.toString() ?? '',
    );
  }

  ManifestOccurrence copyWith({String? status}) {
    return ManifestOccurrence(
      id: id,
      guid: guid,
      orderId: orderId,
      productId: productId,
      type: type,
      code: code,
      quantity: quantity,
      status: status ?? this.status,
      rollId: rollId,
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  return value is Map<String, dynamic> ? value : const {};
}

int _integer(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  _ => int.tryParse(value?.toString() ?? '') ?? 0,
};

List<TripOrder> _uniqueOrders(Object? value) {
  if (value is! List) return const [];
  final unique = <int, TripOrder>{};
  for (final item in value.whereType<Map<String, dynamic>>()) {
    final order = TripOrder.fromJson(item);
    unique.putIfAbsent(order.id, () => order);
  }
  return List.unmodifiable(unique.values);
}

String _formatAddress(Map<String, dynamic> json) {
  final street = json['logradouro']?.toString().trim() ?? '';
  final number = json['numero']?.toString().trim() ?? '';
  final district = json['bairro']?.toString().trim() ?? '';
  return [
    [street, number].where((value) => value.isNotEmpty).join(', '),
    district,
  ].where((value) => value.isNotEmpty).join(' · ');
}
