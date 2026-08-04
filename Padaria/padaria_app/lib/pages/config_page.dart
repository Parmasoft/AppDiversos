import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController();

  bool _testando = false;

  @override
  void initState() {
    super.initState();
    _ipCtrl.text = ApiService.ip;
    _portCtrl.text = ApiService.port;
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _salvar() async {
    final ip = _ipCtrl.text.trim();
    final port = _portCtrl.text.trim();

    if (ip.isEmpty || port.isEmpty) {
      _snack('Preencha IP e Porta.');
      return;
    }

    await ApiService.salvarConfig(ip: ip, port: port);
    _snack('✅ Configuração salva!');
  }

  Future<void> _testar() async {
    final ip = _ipCtrl.text.trim();
    final port = _portCtrl.text.trim();

    if (ip.isEmpty || port.isEmpty) {
      _snack('Preencha IP e Porta antes de testar.');
      return;
    }

    setState(() => _testando = true);

    try {
      final url = Uri.parse('http://$ip:$port/ping');
      final resp = await http.get(url).timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        _snack('✅ Conexão OK! (/ping respondeu)');
      } else {
        _snack('⚠️ Respondeu, mas status ${resp.statusCode}.');
      }
    } catch (_) {
      if (!mounted) return;
      _snack('❌ Falha na conexão. Verifique IP/porta e rede.');
    } finally {
      if (mounted) setState(() => _testando = false);
    }
  }

  InputDecoration _decorCampo(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.black26),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.black54),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _capsuleTitulo(String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black26),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuração'), centerTitle: true),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3B0), // amarelinho claro
              Color(0xFFFFE08A), // amarelinho mais forte
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _capsuleTitulo('Servidor / API'),
              const SizedBox(height: 12),

              TextField(
                controller: _ipCtrl,
                keyboardType: TextInputType.number,
                decoration: _decorCampo('IP do Servidor', 'Ex: 192.168.0.10'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _portCtrl,
                keyboardType: TextInputType.number,
                decoration: _decorCampo('Porta', 'Ex: 5002'),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _salvar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Salvar',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _testando ? null : _testar,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: Colors.white.withOpacity(0.6),
                        ),
                        child: Text(
                          _testando ? 'Testando...' : 'Testar',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black26),
                ),
                child: Text(
                  'Dica: use o botão "Testar" para validar a conexão. '
                  'Depois clique "Salvar" para gravar no aparelho.\n\n'
                  'URL de teste: http://IP:PORT/ping',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
