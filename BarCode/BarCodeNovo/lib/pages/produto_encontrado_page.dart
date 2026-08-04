import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// ============================================================================
// BOTÃO PADRÃO (ÍCONE EM CIMA / TEXTO EMBAIXO)
// ============================================================================
Widget botaoRodape({
  required IconData icon,
  required String texto,
  required VoidCallback? onTap,
  bool desabilitado = false,
}) {
  return Expanded(
    child: InkWell(
      onTap: desabilitado ? null : onTap,
      child: Container(
        color: desabilitado ? Colors.grey.shade300 : Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: desabilitado ? Colors.grey : Colors.black,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              texto,
              style: TextStyle(
                color: desabilitado ? Colors.grey : Colors.black,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================================
// LOGO GIRANDO
// ============================================================================
class LogoGiraProduto extends StatefulWidget {
  const LogoGiraProduto({super.key});

  @override
  State<LogoGiraProduto> createState() => _LogoGiraProdutoState();
}

class _LogoGiraProdutoState extends State<LogoGiraProduto>
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
// PRODUTO ENCONTRADO
// ============================================================================
class ProdutoEncontradoPage extends StatefulWidget {
  final Map<String, dynamic> dados;
  final VoidCallback onBuscar;
  final String baseUrl; // 🔹 VEM DA CONFIGURAÇÃO

  const ProdutoEncontradoPage({
    super.key,
    required this.dados,
    required this.onBuscar,
    required this.baseUrl,
  });

  @override
  State<ProdutoEncontradoPage> createState() => _ProdutoEncontradoPageState();
}

class _ProdutoEncontradoPageState extends State<ProdutoEncontradoPage> {
  bool enviadoParaGondola = false;

  // Quebra a descrição em até 3 linhas
  List<String> _descricaoEm3(String texto) {
    final partes = <String>[];
    for (int i = 0; i < texto.length && partes.length < 3; i += 27) {
      partes.add(
        texto.substring(i, (i + 27 > texto.length) ? texto.length : i + 27),
      );
    }
    while (partes.length < 3) {
      partes.add("");
    }
    return partes;
  }

  // Formata preço para pt-BR
  String formatarPreco(dynamic valor) {
    if (valor == null) return "0,00";
    final numero = double.tryParse(valor.toString()) ?? 0.0;
    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: '',
      decimalDigits: 2,
    );
    return formatter.format(numero);
  }

  // --------------------------------------------------------------------------
  // ENVIAR PARA GÔNDOLA (USANDO BASEURL CONFIGURADA)
  // --------------------------------------------------------------------------
  Future<void> enviarParaGondola() async {
    if (enviadoParaGondola) return;

    try {
      final response = await http.post(
        Uri.parse("${widget.baseUrl}/gondola"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "produto_id": widget.dados["produto_id"],
          "descricao": widget.dados["descricao"],
          "un": widget.dados["unidade"],
          "codigo_barras": widget.dados["codigo"],
          "preco": widget.dados["preco"],
        }),
      );

      final json = jsonDecode(response.body);

      if (!mounted) return;
      setState(() => enviadoParaGondola = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(json["mensagem"] ?? "Produto enviado para gôndola"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao enviar para a gôndola")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final desc = _descricaoEm3(widget.dados["descricao"] ?? "");

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text("Produto Encontrado"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ),

      // ----------------------------------------------------------------------
      // RODAPÉ
      // ----------------------------------------------------------------------
      bottomNavigationBar: SizedBox(
        height: 70,
        child: Row(
          children: [
            botaoRodape(
              icon: Icons.camera_alt,
              texto: "Busca",
              onTap: widget.onBuscar,
            ),
            Container(width: 1, color: Colors.black12),
            botaoRodape(
              icon: Icons.view_list,
              texto: "Gôndola",
              onTap: enviarParaGondola,
              desabilitado: enviadoParaGondola,
            ),
          ],
        ),
      ),

      // ----------------------------------------------------------------------
      // CORPO
      // ----------------------------------------------------------------------
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.25,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF9E3), Color(0xFFF7EFC7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: const Center(child: LogoGiraProduto()),
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _campo(
                      "Código de barras",
                      widget.dados["codigo"],
                      cor: Colors.red,
                    ),
                    const SizedBox(height: 12),

                    _campo("Descrição", desc[0], alinharEsquerda: true),
                    if (desc[1].trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _campo("", desc[1], alinharEsquerda: true),
                    ],
                    if (desc[2].trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _campo("", desc[2], alinharEsquerda: true),
                    ],

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _campo(
                            "Unidade",
                            widget.dados["unidade"],
                            alinharEsquerda: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _campo(
                            "Preço",
                            "R\$ ${formatarPreco(widget.dados["preco"])}",
                            cor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // CAMPO PADRÃO
  // ========================================================================
  Widget _campo(
    String label,
    String valor, {
    Color cor = Colors.black,
    bool alinharEsquerda = false,
  }) {
    return TextField(
      controller: TextEditingController(text: valor),
      readOnly: true,
      textAlign: alinharEsquerda ? TextAlign.left : TextAlign.center,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cor),
      decoration: InputDecoration(
        labelText: label.isEmpty ? null : label,
        floatingLabelAlignment: alinharEsquerda
            ? FloatingLabelAlignment.start
            : FloatingLabelAlignment.center,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
