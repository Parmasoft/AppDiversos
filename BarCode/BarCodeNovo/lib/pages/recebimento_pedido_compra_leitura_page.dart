import 'package:flutter/material.dart';

import '../models/leitura_etiqueta_separacao.dart';
import '../models/pedido_compra_leitura_etiqueta.dart';
import '../models/pedido_compra_recebimento_detalhe.dart';
import '../services/pedido_compra_recebimento_service.dart';
import '../services/pedido_compra_recebimento_rascunho_store.dart';
import 'scanner_page.dart';

class RecebimentoPedidoCompraLeituraPage extends StatefulWidget {
  final int empresa;
  final int pedido;
  final PedidoCompraRecebimentoItem item;
  final PedidoCompraLeituraSessao? sessaoInicial;

  const RecebimentoPedidoCompraLeituraPage({
    super.key,
    required this.empresa,
    required this.pedido,
    required this.item,
    this.sessaoInicial,
  });

  @override
  State<RecebimentoPedidoCompraLeituraPage> createState() =>
      _RecebimentoPedidoCompraLeituraPageState();
}

class _RecebimentoPedidoCompraLeituraPageState
    extends State<RecebimentoPedidoCompraLeituraPage> {
  final List<PedidoCompraLeituraEtiqueta> _leituras = [];
  bool _lendo = false;
  bool _salvandoProduto = false;
  bool _concluidoLocalmente = false;
  final PedidoCompraRecebimentoRascunhoStore _rascunhos =
      PedidoCompraRecebimentoRascunhoStore();

  @override
  void initState() {
    super.initState();
    final sessao = widget.sessaoInicial;
    if (sessao != null) {
      _leituras.addAll(sessao.leituras);
      _concluidoLocalmente = sessao.concluidoLocalmente;
    }
  }

  double get _quantidadeLida =>
      _leituras.fold(0, (total, leitura) => total + leitura.quantidade);

  double get _saldoRestanteEstimado => (widget.item.saldo - _quantidadeLida)
      .clamp(0, double.infinity)
      .toDouble();

  bool get _itemCompleto =>
      _leituras.isNotEmpty && _saldoRestanteEstimado <= 0.0001;

  bool get _podeSalvarProduto => _leituras.isNotEmpty;

  PedidoCompraLeituraSessao get _sessaoAtual => PedidoCompraLeituraSessao(
    leituras: List<PedidoCompraLeituraEtiqueta>.from(_leituras),
    concluidoLocalmente: _concluidoLocalmente,
  );

  Future<void> _persistirSessao(PedidoCompraLeituraSessao sessao) {
    return _rascunhos.salvarSessao(
      empresa: widget.empresa,
      pedido: widget.pedido,
      item: widget.item.sequencia,
      produto: widget.item.produto,
      sessao: sessao,
    );
  }

  Future<void> _lerEtiqueta() async {
    if (_lendo || _salvandoProduto) return;

    setState(() => _lendo = true);
    String? codigo;
    try {
      codigo = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const ScannerPage()),
      );
    } finally {
      if (mounted) setState(() => _lendo = false);
    }

    if (!mounted || codigo == null || codigo.trim().isEmpty) return;

    final leitura = LeituraEtiquetaSeparacao.identificar(codigo);
    if (leitura == null) {
      _mostrarMensagem('Formato de etiqueta não reconhecido.', erro: true);
      return;
    }

    if (!leitura.ehRolo && leitura.produto != widget.item.produto) {
      _mostrarMensagem(
        'A etiqueta pertence ao produto ${leitura.produto}, mas o item aberto é ${widget.item.produto}.',
        erro: true,
      );
      return;
    }

    if (leitura.ehRolo &&
        _leituras.any((item) => item.codigo == leitura.codigo)) {
      _mostrarAvisoCentro(
        'ATENÇÃO !!!',
        'Esta etiqueta R já foi lida nesta sessão.',
      );
      return;
    }

    PedidoCompraLeituraEtiqueta leituraLocal;
    if (leitura.ehRolo) {
      setState(() => _lendo = true);
      try {
        final service = await PedidoCompraRecebimentoService.daConfiguracao();
        final rolo = await service.consultarRolo(
          empresa: widget.empresa,
          codigo: leitura.codigo,
        );
        if (!mounted) return;
        if (rolo.produto != widget.item.produto) {
          _mostrarMensagem(
            'A etiqueta R pertence ao produto ${rolo.produto}, mas o item aberto é ${widget.item.produto}.',
            erro: true,
          );
          return;
        }
        leituraLocal = PedidoCompraLeituraEtiqueta(
          codigo: rolo.codigoLido,
          tipo: 'R',
          produto: rolo.produto,
          quantidade: rolo.quantidade,
          horario: DateTime.now(),
        );
      } catch (erro) {
        _mostrarMensagem(
          erro.toString().replaceFirst('Exception: ', ''),
          erro: true,
        );
        return;
      } finally {
        if (mounted) setState(() => _lendo = false);
      }
    } else {
      leituraLocal = PedidoCompraLeituraEtiqueta.daLeitura(leitura);
    }

    if (leituraLocal.quantidade <= 0) {
      _mostrarMensagem('A quantidade da etiqueta é inválida.', erro: true);
      return;
    }

    final novaSessao = PedidoCompraLeituraSessao(
      leituras: [..._leituras, leituraLocal],
    );
    try {
      await _persistirSessao(novaSessao);
      if (!mounted) return;
      setState(() {
        _leituras.add(leituraLocal);
        _concluidoLocalmente = false;
      });
    } catch (erro) {
      if (!mounted) return;
      _mostrarMensagem(
        'Nao foi possivel salvar a leitura localmente: ${erro.toString().replaceFirst('Exception: ', '')}',
        erro: true,
      );
    }
  }

  void _mostrarMensagem(String mensagem, {bool erro = false}) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leitura recusada'),
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

  Future<void> _salvarProduto() async {
    if (!_podeSalvarProduto || _salvandoProduto) return;

    setState(() => _salvandoProduto = true);
    try {
      await _persistirSessao(
        PedidoCompraLeituraSessao(
          leituras: List<PedidoCompraLeituraEtiqueta>.from(_leituras),
          concluidoLocalmente: true,
        ),
      );
      if (!mounted) return;
      setState(() => _concluidoLocalmente = true);
    } catch (erro) {
      if (mounted) {
        setState(() => _salvandoProduto = false);
        _mostrarMensagem(
          'Nao foi possivel concluir o produto localmente: ${erro.toString().replaceFirst('Exception: ', '')}',
          erro: true,
        );
      }
      return;
    }
    _mostrarAvisoCentro(
      'PRODUTO SALVO',
      'Conclusão local registrada. Nenhum dado foi enviado ao ERP.',
      sucesso: true,
      tempoMs: 1500,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) Navigator.of(context).pop(_sessaoAtual);
  }

  void _mostrarAvisoCentro(
    String titulo,
    String mensagem, {
    bool sucesso = false,
    int tempoMs = 4200,
  }) {
    if (!mounted) return;

    if (!sucesso) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leitura recusada'),
          content: Text(mensagem),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final entry = OverlayEntry(
      builder: (context) => IgnorePointer(
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
                      Icon(
                        sucesso
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: sucesso
                            ? Colors.green.shade700
                            : Colors.amber.shade800,
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        titulo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        mensagem,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);
    Future.delayed(Duration(milliseconds: tempoMs), () {
      try {
        entry.remove();
      } catch (_) {}
    });
  }

  Future<bool> _aoVoltar() async {
    Navigator.of(context).pop(_sessaoAtual);
    return false;
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
          'Leitura de Etiquetas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: WillPopScope(
        onWillPop: _aoVoltar,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              _capaItem(),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _lendo || _salvandoProduto ? null : _lerEtiqueta,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(_lendo ? 'Lendo...' : 'Ler Etiqueta'),
                ),
              ),
              if (_leituras.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _podeSalvarProduto && !_salvandoProduto
                        ? _salvarProduto
                        : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      _salvandoProduto ? 'Salvando...' : 'Salvar Produto',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'Etiquetas lidas (${_leituras.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_leituras.isEmpty)
                const Card(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Nenhuma etiqueta lida nesta sessão.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              else
                ..._leituras.map(_cardLeitura),
            ],
          ),
        ),
      ),
    );
  }

  Widget _capaItem() {
    final item = widget.item;

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
                    'Produto ${item.produto}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_itemCompleto)
                  const Chip(
                    backgroundColor: Color(0xFFE1F3DE),
                    label: Text('ITEM COMPLETO'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(item.descricao.isEmpty ? '-' : item.descricao),
            const Divider(height: 22),
            _linha('Pedido', _formatarQuantidade(item.quantidade)),
            _linha('Recebido', _formatarQuantidade(item.quantidadeRecebida)),
            _linha('Saldo atual', _formatarQuantidade(item.saldo)),
            _linha('Lido nesta sessão', _formatarQuantidade(_quantidadeLida)),
            _linha(
              'Saldo restante estimado',
              _formatarQuantidade(_saldoRestanteEstimado),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardLeitura(PedidoCompraLeituraEtiqueta leitura) {
    return Card(
      color: const Color(0xFFFFF8D6),
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE8D48A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8D48A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                leitura.tipo,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leitura.codigo,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(_formatarHorario(leitura.horario)),
                ],
              ),
            ),
            Text(
              _formatarQuantidade(leitura.quantidade),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linha(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(child: Text('$rotulo:')),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

String _formatarQuantidade(double valor) {
  var texto = valor.toStringAsFixed(4);
  texto = texto.replaceFirst(RegExp(r'\.?0+$'), '');
  return texto.replaceAll('.', ',');
}

String _formatarHorario(DateTime horario) {
  return '${horario.hour.toString().padLeft(2, '0')}:${horario.minute.toString().padLeft(2, '0')}';
}
