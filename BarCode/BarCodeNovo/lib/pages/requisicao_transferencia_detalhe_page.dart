import 'package:flutter/material.dart';

import '../models/requisicao_transferencia.dart';
import '../models/requisicao_transferencia_item.dart';
import '../services/requisicao_transferencia_service.dart';
import 'requisicao_transferencia_item_separacao_page.dart';

class RequisicaoTransferenciaDetalhePage extends StatefulWidget {
  final RequisicaoTransferencia requisicaoInicial;
  final RequisicaoTransferenciaService service;

  const RequisicaoTransferenciaDetalhePage({
    super.key,
    required this.requisicaoInicial,
    required this.service,
  });

  @override
  State<RequisicaoTransferenciaDetalhePage> createState() =>
      _RequisicaoTransferenciaDetalhePageState();
}

class _RequisicaoTransferenciaDetalhePageState
    extends State<RequisicaoTransferenciaDetalhePage> {
  RequisicaoTransferencia? _requisicao;
  List<RequisicaoTransferenciaItem> _itens = const [];
  bool _carregando = true;
  bool _iniciandoSeparacao = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final detalhe = await widget.service.consultarDetalhe(
        widget.requisicaoInicial.id,
      );

      if (!mounted) return;
      setState(() {
        _requisicao = detalhe.requisicao;
        _itens = detalhe.itens;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = e.toString().replaceFirst('Exception: ', '');
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
          'Requisição ${widget.requisicaoInicial.numeroFormatado}',
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
              const Icon(Icons.error_outline, size: 52, color: Colors.red),
              const SizedBox(height: 12),
              Text(_erro!, textAlign: TextAlign.center),
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

    final requisicao = _requisicao ?? widget.requisicaoInicial;

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _capa(requisicao),
          const SizedBox(height: 14),
          Text(
            'Itens (${_itens.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_itens.isEmpty)
            const Card(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Esta requisição não possui itens ativos.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._itens.map(_itemCard),
        ],
      ),
    );
  }

  Widget _capa(RequisicaoTransferencia requisicao) {
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
                    'Requisição ${requisicao.numeroFormatado}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  backgroundColor: const Color(0xFFE8D48A),
                  label: Text(
                    requisicao.status,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(),
            _linha(
              'Matriz',
              _empresa(requisicao.nomeMatriz, requisicao.empresaMatriz),
            ),
            _linha(
              'Solicitante',
              _empresa(
                requisicao.nomeSolicitante,
                requisicao.empresaSolicitante,
              ),
            ),
            _linha('Emissão', requisicao.emissao),
            if (requisicao.lancamento.isNotEmpty)
              _linha('Lançamento', requisicao.lancamento),
            _linha(
              'Quantidade de itens',
              requisicao.quantidadeItens.toString(),
            ),
            _linha(
              'Quantidade total',
              _formatarQuantidade(requisicao.quantidadeTotal),
            ),
            if (requisicao.observacao.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Observação',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(requisicao.observacao),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemCard(RequisicaoTransferenciaItem item) {
    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _iniciandoSeparacao ? null : () => _abrirSeparacao(item),
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
                          '${item.produto}  ${item.descricao}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Solicitada: ${_formatarQuantidade(item.quantidadeSolicitada)} ${item.unidade}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Toque para separar',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.status,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black45),
                ],
              ),
              if (item.observacao.isNotEmpty) ...[
                const Divider(height: 20),
                Text('Observação: ${item.observacao}'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirSeparacao(RequisicaoTransferenciaItem item) async {
    var requisicao = _requisicao ?? widget.requisicaoInicial;
    var itemAtual = item;

    if (requisicao.status == 'L') {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Iniciar separação'),
          content: Text(
            'Deseja iniciar a separação da Requisição '
            '${requisicao.numeroFormatado}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );

      if (confirmar != true || !mounted) return;

      setState(() => _iniciandoSeparacao = true);

      try {
        final inicio = await widget.service.assumir(requisicao.id);
        final detalhe = await widget.service.consultarDetalhe(requisicao.id);

        requisicao = detalhe.requisicao;
        for (final itemRecarregado in detalhe.itens) {
          if (itemRecarregado.sequencia == item.sequencia) {
            itemAtual = itemRecarregado;
            break;
          }
        }

        if (!mounted) return;
        setState(() {
          _requisicao = detalhe.requisicao;
          _itens = detalhe.itens;
        });

        _mostrarMensagem(
          inicio.mensagem.isEmpty
              ? 'Separação iniciada com sucesso.'
              : inicio.mensagem,
        );
      } catch (e) {
        if (!mounted) return;
        _mostrarMensagem(_mensagemErro(e), erro: true);
        return;
      } finally {
        if (mounted) {
          setState(() => _iniciandoSeparacao = false);
        }
      }
    }

    if (requisicao.status != 'S') {
      _mostrarMensagem(
        'A requisição não está disponível para separação.',
        erro: true,
      );
      return;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequisicaoTransferenciaItemSeparacaoPage(
          requisicao: requisicao,
          item: itemAtual,
          service: widget.service,
        ),
      ),
    );

    if (mounted) {
      await _carregar();
    }
  }

  void _mostrarMensagem(String mensagem, {bool erro = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: erro ? Colors.red.shade700 : Colors.black87,
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
            width: 128,
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
}

String _empresa(String nome, int codigo) {
  return nome.isEmpty ? codigo.toString() : '$codigo - $nome';
}

String _formatarQuantidade(double valor) {
  var texto = valor.toStringAsFixed(4);
  texto = texto.replaceFirst(RegExp(r'\.?0+$'), '');
  return texto.replaceAll('.', ',');
}

String _mensagemErro(Object erro) {
  return erro.toString().replaceFirst('Exception: ', '');
}
