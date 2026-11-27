import 'package:app_motorista/viagens/models/trip_summary.dart';
import 'package:app_motorista/viagens/utils/trip_sort.dart';
import 'package:flutter_test/flutter_test.dart';

TripSummary _trip({
  required String guid,
  required bool completed,
  DateTime? releasedAt,
  String? departureDate,
  String? departureTime,
}) => TripSummary(
  manifestGuid: guid,
  loadId: 1,
  description: '',
  stopCount: 1,
  occurrenceCount: 1,
  locallyCompleted: completed,
  releasedAt: releasedAt,
  departureDate: departureDate,
  departureTime: departureTime,
);

void main() {
  test('keeps pending trips ahead of completed trips and newest first', () {
    final ordered = sortTripsByEffectiveState([
      _trip(guid: 'completed-new', completed: true, releasedAt: DateTime(2026, 11, 23, 12)),
      _trip(guid: 'pending-old', completed: false, releasedAt: DateTime(2026, 11, 20)),
      _trip(guid: 'pending-new', completed: false, releasedAt: DateTime(2026, 11, 23, 13)),
      _trip(guid: 'completed-old', completed: true, releasedAt: DateTime(2026, 11, 19)),
    ]);
    expect(ordered.map((trip) => trip.manifestGuid), [
      'pending-new', 'pending-old', 'completed-new', 'completed-old',
    ]);
  });

  test('uses departure date/time and manifest GUID as deterministic fallbacks', () {
    final ordered = sortTripsByEffectiveState([
      _trip(guid: 'B', completed: false, departureDate: '2026-11-23', departureTime: '08:00:00'),
      _trip(guid: 'A', completed: false, departureDate: '2026-11-23', departureTime: '08:00:00'),
      _trip(guid: 'C', completed: false, departureDate: '2026-11-22', departureTime: '23:00:00'),
    ]);
    expect(ordered.map((trip) => trip.manifestGuid), ['A', 'B', 'C']);
  });
}
