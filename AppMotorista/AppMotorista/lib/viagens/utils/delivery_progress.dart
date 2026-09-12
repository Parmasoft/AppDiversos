import 'package:flutter/material.dart';

import '../models/trip_detail.dart';

const completedDeliveryColor = Color(0xFFFFF8D6);
const pendingSyncDeliveryColor = Color(0xFFE3F2FD);

bool orderIsCompleted(TripOrder order) => order.status == 'E';

bool stopIsCompleted(TripStop stop) => stop.status == 'E';

bool occurrenceIsDelivered(ManifestOccurrence occurrence) =>
    occurrence.status == 'E';

bool tripIsCompleted(TripDetail trip) {
  return trip.stops.isNotEmpty &&
      trip.stops.every(
        (stop) =>
            stopIsCompleted(stop) &&
            stop.orders.isNotEmpty &&
            stop.orders.every(orderIsCompleted),
      );
}

List<TripOrder> ordersPendingFirst(Iterable<TripOrder> orders) {
  return _pendingFirst(orders, orderIsCompleted);
}

List<TripStop> stopsPendingFirst(Iterable<TripStop> stops) {
  return _pendingFirst(stops, stopIsCompleted);
}

List<ManifestOccurrence> occurrencesPendingFirst(
  Iterable<ManifestOccurrence> occurrences,
) {
  return _pendingFirst(occurrences, occurrenceIsDelivered);
}

List<T> _pendingFirst<T>(
  Iterable<T> values,
  bool Function(T value) isCompleted,
) {
  final pending = <T>[];
  final completed = <T>[];
  for (final value in values) {
    (isCompleted(value) ? completed : pending).add(value);
  }
  return List.unmodifiable([...pending, ...completed]);
}
