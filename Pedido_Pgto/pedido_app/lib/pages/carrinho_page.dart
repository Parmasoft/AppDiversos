import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pedido/core/image_utils.dart';
import 'package:pedido/pages/pagamento_page.dart';
import 'package:pedido/services/server_config.dart';
import '../core/app_colors.dart';
import '../models/item_carrinho.dart';

class CarrinhoPage extends StatefulWidget {
  final List<ItemCarrinho> itens;
  final int comanda;
  final String imagemVersao;
  final bool somenteVisualizacao;

  const CarrinhoPage({
    super.key,
    required this.itens,
    required this.comanda,
    required this.imagemVersao,
    this.somenteVisualizacao = false,
  });

  @override
  State<CarrinhoPage> createState() => _CarrinhoPageState();
}

class _CarrinhoPageState extends State<CarrinhoPage> {
  bool _alterandoItem = false;
  int? _sequencialProcessando;
  bool _carregandoVisualizacao = false;

  double get totalGeral {
    return widget.itens.fold(0.0, (sum, item) => sum + item.total);
  }

  // Nesta fase 1, é mais seguro considerar "quantidade de linhas"
  // para não quebrar o fluxo já existente do pagamento.
  int get totalItens {
    return widget.itens.length;
  }

  double get totalQuantidade {
    return widget.itens.fold(0.0, (sum, item) => sum + item.quantidade);
  }

  @override
  void initState() {
    super.initState();

    if (widget.somenteVisualizacao) {
      _abrirSomenteVisualizacao();
    }
  }

  Widget _buildCampoVisualizacao({
    required String titulo,
    required String valor,
    double width = 96,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoDireitaVisualizacao(ItemCarrinho item) {
    final qtdTexto = item.fracionado
        ? "${_formatarQuantidade(item.quantidade)} ${item.unidadeVenda}"
        : _formatarQuantidade(item.quantidade);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber, width: 1.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCampoVisualizacao(titulo: "Qtd", valor: qtdTexto, width: 76),
          const SizedBox(width: 14),
          _buildCampoVisualizacao(
            titulo: "Unit.",
            valor: "R\$ ${_formatarMoeda(item.preco)}",
            width: 96,
          ),
          const SizedBox(width: 14),
          _buildCampoVisualizacao(
            titulo: "Total",
            valor: "R\$ ${_formatarMoeda(item.total)}",
            width: 104,
          ),
        ],
      ),
    );
  }

  Widget _buildResumoVisualizacaoInferior() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Center(
          child: Text(
            "${widget.itens.length} linhas • R\$ ${totalGeral.toStringAsFixed(2).replaceAll('.', ',')}",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abrirSomenteVisualizacao() async {
    setState(() {
      _carregandoVisualizacao = true;
    });

    try {
      await _recarregarCarrinhoDaApi();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao carregar itens da venda: $e")),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _carregandoVisualizacao = false;
      });
    }
  }

  String get _dataHoraAtualFormatada {
    final agora = DateTime.now();
    return "${agora.day.toString().padLeft(2, '0')}/"
        "${agora.month.toString().padLeft(2, '0')}/"
        "${agora.year} "
        "${agora.hour.toString().padLeft(2, '0')}:"
        "${agora.minute.toString().padLeft(2, '0')}";
  }

  int _parseInt(dynamic valor) {
    if (valor == null) return 0;
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();

    final texto = valor.toString().replaceAll(',', '.');
    return int.tryParse(texto) ?? double.tryParse(texto)?.toInt() ?? 0;
  }

  double _parseDouble(dynamic valor) {
    if (valor == null) return 0;
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();

    final texto = valor.toString().replaceAll(',', '.');
    return double.tryParse(texto) ?? 0;
  }

  bool _parseBoolFracionado(dynamic valor) {
    final texto = (valor ?? '').toString().trim().toUpperCase();
    return texto == 'S' || texto == 'TRUE' || texto == '1';
  }

  String _parseUnidade(dynamic valor) {
    final texto = (valor ?? '').toString().trim();
    return texto.isEmpty ? 'UN' : texto;
  }

  String _formatarQuantidade(double valor) {
    final texto = valor.toStringAsFixed(3).replaceAll('.', ',');
    return texto.replaceFirst(RegExp(r',?0+$'), '');
  }

  String _formatarMoeda(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  ItemCarrinho _itemCarrinhoFromJson(Map<String, dynamic> item) {
    return ItemCarrinho(
      id: _parseInt(item["produto_id"]),
      descricao: item["descricao"]?.toString() ?? "",
      preco: _parseDouble(item["valor_unitario"]),
      fotoUrl: item["foto_url"]?.toString() ?? "",
      quantidade: _parseDouble(item["quantidade"]),
      existente: true,
      sequencialItem: item["sequencial"] == null
          ? null
          : _parseInt(item["sequencial"]),
      unidadeVenda: _parseUnidade(item["unidade_venda"]),
      fracionado: _parseBoolFracionado(item["fracionado"]),
    );
  }

  Future<void> _recarregarCarrinhoDaApi() async {
    await ServerConfig.carregar();

    if (ServerConfig.ecfIdInt <= 0) {
      throw Exception("ECF do aparelho não configurado.");
    }

    final url = Uri.parse(
      "${ServerConfig.baseUrl}/pdv/tablet/venda"
      "?empresa=1&ecf_id=${ServerConfig.ecfIdInt}&orc_id=${widget.comanda}",
    );

    final response = await http.get(url);
    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200 && data["sucesso"] == true) {
      final itensApi = (data["itens"] as List? ?? []);

      final listaNova = itensApi.map<ItemCarrinho>((item) {
        return _itemCarrinhoFromJson(Map<String, dynamic>.from(item));
      }).toList();

      if (!mounted) return;

      setState(() {
        widget.itens
          ..clear()
          ..addAll(listaNova);
      });
    } else {
      throw Exception(data["erro"] ?? "Erro ao recarregar carrinho");
    }
  }

  Future<List<Map<String, dynamic>>> _buscarVendedoresDaApi() async {
    await ServerConfig.carregar();

    final uri = Uri.parse(
      "${ServerConfig.baseUrl}/pdv/vendedores",
    ).replace(queryParameters: {"empresa": "1"});

    final response = await http.get(
      uri,
      headers: {"Accept": "application/json"},
    );

    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        data = jsonDecode(response.body);
      }
    }

    if (response.statusCode != 200) {
      throw Exception(
        data is Map<String, dynamic>
            ? (data["erro"] ?? data["mensagem"] ?? "Erro ao buscar vendedores.")
                  .toString()
            : "Erro ao buscar vendedores.",
      );
    }

    if (data is Map<String, dynamic>) {
      final lista = (data["dados"] as List? ?? []);
      return lista.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return [];
  }

  Future<Map<String, dynamic>?> _selecionarVendedorAntesPagamento() async {
    try {
      final vendedores = await _buscarVendedoresDaApi();

      if (!mounted) return null;

      if (vendedores.isEmpty) {
        mostrarErro("Nenhum vendedor ativo encontrado.");
        return null;
      }

      return await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: true,
        builder: (_) => AlertDialog(
          title: const Text("Selecione o vendedor"),
          content: SizedBox(
            width: 420,
            height: 420,
            child: ListView.separated(
              itemCount: vendedores.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final vendedor = vendedores[index];
                final descricao = (vendedor["descricao"]?.toString() ?? "")
                    .trim();

                return ListTile(
                  title: Text(
                    descricao.isNotEmpty
                        ? descricao
                        : (vendedor["id"]?.toString() ?? "Sem código"),
                  ),
                  onTap: () => Navigator.pop(context, vendedor),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return null;
      mostrarErro("Erro ao carregar vendedores.\n\n$e");
      return null;
    }
  }

  Future<void> abrirPagamento() async {
    await _recarregarCarrinhoDaApi();

    if (!mounted) return;

    if (widget.itens.isEmpty) {
      mostrarErro("Adicione ao menos um item antes de ir para o pagamento.");
      return;
    }

    final vendedor = await _selecionarVendedorAntesPagamento();

    if (!mounted) return;
    if (vendedor == null) return;

    final vendedorId = _parseInt(vendedor["id"]);
    final vendedorDescricao =
        (vendedor["descricao"]?.toString() ?? "").trim().isNotEmpty
        ? vendedor["descricao"].toString().trim()
        : vendedorId.toString();

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PagamentoPage(
          orcId: widget.comanda,
          totalItensInicial: totalItens,
          valorTotalInicial: totalGeral,
          vendedorId: vendedorId,
          vendedorDescricao: vendedorDescricao,
        ),
      ),
    );

    if (!mounted) return;

    if (resultado != null && resultado is Map<String, dynamic>) {
      final acao = resultado["acao"]?.toString();

      if (acao == "venda_finalizada") {
        Navigator.pop(context, {
          ...resultado,
          "finalizado": true,
          "numero": widget.comanda,
          "cliente": "CONSUMIDOR FINAL",
          "itens": totalItens,
          "valor": totalGeral,
          "dataHora": _dataHoraAtualFormatada,
          "status": resultado["status"] ?? "F",
          "status_descricao": resultado["status_descricao"] ?? "FECHADO",
        });
      }
    }
  }

  // Mantido por compatibilidade, caso ainda exista algum fluxo chamando isso.
  Future<void> finalizarPedido() async {
    if (!mounted) return;

    Navigator.pop(context, {
      "acao": "finalizar_venda",
      "finalizado": true,
      "numero": widget.comanda,
      "cliente": "CONSUMIDOR FINAL",
      "itens": totalItens,
      "valor": totalGeral,
      "status": "DIGITADO",
      "dataHora": _dataHoraAtualFormatada,
    });
  }

  void mostrarErro(String mensagem) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Erro"),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _mostrarAvisoFracionado() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Item fracionado ainda não usa + / -. Na próxima fase ele terá alteração própria de quantidade.",
        ),
      ),
    );
  }

  Future<void> _executarAcaoItem({
    required ItemCarrinho item,
    required String endpoint,
    String mensagemErroPadrao = "Não foi possível alterar o item.",
  }) async {
    if (item.sequencialItem == null || item.sequencialItem! <= 0) {
      mostrarErro("Este item não possui sequencial válido para alteração.");
      return;
    }

    await ServerConfig.carregar();

    if (ServerConfig.ecfIdInt <= 0) {
      mostrarErro("ECF do aparelho não configurado.");
      return;
    }

    if (!mounted) return;

    setState(() {
      _alterandoItem = true;
      _sequencialProcessando = item.sequencialItem;
    });

    try {
      final url = Uri.parse("${ServerConfig.baseUrl}$endpoint");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "empresa": 1,
          "ecf_id": ServerConfig.ecfIdInt,
          "orc_id": widget.comanda,
          "sequencial_item": item.sequencialItem,
        }),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && data["sucesso"] == true) {
        await _recarregarCarrinhoDaApi();

        if (!mounted) return;

        final aviso = data["aviso"]?.toString() ?? "";
        if (aviso.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(aviso)));
        }
      } else {
        throw Exception(data["erro"] ?? mensagemErroPadrao);
      }
    } catch (e) {
      if (!mounted) return;
      mostrarErro("$mensagemErroPadrao\n\n$e");
    } finally {
      if (mounted) {
        setState(() {
          _alterandoItem = false;
          _sequencialProcessando = null;
        });
      }
    }
  }

  Future<void> _incrementarItem(ItemCarrinho item) async {
    if (item.fracionado) {
      _mostrarAvisoFracionado();
      return;
    }

    await _executarAcaoItem(
      item: item,
      endpoint: "/pdv/tablet/venda/item/incrementar",
      mensagemErroPadrao: "Não foi possível aumentar a quantidade.",
    );
  }

  Future<void> _decrementarItem(ItemCarrinho item) async {
    if (item.fracionado) {
      _mostrarAvisoFracionado();
      return;
    }

    await _executarAcaoItem(
      item: item,
      endpoint: "/pdv/tablet/venda/item/decrementar",
      mensagemErroPadrao: "Não foi possível diminuir a quantidade.",
    );
  }

  Future<void> _removerItem(ItemCarrinho item) async {
    await _executarAcaoItem(
      item: item,
      endpoint: "/pdv/tablet/venda/item/remover",
      mensagemErroPadrao: "Não foi possível remover o item.",
    );
  }

  Future<void> _confirmarRemocao(ItemCarrinho item) async {
    final confirmar =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "Remover item",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text("Deseja remover ${item.descricao}?"),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Cancelar",
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Remover"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar) return;

    await _removerItem(item);
  }

  Widget _buildImagem(ItemCarrinho item) {
    if (item.fotoUrl.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        color: Colors.grey.shade300,
        child: const Icon(Icons.fastfood, color: Colors.black38),
      );
    }

    return Image.network(
      montarUrlImagemComVersao(item.fotoUrl, widget.imagemVersao),
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          width: 56,
          height: 56,
          color: Colors.grey.shade300,
          child: const Icon(Icons.fastfood, color: Colors.black38),
        );
      },
    );
  }

  Widget _buildCardItem(ItemCarrinho item) {
    final processandoEsteItem =
        _alterandoItem && _sequencialProcessando == item.sequencialItem;

    final botaoEsquerdaIcone = item.fracionado
        ? Icons.delete
        : (item.quantidade > 1 ? Icons.remove : Icons.delete);

    final botaoEsquerdaCor = item.fracionado
        ? Colors.red
        : (item.quantidade > 1 ? Colors.black : Colors.red);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildImagem(item),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.descricao,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),

                  if (!widget.somenteVisualizacao) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.fracionado
                          ? "Qtd: ${_formatarQuantidade(item.quantidade)} ${item.unidadeVenda}"
                          : "Qtd: ${_formatarQuantidade(item.quantidade)}",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Unit.: R\$ ${_formatarMoeda(item.preco)}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Subtotal: R\$ ${_formatarMoeda(item.total)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 10),
            widget.somenteVisualizacao
                ? _buildResumoDireitaVisualizacao(item)
                : Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE5E5E5),
                        ),
                        child: IconButton(
                          onPressed: _alterandoItem
                              ? null
                              : () async {
                                  if (item.fracionado) {
                                    await _confirmarRemocao(item);
                                    return;
                                  }

                                  if (item.quantidade > 1) {
                                    await _decrementarItem(item);
                                  } else {
                                    await _confirmarRemocao(item);
                                  }
                                },
                          icon: Icon(
                            botaoEsquerdaIcone,
                            color: botaoEsquerdaCor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 74,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber, width: 2),
                        ),
                        child: processandoEsteItem
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _formatarQuantidade(item.quantidade),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                  ),
                                  if (item.fracionado)
                                    Text(
                                      item.unidadeVenda,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black54,
                                        height: 1.0,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE5E5E5),
                        ),
                        child: IconButton(
                          onPressed: _alterandoItem
                              ? null
                              : () async {
                                  await _incrementarItem(item);
                                },
                          icon: Icon(
                            item.fracionado ? Icons.lock_outline : Icons.add,
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoInferior() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary, width: 2),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _alterandoItem
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  child: const Text(
                    "Mais Itens",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 8,
                  ),
                  child: Text(
                    "$totalItens linha${totalItens == 1 ? '' : 's'} • R\$ ${_formatarMoeda(totalGeral)}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _alterandoItem ? null : abrirPagamento,
                  child: const Text(
                    "Ir para Pagamento",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Resumo da Comanda ${widget.comanda}"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _carregandoVisualizacao
                ? const Center(child: CircularProgressIndicator())
                : widget.itens.isEmpty
                ? const Center(
                    child: Text(
                      "Nenhum item no carrinho.",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.itens.length,
                    itemBuilder: (context, index) {
                      final item = widget.itens[index];
                      return _buildCardItem(item);
                    },
                  ),
          ),
          widget.somenteVisualizacao
              ? _buildResumoVisualizacaoInferior()
              : _buildResumoInferior(),
        ],
      ),
    );
  }
}
