import 'package:flutter/material.dart';

import '../../core/widgets/async_message.dart';
import '../../sync/local/outbox_local_store.dart';
import '../../sync/models/outbox_operation.dart';

class SyncDiagnosticScreen extends StatefulWidget {
  const SyncDiagnosticScreen({
    required this.outboxLocalStore,
    required this.driverGuid,
    super.key,
  });

  final OutboxLocalStore outboxLocalStore;
  final String driverGuid;

  @override
  State<SyncDiagnosticScreen> createState() => _SyncDiagnosticScreenState();
}

class _SyncDiagnosticScreenState extends State<SyncDiagnosticScreen> {
  late Future<List<OutboxOperation>> _operations;

  @override
  void initState() {
    super.initState();
    _operations = _readOperations();
  }

  Future<List<OutboxOperation>> _readOperations() =>
      widget.outboxLocalStore.listForDiagnostic(driverGuid: widget.driverGuid);

  Future<void> _reload() async {
    final operations = _readOperations();
    setState(() => _operations = operations);
    await operations;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico de sincronização'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<OutboxOperation>>(
        future: _operations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AsyncMessage(
              icon: Icons.error_outline,
              title: 'Não foi possível ler a outbox local',
              message: 'Nenhuma operação foi alterada.',
              actionLabel: 'ATUALIZAR',
              onAction: _reload,
            );
          }
          final operations = snapshot.data ?? const [];
          if (operations.isEmpty) {
            return const AsyncMessage(
              icon: Icons.inbox_outlined,
              title: 'Nenhuma operação na outbox',
              message: 'A consulta é somente leitura e mostra a fila local atual.',
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: operations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _OperationCard(operation: operations[index]),
            ),
          );
        },
      ),
    );
  }
}

class _OperationCard extends StatelessWidget {
  const _OperationCard({required this.operation});

  final OutboxOperation operation;

  @override
  Widget build(BuildContext context) {
    final state = operation.state.name.toUpperCase();
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          'Pedido ${operation.orderId}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text('Estado: $state • Parada ${operation.stopId}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _DetailsTable(operation: operation),
        ],
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.operation});

  final OutboxOperation operation;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Manifesto', operation.manifestGuid),
      ('Pedido', operation.orderId.toString()),
      ('Parada', operation.stopId.toString()),
      ('Occurrence GUID', operation.occurrenceGuid ?? 'Não informado'),
      ('Operation GUID', operation.operationGuid),
      ('Tipo', operation.operationType),
      ('Estado', operation.state.name.toUpperCase()),
      ('Tentativas', operation.attemptCount.toString()),
      ('Criada em', _formatDateTime(operation.createdAt)),
      ('Última tentativa', _formatDateTime(operation.lastAttemptAt)),
      ('Próxima tentativa', _formatDateTime(operation.nextAttemptAt)),
      ('Sincronizada em', _formatDateTime(operation.syncedAt)),
      ('Último erro', operation.lastError ?? 'Nenhum'),
      ('Código da resposta', operation.responseCode ?? 'Não informado'),
      if (_hasValue(operation.responseJson)) ('Resposta', operation.responseJson!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.$1, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  SelectableText(row.$2),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

String _formatDateTime(DateTime? value) {
  if (value == null) return 'Não informado';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
