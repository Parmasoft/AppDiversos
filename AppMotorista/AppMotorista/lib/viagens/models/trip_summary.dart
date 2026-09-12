class TripSummary {
  const TripSummary({
    required this.manifestGuid,
    required this.loadId,
    required this.description,
    required this.stopCount,
    required this.occurrenceCount,
    this.departureDate,
    this.departureTime,
    this.releasedAt,
    this.locallyCompleted = false,
    this.awaitingSync = false,
  });

  final String manifestGuid;
  final int loadId;
  final String description;
  final int stopCount;
  final int occurrenceCount;
  final String? departureDate;
  final String? departureTime;
  final DateTime? releasedAt;
  final bool locallyCompleted;
  final bool awaitingSync;

  factory TripSummary.fromJson(Map<String, dynamic> json) {
    return TripSummary(
      manifestGuid: json['manifesto_guid']?.toString() ?? '',
      loadId: _integer(json['carga']),
      description: json['descricao']?.toString().trim() ?? '',
      stopCount: _integer(json['quantidade_paradas']),
      occurrenceCount: _integer(json['quantidade_ocorrencias']),
      departureDate: json['saida_data']?.toString(),
      departureTime: json['saida_hora']?.toString(),
      releasedAt: DateTime.tryParse(json['liberado_em']?.toString() ?? ''),
    );
  }
}

int _integer(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  _ => int.tryParse(value?.toString() ?? '') ?? 0,
};
