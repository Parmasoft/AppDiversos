import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/separacao_produto_widgets.dart';
import 'scanner_page.dart';

class SeparacaoRolosPage extends StatefulWidget {
  const SeparacaoRolosPage({super.key});

  @override
  State<SeparacaoRolosPage> createState() => _SeparacaoRolosPageState();
}

class PedidoMock {
  final int numero;
  final String cliente;
  final String emissao;
  final double valorTotal;
  final String status;
  final List<ItemPedidoMock> itens;

  const PedidoMock({
    required this.numero,
    required this.cliente,
    required this.emissao,
    required this.valorTotal,
    required this.status,
    required this.itens,
  });
}

class ItemPedidoMock {
  final int sequencia;
  final int produto;
  final String descricao;
  final double quantidade;
  final String unidade;

  const ItemPedidoMock({
    required this.sequencia,
    required this.produto,
    required this.descricao,
    required this.quantidade,
    required this.unidade,
  });
}

class RoloSeparado {
  final String codigo;
  final int id;
  final int produto;
  final String descricaoProduto;
  final double quantidade;
  final String unidade;

  const RoloSeparado({
    required this.codigo,
    required this.id,
    required this.produto,
    required this.descricaoProduto,
    required this.quantidade,
    required this.unidade,
  });
}

class ProdutoSeparadoResumo {
  final int produto;
  final String descricao;
  final double vendido;
  final double separado;
  final String unidade;
  final List<RoloSeparado> rolos;

  const ProdutoSeparadoResumo({
    required this.produto,
    required this.descricao,
    required this.vendido,
    required this.separado,
    required this.unidade,
    required this.rolos,
  });
}

class _SeparacaoRolosPageState extends State<SeparacaoRolosPage> {
  final TextEditingController _pedidoController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();

  String baseUrl = "http://192.168.0.250:5001";
  int empresaId = 1;
  bool carregandoPedido = false;
  bool consultandoEtiqueta = false;
  bool salvandoSeparacao = false;
  bool saidaLiberadaSemConfirmacao = false;

  int? separacaoRegistradaId;

  PedidoMock? pedidoCarregado;

  int? produtoAtual;
  String descricaoAtual = '';
  double quantidadeVendidaAtual = 0.0;
  String unidadeAtual = 'MT';

  final List<RoloSeparado> rolosProdutoAtual = [];
  final List<ProdutoSeparadoResumo> produtosSeparados = [];

  final Map<int, PedidoMock> pedidosMock = const {
    9567: PedidoMock(
      numero: 9567,
      cliente: 'DM DECOR LTDA',
      emissao: '06/05/2026',
      valorTotal: 18450.00,
      status: 'ABERTO',
      itens: [
        ItemPedidoMock(
          sequencia: 1,
          produto: 1004146,
          descricao: 'LINHO CONFORT 05 CINZA',
          quantidade: 1000.0,
          unidade: 'MT',
        ),
        ItemPedidoMock(
          sequencia: 2,
          produto: 1003259,
          descricao: 'PERFECTO AREIA 14296',
          quantidade: 800.0,
          unidade: 'MT',
        ),
      ],
    ),
  };

  final Map<String, RoloSeparado> rolosMock = const {
    // Produto 1004146 - total 1.060,0 MT.
    'R00000110041461200': RoloSeparado(
      codigo: 'R00000110041461200',
      id: 1,
      produto: 1004146,
      descricaoProduto: 'LINHO CONFORT 05 CINZA',
      quantidade: 120.0,
      unidade: 'MT',
    ),
    'R00000210041461800': RoloSeparado(
      codigo: 'R00000210041461800',
      id: 2,
      produto: 1004146,
      descricaoProduto: 'LINHO CONFORT 05 CINZA',
      quantidade: 180.0,
      unidade: 'MT',
    ),
    'R00000310041462500': RoloSeparado(
      codigo: 'R00000310041462500',
      id: 3,
      produto: 1004146,
      descricaoProduto: 'LINHO CONFORT 05 CINZA',
      quantidade: 250.0,
      unidade: 'MT',
    ),
    'R00000410041462200': RoloSeparado(
      codigo: 'R00000410041462200',
      id: 4,
      produto: 1004146,
      descricaoProduto: 'LINHO CONFORT 05 CINZA',
      quantidade: 220.0,
      unidade: 'MT',
    ),
    'R00000510041462900': RoloSeparado(
      codigo: 'R00000510041462900',
      id: 5,
      produto: 1004146,
      descricaoProduto: 'LINHO CONFORT 05 CINZA',
      quantidade: 290.0,
      unidade: 'MT',
    ),

    // Produto 1003259 - outro item do mesmo pedido.
    'R00010110032592000': RoloSeparado(
      codigo: 'R00010110032592000',
      id: 101,
      produto: 1003259,
      descricaoProduto: 'PERFECTO AREIA 14296',
      quantidade: 200.0,
      unidade: 'MT',
    ),
    'R00010210032593000': RoloSeparado(
      codigo: 'R00010210032593000',
      id: 102,
      produto: 1003259,
      descricaoProduto: 'PERFECTO AREIA 14296',
      quantidade: 300.0,
      unidade: 'MT',
    ),
    'R00010310032593200': RoloSeparado(
      codigo: 'R00010310032593200',
      id: 103,
      produto: 1003259,
      descricaoProduto: 'PERFECTO AREIA 14296',
      quantidade: 320.0,
      unidade: 'MT',
    ),

    // Produto que não pertence ao pedido.
    'R00000699999990800': RoloSeparado(
      codigo: 'R00000699999990800',
      id: 6,
      produto: 9999999,
      descricaoProduto: 'PRODUTO ERRADO PARA TESTE',
      quantidade: 80.0,
      unidade: 'MT',
    ),
  };

  double get totalProdutoAtual {
    return rolosProdutoAtual.fold<double>(
      0.0,
      (total, rolo) => total + rolo.quantidade,
    );
  }

  double get diferencaAtual {
    return totalProdutoAtual - quantidadeVendidaAtual;
  }

  bool get possuiProdutoAtual => produtoAtual != null;

  double get totalVendidoPedido {
    final pedido = pedidoCarregado;
    if (pedido == null) return 0.0;

    return pedido.itens.fold<double>(
      0.0,
      (total, item) => total + item.quantidade,
    );
  }

  double _quantidadeVendidaDoProduto(int produto) {
    final pedido = pedidoCarregado;
    if (pedido == null) return 0.0;

    return pedido.itens
        .where((item) => item.produto == produto)
        .fold<double>(0.0, (total, item) => total + item.quantidade);
  }

  double get totalSeparadoPedido {
    return produtosSeparados.fold<double>(
      0.0,
      (total, produto) => total + produto.separado,
    );
  }

  double get diferencaGeralPedido {
    return totalSeparadoPedido - totalVendidoPedido;
  }

  List<ItemPedidoMock> get itensPendentesSeparacao {
    final pedido = pedidoCarregado;
    if (pedido == null) return [];

    return pedido.itens.where((item) {
      return !produtosSeparados.any((p) => p.produto == item.produto);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _carregarConfiguracao();
  }

  Future<void> _carregarConfiguracao() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getString("api_base_url");
    final empresa = prefs.getInt("empresa_id") ?? 1;

    if (!mounted) return;

    setState(() {
      if (saved != null && saved.trim().isNotEmpty) {
        baseUrl = saved.trim();
      }
      empresaId = empresa;
    });
  }

  @override
  void dispose() {
    _pedidoController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  String _formatarQuantidade(double valor) {
    final arredondado4 = double.parse(valor.toStringAsFixed(4));

    if ((arredondado4 * 100) % 1 == 0) {
      return arredondado4.toStringAsFixed(2).replaceAll('.', ',');
    }

    return arredondado4.toStringAsFixed(4).replaceAll('.', ',');
  }

  String _formatarValor(double valor) {
    final negativo = valor < 0;
    final texto = valor.abs().toStringAsFixed(2);
    final partes = texto.split('.');
    final inteiro = partes[0];
    final decimal = partes[1];

    final buffer = StringBuffer();

    for (int i = 0; i < inteiro.length; i++) {
      final posicaoRestante = inteiro.length - i;

      buffer.write(inteiro[i]);

      if (posicaoRestante > 1 && posicaoRestante % 3 == 1) {
        buffer.write('.');
      }
    }

    return '${negativo ? '-' : ''}${buffer.toString()},$decimal';
  }

  String _normalizarCodigo(String codigo) {
    return codigo.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  void _mostrarMensagem(String mensagem, {bool erro = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  void _mostrarAvisoRapidoCentro(
    String mensagem, {
    bool erro = false,
    bool aviso = false,
    int tempoMs = 4200,
  }) {
    if (!mounted) return;

    final overlay = Overlay.of(context);

    final entry = OverlayEntry(
      builder: (context) {
        return IgnorePointer(
          ignoring: true,
          child: Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.18),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.86,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ATENÇÃO !!!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          mensagem,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            height: 1.40,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    Future.delayed(Duration(milliseconds: tempoMs), () {
      try {
        entry.remove();
      } catch (_) {}
    });
  }

  String _tratarMensagemErroSalvarSeparacao(Object erro) {
    final texto = erro.toString();

    if (texto.contains('já foi usado na separação')) {
      return 'Este pedido já possui uma separação registrada com um dos rolos lidos. '
          'Verifique por favor.';
    }

    if (texto.contains('409')) {
      return 'Já existe uma separação registrada para este pedido ou para algum rolo lido.';
    }

    return texto.replaceFirst('Exception: ', '');
  }

  Future<void> _buscarPedido() async {
    final numero = int.tryParse(_pedidoController.text.trim());

    if (numero == null || numero <= 0) {
      _mostrarMensagem('Informe o número do pedido.', erro: true);
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      carregandoPedido = true;
    });

    try {
      await _carregarConfiguracao();

      final url = Uri.parse(
        "$baseUrl/pedidos/separacao/buscar"
        "?empresa=$empresaId&pedido=$numero",
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 10));

      print('URL: $url');
      print('STATUS HTTP: ${resp.statusCode}');
      print('BODY: ${utf8.decode(resp.bodyBytes)}');

      dynamic data;
      try {
        data = jsonDecode(utf8.decode(resp.bodyBytes));
      } catch (_) {
        data = null;
      }

      final statusApi = data is Map<String, dynamic>
          ? (data["status"] ?? "").toString().trim().toLowerCase()
          : "";

      final mensagemApi = data is Map<String, dynamic>
          ? (data["mensagem"] ?? "").toString().trim().toLowerCase()
          : "";

      if (statusApi == "ja separado" ||
          statusApi == "ja_separado" ||
          mensagemApi.contains("separação aplicada") ||
          mensagemApi.contains("separacao aplicada") ||
          mensagemApi.contains("já possui separação") ||
          mensagemApi.contains("ja possui separacao")) {
        if (!mounted) return;

        setState(() {
          pedidoCarregado = null;
          produtoAtual = null;
          descricaoAtual = '';
          quantidadeVendidaAtual = 0.0;
          unidadeAtual = 'MT';
          rolosProdutoAtual.clear();
          produtosSeparados.clear();
          _codigoController.clear();
          separacaoRegistradaId = null;
        });

        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('ATENÇÃO !!!'),
              content: const Text(
                'Pedido já separado.\n\nNão pode ser separado novamente!',
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );

        return;
      }

      if (resp.statusCode != 200 ||
          data is! Map<String, dynamic> ||
          data["status"] != "ok") {
        final msg = data is Map<String, dynamic>
            ? (data["mensagem"]?.toString() ?? "Erro ao buscar pedido.")
            : "Erro ao buscar pedido.";
        throw Exception(msg);
      }

      final ped = Map<String, dynamic>.from(data["pedido"] as Map);

      final statusPedido = (ped["status"] ?? '')
          .toString()
          .trim()
          .toUpperCase();

      if (statusPedido != 'A') {
        if (!mounted) return;

        setState(() {
          pedidoCarregado = null;
          produtoAtual = null;
          descricaoAtual = '';
          quantidadeVendidaAtual = 0.0;
          unidadeAtual = 'MT';
          rolosProdutoAtual.clear();
          produtosSeparados.clear();
          _codigoController.clear();
          separacaoRegistradaId = null;
        });

        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('ATENÇÃO !!!'),
              content: Text(
                //'Pedido já faturado!\n\nNão pode ser separado.',
                'Pedido já faturado!\n\nNão pode ser separado.',
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );

        return;
      }

      final itensJson = (data["itens"] as List? ?? []);

      final itens = <ItemPedidoMock>[];

      for (int i = 0; i < itensJson.length; i++) {
        final item = Map<String, dynamic>.from(itensJson[i] as Map);

        itens.add(
          ItemPedidoMock(
            sequencia: i + 1,
            produto:
                (item["produto"] as num?)?.toInt() ??
                int.tryParse(item["produto"]?.toString() ?? "0") ??
                0,
            descricao: item["descricao"]?.toString() ?? "",
            quantidade:
                (item["quantidade_vendida"] as num?)?.toDouble() ??
                double.tryParse(
                  item["quantidade_vendida"]?.toString() ?? "0",
                ) ??
                0.0,
            unidade: item["unidade"]?.toString() ?? "",
          ),
        );
      }

      final pedido = PedidoMock(
        numero:
            (ped["numero"] as num?)?.toInt() ??
            int.tryParse(ped["numero"]?.toString() ?? "0") ??
            numero,
        cliente: ped["cliente"]?.toString() ?? "",
        emissao: ped["emissao"]?.toString() ?? "",
        valorTotal:
            (ped["valor_total"] as num?)?.toDouble() ??
            double.tryParse(ped["valor_total"]?.toString() ?? "0") ??
            0.0,
        status: statusPedido,
        itens: itens,
      );

      if (!mounted) return;

      setState(() {
        pedidoCarregado = pedido;
        produtoAtual = null;
        descricaoAtual = '';
        quantidadeVendidaAtual = 0.0;
        unidadeAtual = 'MT';
        rolosProdutoAtual.clear();
        produtosSeparados.clear();
        _codigoController.clear();
        separacaoRegistradaId = null;
      });

      //_mostrarMensagem('Pedido ${pedido.numero} carregado.');
    } catch (e) {
      if (!mounted) return;

      final mensagem = e.toString().replaceFirst('Exception: ', '');

      if (mensagem.contains('separação aplicada') ||
          mensagem.contains('Não é possível separar novamente') ||
          mensagem.contains('já possui separação')) {
        setState(() {
          pedidoCarregado = null;
          produtoAtual = null;
          descricaoAtual = '';
          quantidadeVendidaAtual = 0.0;
          unidadeAtual = 'MT';
          rolosProdutoAtual.clear();
          produtosSeparados.clear();
          _codigoController.clear();
          separacaoRegistradaId = null;
        });
        final mensagemUsuario =
            'Pedido já separado.\nNão pode ser separado novamente!';

        _mostrarAvisoRapidoCentro(mensagemUsuario, aviso: true, tempoMs: 6500);
      } else {
        _mostrarMensagem(mensagem, erro: true);
      }
    } finally {
      if (!mounted) return;

      setState(() {
        carregandoPedido = false;
      });
    }
  }

  ItemPedidoMock? _primeiroItemDoProduto(int produto) {
    final pedido = pedidoCarregado;
    if (pedido == null) return null;

    final itens = pedido.itens
        .where((item) => item.produto == produto)
        .toList();
    if (itens.isEmpty) return null;

    return itens.first;
  }

  bool _codigoJaUtilizado(String codigo) {
    final atual = rolosProdutoAtual.any((rolo) => rolo.codigo == codigo);
    if (atual) return true;

    for (final produto in produtosSeparados) {
      if (produto.rolos.any((rolo) => rolo.codigo == codigo)) {
        return true;
      }
    }

    return false;
  }

  bool _produtoJaSalvo(int produto) {
    return produtosSeparados.any((p) => p.produto == produto);
  }

  void _abrirProdutoParaColeta(ItemPedidoMock item) {
    if (_produtoJaSalvo(item.produto)) {
      _mostrarMensagem(
        'Produto ${item.produto} já foi salvo. Depois faremos opção para reabrir.',
        erro: true,
      );
      return;
    }

    setState(() {
      produtoAtual = item.produto;
      descricaoAtual = item.descricao;
      quantidadeVendidaAtual = _quantidadeVendidaDoProduto(item.produto);
      unidadeAtual = item.unidade;
      rolosProdutoAtual.clear();
      _codigoController.clear();
    });
  }

  Future<RoloSeparado?> _consultarRoloApi(String codigo) async {
    await _carregarConfiguracao();

    final url = Uri.parse(
      "$baseUrl/rolos/consultar-codigo"
      "?empresa=$empresaId&codigo=${Uri.encodeComponent(codigo)}",
    );

    final resp = await http.get(url).timeout(const Duration(seconds: 10));

    print('URL: $url');
    print('STATUS HTTP: ${resp.statusCode}');
    print('BODY: ${utf8.decode(resp.bodyBytes)}');

    dynamic data;
    try {
      data = jsonDecode(utf8.decode(resp.bodyBytes));
    } catch (_) {
      data = null;
    }

    if (resp.statusCode != 200 ||
        data is! Map<String, dynamic> ||
        data["status"] != "ok") {
      final msg = data is Map<String, dynamic>
          ? (data["mensagem"]?.toString() ?? "Erro ao consultar etiqueta.")
          : "Erro ao consultar etiqueta.";
      throw Exception(msg);
    }

    return RoloSeparado(
      codigo: data["codigo_lido"]?.toString() ?? codigo,
      id:
          (data["pror_id"] as num?)?.toInt() ??
          int.tryParse(data["pror_id"]?.toString() ?? "0") ??
          0,
      produto:
          (data["produto_id"] as num?)?.toInt() ??
          int.tryParse(data["produto_id"]?.toString() ?? "0") ??
          0,
      descricaoProduto: data["descricao"]?.toString() ?? "",
      quantidade:
          (data["quantidade"] as num?)?.toDouble() ??
          double.tryParse(data["quantidade"]?.toString() ?? "0") ??
          0.0,
      unidade: data["unidade"]?.toString() ?? "",
    );
  }

  Future<RoloSeparado?> _consultarEtiquetaF22Api(String codigo) async {
    await _carregarConfiguracao();

    final url = Uri.parse(
      "$baseUrl/rolos/consultar-f22"
      "?empresa=$empresaId&codigo=${Uri.encodeComponent(codigo)}",
    );
    final resp = await http.get(url).timeout(const Duration(seconds: 10));

    dynamic data;
    try {
      data = jsonDecode(utf8.decode(resp.bodyBytes));
    } catch (_) {
      data = null;
    }

    if (resp.statusCode != 200 ||
        data is! Map<String, dynamic> ||
        data['status'] != 'ok') {
      final msg = data is Map<String, dynamic>
          ? (data['mensagem']?.toString() ?? 'Erro ao consultar etiqueta F22.')
          : 'Erro ao consultar etiqueta F22.';
      throw Exception(msg);
    }

    return RoloSeparado(
      codigo: data['codigo_lido']?.toString() ?? codigo,
      id: (data['pror_id'] as num?)?.toInt() ??
          int.tryParse(data['pror_id']?.toString() ?? '0') ??
          0,
      produto: (data['produto_id'] as num?)?.toInt() ??
          int.tryParse(data['produto_id']?.toString() ?? '0') ??
          0,
      descricaoProduto: data['descricao']?.toString() ?? '',
      quantidade: (data['quantidade'] as num?)?.toDouble() ??
          double.tryParse(data['quantidade']?.toString() ?? '0') ??
          0.0,
      unidade: data['unidade']?.toString() ?? '',
    );
  }

  bool _prorIdJaUtilizado(int prorId) {
    if (prorId <= 0) return false;
    if (rolosProdutoAtual.any((rolo) => rolo.id == prorId)) return true;
    return produtosSeparados.any(
      (produto) => produto.rolos.any((rolo) => rolo.id == prorId),
    );
  }

  RoloSeparado? _montarLeituraEtiquetaPedidoC(String codigo) {
    final codigoLimpo = codigo.trim().toUpperCase();

    if (!RegExp(r'^C(\d{18}|\d{20})$').hasMatch(codigoLimpo)) {
      return null;
    }

    final pedidoTxt = codigoLimpo.substring(1, 7);
    final produtoTxt = codigoLimpo.substring(7, 14);

    late final String qtdTxt;

    if (codigoLimpo.length == 19) {
      qtdTxt = codigoLimpo.substring(14, 19);
    } else {
      qtdTxt = codigoLimpo.substring(14, 21);
    }

    final pedidoEtiqueta = int.tryParse(pedidoTxt) ?? 0;
    final produtoEtiqueta = int.tryParse(produtoTxt) ?? 0;
    final qtdInt = int.tryParse(qtdTxt) ?? 0;

    final pedidoAtual = pedidoCarregado?.numero ?? 0;

    if (pedidoEtiqueta != pedidoAtual) {
      throw Exception(
        'Etiqueta do pedido $pedidoEtiqueta não pertence ao pedido aberto $pedidoAtual.',
      );
    }

    final itemPedido = _primeiroItemDoProduto(produtoEtiqueta);

    if (itemPedido == null) {
      throw Exception(
        'Produto $produtoEtiqueta não pertence ao pedido $pedidoAtual.',
      );
    }

    // Padrão novo:
    // quantidade * 100
    // 00100 = 1,00
    // 00110 = 1,10
    // 00236 = 2,36
    //final quantidade = qtdInt / 100.0;

    final quantidade = codigoLimpo.length == 19
        ? qtdInt / 100.0
        : qtdInt / 10000.0;

    if (quantidade <= 0) {
      throw Exception('Quantidade inválida na etiqueta: $codigoLimpo.');
    }

    return RoloSeparado(
      codigo: codigoLimpo,
      id: 0, // Etiqueta C não tem PROR_ID.
      produto: produtoEtiqueta,
      descricaoProduto: itemPedido.descricao,
      quantidade: quantidade,
      unidade: itemPedido.unidade,
    );
  }

  Future<void> _processarCodigo(String codigoDigitado) async {
    if (pedidoCarregado == null) {
      _mostrarMensagem('Busque o pedido antes de ler etiquetas.', erro: true);
      return;
    }

    if (produtoAtual == null) {
      _mostrarMensagem(
        'Selecione um produto do pedido antes de ler a etiqueta.',
        erro: true,
      );
      return;
    }

    final codigo = _normalizarCodigo(codigoDigitado);

    if (codigo.isEmpty) {
      _mostrarMensagem('Informe ou leia uma etiqueta.', erro: true);
      return;
    }

    setState(() {
      consultandoEtiqueta = true;
    });

    try {
      RoloSeparado? leitura;

      if (codigo.startsWith('R')) {
        if (!RegExp(r'^R\d{17}$').hasMatch(codigo)) {
          _mostrarMensagem(
            'Etiqueta de rolo inválida: $codigo (${codigo.length} caracteres)',
            erro: true,
          );
          _codigoController.clear();
          return;
        }

        leitura = await _consultarRoloApi(codigo);

        if (leitura == null) {
          _mostrarMensagem('Rolo não encontrado.', erro: true);
          _codigoController.clear();
          return;
        }

        // Para R, continua bloqueando duplicidade.
        if (_codigoJaUtilizado(leitura.codigo)) {
          _mostrarMensagem(
            'Este rolo já foi lido nesta separação.',
            erro: true,
          );
          _codigoController.clear();
          return;
        }
      } else if (codigo.startsWith('C')) {
        leitura = _montarLeituraEtiquetaPedidoC(codigo);

        if (leitura == null) {
          _mostrarMensagem(
            'Etiqueta do pedido inválida: $codigo (${codigo.length} caracteres)',
            erro: true,
          );
          _codigoController.clear();
          return;
        }

        // Para C, NÃO bloqueia código repetido.
        // Pode existir mais de uma etiqueta igual para caixas/volumes iguais.
      } else if (codigo.startsWith('F')) {
        if (!RegExp(r'^F\d{21}$').hasMatch(codigo)) {
          _mostrarMensagem(
            'Etiqueta F22 inválida: $codigo (${codigo.length} caracteres)',
            erro: true,
          );
          _codigoController.clear();
          return;
        }

        leitura = await _consultarEtiquetaF22Api(codigo);

        if (leitura == null || leitura.id <= 0) {
          _mostrarMensagem('Rolo F22 não encontrado.', erro: true);
          _codigoController.clear();
          return;
        }

        if (_prorIdJaUtilizado(leitura.id)) {
          _mostrarMensagem(
            'Este rolo já foi lido nesta separação.',
            erro: true,
          );
          _codigoController.clear();
          return;
        }
      } else {
        _mostrarMensagem(
          'Etiqueta inválida para separação: $codigo',
          erro: true,
        );
        _codigoController.clear();
        return;
      }

      final itemPedido = _primeiroItemDoProduto(leitura.produto);

      if (itemPedido == null) {
        _mostrarMensagem(
          'Produto ${leitura.produto} não pertence ao pedido ${pedidoCarregado!.numero}.',
          erro: true,
        );
        _codigoController.clear();
        return;
      }

      if (_produtoJaSalvo(leitura.produto) && produtoAtual != leitura.produto) {
        _mostrarMensagem(
          'Produto ${leitura.produto} já foi salvo. Depois faremos opção para reabrir.',
          erro: true,
        );
        _codigoController.clear();
        return;
      }

      if (produtoAtual != leitura.produto) {
        _mostrarMensagem(
          'Finalize ou limpe o produto atual antes de ler outro produto.',
          erro: true,
        );
        _codigoController.clear();
        return;
      }

      setState(() {
        rolosProdutoAtual.add(leitura!);
        _codigoController.clear();
      });
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().replaceFirst('Exception: ', '');

      _mostrarMensagem('Erro ao processar etiqueta: $msg', erro: true);
      _codigoController.clear();
    } finally {
      if (!mounted) return;

      setState(() {
        consultandoEtiqueta = false;
      });
    }
  }

  //Future<void> _lerEtiquetaCamera() async {
  //  final String? codigo = await Navigator.push<String>(
  //    context,
  //    MaterialPageRoute(builder: (_) => const ScannerPage()),
  //  );
  //
  //  if (codigo == null || codigo.trim().isEmpty) return;
  //
  //  await _processarCodigo(codigo);
  //}

  Future<void> _lerEtiquetaCamera() async {
    final String? codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerPage(aceitarF22Pedidos: true),
      ),
    );

    if (codigo == null || codigo.trim().isEmpty) {
      return;
    }

    await _processarCodigo(codigo);
  }

  void _simularProximoRolo() {
    if (pedidoCarregado == null) {
      _mostrarMensagem('Busque o pedido antes de simular.', erro: true);
      return;
    }

    final rolosValidos = rolosMock.values.where((rolo) {
      final pertenceAoPedido = _primeiroItemDoProduto(rolo.produto) != null;
      final mesmoProdutoAtual =
          produtoAtual == null || produtoAtual == rolo.produto;

      return pertenceAoPedido &&
          mesmoProdutoAtual &&
          !_codigoJaUtilizado(rolo.codigo);
    }).toList();

    if (rolosValidos.isEmpty) {
      _mostrarMensagem('Nenhum rolo disponível para simular.', erro: true);
      return;
    }

    _processarCodigo(rolosValidos.first.codigo);
  }

  void _testarProdutoErrado() {
    _processarCodigo('R00000699999990800');
  }

  void _removerUltimo() {
    if (rolosProdutoAtual.isEmpty) {
      _mostrarMensagem('Nenhum rolo para remover.', erro: true);
      return;
    }

    final removido = rolosProdutoAtual.last;

    setState(() {
      rolosProdutoAtual.removeLast();

      if (rolosProdutoAtual.isEmpty) {
        produtoAtual = null;
        descricaoAtual = '';
        quantidadeVendidaAtual = 0.0;
        unidadeAtual = 'MT';
      }
    });

    //_mostrarMensagem(
    //'Rolo ${removido.id.toString().padLeft(6, '0')} removido.',
    //);
  }

  void _limparProdutoAtual() {
    if (!possuiProdutoAtual && rolosProdutoAtual.isEmpty) {
      _mostrarMensagem('Não existe produto em separação.', erro: true);
      return;
    }

    setState(() {
      produtoAtual = null;
      descricaoAtual = '';
      quantidadeVendidaAtual = 0.0;
      unidadeAtual = 'MT';
      rolosProdutoAtual.clear();
      _codigoController.clear();
    });

    //_mostrarMensagem('Produto atual limpo.');
  }

  Future<void> _aplicarSeparacaoNoPedidoApi(int separacaoId) async {
    await _carregarConfiguracao();

    final url = Uri.parse('$baseUrl/pedidos/separacao/aplicar-no-pedido');

    final corpo = {
      'empresa': empresaId,
      'separacao_id': separacaoId,
      'usuario': 1,
    };

    final resp = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(corpo),
        )
        .timeout(const Duration(seconds: 15));

    dynamic data;
    try {
      data = jsonDecode(utf8.decode(resp.bodyBytes));
    } catch (_) {
      data = null;
    }

    if (resp.statusCode != 200 ||
        data is! Map<String, dynamic> ||
        data['status'] != 'ok') {
      final msg = data is Map<String, dynamic>
          ? (data['mensagem']?.toString() ??
                'Erro ao aplicar separação no pedido.')
          : 'Erro ao aplicar separação no pedido.';

      throw Exception(msg);
    }
  }

  Future<void> _salvarSeparacaoApi() async {
    final pedido = pedidoCarregado;

    if (separacaoRegistradaId != null) {
      _mostrarMensagem(
        'Esta separação já foi registrada. Nº $separacaoRegistradaId',
        erro: true,
      );
      return;
    }

    if (pedido == null) {
      _mostrarMensagem(
        'Busque o pedido antes de salvar a separação.',
        erro: true,
      );
      return;
    }

    if (possuiProdutoAtual && rolosProdutoAtual.isNotEmpty) {
      _mostrarMensagem(
        'Existe um produto em separação. Salve ou limpe antes de registrar.',
        erro: true,
      );
      return;
    }

    if (produtosSeparados.isEmpty) {
      _mostrarMensagem('Nenhum produto separado para registrar.', erro: true);
      return;
    }

    setState(() {
      salvandoSeparacao = true;
    });

    try {
      await _carregarConfiguracao();

      final url = Uri.parse('$baseUrl/pedidos/separacao/salvar');

      final produtosJson = produtosSeparados.map((produto) {
        return {
          'produto': produto.produto,
          'descricao': produto.descricao,
          'unidade': produto.unidade,
          'vendido': produto.vendido,
          'separado': produto.separado,
          'rolos': produto.rolos.map((rolo) {
            return {
              'id': rolo.id,
              'codigo': rolo.codigo,
              'produto': rolo.produto,
              'descricao': rolo.descricaoProduto,
              'quantidade': rolo.quantidade,
              'unidade': rolo.unidade,
            };
          }).toList(),
        };
      }).toList();

      final corpo = {
        'empresa': empresaId,
        'pedido': pedido.numero,
        'cliente': pedido.cliente,
        'usuario': 1,
        'produtos': produtosJson,
      };

      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(corpo),
          )
          .timeout(const Duration(seconds: 15));

      dynamic data;
      try {
        data = jsonDecode(utf8.decode(resp.bodyBytes));
      } catch (_) {
        data = null;
      }

      if (resp.statusCode != 200 ||
          data is! Map<String, dynamic> ||
          data['status'] != 'ok') {
        final msg = data is Map<String, dynamic>
            ? (data['mensagem']?.toString() ?? 'Erro ao salvar separação.')
            : 'Erro ao salvar separação.';

        throw Exception(msg);
      }

      final separacaoId =
          (data['separacao_id'] as num?)?.toInt() ??
          int.tryParse(data['separacao_id']?.toString() ?? '');

      if (separacaoId == null || separacaoId <= 0) {
        throw Exception(
          'Separação salva, mas a API não retornou o número da separação.',
        );
      }

      if (!mounted) return;

      setState(() {
        separacaoRegistradaId = separacaoId;
      });

      // Agora aplica a separação no pedido oficial.
      await _aplicarSeparacaoNoPedidoApi(separacaoId);

      if (!mounted) return;

      // Fecha a tela/modal do resumo final.
      Navigator.of(context, rootNavigator: true).pop();

      await Future.delayed(const Duration(milliseconds: 150));

      if (!mounted) return;

      _mostrarAvisoRapidoCentro('Separação salva e aplicada\ncom sucesso');

      await Future.delayed(const Duration(milliseconds: 1800));

      if (!mounted) return;

      // Volta para a tela anterior/inicial.
      saidaLiberadaSemConfirmacao = true;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      // Se o resumo estiver aberto, fecha antes de mostrar o erro na tela principal.
      Navigator.of(context, rootNavigator: true).pop();

      await Future.delayed(const Duration(milliseconds: 150));

      if (!mounted) return;

      final mensagem = _tratarMensagemErroSalvarSeparacao(e);

      _mostrarMensagem(
        mensagem.contains('aplicar separação') ||
                mensagem.contains('pedido oficial')
            ? mensagem
            : 'Erro ao salvar/aplicar separação: $mensagem',
        erro: true,
      );
    } finally {
      if (!mounted) return;

      setState(() {
        salvandoSeparacao = false;
      });
    }
  }

  void _salvarProdutoAtual() {
    if (!possuiProdutoAtual || rolosProdutoAtual.isEmpty) {
      _mostrarMensagem('Leia pelo menos um rolo antes de salvar.', erro: true);
      return;
    }

    final resumo = ProdutoSeparadoResumo(
      produto: produtoAtual!,
      descricao: descricaoAtual,
      vendido: quantidadeVendidaAtual,
      separado: totalProdutoAtual,
      unidade: unidadeAtual,
      rolos: List<RoloSeparado>.from(rolosProdutoAtual),
    );

    setState(() {
      produtosSeparados.add(resumo);
      produtoAtual = null;
      descricaoAtual = '';
      quantidadeVendidaAtual = 0.0;
      unidadeAtual = 'MT';
      rolosProdutoAtual.clear();
      _codigoController.clear();
    });

    //_mostrarMensagem('Produto ${resumo.produto} salvo no aparelho.');
    _mostrarAvisoRapidoCentro('Produto salvo com sucesso', tempoMs: 1200);
  }

  Color _corDiferenca() {
    if (!possuiProdutoAtual) return Colors.black54;
    if (diferencaAtual > 0.0001) return Colors.orange.shade800;
    if (diferencaAtual < -0.0001) return Colors.red.shade700;
    return Colors.green.shade700;
  }

  String _textoStatusAtual() {
    if (!possuiProdutoAtual) return 'AGUARDANDO';
    if (diferencaAtual > 0.0001) return 'SOBRA';
    if (diferencaAtual < -0.0001) return 'FALTA';
    return 'FECHADO';
  }

  String _textoFaltaSobra() {
    if (!possuiProdutoAtual) {
      return 'Leia a primeira etiqueta para identificar o produto.';
    }

    if (diferencaAtual > 0.0001) {
      return 'Sobrou ${_formatarQuantidade(diferencaAtual.abs())} $unidadeAtual';
    }

    if (diferencaAtual < -0.0001) {
      return 'Falta ${_formatarQuantidade(diferencaAtual.abs())} $unidadeAtual';
    }

    return 'Quantidade fechada';
  }

  String _tituloTerceiroResumo() {
    if (!possuiProdutoAtual) return 'Falta';

    if (diferencaAtual > 0.0001) return 'Sobra';
    if (diferencaAtual < -0.0001) return 'Falta';

    return 'Zerou';
  }

  String _valorTerceiroResumo() {
    final valor = possuiProdutoAtual ? diferencaAtual.abs() : 0.0;
    return _formatarQuantidade(valor);
  }

  Color _corTerceiroResumo() {
    if (!possuiProdutoAtual) return Colors.red.shade700;

    if (diferencaAtual < -0.0001) return Colors.red.shade700;
    return Colors.green.shade700;
  }

  String _statusProdutoResumo(ProdutoSeparadoResumo produto) {
    final diferenca = produto.separado - produto.vendido;

    if (diferenca > 0.0001) return 'SOBRA';
    if (diferenca < -0.0001) return 'FALTA';
    return 'FECHADO';
  }

  Color _corStatusProdutoResumo(ProdutoSeparadoResumo produto) {
    final diferenca = produto.separado - produto.vendido;

    if (diferenca > 0.0001) return Colors.orange.shade800;
    if (diferenca < -0.0001) return Colors.red.shade700;
    return Colors.green.shade700;
  }

  String _textoSituacaoGeralResumo() {
    if (pedidoCarregado == null) {
      return 'Nenhum pedido carregado.';
    }

    if (produtosSeparados.isEmpty) {
      return 'Nenhum produto foi separado ainda.';
    }

    if (itensPendentesSeparacao.isNotEmpty) {
      return 'Pedido ainda possui ${itensPendentesSeparacao.length} produto(s) pendente(s) de separação.';
    }

    if (diferencaGeralPedido > 0.0001) {
      return 'Pedido separado com sobra geral de ${_formatarQuantidade(diferencaGeralPedido.abs())}.';
    }

    if (diferencaGeralPedido < -0.0001) {
      return 'Pedido separado com falta geral de ${_formatarQuantidade(diferencaGeralPedido.abs())}.';
    }

    return 'Pedido separado corretamente.';
  }

  Color _corSituacaoGeralResumo() {
    if (pedidoCarregado == null || produtosSeparados.isEmpty) {
      return Colors.black54;
    }

    if (itensPendentesSeparacao.isNotEmpty) {
      return Colors.red.shade700;
    }

    if (diferencaGeralPedido > 0.0001) {
      return Colors.orange.shade800;
    }

    if (diferencaGeralPedido < -0.0001) {
      return Colors.red.shade700;
    }

    return Colors.green.shade700;
  }

  String _tituloResumoPorDiferenca(double diferenca) {
    if (diferenca > 0.0001) return 'Sobra';
    if (diferenca < -0.0001) return 'Falta';
    return 'Zerou';
  }

  String _valorResumoPorDiferenca(double diferenca) {
    return _formatarQuantidade(diferenca.abs());
  }

  Color _corResumoPorDiferenca(double diferenca) {
    if (diferenca < -0.0001) return Colors.red.shade700;
    return Colors.green.shade700;
  }

  void _mostrarResumoFinalSeparacao() {
    final pedido = pedidoCarregado;

    if (pedido == null) {
      _mostrarMensagem('Busque o pedido antes de ver o resumo.', erro: true);
      return;
    }

    if (possuiProdutoAtual && rolosProdutoAtual.isNotEmpty) {
      _mostrarMensagem(
        'Existe um produto em separação. Salve ou limpe antes de concluir.',
        erro: true,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),

            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.94,
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Resumo Final da Separação',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: _boxDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedido ${pedido.numero.toString().padLeft(6, '0')}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          pedido.cliente,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _cardResumo(
                                'Pedido',
                                _formatarQuantidade(totalVendidoPedido),
                                Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _cardResumo(
                                'Coleta',
                                _formatarQuantidade(totalSeparadoPedido),
                                Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _cardResumo(
                                _tituloResumoPorDiferenca(diferencaGeralPedido),
                                _valorResumoPorDiferenca(diferencaGeralPedido),
                                _corResumoPorDiferenca(diferencaGeralPedido),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: _boxDecoration(),
                    child: Text(
                      _textoSituacaoGeralResumo(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _corSituacaoGeralResumo(),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  if (separacaoRegistradaId != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Text(
                        'Separação registrada Nº $separacaoRegistradaId',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (produtosSeparados.isNotEmpty)
                            ...produtosSeparados.map(_linhaProdutoResumoFinal),
                          if (itensPendentesSeparacao.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _painelPendentesResumoFinal(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: salvandoSeparacao
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text(
                              'Voltar',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black87,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed:
                                (salvandoSeparacao ||
                                    separacaoRegistradaId != null)
                                ? null
                                : _salvarSeparacaoApi,
                            icon: salvandoSeparacao
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),

                            label: Text(
                              separacaoRegistradaId != null
                                  ? 'Já registrada'
                                  : salvandoSeparacao
                                  ? 'Salvando'
                                  : 'Salvar Separação',

                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
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
      },
    );
  }

  Widget _linhaProdutoResumoFinal(ProdutoSeparadoResumo produto) {
    final diferenca = produto.separado - produto.vendido;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${produto.produto} - ${produto.descricao}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _cardResumo(
                  'Pedido',
                  _formatarQuantidade(produto.vendido),
                  Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _cardResumo(
                  'Coleta',
                  _formatarQuantidade(produto.separado),
                  Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _cardResumo(
                  _tituloResumoPorDiferenca(diferenca),
                  _valorResumoPorDiferenca(diferenca),
                  _corResumoPorDiferenca(diferenca),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rolos lidos: ${produto.rolos.length}',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _painelPendentesResumoFinal() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produtos pendentes',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...itensPendentesSeparacao.map((item) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                '${item.produto} - ${item.descricao} | Vendido: ${_formatarQuantidade(item.quantidade)} ${item.unidade}',
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  bool _temSeparacaoEmAndamento() {
    if (saidaLiberadaSemConfirmacao) {
      return false;
    }

    return pedidoCarregado != null &&
        separacaoRegistradaId == null &&
        (produtosSeparados.isNotEmpty ||
            rolosProdutoAtual.isNotEmpty ||
            produtoAtual != null);
  }

  Future<bool> _confirmarSaidaSeparacao() async {
    if (!_temSeparacaoEmAndamento()) {
      return true;
    }

    final sair = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'ATENÇÃO !!!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          content: const Text(
            'Existe uma separação em andamento.\n\n'
            'Se sair agora, as leituras ainda não registradas serão perdidas.\n\n'
            'Finalize a separação ou continue na tela.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              height: 1.35,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          actions: [
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.black54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sair sem salvar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );

    return sair == true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmarSaidaSeparacao,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),

          appBar: AppBar(
            backgroundColor: const Color(0xFFE8D48A),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            titleSpacing: 0,
            centerTitle: false,
            title: const SizedBox(
              height: 54,
              child: TabBar(
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.black,
                indicatorWeight: 3,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                tabs: [
                  Tab(text: 'Pedido'),
                  Tab(text: 'Separação'),
                ],
              ),
            ),
          ),
          body: SafeArea(
            child: TabBarView(children: [_abaPedido(), _abaSeparacao()]),
          ),
        ),
      ),
    );
  }

  Widget _abaPedido() {
    final pedido = pedidoCarregado;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _boxDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pedidoController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Número do pedido',
                        hintText: 'Ex.: 1930',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.receipt_long_outlined),
                      ),
                      onSubmitted: (_) => _buscarPedido(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: carregandoPedido ? null : _buscarPedido,
                      icon: carregandoPedido
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(carregandoPedido ? 'Buscando' : 'Buscar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            if (pedido == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: _boxDecoration(),
                child: const Text(
                  'Digite o número do pedido para carregar o cabeçalho.\n\n'
                  'Somente pedidos com status A podem ser separados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
              )
            else
              _cabecalhoPedido(pedido),
          ],
        ),
      ),
    );
  }

  Widget _cabecalhoPedido(PedidoMock pedido) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cabeçalho do pedido',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _campoPedidoVertical(
            titulo: 'Pedido',
            valor: pedido.numero.toString().padLeft(6, '0'),
          ),
          const SizedBox(height: 8),
          _campoPedidoVertical(titulo: 'Cliente', valor: pedido.cliente),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _campoPedidoVertical(
                  titulo: 'Emissão',
                  valor: pedido.emissao,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: _campoPedidoVertical(
                  titulo: 'Itens',
                  valor: '${pedido.itens.length}',
                  centralizarValor: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _campoPedidoVertical(
            titulo: 'Valor total',
            valor: 'R\$ ${_formatarValor(pedido.valorTotal)}',
            destaque: true,
          ),
        ],
      ),
    );
  }

  Widget _abaSeparacao() {
    if (pedidoCarregado == null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: _boxDecoration(),
          child: const Text(
            'Busque o pedido na aba Pedido antes de iniciar a separação.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
        ),
      );
    }

    if (produtoAtual == null) {
      return Column(
        children: [
          _painelResumoGeralPedido(),
          Expanded(child: _listaItensPedidoSeparacao()),
          _rodapeResumoPedido(),
        ],
      );
    }

    return Column(
      children: [
        _painelProdutoAtual(),
        _entradaCodigo(),
        Expanded(child: _listaRolos()),
        _rodapeColetaProduto(),
      ],
    );
  }

  Widget _painelResumoGeralPedido() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: _boxDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _cardResumo(
              'Pedido',
              _formatarQuantidade(totalVendidoPedido),
              Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _cardResumo(
              'Coleta',
              _formatarQuantidade(totalSeparadoPedido),
              Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _cardResumo(
              _tituloResumoPorDiferenca(diferencaGeralPedido),
              _valorResumoPorDiferenca(diferencaGeralPedido),
              _corResumoPorDiferenca(diferencaGeralPedido),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaItensPedidoSeparacao() {
    final pedido = pedidoCarregado;

    if (pedido == null || pedido.itens.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        decoration: _boxDecoration(),
        child: const Center(
          child: Text(
            'Nenhum item encontrado para este pedido.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.all(8),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 2, 4, 8),
            child: Text(
              'Itens do pedido',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: pedido.itens.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = pedido.itens[index];

                ProdutoSeparadoResumo? produtoSalvo;

                for (final p in produtosSeparados) {
                  if (p.produto == item.produto) {
                    produtoSalvo = p;
                    break;
                  }
                }

                final separado = produtoSalvo?.separado ?? 0.0;
                final diferenca = separado - item.quantidade;
                final salvo = produtoSalvo != null;

                final tituloDiferenca = salvo
                    ? _tituloResumoPorDiferenca(diferenca)
                    : 'Falta';

                final valorDiferenca = salvo
                    ? _valorResumoPorDiferenca(diferenca)
                    : _formatarQuantidade(item.quantidade);

                final corDiferenca = salvo
                    ? _corResumoPorDiferenca(diferenca)
                    : Colors.red.shade700;

                final textoStatus = salvo ? 'SALVO' : 'PENDENTE';

                final corStatus = salvo
                    ? Colors.green.shade700
                    : Colors.red.shade700;

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _abrirProdutoParaColeta(item),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: salvo
                          ? const Color(0xFFFFF8D6)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: salvo ? Colors.amber.shade300 : Colors.black12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.produto} - ${item.descricao}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: corStatus.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: corStatus),
                              ),
                              child: Text(
                                textoStatus,
                                style: TextStyle(
                                  color: corStatus,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _cardResumo(
                                'Pedido',
                                _formatarQuantidade(item.quantidade),
                                Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _cardResumo(
                                'Coleta',
                                _formatarQuantidade(separado),
                                Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _cardResumo(
                                tituloDiferenca,
                                valorDiferenca,
                                corDiferenca,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          salvo
                              ? 'Toque para consultar. Reabrir será liberado depois.'
                              : 'Toque para iniciar a coleta deste produto.',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
    );
  }

  Widget _rodapeResumoPedido() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(10),
      decoration: _boxDecoration(),
      child: SizedBox(
        height: 58,
        child: _botaoRodape(
          icone: Icons.fact_check_outlined,
          texto: 'Resumo',
          onTap: _mostrarResumoFinalSeparacao,
          destaque: true,
        ),
      ),
    );
  }

  Widget _rodapeColetaProduto() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(10),
      decoration: _boxDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _botaoRodape(
              icone: Icons.arrow_back,
              texto: 'Voltar',
              onTap: () {
                if (rolosProdutoAtual.isNotEmpty) {
                  _mostrarMensagem(
                    'Salve ou limpe o produto antes de voltar.',
                    erro: true,
                  );
                  return;
                }

                _limparProdutoAtual();
              },
              destaque: false,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _botaoRodape(
              icone: Icons.save_outlined,
              texto: 'Salvar Produto',
              onTap: _salvarProdutoAtual,
              destaque: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _painelProdutoAtual() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: _boxDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _cardResumo(
              'Pedido',
              possuiProdutoAtual
                  ? _formatarQuantidade(quantidadeVendidaAtual)
                  : '0,0',
              Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _cardResumo(
              'Coleta',
              _formatarQuantidade(totalProdutoAtual),
              Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _cardResumo(
              _tituloTerceiroResumo(),
              _valorTerceiroResumo(),
              _corTerceiroResumo(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entradaCodigo() {
    return SeparacaoBotaoLerEtiqueta(
      processando: consultandoEtiqueta,
      habilitado: diferencaAtual < 0,
      onPressed: _lerEtiquetaCamera,
      textoProcessando: 'Consultando etiqueta...',
    );
  }

  Widget _listaRolos() {
    if (rolosProdutoAtual.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        decoration: _boxDecoration(),
        child: const Center(
          child: Text(
            'Nenhum rolo lido para o produto atual.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      decoration: _boxDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F1F3),
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: const [
                SizedBox(
                  width: 72,
                  child: Text(
                    'Rolo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Código',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    'Qtde',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: rolosProdutoAtual.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Colors.black12),
              itemBuilder: (context, index) {
                final rolo = rolosProdutoAtual[index];

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 11,
                  ),
                  color: index.isEven ? Colors.white : const Color(0xFFFFF9E6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          rolo.id.toString().padLeft(6, '0'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          rolo.codigo,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: Text(
                          '${_formatarQuantidade(rolo.quantidade)} ${rolo.unidade}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumoProdutosSalvos({bool compacto = false}) {
    if (produtosSeparados.isEmpty) {
      if (compacto) return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _boxDecoration(),
        child: const Text(
          'Nenhum produto separado ainda.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: compacto
          ? const EdgeInsets.fromLTRB(12, 0, 12, 6)
          : EdgeInsets.zero,
      padding: const EdgeInsets.all(10),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Produtos salvos no aparelho',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...produtosSeparados.map((produto) {
            final dif = produto.separado - produto.vendido;
            final cor = dif > 0.0001
                ? Colors.orange.shade800
                : dif < -0.0001
                ? Colors.red.shade700
                : Colors.green.shade700;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${produto.produto} - ${produto.descricao}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${_formatarQuantidade(produto.separado)} ${produto.unidade}',
                    style: TextStyle(color: cor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _rodapeAcoes() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(10),
      decoration: _boxDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _botaoRodape(
              icone: Icons.save_outlined,
              texto: 'Salvar Produto',
              onTap: _salvarProdutoAtual,
              destaque: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _botaoRodape(
              icone: Icons.fact_check_outlined,
              texto: 'Resumo',
              onTap: _mostrarResumoFinalSeparacao,
              destaque: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoPedidoVertical({
    required String titulo,
    required String valor,
    bool destaque = false,
    bool centralizarValor = false,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: titulo,
        filled: true,
        fillColor: destaque ? const Color(0xFFFFF9E3) : const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(
            color: destaque ? Colors.orange.shade300 : Colors.black12,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(
            color: destaque ? Colors.orange.shade400 : Colors.black26,
          ),
        ),
        labelStyle: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      child: Text(
        valor,
        textAlign: centralizarValor ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          color: destaque ? Colors.deepOrange.shade700 : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: destaque ? 18 : 16,
        ),
      ),
    );
  }

  Widget _linhaDetalhePedido({
    required String titulo,
    required String valor,
    bool destaque = false,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: destaque ? const Color(0xFFFFF9E3) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: destaque ? Colors.orange.shade300 : Colors.black12,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              '$titulo:',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                color: destaque ? Colors.orange.shade900 : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: destaque ? 17 : 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardResumo(String titulo, String valor, Color cor) {
    return SeparacaoCardResumo(titulo: titulo, valor: valor, cor: cor);
  }

  Widget _botaoPequeno({
    required IconData icone,
    required String texto,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icone, size: 18),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            texto,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFFF3F4F6),
          foregroundColor: Colors.black87,
          side: const BorderSide(color: Colors.black26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _botaoRodape({
    required IconData icone,
    required String texto,
    required VoidCallback onTap,
    bool destaque = false,
  }) {
    return SeparacaoBotaoRodape(
      icone: icone,
      texto: texto,
      onTap: onTap,
      destaque: destaque,
    );
  }

  BoxDecoration _boxDecoration() {
    return separacaoBoxDecoration();
  }
}
