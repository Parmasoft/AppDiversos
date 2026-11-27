import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/scanner_page.dart';
import 'pages/produto_encontrado_page.dart';
import 'pages/config_page.dart';
import 'pages/buscar_produto_page.dart';
import 'pages/recebimento_pedido_compra_page.dart';
import 'pages/requisicoes_transferencia_page.dart';
import 'pages/regularizacao_rolos_filial_page.dart';
import 'pages/separacao_rolos_page.dart';

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
          width: 145,
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
  int _moduloSelecionado = 0;

  // Default (caso não exista config salva)
  String baseUrl = "http://192.168.0.250:5001";
  //String baseUrl = "http://192.168.1.238:5001";
  int empresaId = 1;
  String? empresaNome;
  String? empresaTipo;
  bool empresaEhFilial = false;

  @override
  void initState() {
    super.initState();
    _carregarBaseUrl();
  }

  Future<void> _carregarBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString("api_base_url");
    final empresa = prefs.getInt("empresa_id") ?? 1;
    final base = saved != null && saved.trim().isNotEmpty
        ? saved.trim()
        : baseUrl;

    setState(() {
      baseUrl = base;
      empresaId = empresa;
      empresaNome = null;
      empresaTipo = null;
      empresaEhFilial = false;
    });

    await _consultarEmpresaAtual(base, empresa);
  }

  Future<void> _consultarEmpresaAtual(String base, int empresa) async {
    try {
      final raiz = base.endsWith('/')
          ? base.substring(0, base.length - 1)
          : base;
      final url = Uri.parse(
        '$raiz/empresas/atual',
      ).replace(queryParameters: {'empresa': empresa.toString()});

      final resp = await http.get(url).timeout(const Duration(seconds: 5));

      if (!mounted || baseUrl != base || empresaId != empresa) return;

      if (resp.statusCode != 200) {
        setState(() {
          empresaNome = null;
          empresaTipo = null;
          empresaEhFilial = false;
        });
        return;
      }

      final dados = jsonDecode(utf8.decode(resp.bodyBytes));
      final tipo = (dados["tipo"] ?? "").toString().trim().toUpperCase();

      setState(() {
        empresaNome = (dados["nome"] ?? "").toString().trim();
        empresaTipo = tipo;
        empresaEhFilial = dados["eh_filial"] == true && tipo == "F";
      });
    } catch (_) {
      if (!mounted || baseUrl != base || empresaId != empresa) return;

      setState(() {
        empresaNome = null;
        empresaTipo = null;
        empresaEhFilial = false;
      });
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
      final prefs = await SharedPreferences.getInstance();
      final empresa = prefs.getInt("empresa_id") ?? 1;
      final base = novo.trim();

      setState(() {
        baseUrl = base;
        empresaId = empresa;
        empresaNome = null;
        empresaTipo = null;
        empresaEhFilial = false;
      });

      await _consultarEmpresaAtual(base, empresa);

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
  // ABRIR BUSCA POR DESCRIÇÃO
  // --------------------------------------------------------------------------
  Future<void> abrirBuscaProduto() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BuscarProdutoPage(baseUrl: baseUrl, empresaId: empresaId),
      ),
    );
  }

  Future<void> abrirRecebimentoPedidoCompra() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RecebimentoPedidoCompraPage(),
      ),
    );
  }

  Future<void> abrirSeparacaoRolos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SeparacaoRolosPage()),
    );
  }

  Future<void> abrirRegularizacaoRolosFilial() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegularizacaoRolosFilialPage(
          baseUrl: baseUrl,
          empresaId: empresaId,
          empresaNome: empresaNome,
        ),
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Produto não encontrado"),
            backgroundColor: Colors.orange,
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
  // ABRIR SCANNER PARA LER ETIQUETA DE ROLO
  // Regra: ROLO + produto 8 dígitos + quantidade 6 dígitos
  // Exemplo: ROLO01004146008500 = produto 1004146 / quantidade 85,00
  // --------------------------------------------------------------------------
  // --------------------------------------------------------------------------
  // ABRIR SCANNER PARA LER ETIQUETA DE ROLO
  // Consulta a API para trazer produto, descrição, unidade e quantidade.
  // --------------------------------------------------------------------------
  Future<void> abrirScannerRolo() async {
    final String? codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );

    if (codigo == null || codigo.trim().isEmpty) return;

    final codigoLido = codigo.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );

    if (!RegExp(r'^R\d{17}$').hasMatch(codigoLido)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Etiqueta inválida: $codigoLido (${codigoLido.length} caracteres)",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final url = Uri.parse(
        "$baseUrl/rolos/consultar-codigo?empresa=$empresaId&codigo=${Uri.encodeComponent(codigoLido)}",
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Produto da etiqueta não encontrado."),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final dados = jsonDecode(resp.body);

      if (dados["status"] != "ok") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dados["mensagem"]?.toString() ?? "Erro ao ler etiqueta.",
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (_) {
          final descricao = dados["descricao"]?.toString() ?? "";
          final produtoId = dados["produto_id"]?.toString() ?? "";
          final unidade = dados["unidade"]?.toString() ?? "";
          final quantidade =
              dados["quantidade_formatada"]?.toString() ?? "0,00";

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Row(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.green),
                SizedBox(width: 8),
                Text("Etiqueta lida"),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      codigoLido,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "Produto",
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  Text(
                    produtoId,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "Descrição",
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  Text(
                    descricao,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "QUANTIDADE",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$quantidade $unidade",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Fechar"),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  abrirScannerRolo();
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Ler outra"),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erro de conexão ao consultar etiqueta."),
          backgroundColor: Colors.red,
        ),
      );
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
            _seletorModulos(),
            Expanded(
              child: _moduloSelecionado == 0
                  ? Column(
                      children: [
                        Container(
                          height: MediaQuery.of(context).size.height * 0.22,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFFF9E3), Color(0xFFF7EFC7)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Stack(
                            children: [
                              const Center(child: LogoGira()),
                              Positioned(
                                top: 4,
                                right: 8,
                                child: IconButton(
                                  onPressed: abrirConfig,
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.black87,
                                    size: 28,
                                  ),
                                  tooltip: 'Configurar',
                                ),
                              ),
                            ],
                          ),
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
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  14,
                                  24,
                                  18,
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      "Etiquetas de Rolos",
                                      style: TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    const SizedBox(height: 14),
                                    Image.asset(
                                      'assets/images/scanner.png',
                                      width: 185,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(height: 22),
                                    SizedBox(
                                      width: 250,
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        onPressed: abrirBuscaProduto,
                                        icon: const Icon(
                                          Icons.search,
                                          size: 22,
                                        ),
                                        label: const Text(
                                          "Buscar Produto",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            side: const BorderSide(
                                              color: Colors.black12,
                                            ),
                                          ),
                                          elevation: 3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: 250,
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        onPressed: abrirRecebimentoPedidoCompra,
                                        icon: const Icon(
                                          Icons.shopping_cart_outlined,
                                          size: 22,
                                        ),
                                        label: const Text(
                                          "Pedido de Compras",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            side: const BorderSide(
                                              color: Colors.black12,
                                            ),
                                          ),
                                          elevation: 3,
                                        ),
                                      ),
                                    ),
                                    if (empresaEhFilial) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: 285,
                                        height: 52,
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              abrirRegularizacaoRolosFilial,
                                          icon: const Icon(
                                            Icons.fact_check_outlined,
                                            size: 22,
                                          ),
                                          label: const Text(
                                            "Regularizar rolos da filial",
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              side: const BorderSide(
                                                color: Colors.black12,
                                              ),
                                            ),
                                            elevation: 3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        Container(
                          height: 78,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Colors.black12),
                            ),
                          ),
                          child: Row(
                            children: [
                              botaoRodape(
                                icon: Icons.qr_code_scanner,
                                texto: "Ler Etiqueta",
                                onTap: abrirScannerRolo,
                              ),
                              Container(
                                width: 1,
                                height: 48,
                                color: Colors.black12,
                              ),
                              botaoRodape(
                                icon: Icons.inventory_2_outlined,
                                texto: "Separação",
                                onTap: abrirSeparacaoRolos,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const RequisicoesTransferenciaPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seletorModulos() {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFFFFE000),
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _opcaoModulo(0, 'Pedidos', Icons.receipt_long_outlined),
          const SizedBox(width: 6),
          _opcaoModulo(1, 'Requisições', Icons.swap_horiz_outlined),
        ],
      ),
    );
  }

  Widget _opcaoModulo(int indice, String texto, IconData icone) {
    final selecionado = _moduloSelecionado == indice;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selecionado,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (_moduloSelecionado != indice) {
              setState(() => _moduloSelecionado = indice);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: selecionado ? const Color(0xFFFFFBE6) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selecionado ? Colors.black26 : Colors.transparent,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, size: 20, color: Colors.black87),
                const SizedBox(width: 7),
                Text(
                  texto,
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: selecionado ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
