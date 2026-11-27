import 'package:flutter/material.dart';

import '../models/pedido_compra_recebimento.dart';
import '../models/pedido_compra_recebimento_detalhe.dart';
import '../models/pedido_compra_leitura_etiqueta.dart';
import '../services/pedido_compra_recebimento_service.dart';
import '../services/pedido_compra_recebimento_rascunho_store.dart';
import 'recebimento_pedido_compra_leitura_page.dart';
import 'recebimento_pedido_compra_resumo_page.dart';

class RecebimentoPedidoCompraDetalhePage extends StatefulWidget {
  final PedidoCompraRecebimento pedido;

  const RecebimentoPedidoCompraDetalhePage({super.key, required this.pedido});

  @override
  State<RecebimentoPedidoCompraDetalhePage> createState() =>
      _RecebimentoPedidoCompraDetalhePageState();
}

class _RecebimentoPedidoCompraDetalhePageState
    extends State<RecebimentoPedidoCompraDetalhePage> {
  PedidoCompraRecebimentoDetalhe? _detalhe;
  final Map<int, PedidoCompraLeituraSessao> _sessoesPorItem = {};
  final PedidoCompraRecebimentoRascunhoStore _rascunhos =
      PedidoCompraRecebimentoRascunhoStore();
  bool _carregando = true;
  String? _erro;
  String? _avisoRascunho;

  PedidoCompraLeituraSessao? _sessaoDo(PedidoCompraRecebimentoItem item) =>
      _sessoesPorItem[item.sequencia];

  bool _itemConcluido(PedidoCompraRecebimentoItem item) =>
      _sessaoDo(item)?.concluidoLocalmente ?? false;

  bool get _pedidoEncerrado {
    final status = _detalhe?.status.toUpperCase();
    return status == 'T' || status == 'R' || status == 'C';
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      final service = await PedidoCompraRecebimentoService.daConfiguracao();
      final detalhe = await service.consultarDetalhe(
        empresa: widget.pedido.empresa,
        pedidoId: widget.pedido.pedidoId,
      );

      if (!mounted) return;
      final rascunhos = await _rascunhos.carregarPedido(
        empresa: widget.pedido.empresa,
        pedido: widget.pedido.pedidoId,
      );
      final itensAtuais = {
        for (final item in detalhe.itens) item.sequencia: item,
      };
      final sessoesRestauradas = <int, PedidoCompraLeituraSessao>{};
      var divergencias = 0;
      for (final entrada in rascunhos.entries) {
        final itemAtual = itensAtuais[entrada.key];
        if (itemAtual == null || itemAtual.produto != entrada.value.produto) {
          divergencias++;
          continue;
        }
        sessoesRestauradas[entrada.key] = entrada.value.sessao;
      }
      if (!mounted) return;
      setState(() {
        _detalhe = detalhe;
        _sessoesPorItem
          ..clear()
          ..addAll(sessoesRestauradas);
        _avisoRascunho = divergencias == 0
            ? null
            : '$divergencias rascunho(s) local(is) nao foi(ram) aplicado(s), pois o item do pedido mudou. Os dados foram preservados no celular.';
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = _mensagemErro(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8D48A),
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Pedido de Compra ${widget.pedido.numeroFormatado}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _carregando ? null : _carregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: _conteudo()),
    );
  }

  Widget _conteudo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 52, color: Colors.black54),
              const SizedBox(height: 12),
              Text(
                _erro!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _carregar,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final detalhe = _detalhe;
    if (detalhe == null) return const SizedBox.shrink();
    final itens = List<PedidoCompraRecebimentoItem>.from(detalhe.itens)
      ..sort((a, b) {
        final aConcluido = _itemConcluido(a);
        final bConcluido = _itemConcluido(b);
        if (aConcluido != bConcluido) return aConcluido ? 1 : -1;
        return a.sequencia.compareTo(b.sequencia);
      });

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _capa(detalhe),
          if (_avisoRascunho != null) ...[
            const SizedBox(height: 10),
            Card(
              color: const Color(0xFFFFF3CD),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_avisoRascunho!),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (!_pedidoEncerrado) ...[
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _abrirResumo(detalhe),
                icon: const Icon(Icons.summarize_outlined),
                label: const Text('RESUMO'),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'Itens do Pedido (${itens.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (itens.isEmpty)
            const Card(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Este Pedido de Compra não possui itens.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          else
            ...itens.map(_cardItem),
        ],
      ),
    );
  }

  Widget _capa(PedidoCompraRecebimentoDetalhe detalhe) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido de Compra ${detalhe.numeroFormatado}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  backgroundColor: const Color(0xFFE8D48A),
                  label: Text(
                    _statusDescricao(detalhe.status),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(),
            _linha(
              'Fornecedor',
              detalhe.fornecedorNome.isEmpty
                  ? 'Fornecedor não informado'
                  : detalhe.fornecedorNome,
            ),
            _linha('Emissão', detalhe.dataEmissao ?? '-'),
            _linha('Status', _statusDescricao(detalhe.status)),
          ],
        ),
      ),
    );
  }

  Widget _cardItem(PedidoCompraRecebimentoItem item) {
    final sessao = _sessaoDo(item);
    final concluido = _itemConcluido(item);
    final lido = sessao?.quantidadeLida ?? 0;
    final saldoEstimado = (item.saldo - lido)
        .clamp(0, double.infinity)
        .toDouble();
    return Card(
      color: concluido ? const Color(0xFFFFF8D6) : Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: concluido ? const Color(0xFFE8D48A) : Colors.black12,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _pedidoEncerrado ? null : () => _abrirLeitura(item),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1E6BA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.sequencia.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Produto ${item.produto}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.descricao.isEmpty ? '-' : item.descricao,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _pedidoEncerrado
                        ? 'ENCERRADO'
                        : (concluido
                              ? 'LOCAL'
                              : (item.status.isEmpty ? '-' : item.status)),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 20),
              _linhaItem('Pedido', _formatarQuantidade(item.quantidade)),
              _linhaItem(
                'Recebido',
                _formatarQuantidade(item.quantidadeRecebida),
              ),
              _linhaItem(
                'Não atendido',
                _formatarQuantidade(item.quantidadeNaoAtendida),
              ),
              _linhaItem('Saldo', _formatarQuantidade(item.saldo)),
              _linhaItem('Status', item.status.isEmpty ? '-' : item.status),
              if (sessao != null && !_pedidoEncerrado) ...[
                const Divider(height: 20),
                _linhaItem('Lido nesta sessão', _formatarQuantidade(lido)),
                _linhaItem(
                  'Saldo estimado',
                  _formatarQuantidade(saldoEstimado),
                ),
                _linhaItem(
                  'Situação local',
                  concluido ? 'Conferido localmente' : 'Leitura em andamento',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirLeitura(PedidoCompraRecebimentoItem item) async {
    if (_pedidoEncerrado) {
      await _mostrarCensura(
        'Este Pedido de Compra ja esta encerrado e nao permite novas leituras.',
      );
      return;
    }
    if (item.saldo <= 0) {
      _mostrarMensagem(
        'Este item não possui saldo disponível para leitura.',
        erro: true,
      );
      return;
    }

    final leituras = await Navigator.push<PedidoCompraLeituraSessao>(
      context,
      MaterialPageRoute(
        builder: (_) => RecebimentoPedidoCompraLeituraPage(
          empresa: widget.pedido.empresa,
          pedido: widget.pedido.pedidoId,
          item: item,
          sessaoInicial: _sessoesPorItem[item.sequencia],
        ),
      ),
    );

    if (!mounted || leituras == null) return;
    setState(() {
      _sessoesPorItem[item.sequencia] = leituras;
    });
  }

  Future<void> _abrirResumo(PedidoCompraRecebimentoDetalhe detalhe) async {
    final confirmado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecebimentoPedidoCompraResumoPage(
          detalhe: detalhe,
          sessoesPorItem: _sessoesPorItem,
        ),
      ),
    );
    if (confirmado != true || !mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _mostrarCensura(String mensagem) {
    if (!mounted) return Future.value();
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leitura indisponivel'),
        content: Text(mensagem),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _mostrarMensagem(String mensagem, {bool erro = false}) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leitura indisponivel'),
        content: Text(mensagem),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _linha(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              rotulo,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(valor.isEmpty ? '-' : valor)),
        ],
      ),
    );
  }

  Widget _linhaItem(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text('$rotulo:')),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

String _statusDescricao(String status) {
  switch (status.toUpperCase()) {
    case 'A':
      return 'Aberto';
    case 'P':
      return 'Parcial';
    default:
      return status.isEmpty ? '-' : status;
  }
}

String _formatarQuantidade(double valor) {
  var texto = valor.toStringAsFixed(4);
  texto = texto.replaceFirst(RegExp(r'\.?0+$'), '');
  return texto.replaceAll('.', ',');
}

String _mensagemErro(Object erro) {
  return erro.toString().replaceFirst('Exception: ', '');
}
