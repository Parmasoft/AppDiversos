import 'package:flutter/foundation.dart';

import '../models/trip_detail.dart';
import '../models/trip_summary.dart';

typedef TripSnapshotReader =
    Future<TripDetail?> Function({
      required String driverGuid,
      required String manifestGuid,
    });

typedef PendingStopIdsReader =
    Future<Set<int>> Function({
      required String driverGuid,
      required String manifestGuid,
    });

typedef PendingOrderIdsReader =
    Future<Set<int>> Function({
      required String driverGuid,
      required String manifestGuid,
      required int stopId,
    });

/// Immutable local projection published only after SQLite has committed.
class TripStateSnapshot {
  const TripStateSnapshot({
    required this.driverGuid,
    required this.trip,
    required this.awaitingSync,
    required this.pendingStopIds,
    required this.pendingOrderIdsByStop,
    required this.offlineAvailability,
    required this.revision,
  });

  final String driverGuid;
  final TripDetail trip;

  /// Manifest-level indicator, intended only for the load summary.
  final bool awaitingSync;
  final Set<int> pendingStopIds;
  final Map<int, Set<int>> pendingOrderIdsByStop;
  final OfflineAvailability offlineAvailability;
  final int revision;
}

/// Single in-memory, scoped view of the persisted trip state.
///
/// The database remains the source of truth. A monotonically increasing token
/// per manifest prevents a slow, older read from replacing a newer projection.
class TripStateController extends ChangeNotifier {
  TripStateController({
    required String scope,
    required String? Function() activeDriverGuid,
    required TripSnapshotReader readSnapshot,
    required PendingStopIdsReader pendingStopIds,
    required PendingOrderIdsReader pendingOrderIds,
  }) : _scope = scope,
       _activeDriverGuid = activeDriverGuid,
       _readSnapshot = readSnapshot,
       _pendingStopIds = pendingStopIds,
       _pendingOrderIds = pendingOrderIds;

  final String _scope;
  final String? Function() _activeDriverGuid;
  final TripSnapshotReader _readSnapshot;
  final PendingStopIdsReader _pendingStopIds;
  final PendingOrderIdsReader _pendingOrderIds;
  final Map<String, TripStateSnapshot> _snapshots = {};
  final Map<String, int> _requests = {};
  int _revision = 0;

  TripStateSnapshot? snapshotFor({
    required String driverGuid,
    required String manifestGuid,
  }) => _snapshots[_key(driverGuid, manifestGuid)];

  TripStateSnapshot? activeSnapshotFor(String manifestGuid) {
    final driverGuid = _activeDriverGuid()?.trim() ?? '';
    if (driverGuid.isEmpty) return null;
    return snapshotFor(driverGuid: driverGuid, manifestGuid: manifestGuid);
  }

  /// Reads the committed local snapshot and makes that exact projection visible.
  Future<void> publish({
    required String driverGuid,
    required String manifestGuid,
  }) async {
    if (!_isActiveDriver(driverGuid)) return;
    final key = _key(driverGuid, manifestGuid);
    final request = (_requests[key] ?? 0) + 1;
    _requests[key] = request;
    final trip = await _readSnapshot(
      driverGuid: driverGuid,
      manifestGuid: manifestGuid,
    );
    if (_requests[key] != request || !_isActiveDriver(driverGuid)) return;
    if (trip == null) {
      if (_snapshots.remove(key) != null) notifyListeners();
      return;
    }
    final pendingStopIds = await _pendingStopIds(
      driverGuid: driverGuid,
      manifestGuid: manifestGuid,
    );
    final pendingOrderIds = await Future.wait([
      for (final stop in trip.stops)
        _pendingOrderIds(
          driverGuid: driverGuid,
          manifestGuid: manifestGuid,
          stopId: stop.id,
        ),
    ]);
    if (_requests[key] != request || !_isActiveDriver(driverGuid)) return;
    final pendingOrdersByStop = <int, Set<int>>{
      for (var index = 0; index < trip.stops.length; index++)
        trip.stops[index].id: Set.unmodifiable(pendingOrderIds[index]),
    };
    _snapshots[key] = TripStateSnapshot(
      driverGuid: driverGuid,
      trip: trip,
      awaitingSync: pendingStopIds.isNotEmpty,
      pendingStopIds: Set.unmodifiable(pendingStopIds),
      pendingOrderIdsByStop: Map.unmodifiable(pendingOrdersByStop),
      // A TripStateSnapshot is published only after readSnapshot finds the
      // committed complete SQLite snapshot.
      offlineAvailability: OfflineAvailability.available,
      revision: ++_revision,
    );
    notifyListeners();
  }

  void clearInactive() {
    final activeDriver = _activeDriverGuid()?.trim();
    final obsolete = _snapshots.keys
        .where((key) => !key.startsWith('$_scope/${activeDriver ?? ''}/'))
        .toList(growable: false);
    if (obsolete.isEmpty) return;
    for (final key in obsolete) {
      _snapshots.remove(key);
      _requests.remove(key);
    }
    notifyListeners();
  }

  bool _isActiveDriver(String driverGuid) =>
      _activeDriverGuid()?.trim() == driverGuid.trim() && driverGuid.isNotEmpty;

  String _key(String driverGuid, String manifestGuid) =>
      '$_scope/${driverGuid.trim()}/${manifestGuid.trim()}';
}
