import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/leitura_etiqueta_separacao.dart';

class ScannerPage extends StatefulWidget {
  final bool aceitarQualquerCodigo;

  const ScannerPage({super.key, this.aceitarQualquerCodigo = false});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.code128, BarcodeFormat.qrCode],
  );

  String? _lastCode;
  DateTime? _lastReadTime;
  bool _processing = false;

  static const int debounceMs = 800;

  //bool _isValidCode(String code) {
  //  if (!RegExp(r'^\d+$').hasMatch(code)) return false;
  //  return code.length >= 8 && code.length <= 14;
  // }
  //bool _isValidCode(String code) {
  //  final codigo = code.trim().toUpperCase();
  //
  //  // Projeto de rolos:
  //  // Aceita somente etiqueta Code128 no padrão:
  //  // R + PROR_ID 6 dígitos + produto 7 dígitos + quantidade 4 dígitos
  //  // Exemplo: R00138100089451020
  //  return RegExp(r'^R\d{17}$').hasMatch(codigo);
  //}

  bool _isValidCode(String code) {
    if (widget.aceitarQualquerCodigo) {
      return code.trim().isNotEmpty;
    }

    return LeituraEtiquetaSeparacao.identificar(code) != null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    final codeBruto = barcode.rawValue;

    print("===== SCANNER DETECTOU =====");
    print("Formato: ${barcode.format}");
    print("Valor bruto: $codeBruto");
    print("============================");

    if (codeBruto == null) {
      print("Código ignorado: valor nulo");
      return;
    }

    final code = codeBruto.trim().toUpperCase();

    //if (!_isValidCode(code)) {
    //  print("Código ignorado pela validação de rolo: $code");
    //  return;
    //}
    if (!_isValidCode(code)) {
      print("Código ignorado pela validação da separação: $code");
      return;
    }

    final now = DateTime.now();

    if (_lastCode == code &&
        _lastReadTime != null &&
        now.difference(_lastReadTime!).inMilliseconds < debounceMs) {
      print("Código ignorado por debounce: $code");
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
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: const Text(
                'Aponte o QR Code dentro do quadrado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
