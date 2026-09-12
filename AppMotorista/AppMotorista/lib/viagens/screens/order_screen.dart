import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/display_format.dart';
import '../models/trip_detail.dart';
import '../services/delivery_scanner_controller.dart';
import '../services/hardware_barcode_buffer.dart';
import '../services/trips_service.dart';
import '../utils/delivery_progress.dart';
import 'camera_scanner_screen.dart';

enum OrderScreenResult { changed, orderCompleted, stopCompleted }

class OrderScreen extends StatefulWidget {
  const OrderScreen({
    required this.manifestGuid,
    required this.stopId,
    required this.order,
    required this.occurrences,
    required this.tripsService,
    this.cameraReader,
    super.key,
  });

  final String manifestGuid;
  final int stopId;
  final TripOrder order;
  final List<ManifestOccurrence> occurrences;
  final DeliveryGateway tripsService;
  final Future<String?> Function(BuildContext context)? cameraReader;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  late final DeliveryScannerController _scanner;
  final _hardwareFocus = FocusNode(debugLabel: 'leitor-fisico');
  final _hardwareBuffer = HardwareBarcodeBuffer();

  @override
  void initState() {
    super.initState();
    _scanner = DeliveryScannerController(
      gateway: widget.tripsService,
      manifestGuid: widget.manifestGuid,
      stopId: widget.stopId,
      order: widget.order,
      occurrences: widget.occurrences,
    )..addListener(_onScannerChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _restoreHardwareFocus(),
    );
  }

  @override
  void dispose() {
    _scanner
      ..removeListener(_onScannerChanged)
      ..dispose();
    _hardwareFocus.dispose();
    super.dispose();
  }

  void _onScannerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submit(String code) async {
    final status = await _scanner.submit(code);
    if (!mounted) return;
    if (status == ScanSubmitStatus.sent) {
      final feedback = _scanner.feedback;
      if (feedback?.kind == DeliveryFeedbackKind.success) {
        HapticFeedback.mediumImpact();
      } else if (feedback != null) {
        HapticFeedback.vibrate();
      }
      if (feedback?.kind == DeliveryFeedbackKind.success) {
        if (_scanner.stopCompleted) {
          Navigator.of(context).pop(OrderScreenResult.stopCompleted);
          return;
        }
        if (_scanner.order.status == 'E') {
          Navigator.of(context).pop(OrderScreenResult.orderCompleted);
          return;
        }
      }
    }
    _restoreHardwareFocus();
  }

  void _onHardwareKey(KeyEvent event) {
    if (_scanner.busy) {
      _hardwareBuffer.clear();
      return;
    }
    final code = _hardwareBuffer.handle(event);
    if (code != null) _submit(code);
  }

  Future<void> _openCamera() async {
    if (_scanner.busy) return;
    _hardwareBuffer.clear();
    _hardwareFocus.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    if (!context.mounted) return;
    final code = await _readCameraCode();
    if (!mounted) return;
    if (code != null && code.trim().isNotEmpty) await _submit(code);
    _restoreHardwareFocus();
  }

  Future<String?> _readCameraCode() {
    final cameraReader = widget.cameraReader;
    if (cameraReader != null) return cameraReader(context);
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const CameraScannerScreen()),
    );
  }

  void _restoreHardwareFocus() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hardwareFocus.requestFocus();
    });
  }

  void _close() {
    if (!_scanner.busy) {
      Navigator.of(
        context,
      ).pop(_scanner.changed ? OrderScreenResult.changed : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderedOccurrences = occurrencesPendingFirst(_scanner.occurrences);
    return KeyboardListener(
      focusNode: _hardwareFocus,
      autofocus: true,
      onKeyEvent: _onHardwareKey,
      child: PopScope<OrderScreenResult>(
        canPop: !_scanner.busy,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: _scanner.busy ? null : _close,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Voltar',
            ),
            title: const Text('Pedido'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(
                'PEDIDO ${_scanner.order.id}',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _CountCard(
                      label: 'Pendentes',
                      value: _scanner.pending,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CountCard(
                      label: 'Entregues',
                      value: _scanner.delivered,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ScannerArea(busy: _scanner.busy, onCamera: _openCamera),
              if (_scanner.feedback case final feedback?) ...[
                const SizedBox(height: 12),
                _FeedbackCard(feedback: feedback),
              ],
              if (_scanner.order.status == 'E') ...[
                const SizedBox(height: 12),
                const _CompletionCard(
                  icon: Icons.task_alt,
                  message: 'Pedido concluído.',
                ),
              ],
              if (_scanner.stopCompleted) ...[
                const SizedBox(height: 12),
                const _CompletionCard(
                  icon: Icons.location_on,
                  message: 'Parada concluída.',
                ),
              ],
              const SizedBox(height: 28),
              Text(
                'Etiquetas esperadas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Cada linha representa uma ocorrência do manifesto.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              for (final occurrence in orderedOccurrences) ...[
                _OccurrenceCard(occurrence: occurrence),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerArea extends StatelessWidget {
  const _ScannerArea({required this.busy, required this.onCamera});

  final bool busy;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 58,
            child: ElevatedButton.icon(
              onPressed: busy ? null : onCamera,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_scanner, size: 24),
              label: Text(
                busy ? 'Processando etiqueta...' : 'Ler etiqueta com câmera',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.barcode_reader,
                size: 18,
                color: busy ? Colors.black38 : const Color(0xFF176B3A),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  busy
                      ? 'Aguarde o retorno da leitura'
                      : 'Leitor físico pronto — envie com ENTER',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.feedback});

  final DeliveryFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (feedback.kind) {
      DeliveryFeedbackKind.success => (
        const Color(0xFF176B3A),
        Icons.check_circle,
      ),
      DeliveryFeedbackKind.warning => (
        const Color(0xFF8A4B00),
        Icons.warning_amber,
      ),
      DeliveryFeedbackKind.error => (
        Theme.of(context).colorScheme.error,
        Icons.error_outline,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Card(
        color: color.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  feedback.message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF176B3A);
    return Card(
      color: color.withValues(alpha: 0.10),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          message,
          style: const TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Column(
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({required this.occurrence});

  final ManifestOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final isDelivered = occurrence.isDelivered;
    final color = isDelivered
        ? const Color(0xFF176B3A)
        : const Color(0xFF8A4B00);
    return Card(
      key: ValueKey('occurrence-card-${occurrence.guid}'),
      color: isDelivered ? completedDeliveryColor : null,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Text(
            occurrence.type,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          'Produto ${occurrence.productId}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            occurrenceStatus(occurrence.status),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        children: [
          _Detail(label: 'Quantidade', value: occurrence.quantity),
          if (occurrence.type == 'R' && occurrence.rollId != null)
            _Detail(label: 'Rolo', value: '${occurrence.rollId}'),
          if (occurrence.code.isNotEmpty)
            _Detail(label: 'Código', value: occurrence.code),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
