import 'package:flutter/material.dart';

import '../models/leitura_etiqueta_separacao.dart';
import '../models/requisicao_transferencia.dart';
import '../models/requisicao_transferencia_item.dart';
import '../models/requisicao_transferencia_leitura.dart';
import '../services/requisicao_transferencia_service.dart';
import '../widgets/separacao_produto_widgets.dart';
import 'scanner_page.dart';

class RequisicaoTransferenciaItemSeparacaoPage extends StatefulWidget {
  final RequisicaoTransferencia requisicao;
  final RequisicaoTransferenciaItem item;
  final RequisicaoTransferenciaService service;

  const RequisicaoTransferenciaItemSeparacaoPage({
    super.key,
    required this.requisicao,
    required this.item,
    required this.service,
  });

  @override
  State<RequisicaoTransferenciaItemSeparacaoPage> createState() =>
      _RequisicaoTransferenciaItemSeparacaoPageState();
}

class _RequisicaoTransferenciaItemSeparacaoPageState
    extends State<RequisicaoTransferenciaItemSeparacaoPage> {
  late RequisicaoTransferenciaItem _item;
  List<RequisicaoTransferenciaLeitura> _leiturasPersistidas = const [];
  final List<LeituraEtiquetaSeparacao> _leiturasPendentes = [];
  bool _carregando = true;
  bool _processandoEtiqueta = false;
  bool _salvando = false;
  String? _erroCarregamento;

  double get _quantidadeSolicitada => _item.quantidadeSolicitada;

  double get _quantidadeSeparada => _item.quantidadeSeparada;

  double get _quantidadeRestante {
    final restante = _quantidadeSolicitada - _quantidadeSeparada;
    return restante > 0 ? restante : 0;
  }

  double get _quantidadePendente => _leiturasPendentes.fold(
    0,
    (total, leitura) => total + _quantidadeDaLeitura(leitura),
  );

  double get _saldoParaNovaLeitura {
    final saldo = _quantidadeRestante - _quantidadePendente;
    return saldo > 0 ? saldo : 0;
  }

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _carregar();
  }

  Future<void> _carregar() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erroCarregamento = null;
      });
    }

    try {
      final resultado = await widget.service.consultarItemSeparacao(
        requisicao: widget.requisicao.id,
        item: widget.item.sequencia,
      );

      if (!mounted) return;
      setState(() {
        _item = resultado.item;
        _leiturasPersistidas = resultado.leituras;
        _carregando = false;
        _erroCarregamento = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erroCarregamento = _mensagemErro(e);
      });
    }
  }

  Future<void> _lerEtiqueta() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );

    if (!mounted || codigo == null || codigo.trim().isEmpty) return;

    setState(() => _processandoEtiqueta = true);

    try {
      final leitura = LeituraEtiquetaSeparacao.identificar(codigo);

      if (leitura == null) {
        _mostrarMensagem('Formato de etiqueta não reconhecido.', erro: true);
        return;
      }

      if (!leitura.ehRolo && !RegExp(r'^C\d{20}$').hasMatch(leitura.codigo)) {
        _mostrarMensagem(
          'A etiqueta C da requisição deve possuir exatamente 21 caracteres.',
          erro: true,
        );
        return;
      }

      if (leitura.ehRolo && !RegExp(r'^R\d{17}$').hasMatch(leitura.codigo)) {
        _mostrarMensagem(
          'A etiqueta R deve possuir exatamente 18 caracteres.',
          erro: true,
        );
        return;
      }

      if (leitura.produto != _item.produto) {
        _mostrarMensagem(
          'A ${leitura.descricaoTipo} pertence ao produto '
          '${leitura.produto}, mas o produto aberto é ${_item.produto}.',
          erro: true,
        );
        return;
      }

      if (!leitura.ehRolo && leitura.referencia != widget.requisicao.id) {
        _mostrarMensagem(
          'A etiqueta C pertence à requisição '
          '${leitura.referencia.toString().padLeft(6, '0')}.',
          erro: true,
        );
        return;
      }

      final quantidade = _quantidadeDaLeitura(leitura);
      if (quantidade <= 0) {
        _mostrarMensagem('A quantidade da etiqueta é inválida.', erro: true);
        return;
      }

      if (quantidade > _saldoParaNovaLeitura + 0.0001) {
        _mostrarMensagem(
          'A leitura ultrapassa o saldo restante do item.',
          erro: true,
        );
        return;
      }

      if (leitura.ehRolo && _roloJaLido(leitura)) {
        _mostrarMensagem('Esta etiqueta R já foi lida.', erro: true);
        return;
      }

      setState(() => _leiturasPendentes.add(leitura));
      _mostrarMensagem('${leitura.descricaoTipo} adicionada como pendente.');
    } finally {
      if (mounted) {
        setState(() => _processandoEtiqueta = false);
      }
    }
  }

  bool _roloJaLido(LeituraEtiquetaSeparacao leitura) {
    return _leiturasPendentes.any((item) => item.codigo == leitura.codigo) ||
        _leiturasPersistidas.any(
          (item) =>
              item.ehRolo &&
              (item.codigoLido == leitura.codigo ||
                  item.roloId == leitura.referencia),
        );
  }

  double _quantidadeDaLeitura(LeituraEtiquetaSeparacao leitura) {
    if (leitura.quantidade != null) return leitura.quantidade!;

    if (leitura.ehRolo && leitura.codigo.length == 18) {
      final quantidadeInteira = int.tryParse(leitura.codigo.substring(14));
      return (quantidadeInteira ?? 0) / 10;
    }

    return 0;
  }

  Future<void> _salvarProduto() async {
    if (_leiturasPendentes.isEmpty) {
      _mostrarMensagem('Não há leituras pendentes para salvar.', erro: true);
      return;
    }

    setState(() => _salvando = true);

    try {
      final resultado = await widget.service.salvarLeituras(
        requisicao: widget.requisicao.id,
        item: _item.sequencia,
        codigosLidos: _leiturasPendentes
            .map((leitura) => leitura.codigo)
            .toList(growable: false),
      );

      if (!mounted) return;
      setState(() {
        _item = resultado.item;
        _leiturasPersistidas = resultado.leituras;
        _leiturasPendentes.clear();
      });
      _mostrarMensagem(
        resultado.mensagem.isEmpty
            ? 'Produto salvo com sucesso.'
            : resultado.mensagem,
      );
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem(_mensagemErro(e), erro: true);
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8D48A),
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Separação do Produto',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _erroCarregamento != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 52, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_erroCarregamento!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _carregar,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  _produto(),
                  _resumo(),
                  SeparacaoBotaoLerEtiqueta(
                    processando: _processandoEtiqueta,
                    habilitado: !_salvando,
                    onPressed: _lerEtiqueta,
                  ),
                  Expanded(child: _areaLeituras()),
                  _rodape(),
                ],
              ),
      ),
    );
  }

  Widget _produto() {
    final item = _item;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: separacaoBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.produto} - ${item.descricao}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3B0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.unidade,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Requisição ${widget.requisicao.numeroFormatado}  •  '
            'Item ${item.sequencia}',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _resumo() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: separacaoBoxDecoration(),
      child: Row(
        children: [
          Expanded(
            child: SeparacaoCardResumo(
              titulo: 'Pedido',
              valor: _formatarQuantidade(_quantidadeSolicitada),
              cor: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SeparacaoCardResumo(
              titulo: 'Coleta',
              valor: _formatarQuantidade(_quantidadeSeparada),
              cor: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SeparacaoCardResumo(
              titulo: 'Falta',
              valor: _formatarQuantidade(_quantidadeRestante),
              cor: _quantidadeRestante > 0
                  ? Colors.red.shade700
                  : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _areaLeituras() {
    if (_leiturasPersistidas.isEmpty && _leiturasPendentes.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        decoration: separacaoBoxDecoration(),
        child: const Center(
          child: Text(
            'Nenhuma leitura gravada ou pendente para o produto atual.',
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
      decoration: separacaoBoxDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFFF0F1F3),
            child: Text(
              'Gravadas: ${_leiturasPersistidas.length}  •  '
              'Pendentes: ${_leiturasPendentes.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (_leiturasPersistidas.isNotEmpty) ...[
                  _tituloGrupo('Leituras gravadas', Colors.green.shade700),
                  ..._leiturasPersistidas.map(_leituraPersistida),
                ],
                if (_leiturasPendentes.isNotEmpty) ...[
                  _tituloGrupo('Leituras pendentes', Colors.orange.shade800),
                  ..._leiturasPendentes.map(_leituraPendente),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloGrupo(String texto, Color cor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: cor.withValues(alpha: 0.10),
      child: Text(
        texto,
        style: TextStyle(color: cor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _leituraPersistida(RequisicaoTransferenciaLeitura leitura) {
    final detalheRolo = leitura.roloId == null
        ? ''
        : '  •  Rolo ${leitura.roloId.toString().padLeft(6, '0')}';
    final data = leitura.dataLeitura.isEmpty
        ? ''
        : '  •  ${leitura.dataLeitura}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _linhaCodigo(
            rotulo: 'Gravada ${leitura.tipoEtiqueta}',
            codigo: leitura.codigoLido,
            cor: Colors.green.shade700,
          ),
          const SizedBox(height: 6),
          Text(
            'Qtde. ${_formatarQuantidade(leitura.quantidade)}'
            '$detalheRolo$data',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _leituraPendente(LeituraEtiquetaSeparacao leitura) {
    final detalhe = leitura.ehRolo
        ? 'Rolo ${leitura.referencia.toString().padLeft(6, '0')}'
        : 'Requisição ${leitura.referencia.toString().padLeft(6, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF9E6),
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _linhaCodigo(
            rotulo: 'Pendente ${leitura.ehRolo ? 'R' : 'C'}',
            codigo: leitura.codigo,
            cor: Colors.orange.shade800,
          ),
          const SizedBox(height: 6),
          Text(
            '$detalhe  •  Qtde. '
            '${_formatarQuantidade(_quantidadeDaLeitura(leitura))}',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _linhaCodigo({
    required String rotulo,
    required String codigo,
    required Color cor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            rotulo,
            style: TextStyle(color: cor, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            codigo,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _rodape() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(10),
      decoration: separacaoBoxDecoration(),
      child: Row(
        children: [
          Expanded(
            child: SeparacaoBotaoRodape(
              icone: Icons.arrow_back,
              texto: 'Voltar',
              onTap: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SeparacaoBotaoRodape(
              icone: Icons.save_outlined,
              texto: _salvando ? 'Salvando...' : 'Salvar Produto',
              onTap: _salvando ? () {} : _salvarProduto,
              destaque: true,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatarQuantidade(double valor) {
  final arredondado4 = double.parse(valor.toStringAsFixed(4));

  if ((arredondado4 * 100) % 1 == 0) {
    return arredondado4.toStringAsFixed(2).replaceAll('.', ',');
  }

  return arredondado4.toStringAsFixed(4).replaceAll('.', ',');
}

String _mensagemErro(Object erro) {
  return erro.toString().replaceFirst('Exception: ', '');
}
