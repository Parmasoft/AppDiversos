import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cotacao_online/app/app_config.dart';

class VerificarApiPage extends StatefulWidget {
  final Widget onSuccess;

  const VerificarApiPage({super.key, required this.onSuccess});

  @override
  State<VerificarApiPage> createState() => _VerificarApiPageState();
}

class _VerificarApiPageState extends State<VerificarApiPage> {
  bool carregando = true;
  String? erro;

  @override
  void initState() {
    super.initState();
    testarApi();
  }

  Future<void> testarApi() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final resp = await http
          .get(Uri.parse('${AppConfig.baseUrl}/ping'))
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => widget.onSuccess),
        );
      } else {
        throw Exception('API respondeu com erro');
      }
    } catch (_) {
      setState(() {
        erro = 'Não foi possível conectar ao servidor.\n'
            'Verifique se a API está em execução.';
      });
    } finally {
      setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: carregando
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    erro ?? '',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: testarApi,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
      ),
    );
  }
}
