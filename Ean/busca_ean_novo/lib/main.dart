import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/scanner_page.dart';
import 'pages/produto_encontrado_page.dart';
import 'pages/config_page.dart';
import 'pages/vincular_codigo_page.dart';

void main() {
  runApp(const BuscaEANApp());
}

class BuscaEANApp extends StatelessWidget {
  const BuscaEANApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TelaUnica(),
    );
  }
}

// ============================================================================
// LOGO GIRANDO (TELA INICIAL)
// ============================================================================
class LogoGira extends StatefulWidget {
  const LogoGira({super.key});

  @override
  State<LogoGira> createState() => _LogoGiraState();
}

class _LogoGiraState extends State<LogoGira>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        final angle = controller.value * 6.28318;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(-angle),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: Image.asset(
          'assets/images/logo.jpeg',
          width: 180,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ============================================================================
// BOTÃO PADRÃO DE RODAPÉ
// ============================================================================
Widget botaoRodape({
  required IconData icon,
  required String texto,
  required VoidCallback onTap,
}) {
  return Expanded(
    child: InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 26),
            const SizedBox(height: 4),
            Text(
              texto,
              style: const TextStyle(color: Colors.black, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget botaoTopo({
  required IconData icon,
  required String texto,
  required VoidCallback onTap,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black87, size: 20),
          const SizedBox(width: 8),
          Text(
            texto,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================================
// TELA PRINCIPAL (HOME REAL)
// ============================================================================
class TelaUnica extends StatefulWidget {
  const TelaUnica({super.key});

  @override
  State<TelaUnica> createState() => _TelaUnicaState();
}

class _TelaUnicaState extends State<TelaUnica> {
  // Default (caso não exista config salva)
  String baseUrl = "http://192.168.0.250:5001";
  //String baseUrl = "http://192.168.1.238:5001";

  @override
  void initState() {
    super.initState();
    _carregarBaseUrl();
  }

  Future<void> _carregarBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString("api_base_url");
    if (saved != null && saved.trim().isNotEmpty) {
      setState(() => baseUrl = saved.trim());
    }
  }

  // --------------------------------------------------------------------------
  // ABRIR CONFIG
  // --------------------------------------------------------------------------
  Future<void> abrirConfig() async {
    final novo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => ConfigPage(baseUrlAtual: baseUrl)),
    );

    if (novo != null && novo.trim().isNotEmpty) {
      setState(() => baseUrl = novo.trim());
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Configuração salva: $baseUrl"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // --------------------------------------------------------------------------
  // ABRIR SCANNER
  // --------------------------------------------------------------------------
  Future<void> abrirScanner() async {
    final String? codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );

    if (codigo == null || codigo.trim().isEmpty) return;

    final resultado = await buscar(codigo.trim());

    if (!mounted) return;

    switch (resultado["status"]) {
      case "ok":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProdutoEncontradoPage(
              dados: resultado["dados"],
              baseUrl: baseUrl, // 👈 A CONFIGURAÇÃO ATUAL
              onBuscar: () {
                Navigator.pop(context);
                abrirScanner();
              },
            ),
          ),
        );
        break;

      case "nao_encontrado":
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => VincularCodigoPage(
              codigoBarras: codigo.trim(),
              baseUrl: baseUrl,
            ),
          ),
        );
        break;

      case "erro_conexao":
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erro de conexão com o servidor"),
            backgroundColor: Colors.red,
          ),
        );
        break;
    }
  }

  // --------------------------------------------------------------------------
  // BUSCAR PRODUTO NA API (COM STATUS)
  // --------------------------------------------------------------------------
  Future<Map<String, dynamic>> buscar(String cod) async {
    try {
      final url = Uri.parse("$baseUrl/produto?cod=$cod");
      final resp = await http.get(url).timeout(const Duration(seconds: 5));

      if (resp.statusCode != 200) {
        return {"status": "erro_conexao"};
      }

      final dados = jsonDecode(resp.body);

      if (dados["encontrado"] == true ||
          dados["encontrado"] == 1 ||
          dados["encontrado"] == "true") {
        return {
          "status": "ok",
          "dados": {
            "produto_id": dados["produto_id"],
            "codigo": dados["codigo"] ?? cod,
            "descricao": dados["descricao"] ?? "",
            "unidade": dados["unidade"] ?? "",
            "preco": dados["preco"]?.toString() ?? "0.00",
          },
        };
      } else {
        return {"status": "nao_encontrado"};
      }
    } catch (_) {
      return {"status": "erro_conexao"};
    }
  }

  // --------------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF9E3),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: abrirConfig,
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.black87,
                      size: 28,
                    ),
                    tooltip: 'Configurar',
                  ),
                ],
              ),
            ),

            Container(
              height: MediaQuery.of(context).size.height * 0.35,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFF9E3), Color(0xFFF7EFC7)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(child: LogoGira()),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEDEDED), Color(0xFFD9D9D9)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                    child: Column(
                      children: [
                        const Text(
                          "<<< Consulta Preços >>>",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            //color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        //Text(
                        //  "API: $baseUrl",
                        //  style: const TextStyle(color: Colors.black45),
                        //  textAlign: TextAlign.center,
                        //),
                        const SizedBox(height: 18),
                        Image.asset(
                          'assets/images/scanner.png',
                          width: 220,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: 230,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: abrirScanner,
                            icon: const Icon(Icons.camera_alt, size: 22),
                            label: const Text(
                              "Buscar Produto",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: Colors.black12),
                              ),
                              elevation: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
