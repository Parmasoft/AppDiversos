import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/display_format.dart';
import '../../core/widgets/completion_dialog.dart';
import '../models/trip_detail.dart';
import '../services/trips_service.dart';
import '../services/trip_state_controller.dart';
import '../utils/delivery_progress.dart';
import 'order_screen.dart';

enum StopScreenResult { completed }

class StopScreen extends StatefulWidget {
  const StopScreen({
    required this.manifestGuid,
    required this.stop,
    required this.tripsService,
    this.syncEvents,
    this.tripStateController,
    this.readOnly = false,
    super.key,
  });

  final String manifestGuid;
  final TripStop stop;
  final DeliveryGateway tripsService;
  final Listenable? syncEvents;
  final TripStateController? tripStateController;
  final bool readOnly;

  @override
  State<StopScreen> createState() => _StopScreenState();
}

class _StopScreenState extends State<StopScreen> {
  late TripStop _stop;
  bool _refreshing = false;
  Set<int> _ordersAwaitingSync = const {};

  @override
  void initState() {
    super.initState();
    _stop = widget.stop;
    _refreshPendingSyncState();
    widget.syncEvents?.addListener(_handleSyncEvent);
    widget.tripStateController?.addListener(_applyLocalState);
  }

  @override
  void didUpdateWidget(covariant StopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncEvents != widget.syncEvents) {
      oldWidget.syncEvents?.removeListener(_handleSyncEvent);
      widget.syncEvents?.addListener(_handleSyncEvent);
    }
    if (oldWidget.tripStateController != widget.tripStateController) {
      oldWidget.tripStateController?.removeListener(_applyLocalState);
      widget.tripStateController?.addListener(_applyLocalState);
    }
  }

  @override
  void dispose() {
    widget.syncEvents?.removeListener(_handleSyncEvent);
    widget.tripStateController?.removeListener(_applyLocalState);
    super.dispose();
  }

  void _handleSyncEvent() {
    if (widget.tripStateController != null) return;
    unawaited(_reloadAfterSync());
  }

  void _applyLocalState() {
    if (!mounted) return;
    final state = widget.tripStateController?.activeSnapshotFor(
      widget.manifestGuid,
    );
    if (state == null) return;
    final stops = state.trip.stops.where((item) => item.id == _stop.id);
    if (stops.isEmpty) return;
    setState(() {
      _stop = stops.first;
      _ordersAwaitingSync = state.pendingOrderIdsByStop[_stop.id] ?? const {};
    });
  }

  Future<void> _reloadAfterSync() async {
    if (!mounted) return;
    _applyLocalState();
    try {
      final trip = await widget.tripsService.get(widget.manifestGuid);
      final refreshed = trip.stops.where((item) => item.id == _stop.id);
      if (refreshed.isNotEmpty && mounted) {
        setState(() => _stop = refreshed.first);
      }
      await _refreshPendingSyncState();
    } catch (_) {
      // A sincronizacao persiste; a proxima recarga atualiza a apresentacao.
    }
  }

  Future<void> _openOrder(TripOrder order) async {
    if (widget.readOnly) return;
    if (orderIsCompleted(order)) return;
    final result = await Navigator.of(context).push<OrderScreenResult>(
      MaterialPageRoute<OrderScreenResult>(
        builder: (_) => OrderScreen(
          manifestGuid: widget.manifestGuid,
          stopId: _stop.id,
          order: order,
          occurrences: _stop.occurrencesFor(order.id),
          tripsService: widget.tripsService,
        ),
      ),
    );
    if (!mounted) return;
    final orderCompleted =
        result == OrderScreenResult.orderCompleted ||
        result == OrderScreenResult.stopCompleted;
    if (orderCompleted) {
      _applyCompletedOrder(
        order.id,
        stopCompleted: result == OrderScreenResult.stopCompleted,
      );
    }

    if (result != OrderScreenResult.stopCompleted &&
        widget.tripStateController == null) {
      setState(() => _refreshing = true);
      try {
        final trip = await widget.tripsService.get(widget.manifestGuid);
        final refreshed = trip.stops.where((item) => item.id == _stop.id);
        if (refreshed.isNotEmpty && mounted) {
          setState(() => _stop = refreshed.first);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível atualizar os dados da parada.'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _refreshing = false);
      }
    }

    if (!mounted) return;
    if (orderCompleted) {
      await _refreshPendingSyncState();
      if (!mounted) return;
      final awaitingSync = await _hasPendingSync();
      if (!mounted) return;
      await showCompletionDialog(
        context,
        message: 'Pedido recepcionado com sucesso.',
        detail: awaitingSync ? 'Aguardando sincronização.' : null,
      );
      if (!mounted) return;
    }
    if (result == OrderScreenResult.stopCompleted || stopIsCompleted(_stop)) {
      Navigator.of(context).pop(StopScreenResult.completed);
    }
  }

  Future<void> _refreshPendingSyncState() async {
    final service = widget.tripsService;
    if (service is! PendingOrderSyncStatus) return;
    try {
      final pendingOrders = await (service as PendingOrderSyncStatus)
          .pendingSyncOrderIds(
            manifestGuid: widget.manifestGuid,
            stopId: _stop.id,
          );
      if (mounted) setState(() => _ordersAwaitingSync = pendingOrders);
    } catch (_) {
      // A falta do indicador visual nao altera o estado operacional persistido.
    }
  }

  Future<bool> _hasPendingSync() async {
    final service = widget.tripsService;
    if (service is! PendingSyncStatus) return false;
    try {
      return await (service as PendingSyncStatus).hasPendingSync(
        widget.manifestGuid,
      );
    } catch (_) {
      return false;
    }
  }

  void _applyCompletedOrder(int orderId, {required bool stopCompleted}) {
    setState(() {
      _stop = TripStop(
        id: _stop.id,
        plannedOrder: _stop.plannedOrder,
        status: stopCompleted ? 'E' : _stop.status,
        clientName: _stop.clientName,
        city: _stop.city,
        state: _stop.state,
        address: _stop.address,
        orders: [
          for (final order in _stop.orders)
            order.id == orderId ? order.copyWith(status: 'E') : order,
        ],
        occurrences: _stop.occurrences,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderedOrders = ordersPendingFirst(_stop.orders);
    final location = [
      _stop.city,
      _stop.state,
    ].where((value) => value.isNotEmpty).join(' / ');
    return Scaffold(
      appBar: AppBar(title: const Text('Parada')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_refreshing) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
          ],
          Text('CLIENTE', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            _stop.clientName,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(location, style: Theme.of(context).textTheme.bodyLarge),
          ],
          if (_stop.address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_stop.address, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 12),
          Text(
            stopStatus(_stop.status),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          Text('Pedidos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final order in orderedOrders) ...[
            _OrderCard(
              stop: _stop,
              order: order,
              awaitingSync: _ordersAwaitingSync.contains(order.id),
              onOpen: widget.readOnly ? null : () => _openOrder(order),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.stop,
    required this.order,
    required this.awaitingSync,
    required this.onOpen,
  });

  final TripStop stop;
  final TripOrder order;
  final bool awaitingSync;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final completed = orderIsCompleted(order);
    final waitingForSync = completed && awaitingSync;
    final pending = stop.pendingFor(order.id);
    final delivered = stop.deliveredFor(order.id);
    return Card(
      key: ValueKey('order-card-${order.id}'),
      color: waitingForSync
          ? pendingSyncDeliveryColor
          : completed
          ? completedDeliveryColor
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: completed ? null : onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pedido ${order.id}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                completed
                    ? 'Concluído'
                    : '$pending ${pending == 1 ? 'etiqueta pendente' : 'etiquetas pendentes'}',
                style: Theme.of(context).textTheme.bodyLarge,
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
              if (delivered > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$delivered entregues',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: completed ? null : onOpen,
                child: Text(completed ? 'PEDIDO CONCLUÍDO' : 'ABRIR PEDIDO'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
