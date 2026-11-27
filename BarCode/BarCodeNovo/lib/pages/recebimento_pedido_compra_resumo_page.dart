import 'dart:math';

import 'package:flutter/material.dart';

import '../models/pedido_compra_leitura_etiqueta.dart';
import '../models/pedido_compra_recebimento_detalhe.dart';
import '../services/pedido_compra_recebimento_service.dart';
import '../services/pedido_compra_recebimento_rascunho_store.dart';

class RecebimentoPedidoCompraResumoPage extends StatefulWidget {
  final PedidoCompraRecebimentoDetalhe detalhe;
  final Map<int, PedidoCompraLeituraSessao> sessoesPorItem;

  const RecebimentoPedidoCompraResumoPage({
    super.key,
    required this.detalhe,
    required this.sessoesPorItem,
  });

  @override
  State<RecebimentoPedidoCompraResumoPage> createState() =>
      _RecebimentoPedidoCompraResumoPageState();
}

class _RecebimentoPedidoCompraResumoPageState
    extends State<RecebimentoPedidoCompraResumoPage> {
  final PedidoCompraRecebimentoRascunhoStore _rascunhos =
      PedidoCompraRecebimentoRascunhoStore();
  String? _operacaoGuid;
  bool _confirmando = false;

  @override
  void initState() {
    super.initState();
    _carregarOperacaoGuid();
  }

  Future<void> _carregarOperacaoGuid() async {
    try {
      final guid = await _rascunhos.obterOuCriarOperacaoGuid(
        empresa: widget.detalhe.empresa,
        pedido: widget.detalhe.pedidoId,
        criarGuid: _novoOperacaoGuid,
      );
      if (mounted) setState(() => _operacaoGuid = guid);
    } catch (e) {
      if (mounted) {
        _mostrarMensagem(
          e.toString().replaceFirst('Exception: ', ''),
          erro: true,
        );
      }
    }
  }

  int get _itensConferidos => widget.sessoesPorItem.values
      .where((sessao) => sessao.concluidoLocalmente)
      .length;

  int get _totalEtiquetas => widget.sessoesPorItem.values.fold(
    0,
    (total, sessao) => total + sessao.leituras.length,
  );

  bool get _possuiExcedente => widget.detalhe.itens.any((item) {
    final lido = widget.sessoesPorItem[item.sequencia]?.quantidadeLida ?? 0;
    return lido > item.saldo + 0.0001;
  });

  @override
  Widget build(BuildContext context) {
    final itens = List<PedidoCompraRecebimentoItem>.from(widget.detalhe.itens)
      ..sort((a, b) => a.sequencia.compareTo(b.sequencia));
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8D48A),
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Resumo da Conferência',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _capa(),
            const SizedBox(height: 14),
            ...itens.map(_cardItem),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _confirmando || _operacaoGuid == null
                    ? null
                    : _confirmarRecebimento,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  _confirmando ? 'CONFIRMANDO...' : 'CONFIRMAR RECEBIMENTO',
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'As leituras permanecem revisáveis até a confirmação no ERP.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _capa() => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pedido de Compra ${widget.detalhe.numeroFormatado}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          _linha('Total de itens', widget.detalhe.itens.length.toString()),
          _linha('Itens conferidos', _itensConferidos.toString()),
          _linha(
            'Itens pendentes',
            (widget.detalhe.itens.length - _itensConferidos).toString(),
          ),
          _linha('Etiquetas lidas', _totalEtiquetas.toString()),
        ],
      ),
    ),
  );

  Widget _cardItem(PedidoCompraRecebimentoItem item) {
    final sessao = widget.sessoesPorItem[item.sequencia];
    final lido = sessao?.quantidadeLida ?? 0;
    final saldo = (item.saldo - lido).clamp(0, double.infinity).toDouble();
    final concluido = sessao?.concluidoLocalmente ?? false;
    return Card(
      color: concluido ? const Color(0xFFFFF8D6) : Colors.white,
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Produto ${item.produto}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Text(item.descricao.isEmpty ? '-' : item.descricao),
            const Divider(height: 20),
            _linha('Pedido', _formatarQuantidade(item.quantidade)),
            _linha(
              'Recebido atual',
              _formatarQuantidade(item.quantidadeRecebida),
            ),
            _linha('Lido nesta sessão', _formatarQuantidade(lido)),
            _linha('Saldo estimado', _formatarQuantidade(saldo)),
            _linha(
              'Situação local',
              concluido ? 'Conferido localmente' : 'Pendente',
            ),
          ],
        ),
      ),
    );
  }

  Widget _linha(String rotulo, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        Expanded(child: Text('$rotulo:')),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Future<void> _confirmarRecebimento() async {
    if (_totalEtiquetas == 0) {
      _mostrarMensagem(
        'Leia ao menos uma etiqueta antes de confirmar.',
        erro: true,
      );
      return;
    }
    var excedenteConfirmado = false;
    if (_possuiExcedente) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar excedente'),
          content: const Text(
            'Há quantidade acima do saldo do pedido. Confirma gravar o excedente?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
      excedenteConfirmado = true;
    }
    setState(() => _confirmando = true);
    try {
      final service = await PedidoCompraRecebimentoService.daConfiguracao();
      final retorno = await service.confirmarRecebimento(
        detalhe: widget.detalhe,
        sessoesPorItem: widget.sessoesPorItem,
        operacaoGuid: _operacaoGuid!,
        excedenteConfirmado: excedenteConfirmado,
      );
      await _rascunhos.apagarPedido(
        empresa: widget.detalhe.empresa,
        pedido: widget.detalhe.pedidoId,
      );
      if (!mounted) return;
      final filho = (retorno['pedido_filho'] ?? 0).toString();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Recebimento confirmado'),
          content: Text(
            filho == '0'
                ? 'O recebimento foi gravado no ERP.'
                : 'O recebimento foi gravado no ERP. Pedido filho gerado: $filho.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _mostrarMensagem(
          e.toString().replaceFirst('Exception: ', ''),
          erro: true,
        );
      }
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  void _mostrarMensagem(String mensagem, {bool erro = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: erro ? Colors.red.shade700 : Colors.black87,
        ),
      );
  }
}

String _novoOperacaoGuid() {
  final random = Random.secure();
  final valores = List<int>.generate(16, (_) => random.nextInt(256));
  valores[6] = (valores[6] & 0x0f) | 0x40;
  valores[8] = (valores[8] & 0x3f) | 0x80;
  final hex = valores
      .map((valor) => valor.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String _formatarQuantidade(double valor) {
  var texto = valor.toStringAsFixed(4);
  texto = texto.replaceFirst(RegExp(r'\.?0+$'), '');
  return texto.replaceAll('.', ',');
}
