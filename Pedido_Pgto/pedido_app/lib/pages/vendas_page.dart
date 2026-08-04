import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pedido/pages/carrinho_page.dart';
import 'package:pedido/pages/config_page.dart';
import 'package:pedido/pages/menu_page.dart';
import 'package:pedido/pages/produto_busca_page.dart';
import 'package:pedido/services/server_config.dart';

class VendaResumo {
  final int numero;
  final String cliente;
  final int itens;
  final double valor;
  final String status;
  final String dataHora;

  VendaResumo({
    required this.numero,
    required this.cliente,
    required this.itens,
    required this.valor,
    required this.status,
    required this.dataHora,
  });
}

class VendasPage extends StatefulWidget {
  const VendasPage({super.key});

  @override
  State<VendasPage> createState() => _VendasPageState();
}

class _VendasPageState extends State<VendasPage> {
  int? indiceSelecionado;
  bool carregando = true;
  List<VendaResumo> vendas = [];

  @override
  void initState() {
    super.initState();
    _iniciarTela();
  }

  Future<void> _iniciarTela() async {
    await ServerConfig.carregar();
    await _carregarVendas();
  }

  Future<void> _recarregarConfiguracao() async {
    await ServerConfig.carregar();
    await _carregarVendas();
  }

  Future<void> _abrirConfiguracao() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ConfigPage(emDialogo: true),
    );

    await _recarregarConfiguracao();
  }

  Future<void> _abrirPesquisaPreco() async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProdutoBuscaPage(
            empresa: 1,
            imagemVersao: '',
            modoConsulta: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao abrir pesquisa: $e')));
    }
  }

  Future<void> visualizarVendaSelecionada() async {
    if (indiceSelecionado == null) return;

    final venda = vendas[indiceSelecionado!];

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarrinhoPage(
          itens: [],
          comanda: venda.numero,
          imagemVersao: '',
          somenteVisualizacao: true,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  String _extrairMensagemResposta(
    dynamic data, {
    String padrao = "Erro na operação",
  }) {
    if (data is Map<String, dynamic>) {
      final mensagem =
          data["mensagem"] ?? data["erro"] ?? data["message"] ?? data["detail"];

      if (mensagem != null && mensagem.toString().trim().isNotEmpty) {
        return mensagem.toString();
      }
    }

    return padrao;
  }

  VendaResumo _vendaResumoFromJson(Map<String, dynamic> json) {
    return VendaResumo(
      numero:
          (json["numero"] as num?)?.toInt() ??
          int.tryParse(json["numero"]?.toString() ?? "0") ??
          0,
      cliente: json["cliente"]?.toString() ?? "CONSUMIDOR FINAL",
      itens:
          (json["itens"] as num?)?.toInt() ??
          int.tryParse(json["itens"]?.toString() ?? "0") ??
          0,
      valor:
          (json["valor"] as num?)?.toDouble() ??
          double.tryParse(json["valor"]?.toString() ?? "0") ??
          0.0,
      status:
          json["status_descricao"]?.toString() ??
          json["status"]?.toString() ??
          "",
      dataHora: json["dataHora"]?.toString() ?? "",
    );
  }

  Future<void> _carregarVendas() async {
    if (!mounted) return;

    setState(() {
      carregando = true;
      indiceSelecionado = null;
    });

    try {
      if (ServerConfig.ecfIdInt <= 0) {
        if (!mounted) return;

        setState(() {
          vendas = [];
          carregando = false;
        });
        return;
      }

      final url = Uri.parse(
        "${ServerConfig.baseUrl}/pdv/tablet/vendas"
        "?empresa=1&ecf_id=${ServerConfig.ecfIdInt}",
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      dynamic data;
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        data = null;
      }

      if (response.statusCode == 200 &&
          data is Map<String, dynamic> &&
          data["sucesso"] == true) {
        final lista = (data["dados"] as List? ?? [])
            .map((e) => _vendaResumoFromJson(Map<String, dynamic>.from(e)))
            .toList();

        if (!mounted) return;

        setState(() {
          vendas = lista;
          carregando = false;
        });
      } else {
        throw Exception(
          _extrairMensagemResposta(data, padrao: "Erro ao carregar vendas"),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        vendas = [];
        carregando = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao carregar vendas: $e")));
    }
  }

  Color corStatus(String status) {
    switch (status.toUpperCase()) {
      case "FECHADO":
      case "F":
        return Colors.blue;
      case "CANCELADO":
      case "C":
        return Colors.red;
      case "IMPORTADO":
      case "I":
        return Colors.black54;
      case "DIGITADO":
      case "D":
        return Colors.green;
      case "ABERTO":
      case "S":
        return Colors.orange;
      default:
        return Colors.orange;
    }
  }

  Future<void> abrirNovaVenda() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MenuPage()),
    );

    if (!mounted) return;

    await _carregarVendas();
  }

  Future<void> abrirVenda(VendaResumo venda) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarrinhoPage(
          itens: [],
          comanda: venda.numero,
          imagemVersao: '',
          somenteVisualizacao: true,
        ),
      ),
    );
  }

  Future<void> _imprimirVendaSelecionada() async {
    if (indiceSelecionado == null ||
        indiceSelecionado! < 0 ||
        indiceSelecionado! >= vendas.length) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione uma venda para imprimir.")),
      );
      return;
    }

    final venda = vendas[indiceSelecionado!];

    try {
      final url = Uri.parse(
        "${ServerConfig.baseUrl}/pdv/tablet/venda/imprimir",
      );

      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "empresa": 1,
              "ecf_id": ServerConfig.ecfIdInt,
              "orc_id": venda.numero,
            }),
          )
          .timeout(const Duration(seconds: 15));

      dynamic data;
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        data = null;
      }

      if (response.statusCode == 200 &&
          data is Map<String, dynamic> &&
          data["sucesso"] == true) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data["mensagem"]?.toString() ??
                  "Comprovante enviado para impressão.",
            ),
          ),
        );
      } else {
        throw Exception(
          _extrairMensagemResposta(
            data,
            padrao: "Erro ao imprimir comprovante",
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao imprimir: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalGeral = vendas.fold<double>(
      0.0,
      (soma, venda) => soma + venda.valor,
    );

    final totalVendasTexto = vendas.length.toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8D48A),
        elevation: 0,
        title: const Text(
          "Vendas",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: _abrirConfiguracao,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: carregando
                  ? const Center(child: CircularProgressIndicator())
                  : vendas.isEmpty
                  ? const Center(
                      child: Text(
                        "Nenhuma venda encontrada neste aparelho.",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF0F1F3),
                              border: Border(
                                bottom: BorderSide(color: Colors.black12),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    "St.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "Código",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    "Data/Hora",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "Qtde Itens",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    "Cliente",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "Valor Total",
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              itemCount: vendas.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: Colors.black12,
                              ),
                              itemBuilder: (context, index) {
                                final venda = vendas[index];
                                final cor = corStatus(venda.status);

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      indiceSelecionado = index;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    color: indiceSelecionado == index
                                        ? const Color(0xFFDCEBFF)
                                        : index.isEven
                                        ? Colors.white
                                        : const Color(0xFFFFF9E6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Center(
                                            child: Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: cor,
                                                shape: BoxShape.circle,
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 2,
                                                    offset: Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            venda.numero.toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            venda.dataHora,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            venda.itens.toString(),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            venda.cliente,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            "R\$ ${venda.valor.toStringAsFixed(2)}",
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Wrap(
                            spacing: 18,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _itemLegenda("DIGITADO", Colors.green),
                              _itemLegenda("FECHADO", Colors.blue),
                              _itemLegenda("IMPORTADO", Colors.black54),
                              _itemLegenda("CANCELADO", Colors.red),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 470,
                                child: Row(
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: "Aparelho: ",
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          TextSpan(
                                            text: "ECF ${ServerConfig.ecfId}",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: "Vendas: ",
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          TextSpan(
                                            text: totalVendasTexto,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: "Total: ",
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                "R\$ ${totalGeral.toStringAsFixed(2)}",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
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
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6),
                      ],
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.start,
                      children: [
                        _botaoRodape(
                          icone: Icons.filter_alt_outlined,
                          texto: "Filtrar",
                          habilitado: false,
                        ),
                        _botaoRodape(
                          icone: Icons.visibility_outlined,
                          texto: "Visualizar",
                          onTap: indiceSelecionado == null
                              ? null
                              : () => abrirVenda(vendas[indiceSelecionado!]),
                          habilitado: indiceSelecionado != null,
                        ),
                        _botaoRodape(
                          icone: Icons.add,
                          texto: "Incluir",
                          onTap: abrirNovaVenda,
                        ),
                        _botaoRodape(
                          icone: Icons.edit_outlined,
                          texto: "Alterar",
                          habilitado: false,
                        ),

                        _botaoRodape(
                          icone: Icons.search,
                          texto: "Pesq. Preço",
                          onTap: _abrirPesquisaPreco,
                          habilitado: true,
                        ),
                        _botaoRodape(
                          icone: Icons.receipt_long_outlined,
                          texto: "NFC-e",
                          habilitado: false,
                        ),
                        _botaoRodape(
                          icone: Icons.close,
                          texto: "Cancelar",
                          habilitado: false,
                        ),

                        _botaoRodape(
                          icone: Icons.print_outlined,
                          texto: "Imprimir",
                          onTap: _imprimirVendaSelecionada,
                          habilitado: indiceSelecionado != null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemLegenda(String texto, Color cor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: cor,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _botaoRodape({
    required IconData icone,
    required String texto,
    VoidCallback? onTap,
    bool habilitado = true,
  }) {
    final corFundo = habilitado
        ? const Color(0xFFF3F4F6)
        : const Color(0xFFE5E7EB);
    final corBorda = habilitado ? Colors.black26 : Colors.black12;
    final corTexto = habilitado ? Colors.black87 : Colors.black38;

    return SizedBox(
      width: 120,
      height: 58,
      child: ElevatedButton(
        onPressed: habilitado ? onTap : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: corFundo,
          foregroundColor: corTexto,
          disabledBackgroundColor: corFundo,
          disabledForegroundColor: corTexto,
          side: BorderSide(color: corBorda),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 20),
            const SizedBox(height: 4),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
