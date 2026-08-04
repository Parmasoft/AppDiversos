import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  String? _lastCode;
  DateTime? _lastReadTime;
  bool _processing = false;

  static const int debounceMs = 800;

  bool _isValidCode(String code) {
    if (!RegExp(r'^\d+$').hasMatch(code)) return false;
    return code.length >= 8 && code.length <= 14;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;

    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue;

    if (code == null || !_isValidCode(code)) return;

    final now = DateTime.now();

    if (_lastCode == code &&
        _lastReadTime != null &&
        now.difference(_lastReadTime!).inMilliseconds < debounceMs) {
      return;
    }

    _lastCode = code;
    _lastReadTime = now;
    _processing = true;

    _controller.stop();

    Navigator.pop(context, code);
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

          // ⚠️ Overlay NUNCA REMOVER
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Aponte para o código de barras',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
