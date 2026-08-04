import 'package:flutter/material.dart';

import '../models/requisicao_transferencia.dart';
import '../services/requisicao_transferencia_service.dart';
import 'requisicao_transferencia_separacao_page.dart';

class RequisicoesTransferenciaPage extends StatefulWidget {
  const RequisicoesTransferenciaPage({super.key});

  @override
  State<RequisicoesTransferenciaPage> createState() =>
      _RequisicoesTransferenciaPageState();
}

class _RequisicoesTransferenciaPageState
    extends State<RequisicoesTransferenciaPage> {
  RequisicaoTransferenciaService? _service;
  List<RequisicaoTransferencia> _requisicoes = const [];
  int? _empresaMatriz;
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
          _service ?? await RequisicaoTransferenciaService.daConfiguracao();
      final requisicoes = await service.listarDisponiveis();

      if (!mounted) return;
      setState(() {
        _service = service;
        _empresaMatriz = service.empresaMatriz;
        _requisicoes = requisicoes;
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
          'Requisições para separação',
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                const Icon(Icons.business, color: Colors.black54),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Matriz configurada: ${_empresaMatriz ?? '-'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${_requisicoes.length} requisição(ões)',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_requisicoes.isEmpty)
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
                    'Não há requisições liberadas ou em separação para esta matriz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ],
              ),
            )
          else
            ..._requisicoes.map(_cardRequisicao),
        ],
      ),
    );
  }

  Widget _cardRequisicao(RequisicaoTransferencia requisicao) {
    final ehPendencia = requisicao.ehPendenciaAt;
    final corBase = ehPendencia ? const Color(0xFFFFF1F2) : Colors.white;
    final corBorda = ehPendencia ? const Color(0xFFF4A6AE) : Colors.black12;
    final corSelo = ehPendencia
        ? const Color(0xFFD94A58)
        : const Color(0xFFE8D48A);
    final corTextoSelo = ehPendencia ? Colors.white : Colors.black;

    return Card(
      color: corBase,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: corBorda),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirSeparacao(requisicao),
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
                      color: corSelo,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ehPendencia ? 'AT' : requisicao.status,
                      style: TextStyle(
                        color: corTextoSelo,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (ehPendencia) ...[
                const SizedBox(height: 6),
                const Text(
                  'Pendência',
                  style: TextStyle(
                    color: Color(0xFFB42333),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                requisicao.nomeSolicitante.isEmpty
                    ? 'Filial ${requisicao.empresaSolicitante}'
                    : requisicao.nomeSolicitante,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: Text('Emissão: ${requisicao.emissao}')),
                  Text('${requisicao.quantidadeItens} item(ns)'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      requisicao.status == 'S'
                          ? 'Toque para continuar a separação'
                          : 'Toque para visualizar',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  Text(
                    'Qtde.: ${_formatarQuantidade(requisicao.quantidadeTotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.black54),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirSeparacao(RequisicaoTransferencia requisicao) async {
    final service = _service;
    if (service == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequisicaoTransferenciaSeparacaoPage(
          requisicaoInicial: requisicao,
          service: service,
        ),
      ),
    );

    if (mounted) {
      await _carregar();
    }
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
