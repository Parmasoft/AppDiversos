import 'package:flutter/material.dart';
import 'package:pedido/services/server_config.dart';
import '../core/app_colors.dart';
import 'package:http/http.dart' as http;
import '../services/server_config.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final TextEditingController ipController = TextEditingController(
    text: "192.168.1.238",
  );

  final TextEditingController portaController = TextEditingController(
    text: "5002",
  );

  Future<void> testarConexao() async {
    final ip = ipController.text.trim();
    final porta = portaController.text.trim();

    final url = Uri.parse("http://$ip:$porta/ping");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 3));

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text("Servidor conectado com sucesso"),
          ),
        );
      } else {
        throw Exception();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("Não foi possível conectar ao servidor"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),

      appBar: AppBar(
        backgroundColor: const Color(0xFFE8D48A),
        elevation: 0,
        title: const Text(
          "Configuração",
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // TÍTULO SERVIDOR
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFD8CC8F),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black26),
              ),
              child: const Text(
                "Servidor / API",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 20),

            // IP
            TextField(
              controller: ipController,
              decoration: InputDecoration(
                labelText: "IP do Servidor",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // PORTA
            TextField(
              controller: portaController,
              decoration: InputDecoration(
                labelText: "Porta",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // BOTÕES
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      await ServerConfig.salvar(
                        ipController.text,
                        portaController.text,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Configuração salva com sucesso"),
                        ),
                      );
                    },
                    child: const Text("Salvar"),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      testarConexao();
                    },
                    child: const Text("Testar"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // DICA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2E9C9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Dica: use o botão \"Testar\" para validar a conexão.\n"
                "Depois clique \"Salvar\" para gravar no aparelho.\n\n"
                "URL de teste: http://IP:PORT/ping",
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
