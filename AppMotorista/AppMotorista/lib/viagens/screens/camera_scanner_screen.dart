import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({this.preserveCase = false, super.key});

  final bool preserveCase;

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.code128, BarcodeFormat.qrCode],
  );

  static const _debounce = Duration(milliseconds: 800);

  String? _lastCode;
  DateTime? _lastReadAt;
  bool _processing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || capture.barcodes.isEmpty) return;

    final rawCode = capture.barcodes.first.rawValue;
    if (rawCode == null) return;
    final code = widget.preserveCase
        ? rawCode.trim()
        : rawCode.trim().toUpperCase();
    if (code.isEmpty) return;

    final now = DateTime.now();
    if (_lastCode == code &&
        _lastReadAt != null &&
        now.difference(_lastReadAt!) < _debounce) {
      return;
    }

    _lastCode = code;
    _lastReadAt = now;
    _processing = true;
    await _controller.stop();
    if (mounted) Navigator.of(context).pop(code);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: IconButton.filledTonal(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              tooltip: 'Fechar câmera',
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Aponte a etiqueta dentro do quadrado',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
