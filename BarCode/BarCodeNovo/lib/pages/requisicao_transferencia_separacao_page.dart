import 'package:flutter/material.dart';

import '../models/leitura_etiqueta_separacao.dart';
import '../models/requisicao_transferencia.dart';
import '../models/requisicao_transferencia_item.dart';
import '../models/requisicao_transferencia_leitura.dart';
import '../services/requisicao_transferencia_service.dart';
import '../utils/requisicao_transferencia_separacao_ordenacao.dart';
import '../widgets/separacao_produto_widgets.dart';
import 'scanner_page.dart';

class RequisicaoTransferenciaSeparacaoPage extends StatefulWidget {
  final RequisicaoTransferencia requisicaoInicial;
  final RequisicaoTransferenciaService service;

  const RequisicaoTransferenciaSeparacaoPage({
    super.key,
    required this.requisicaoInicial,
    required this.service,
  });

  @override
  State<RequisicaoTransferenciaSeparacaoPage> createState() =>
      _RequisicaoTransferenciaSeparacaoPageState();
}

class _RequisicaoTransferenciaSeparacaoPageState
    extends State<RequisicaoTransferenciaSeparacaoPage> {
  RequisicaoTransferencia? _requisicao;
  List<RequisicaoTransferenciaItem> _itens = const [];
  final Map<int, List<RequisicaoTransferenciaLeitura>> _leiturasPorItem = {};
  final List<LeituraEtiquetaSeparacao> _leiturasPendentes = [];

  RequisicaoTransferenciaItem? _itemAtual;
  bool _carregando = true;
  bool _processando = false;
  bool _salvandoProduto = false;
  bool _finalizando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  double get _totalSolicitado =>
      _itens.fold(0, (total, item) => total + item.quantidadeSolicitada);

  double get _totalColetado =>
      _itens.fold(0, (total, item) => total + item.quantidadeSeparada);

  double get _totalFalta {
    return _itens.fold(0, (total, item) => total + item.quantidadeFaltante);
  }

  double get _totalExcedente =>
      _itens.fold(0, (total, item) => total + item.quantidadeExcedente);

  bool get _todosItensConcluidos =>
      _itens.isNotEmpty && _itens.every(_itemConcluido);

  int get _qtdeAtendidosTotal =>
      _itens.where((item) => item.atendimentoTotal).length;

  int get _qtdeParciais =>
      _itens.where((item) => item.atendimentoParcial).length;

  int get _qtdeNaoAtendidos => _itens.where((item) => item.naoAtendido).length;

  int get _qtdeExcedentes =>
      _itens.where((item) => item.atendimentoExcedente).length;

  bool get _possuiDiferencaAtendimento =>
      _qtdeParciais > 0 || _qtdeNaoAtendidos > 0 || _qtdeExcedentes > 0;

  double get _totalPendenteAtual => _leiturasPendentes.fold(
    0,
    (total, leitura) => total + _quantidadeDaLeitura(leitura),
  );

  Future<void> _carregar() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      final detalhe = await widget.service.consultarDetalhe(
        widget.requisicaoInicial.id,
      );

      final leituras = <int, List<RequisicaoTransferenciaLeitura>>{};
      var itens = detalhe.itens;

      if (detalhe.requisicao.status == 'S') {
        final itensAtualizados = <RequisicaoTransferenciaItem>[];

        for (final item in detalhe.itens) {
          final resultado = await widget.service.consultarItemSeparacao(
            requisicao: detalhe.requisicao.id,
            item: item.sequencia,
          );

          itensAtualizados.add(resultado.item);
          leituras[item.sequencia] = resultado.leituras;
        }

        itens = itensAtualizados;
      }

      if (!mounted) return;
      setState(() {
        _requisicao = detalhe.requisicao;
        _itens = ordenarItensSeparacaoTransferencia(itens);
        _leiturasPorItem
          ..clear()
          ..addAll(leituras);
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

  Future<bool> _assumirSeNecessario() async {
    final requisicao = _requisicao ?? widget.requisicaoInicial;

    if (requisicao.status == 'S') {
      return true;
    }

    if (requisicao.status != 'L') {
      _mostrarMensagem(
        'A requisição não está disponível para separação.',
        erro: true,
      );
      return false;
    }

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

    if (confirmar != true || !mounted) return false;

    setState(() => _processando = true);
    try {
      final inicio = await widget.service.assumir(requisicao.id);
      await _carregar();

      if (!mounted) return false;
      _mostrarMensagem(
        inicio.mensagem.isEmpty
            ? 'Separação iniciada com sucesso.'
            : inicio.mensagem,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      _mostrarMensagem(_mensagemErro(e), erro: true);
      return false;
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  Future<void> _abrirItem(RequisicaoTransferenciaItem item) async {
    if (!await _assumirSeNecessario()) return;

    final itemAtualizado = _itens.firstWhere(
      (atual) => atual.sequencia == item.sequencia,
      orElse: () => item,
    );

    setState(() {
      _itemAtual = itemAtualizado;
      _leiturasPendentes.clear();
    });
  }

  Future<void> _lerEtiqueta() async {
    final item = _itemAtual;
    if (item == null) return;

    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );

    if (!mounted || codigo == null || codigo.trim().isEmpty) return;

    setState(() => _processando = true);

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

      if (leitura.produto != item.produto) {
        _mostrarMensagem(
          'A ${leitura.descricaoTipo} pertence ao produto '
          '${leitura.produto}, mas o item aberto é ${item.produto}.',
          erro: true,
        );
        return;
      }

      final requisicao = _requisicao ?? widget.requisicaoInicial;
      if (!leitura.ehRolo &&
          !requisicao.ehPendenciaAt &&
          leitura.referencia != requisicao.id) {
        _mostrarMensagem(
          'A etiqueta C pertence à requisição '
          '${leitura.referencia.toString().padLeft(6, '0')}.',
          erro: true,
        );
        return;
      }

      if (leitura.ehRolo && _roloJaLido(leitura)) {
        _mostrarMensagem('Esta etiqueta R já foi lida.', erro: true);
        return;
      }

      final quantidade = _quantidadeDaLeitura(leitura);
      if (quantidade <= 0) {
        _mostrarMensagem('A quantidade da etiqueta é inválida.', erro: true);
        return;
      }

      setState(() => _leiturasPendentes.add(leitura));
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  bool _roloJaLido(LeituraEtiquetaSeparacao leitura) {
    if (_leiturasPendentes.any((item) => item.codigo == leitura.codigo)) {
      return true;
    }

    for (final leituras in _leiturasPorItem.values) {
      if (leituras.any(
        (item) =>
            item.ehRolo &&
            (item.codigoLido == leitura.codigo ||
                item.roloId == leitura.referencia),
      )) {
        return true;
      }
    }

    return false;
  }

  Future<void> _salvarProduto() async {
    final item = _itemAtual;
    final requisicao = _requisicao ?? widget.requisicaoInicial;

    if (item == null) return;

    if (_leiturasPendentes.isEmpty) {
      _mostrarMensagem('Não há leituras pendentes para salvar.', erro: true);
      return;
    }

    setState(() => _salvandoProduto = true);

    try {
      final resultado = await widget.service.salvarLeituras(
        requisicao: requisicao.id,
        item: item.sequencia,
        codigosLidos: _leiturasPendentes
            .map((leitura) => leitura.codigo)
            .toList(growable: false),
      );

      if (!mounted) return;
      setState(() {
        _itens = ordenarItensSeparacaoTransferencia(
          _itens.map(
            (atual) => atual.sequencia == resultado.item.sequencia
                ? resultado.item
                : atual,
          ),
        );
        _leiturasPorItem[resultado.item.sequencia] = resultado.leituras;
        _leiturasPendentes.clear();
        _itemAtual = null;
      });

      _mostrarAvisoCentro('Produto salvo com sucesso');
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem(_mensagemErro(e), erro: true);
    } finally {
      if (mounted) {
        setState(() => _salvandoProduto = false);
      }
    }
  }

  Future<void> _finalizarSeparacao() async {
    if (_possuiDiferencaAtendimento) {
      final confirmar = await _confirmarFinalizacaoComDiferenca();
      if (confirmar != true) return;
    }

    setState(() => _finalizando = true);

    try {
      final requisicao = _requisicao ?? widget.requisicaoInicial;
      final retorno = await widget.service.finalizarSeparacao(
        requisicao: requisicao.id,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ATENÇÃO !!!'),
          content: Text(
            retorno.mensagem.isEmpty
                ? 'Separação salva com sucesso.'
                : retorno.mensagem,
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem(_mensagemErro(e), erro: true);
    } finally {
      if (mounted) {
        setState(() => _finalizando = false);
      }
    }
  }

  Future<bool?> _confirmarFinalizacaoComDiferenca() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar separação'),
        content: Text(
          'A separação possui itens com diferenças em relação ao solicitado:\n\n'
          'Não atendidos: $_qtdeNaoAtendidos\n'
          'Parciais: $_qtdeParciais\n'
          'Excedentes: $_qtdeExcedentes\n\n'
          'Deseja finalizar com essas quantidades?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarResumoFinal() async {
    if (_itemAtual != null && _leiturasPendentes.isNotEmpty) {
      _mostrarMensagem(
        'Existe um produto em separação. Salve ou volte antes de concluir.',
        erro: true,
      );
      return;
    }

    await _carregar();
    if (!mounted || _erro != null) return;

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
                        onPressed: _finalizando
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _painelIdentificacao(compacto: true),
                  const SizedBox(height: 10),
                  _painelTotais(),
                  const SizedBox(height: 10),
                  _painelResumoAtendimento(),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: separacaoBoxDecoration(),
                    child: Text(
                      _todosItensConcluidos
                          ? 'Todos os itens ativos foram atendidos conforme solicitado.'
                          : 'Existem diferencas em relacao ao solicitado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _todosItensConcluidos
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: _itens.map(_linhaResumoItem).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SeparacaoBotaoRodape(
                          icone: Icons.arrow_back,
                          texto: 'Voltar',
                          onTap: _finalizando
                              ? () {}
                              : () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SeparacaoBotaoRodape(
                          icone: Icons.save_outlined,
                          texto: _finalizando
                              ? 'Salvando...'
                              : 'Salvar Separação',
                          onTap: _finalizando ? () {} : _finalizarSeparacao,
                          destaque: true,
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

  void _voltarDoProduto() {
    if (_leiturasPendentes.isNotEmpty) {
      _mostrarMensagem('Salve o produto antes de voltar.', erro: true);
      return;
    }

    setState(() => _itemAtual = null);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_itemAtual != null && _leiturasPendentes.isNotEmpty) {
          _mostrarMensagem('Salve o produto antes de sair.', erro: true);
          return false;
        }

        if (_itemAtual != null) {
          setState(() => _itemAtual = null);
          return false;
        }

        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          backgroundColor: const Color(0xFFE8D48A),
          foregroundColor: Colors.black,
          elevation: 0,
          title: Text(
            _itemAtual == null
                ? 'Separação da Requisição'
                : 'Coleta do Produto',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            if (_itemAtual == null)
              IconButton(
                tooltip: 'Atualizar',
                onPressed: _carregando || _processando ? null : _carregar,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body: SafeArea(child: _conteudo()),
      ),
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
              const Icon(Icons.cloud_off, size: 52, color: Colors.red),
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

    if (_itemAtual != null) {
      return _conteudoProduto();
    }

    return _conteudoLista();
  }

  Widget _conteudoLista() {
    return Column(
      children: [
        _painelIdentificacao(),
        _painelTotais(),
        Expanded(child: _listaItens()),
        _rodapeResumo(),
      ],
    );
  }

  Widget _conteudoProduto() {
    return Column(
      children: [
        _painelProdutoAtual(),
        SeparacaoBotaoLerEtiqueta(
          processando: _processando,
          habilitado: !_salvandoProduto,
          onPressed: _lerEtiqueta,
          textoProcessando: 'Consultando etiqueta...',
        ),
        Expanded(child: _listaLeiturasProduto()),
        _rodapeProduto(),
      ],
    );
  }

  Widget _painelIdentificacao({bool compacto = false}) {
    final requisicao = _requisicao ?? widget.requisicaoInicial;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(12, compacto ? 0 : 10, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: separacaoBoxDecoration(),
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
                  requisicao.status,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            requisicao.nomeSolicitante.isEmpty
                ? 'Filial ${requisicao.empresaSolicitante}'
                : requisicao.nomeSolicitante,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (!compacto) ...[
            const SizedBox(height: 4),
            Text(
              '${_itens.length} item(ns)  •  Emissão: ${requisicao.emissao}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _painelTotais() {
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
              valor: _formatarQuantidade(_totalSolicitado),
              cor: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SeparacaoCardResumo(
              titulo: 'Coleta',
              valor: _formatarQuantidade(_totalColetado),
              cor: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SeparacaoCardResumo(
              titulo: 'Falta',
              valor: _formatarQuantidade(_totalFalta),
              cor: _quantidade4(_totalFalta) == 0
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SeparacaoCardResumo(
              titulo: 'Exced.',
              valor: _formatarQuantidade(_totalExcedente),
              cor: _quantidade4(_totalExcedente) == 0
                  ? Colors.green.shade700
                  : Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _painelResumoAtendimento() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: separacaoBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Atendimento dos itens',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _cardContadorAtendimento(
                  'Total',
                  _qtdeAtendidosTotal,
                  Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _cardContadorAtendimento(
                  'Parcial',
                  _qtdeParciais,
                  Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _cardContadorAtendimento(
                  'Não atend.',
                  _qtdeNaoAtendidos,
                  Colors.red.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _cardContadorAtendimento(
                  'Exced.',
                  _qtdeExcedentes,
                  Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardContadorAtendimento(String titulo, int valor, Color cor) {
    return SeparacaoCardResumo(
      titulo: titulo,
      valor: valor.toString(),
      cor: cor,
    );
  }

  Widget _listaItens() {
    if (_itens.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        decoration: separacaoBoxDecoration(),
        child: const Center(
          child: Text(
            'Nenhum item encontrado para esta requisição.',
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
      decoration: separacaoBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 2, 4, 8),
            child: Text(
              'Itens da requisição',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _itens.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _cardItem(_itens[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardItem(RequisicaoTransferenciaItem item) {
    final concluido = _itemConcluido(item);
    final corAtendimento = _corAtendimento(item);
    final diferenca = _diferencaItem(item);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _processando ? null : () => _abrirItem(item),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: concluido ? const Color(0xFFFFF8D6) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: concluido ? Colors.amber.shade300 : corAtendimento,
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
                _chipStatus(item.rotuloAtendimento, corAtendimento),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SeparacaoCardResumo(
                    titulo: 'Pedido',
                    valor: _formatarQuantidade(item.quantidadeSolicitada),
                    cor: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SeparacaoCardResumo(
                    titulo: 'Coleta',
                    valor: _formatarQuantidade(item.quantidadeSeparada),
                    cor: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SeparacaoCardResumo(
                    titulo: _tituloDiferencaItem(item),
                    valor: _formatarQuantidade(diferenca),
                    cor: corAtendimento,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Toque para consultar ou continuar as leituras.',
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
  }

  Widget _chipStatus(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cor),
      ),
      child: Text(
        texto,
        style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _rodapeResumo() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(10),
      decoration: separacaoBoxDecoration(),
      child: SizedBox(
        height: 58,
        child: SeparacaoBotaoRodape(
          icone: Icons.fact_check_outlined,
          texto: 'Resumo',
          onTap: _mostrarResumoFinal,
          destaque: true,
        ),
      ),
    );
  }

  Widget _painelProdutoAtual() {
    final item = _itemAtual!;
    final coleta = item.quantidadeSeparada + _totalPendenteAtual;
    final falta = item.quantidadeSolicitada - coleta;
    final faltaPositiva = falta > 0 ? falta : 0.0;
    final excedente = coleta - item.quantidadeSolicitada;
    final excedentePositivo = excedente > 0 ? excedente : 0.0;
    final possuiExcedente = _quantidade4(excedentePositivo) > 0;
    final zerou = _quantidade4(faltaPositiva) == 0 && !possuiExcedente;
    var tituloDiferenca = 'Falta';
    var valorDiferenca = faltaPositiva;
    var corDiferenca = Colors.red.shade700;

    if (zerou) {
      tituloDiferenca = 'Zerou';
      corDiferenca = Colors.green.shade700;
    }

    if (possuiExcedente) {
      tituloDiferenca = 'Exced.';
      valorDiferenca = excedentePositivo;
      corDiferenca = Colors.blue.shade700;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: separacaoBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.produto} - ${item.descricao}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SeparacaoCardResumo(
                  titulo: 'Pedido',
                  valor: _formatarQuantidade(item.quantidadeSolicitada),
                  cor: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SeparacaoCardResumo(
                  titulo: 'Coleta',
                  valor: _formatarQuantidade(coleta),
                  cor: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SeparacaoCardResumo(
                  titulo: tituloDiferenca,
                  valor: _formatarQuantidade(valorDiferenca),
                  cor: corDiferenca,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _listaLeiturasProduto() {
    final item = _itemAtual!;
    final gravadas = _leiturasPorItem[item.sequencia] ?? const [];

    if (gravadas.isEmpty && _leiturasPendentes.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        decoration: separacaoBoxDecoration(),
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
      decoration: separacaoBoxDecoration(),
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
            child: ListView(
              children: [
                ...gravadas.map(_linhaLeituraGravada),
                ..._leiturasPendentes.map(_linhaLeituraPendente),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaLeituraGravada(RequisicaoTransferenciaLeitura leitura) {
    final rolo = leitura.roloId == null
        ? '000000'
        : leitura.roloId.toString().padLeft(6, '0');

    return _linhaLeitura(
      rolo: rolo,
      codigo: leitura.codigoLido,
      quantidade: leitura.quantidade,
      unidade: _itemAtual?.unidade ?? '',
      pendente: false,
    );
  }

  Widget _linhaLeituraPendente(LeituraEtiquetaSeparacao leitura) {
    final rolo = leitura.ehRolo
        ? leitura.referencia.toString().padLeft(6, '0')
        : '000000';

    return _linhaLeitura(
      rolo: rolo,
      codigo: leitura.codigo,
      quantidade: _quantidadeDaLeitura(leitura),
      unidade: _itemAtual?.unidade ?? '',
      pendente: true,
    );
  }

  Widget _linhaLeitura({
    required String rolo,
    required String codigo,
    required double quantidade,
    required String unidade,
    required bool pendente,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      color: pendente ? const Color(0xFFFFF9E6) : Colors.white,
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              rolo,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(codigo, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 110,
            child: Text(
              '${_formatarQuantidade(quantidade)} $unidade',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rodapeProduto() {
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
              onTap: _voltarDoProduto,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SeparacaoBotaoRodape(
              icone: Icons.save_outlined,
              texto: _salvandoProduto ? 'Salvando...' : 'Salvar Produto',
              onTap: _salvandoProduto ? () {} : _salvarProduto,
              destaque: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaResumoItem(RequisicaoTransferenciaItem item) {
    final leituras = _leiturasPorItem[item.sequencia] ?? const [];
    final concluido = _itemConcluido(item);
    final corAtendimento = _corAtendimento(item);
    final diferenca = _diferencaItem(item);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: concluido ? const Color(0xFFFFF8D6) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: concluido ? Colors.amber.shade300 : corAtendimento,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.produto} - ${item.descricao}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _chipStatus(item.rotuloAtendimento, corAtendimento),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SeparacaoCardResumo(
                  titulo: 'Pedido',
                  valor: _formatarQuantidade(item.quantidadeSolicitada),
                  cor: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SeparacaoCardResumo(
                  titulo: 'Coleta',
                  valor: _formatarQuantidade(item.quantidadeSeparada),
                  cor: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SeparacaoCardResumo(
                  titulo: _tituloDiferencaItem(item),
                  valor: _formatarQuantidade(diferenca),
                  cor: corAtendimento,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Leituras: ${leituras.length}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          ...leituras.map(
            (leitura) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${leitura.ehRolo ? 'R' : 'C'}  '
                '${leitura.codigoLido}  '
                '${_formatarQuantidade(leitura.quantidade)} ${item.unidade}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _itemConcluido(RequisicaoTransferenciaItem item) =>
      itemSeparacaoTransferenciaConcluido(item);

  double _diferencaItem(RequisicaoTransferenciaItem item) {
    if (item.atendimentoExcedente) return item.quantidadeExcedente;
    return item.quantidadeFaltante;
  }

  String _tituloDiferencaItem(RequisicaoTransferenciaItem item) {
    if (item.atendimentoExcedente) return 'Exced.';
    if (item.atendimentoTotal) return 'Zerou';
    return 'Falta';
  }

  Color _corAtendimento(RequisicaoTransferenciaItem item) {
    if (item.atendimentoExcedente) return Colors.blue.shade700;
    if (item.atendimentoParcial) return Colors.orange.shade800;
    if (item.naoAtendido) return Colors.red.shade700;
    return Colors.green.shade700;
  }

  double _quantidadeDaLeitura(LeituraEtiquetaSeparacao leitura) {
    if (leitura.quantidade != null) return leitura.quantidade!;

    if (leitura.ehRolo && leitura.codigo.length == 18) {
      final quantidadeInteira = int.tryParse(leitura.codigo.substring(14));
      return (quantidadeInteira ?? 0) / 10;
    }

    return 0;
  }

  int _quantidade4(double valor) => (valor * 10000).round();

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

  void _mostrarAvisoCentro(String mensagem) {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(content: Text(mensagem, textAlign: TextAlign.center)),
    );

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
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
