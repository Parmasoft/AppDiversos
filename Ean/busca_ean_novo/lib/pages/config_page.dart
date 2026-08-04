import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ConfigPage extends StatefulWidget {
  final String baseUrlAtual;

  const ConfigPage({super.key, required this.baseUrlAtual});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  bool _https = false;
  bool _testando = false;

  @override
  void initState() {
    super.initState();

    // tenta “quebrar” a baseUrl atual em host/porta
    final uri = Uri.tryParse(widget.baseUrlAtual);
    if (uri != null && uri.host.isNotEmpty) {
      _hostCtrl.text = uri.host;
      _portCtrl.text = (uri.hasPort ? uri.port : 5001).toString();
      _https = uri.scheme.toLowerCase() == 'https';
    } else {
      // fallback
      _hostCtrl.text = "192.168.0.250";
      _portCtrl.text = "5001";
      _https = false;
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  String _montarBaseUrl() {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 5001;
    final scheme = _https ? "https" : "http";
    return "$scheme://$host:$port";
  }

  Future<void> _salvar() async {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim());

    if (host.isEmpty || port == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Informe um HOST/IP e uma PORTA válidos."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final baseUrl = _montarBaseUrl();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("api_base_url", baseUrl);

    if (!mounted) return;
    Navigator.pop(context, baseUrl); // devolve a baseUrl nova pra tela inicial
  }

  Future<void> _testarConexao() async {
    setState(() => _testando = true);

    final baseUrl = _montarBaseUrl();
    try {
      // Teste “real”: tenta bater na rota que você já usa
      final url = Uri.parse("$baseUrl/produto?cod=0");
      final resp = await http.get(url).timeout(const Duration(seconds: 4));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Conexão OK: $baseUrl"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Servidor respondeu, mas status ${resp.statusCode}."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Falha na conexão com: $baseUrl"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _testando = false);
    }
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black26),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configurar"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF9E3), Color(0xFFF7EFC7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 8),

              TextField(
                controller: _hostCtrl,
                decoration: _dec("IP / Host da API"),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _portCtrl,
                keyboardType: TextInputType.number,
                decoration: _dec("Porta"),
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                value: _https,
                onChanged: (v) => setState(() => _https = v),
                title: const Text("Usar HTTPS"),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(
                  "Base URL: ${_montarBaseUrl()}",
                  style: const TextStyle(color: Colors.black87),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _testando ? null : _testarConexao,
                      icon: _testando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering),
                      label: Text(_testando ? "Testando..." : "Testar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _salvar,
                      icon: const Icon(Icons.save),
                      label: const Text("Salvar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Colors.black26),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
