import 'package:flutter/material.dart';

import '../../core/errors/api_exception.dart';
import '../../core/utils/display_format.dart';
import '../../core/widgets/async_message.dart';
import '../../core/widgets/offline_cache_banner.dart';
import '../models/trip_detail.dart';
import '../services/trips_service.dart';
import '../utils/delivery_progress.dart';
import 'stop_screen.dart';

enum TripDetailResult { completed }

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({
    required this.manifestGuid,
    required this.tripsService,
    this.syncEvents,
    this.readOnly = false,
    super.key,
  });

  final String manifestGuid;
  final DeliveryGateway tripsService;
  final Listenable? syncEvents;
  final bool readOnly;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Future<TripDetail> _trip;
  Set<int> _stopsAwaitingSync = const {};

  @override
  void initState() {
    super.initState();
    _trip = _loadTrip();
    widget.syncEvents?.addListener(_reload);
  }

  @override
  void didUpdateWidget(covariant TripDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncEvents == widget.syncEvents) return;
    oldWidget.syncEvents?.removeListener(_reload);
    widget.syncEvents?.addListener(_reload);
  }

  @override
  void dispose() {
    widget.syncEvents?.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    final reloadedTrip = _loadTrip();
    setState(() {
      _trip = reloadedTrip;
    });
  }

  Future<void> _handleStopClosed(StopScreenResult? result) async {
    final reloadedTrip = _loadTrip();
    setState(() {
      _trip = reloadedTrip;
    });
    try {
      final officialTrip = await reloadedTrip;
      if (!mounted) return;
      if (result == StopScreenResult.completed &&
          tripIsCompleted(officialTrip)) {
        Navigator.of(context).pop(TripDetailResult.completed);
      }
    } catch (_) {
      // O FutureBuilder apresenta o erro. Sem retorno oficial, a viagem nao
      // e considerada concluida pelo App.
    }
  }

  Future<TripDetail> _loadTrip() async {
    final trip = await widget.tripsService.get(widget.manifestGuid);
    final service = widget.tripsService;
    if (service is PendingStopSyncStatus) {
      try {
        _stopsAwaitingSync = await (service as PendingStopSyncStatus)
            .pendingSyncStopIds(widget.manifestGuid);
      } catch (_) {
        _stopsAwaitingSync = const {};
      }
    } else {
      _stopsAwaitingSync = const {};
    }
    return trip;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viagem')),
      body: FutureBuilder<TripDetail>(
        future: _trip,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AsyncMessage(
              icon: Icons.error_outline,
              title: 'Viagem indisponível',
              message: _message(snapshot.error),
              actionLabel: 'TENTAR NOVAMENTE',
              onAction: _reload,
            );
          }
          return _TripBody(
            trip: snapshot.requireData,
            tripsService: widget.tripsService,
            syncEvents: widget.syncEvents,
            onStopClosed: _handleStopClosed,
            stopsAwaitingSync: _stopsAwaitingSync,
            usesSavedData: switch (widget.tripsService) {
              final OfflineDataStatus status => status.tripUsesSavedData(
                widget.manifestGuid,
              ),
              _ => false,
            },
            readOnly: widget.readOnly,
          );
        },
      ),
    );
  }

  String _message(Object? error) {
    if (error is OfflineTripUnavailableException) return error.message;
    if (error is ApiException) return error.message;
    return 'Não foi possível abrir esta viagem.';
  }
}

class _TripBody extends StatelessWidget {
  const _TripBody({
    required this.trip,
    required this.tripsService,
    required this.onStopClosed,
    required this.usesSavedData,
    required this.stopsAwaitingSync,
    required this.syncEvents,
    required this.readOnly,
  });

  final TripDetail trip;
  final DeliveryGateway tripsService;
  final Future<void> Function(StopScreenResult? result) onStopClosed;
  final bool usesSavedData;
  final Set<int> stopsAwaitingSync;
  final Listenable? syncEvents;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final time = compactTime(trip.departureTime);
    final orderedStops = stopsPendingFirst(trip.stops);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (usesSavedData) ...[
          const OfflineCacheBanner(),
          const SizedBox(height: 12),
        ],
        Text(
          'CARGA ${trip.loadId}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 5),
        Text(
          trip.description.isEmpty ? 'Destino não informado' : trip.description,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 16),
        Text(
          '${compactDate(trip.departureDate)}${time.isEmpty ? '' : ' · $time'}  •  ${trip.stops.length} paradas',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (trip.originName.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Origem: ${trip.originName}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 28),
        Text('Paradas', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final stop in orderedStops) ...[
          _StopCard(
            manifestGuid: trip.manifestGuid,
            stop: stop,
            awaitingSync: stopsAwaitingSync.contains(stop.id),
            tripsService: tripsService,
            syncEvents: syncEvents,
            readOnly: readOnly,
            onClosed: onStopClosed,
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.manifestGuid,
    required this.stop,
    required this.awaitingSync,
    required this.tripsService,
    required this.onClosed,
    required this.syncEvents,
    required this.readOnly,
  });

  final String manifestGuid;
  final TripStop stop;
  final bool awaitingSync;
  final DeliveryGateway tripsService;
  final Future<void> Function(StopScreenResult? result) onClosed;
  final Listenable? syncEvents;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final completed = stopIsCompleted(stop);
    final waitingForSync = completed && awaitingSync;
    final location = [
      stop.city,
      stop.state,
    ].where((value) => value.isNotEmpty).join(' / ');
    return Card(
      key: ValueKey('stop-card-${stop.id}'),
      color: waitingForSync
          ? pendingSyncDeliveryColor
          : completed
          ? completedDeliveryColor
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: completed ? null : () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'PARADA ${stop.plannedOrder}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 5),
              Text(
                stop.clientName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(location, style: Theme.of(context).textTheme.bodyLarge),
              ],
              const SizedBox(height: 10),
              Text(
                '${stop.orders.length} ${stop.orders.length == 1 ? 'pedido' : 'pedidos'}  •  ${stopStatus(stop.status)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (waitingForSync) ...[
                const SizedBox(height: 6),
                Text(
                  'Aguardando sincronização',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF0D47A1),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: completed ? null : () => _open(context),
                child: Text(completed ? 'PARADA CONCLUÍDA' : 'ABRIR PARADA'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    if (stopIsCompleted(stop)) return;
    final result = await Navigator.of(context).push<StopScreenResult>(
      MaterialPageRoute<StopScreenResult>(
        builder: (_) => StopScreen(
          manifestGuid: manifestGuid,
          stop: stop,
          tripsService: tripsService,
          syncEvents: syncEvents,
          readOnly: readOnly,
        ),
      ),
    );
    if (context.mounted) await onClosed(result);
  }
}
