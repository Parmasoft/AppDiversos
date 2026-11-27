import '../models/trip_summary.dart';

/// Pending/partial trips first, then fully completed trips. Within each group,
/// newest release (or departure) is first and the manifest GUID is a stable tie-breaker.
List<TripSummary> sortTripsByEffectiveState(Iterable<TripSummary> trips) {
  final ordered = List<TripSummary>.of(trips);
  ordered.sort((left, right) {
    final completion = (_isCompleted(left) ? 1 : 0).compareTo(
      _isCompleted(right) ? 1 : 0,
    );
    if (completion != 0) return completion;
    final recency = _createdAt(right).compareTo(_createdAt(left));
    if (recency != 0) return recency;
    return left.manifestGuid.compareTo(right.manifestGuid);
  });
  return List.unmodifiable(ordered);
}

bool _isCompleted(TripSummary trip) => trip.locallyCompleted;

DateTime _createdAt(TripSummary trip) {
  if (trip.releasedAt != null) return trip.releasedAt!;
  final date = trip.departureDate?.trim() ?? '';
  final time = trip.departureTime?.trim() ?? '';
  return DateTime.tryParse(time.isEmpty ? date : '${date}T$time') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
