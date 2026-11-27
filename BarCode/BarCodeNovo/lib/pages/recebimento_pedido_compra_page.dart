import 'package:flutter/material.dart';

import '../models/pedido_compra_recebimento.dart';
import '../services/pedido_compra_recebimento_service.dart';
import 'recebimento_pedido_compra_detalhe_page.dart';

class RecebimentoPedidoCompraPage extends StatefulWidget {
  const RecebimentoPedidoCompraPage({super.key});

  @override
  State<RecebimentoPedidoCompraPage> createState() =>
      _RecebimentoPedidoCompraPageState();
}

class _RecebimentoPedidoCompraPageState
    extends State<RecebimentoPedidoCompraPage> {
  PedidoCompraRecebimentoService? _service;
  List<PedidoCompraRecebimento> _pedidos = const [];
  int? _empresa;
  bool _carregando = true;
  String? _erro;

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
      final service =
          _service ?? await PedidoCompraRecebimentoService.daConfiguracao();
      final pedidos = await service.listarDisponiveis();

      if (!mounted) return;
      setState(() {
        _service = service;
        _empresa = service.empresaId;
        _pedidos = pedidos;
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
        title: const Text(
          'Recebimento de Compras',
          style: TextStyle(fontWeight: FontWeight.bold),
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

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _resumo(),
          const SizedBox(height: 10),
          if (_pedidos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 64),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 58,
                    color: Colors.black38,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Nenhum Pedido de Compra disponível para recebimento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ],
              ),
            )
          else
            ..._pedidos.map(_cardPedido),
        ],
      ),
    );
  }

  Widget _resumo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_outlined, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Empresa configurada: ${_empresa ?? '-'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${_pedidos.length} pedido(s)',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _cardPedido(PedidoCompraRecebimento pedido) {
    final status = _statusDescricao(pedido.status);

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirDetalhe(pedido),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido de Compra ${pedido.numeroFormatado}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8D48A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              pedido.fornecedorNome.isEmpty
                  ? 'Fornecedor não informado'
                  : pedido.fornecedorNome,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text('Emissão: ${pedido.dataEmissao}')),
                Text('${pedido.totalItens} item(ns)'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text('Pendentes: ${pedido.itensPendentes}'),
                ),
                Text(
                  'Qtde. pendente: ${_formatarQuantidade(pedido.quantidadePendente)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.black54),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Toque para abrir o recebimento.',
              style: TextStyle(color: Colors.black54),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirDetalhe(PedidoCompraRecebimento pedido) async {
    final atualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecebimentoPedidoCompraDetalhePage(pedido: pedido),
      ),
    );
    if (atualizado == true && mounted) {
      await _carregar();
    }
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
