enum OutboxSyncState { synced, pending, sending, retry, rejected, conflict }

class OutboxOperation {
  const OutboxOperation({
    required this.operationGuid,
    required this.operationType,
    required this.payloadVersion,
    required this.driverGuid,
    required this.manifestGuid,
    required this.stopId,
    required this.orderId,
    required this.code,
    required this.deviceDateTime,
    required this.timezoneOffsetMinutes,
    required this.payloadJson,
    required this.state,
    required this.attemptCount,
    required this.createdAt,
    this.lastAttemptAt,
    this.nextAttemptAt,
    this.syncedAt,
    this.responseCode,
    this.responseJson,
    this.lastError,
    this.occurrenceGuid,
  });

  final String operationGuid;
  final String operationType;
  final int payloadVersion;
  final String driverGuid;
  final String manifestGuid;
  final String? occurrenceGuid;
  final int stopId;
  final int orderId;
  final String code;
  final DateTime deviceDateTime;
  final int timezoneOffsetMinutes;
  final String payloadJson;
  final OutboxSyncState state;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final DateTime? nextAttemptAt;
  final DateTime? syncedAt;
  final String? responseCode;
  final String? responseJson;
  final String? lastError;

  Map<String, Object?> toMap() => {
    'operation_guid': operationGuid,
    'operation_type': operationType,
    'payload_version': payloadVersion,
    'driver_guid': driverGuid,
    'manifest_guid': manifestGuid,
    'occurrence_guid': occurrenceGuid,
    'stop_id': stopId,
    'order_id': orderId,
    'code': code,
    'device_datetime': _date(deviceDateTime),
    'timezone_offset_minutes': timezoneOffsetMinutes,
    'payload_json': payloadJson,
    'state': state.name,
    'attempt_count': attemptCount,
    'created_at': _date(createdAt),
    'last_attempt_at': _nullableDate(lastAttemptAt),
    'next_attempt_at': _nullableDate(nextAttemptAt),
    'synced_at': _nullableDate(syncedAt),
    'response_code': responseCode,
    'response_json': responseJson,
    'last_error': lastError,
  };

  factory OutboxOperation.fromMap(Map<String, Object?> row) {
    return OutboxOperation(
      operationGuid: _string(row, 'operation_guid'),
      operationType: _string(row, 'operation_type'),
      payloadVersion: _integer(row, 'payload_version'),
      driverGuid: _string(row, 'driver_guid'),
      manifestGuid: _string(row, 'manifest_guid'),
      occurrenceGuid: _nullableString(row, 'occurrence_guid'),
      stopId: _integer(row, 'stop_id'),
      orderId: _integer(row, 'order_id'),
      code: _string(row, 'code'),
      deviceDateTime: DateTime.parse(_string(row, 'device_datetime')),
      timezoneOffsetMinutes: _integer(row, 'timezone_offset_minutes'),
      payloadJson: _string(row, 'payload_json'),
      state: OutboxSyncState.values.byName(_string(row, 'state')),
      attemptCount: _integer(row, 'attempt_count'),
      createdAt: DateTime.parse(_string(row, 'created_at')),
      lastAttemptAt: _nullableDateTime(row, 'last_attempt_at'),
      nextAttemptAt: _nullableDateTime(row, 'next_attempt_at'),
      syncedAt: _nullableDateTime(row, 'synced_at'),
      responseCode: _nullableString(row, 'response_code'),
      responseJson: _nullableString(row, 'response_json'),
      lastError: _nullableString(row, 'last_error'),
    );
  }
}

String _date(DateTime value) => value.toUtc().toIso8601String();

String? _nullableDate(DateTime? value) => value == null ? null : _date(value);

String _string(Map<String, Object?> row, String field) =>
    row[field]?.toString() ?? '';

String? _nullableString(Map<String, Object?> row, String field) =>
    row[field]?.toString();

int _integer(Map<String, Object?> row, String field) =>
    (row[field] as num).toInt();

DateTime? _nullableDateTime(Map<String, Object?> row, String field) {
  final value = _nullableString(row, field);
  return value == null ? null : DateTime.parse(value);
}
