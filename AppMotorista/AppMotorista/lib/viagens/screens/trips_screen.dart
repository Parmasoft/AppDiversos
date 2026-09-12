import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/services/session_controller.dart';
import '../../core/errors/api_exception.dart';
import '../../core/utils/display_format.dart';
import '../../core/widgets/async_message.dart';
import '../../core/widgets/completion_dialog.dart';
import '../../core/widgets/offline_cache_banner.dart';
import '../models/trip_summary.dart';
import '../services/trips_service.dart';
import '../utils/delivery_progress.dart';
import 'trip_detail_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({
    required this.sessionController,
    required this.tripsService,
    this.syncEvents,
    this.readOnly = false,
    super.key,
  });

  final SessionController sessionController;
  final TripsGateway tripsService;
  final Listenable? syncEvents;
  final bool readOnly;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  late Future<List<TripSummary>> _trips;
  String? _recentlyCompletedManifestGuid;

  @override
  void initState() {
    super.initState();
    _trips = widget.tripsService.list();
    widget.syncEvents?.addListener(_handleSyncEvent);
  }

  @override
  void didUpdateWidget(covariant TripsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncEvents == widget.syncEvents) return;
    oldWidget.syncEvents?.removeListener(_handleSyncEvent);
    widget.syncEvents?.addListener(_handleSyncEvent);
  }

  @override
  void dispose() {
    widget.syncEvents?.removeListener(_handleSyncEvent);
    super.dispose();
  }

  void _handleSyncEvent() {
    if (!mounted) return;
    unawaited(_reload().catchError((Object _) {}));
  }

  Future<void> _reload() async {
    final future = widget.tripsService.list();
    setState(() {
      _trips = future;
    });
    await future;
  }

  Future<void> _openTrip(TripSummary trip) async {
    final result = await Navigator.of(context).push<TripDetailResult>(
      MaterialPageRoute<TripDetailResult>(
        builder: (_) => TripDetailScreen(
          manifestGuid: trip.manifestGuid,
          tripsService: widget.tripsService,
          syncEvents: widget.syncEvents,
          readOnly: widget.readOnly,
        ),
      ),
    );
    if (!mounted || result != TripDetailResult.completed) return;

    setState(() {
      _recentlyCompletedManifestGuid = trip.manifestGuid;
    });

    try {
      await _reload();
    } catch (_) {
      // O FutureBuilder apresenta o erro da recarga oficial da lista.
    }
    if (!mounted) return;

    final awaitingSync = await _hasPendingSync(trip.manifestGuid);
    if (!mounted) return;
    await showCompletionDialog(
      context,
      message: 'Carga concluída com sucesso.',
      detail: awaitingSync ? 'Aguardando sincronização.' : null,
    );
  }

  Future<bool> _hasPendingSync(String manifestGuid) async {
    final service = widget.tripsService;
    if (service is! PendingSyncStatus) return false;
    try {
      return await (service as PendingSyncStatus).hasPendingSync(manifestGuid);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas viagens'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: widget.sessionController.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<List<TripSummary>>(
        future: _trips,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AsyncMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Não foi possível carregar',
              message: _message(snapshot.error),
              actionLabel: 'TENTAR NOVAMENTE',
              onAction: _reload,
            );
          }
          final trips = snapshot.data ?? const [];
          if (trips.isEmpty) {
            return AsyncMessage(
              icon: Icons.route_outlined,
              title: 'Nenhuma viagem liberada',
              message:
                  'Quando uma carga for liberada para você, ela aparecerá aqui.',
              actionLabel: 'ATUALIZAR',
              onAction: _reload,
            );
          }
          final usesSavedData = switch (widget.tripsService) {
            final OfflineDataStatus status => status.listUsesSavedData,
            _ => false,
          };
          return Column(
            children: [
              if (usesSavedData) const OfflineCacheBanner(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    itemCount: trips.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) => _TripCard(
                      trip: trips[index],
                      completed:
                          trips[index].locallyCompleted ||
                          trips[index].manifestGuid ==
                              _recentlyCompletedManifestGuid,
                      awaitingSync: trips[index].awaitingSync,
                      onOpen: () => _openTrip(trips[index]),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _message(Object? error) {
    if (error is OfflineTripUnavailableException) return error.message;
    return error is ApiException
        ? error.message
        : 'Verifique sua conexão e tente novamente.';
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.completed,
    required this.awaitingSync,
    required this.onOpen,
  });

  final TripSummary trip;
  final bool completed;
  final bool awaitingSync;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final time = compactTime(trip.departureTime);
    final waitingForSync = completed && awaitingSync;
    return Card(
      key: ValueKey('trip-card-${trip.manifestGuid}'),
      color: waitingForSync
          ? pendingSyncDeliveryColor
          : completed
          ? completedDeliveryColor
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'CARGA ${trip.loadId}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                trip.description.isEmpty
                    ? 'Destino não informado'
                    : trip.description,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (waitingForSync) ...[
                const SizedBox(height: 8),
                Text(
                  'Aguardando sincronização',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF0D47A1),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _Info(
                    icon: Icons.calendar_today_outlined,
                    text: compactDate(trip.departureDate),
                  ),
                  if (time.isNotEmpty) _Info(icon: Icons.schedule, text: time),
                  _Info(
                    icon: Icons.location_on_outlined,
                    text: '${trip.stopCount} paradas',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: onOpen,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('ABRIR VIAGEM'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 21),
        const SizedBox(width: 7),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
