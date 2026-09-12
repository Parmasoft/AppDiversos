import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/leitura_etiqueta_separacao.dart';
import '../widgets/separacao_produto_widgets.dart';
import 'scanner_page.dart';

class RegularizacaoRolosFilialPage extends StatefulWidget {
  final String baseUrl;
  final int empresaId;
  final String? empresaNome;

  const RegularizacaoRolosFilialPage({
    super.key,
    required this.baseUrl,
    required this.empresaId,
    this.empresaNome,
  });

  @override
  State<RegularizacaoRolosFilialPage> createState() =>
      _RegularizacaoRolosFilialPageState();
}

class _RegularizacaoRolosFilialPageState
    extends State<RegularizacaoRolosFilialPage> {
  final List<_RoloRegularizacao> _rolos = [];
  bool _processandoLeitura = false;
  bool _confirmandoRegularizacao = false;

  String get _nomeFilial {
    final nome = (widget.empresaNome ?? '').trim();
    return nome.isEmpty ? 'Filial ${widget.empresaId}' : nome;
  }

  String get _baseUrlNormalizada {
    final base = widget.baseUrl.trim();
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  Future<void> _lerEtiqueta() async {
    if (_confirmandoRegularizacao) return;

    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerPage(aceitarQualquerCodigo: true),
      ),
    );

    if (!mounted || codigo == null || codigo.trim().isEmpty) return;

    setState(() => _processandoLeitura = true);

    try {
      final leitura = LeituraEtiquetaSeparacao.identificar(codigo);

      if (leitura == null) {
        _mostrarMensagem('Etiqueta inválida.', erro: true);
        return;
      }

      if (!leitura.ehRolo) {
        _mostrarMensagem(
          'Nesta rotina são permitidas somente etiquetas de rolo.',
          erro: true,
        );
        return;
      }

      if (!RegExp(r'^R\d{17}$').hasMatch(leitura.codigo)) {
        _mostrarMensagem('Etiqueta inválida.', erro: true);
        return;
      }

      if (_rolos.any((rolo) => rolo.codigo == leitura.codigo)) {
        _mostrarMensagem('Esta etiqueta já foi lida nesta coleta.', erro: true);
        return;
      }

      setState(() => _rolos.add(_RoloRegularizacao.fromLeitura(leitura)));
      _mostrarMensagem('Etiqueta adicionada à coleta.');
    } finally {
      if (mounted) {
        setState(() => _processandoLeitura = false);
      }
    }
  }

  void _removerRolo(_RoloRegularizacao rolo) {
    if (_confirmandoRegularizacao) return;

    setState(() => _rolos.removeWhere((item) => item.codigo == rolo.codigo));
    _mostrarMensagem('Etiqueta removida da coleta.');
  }

  Future<void> _limparColeta() async {
    if (_confirmandoRegularizacao) return;

    if (_rolos.isEmpty) {
      _mostrarMensagem('Nenhuma etiqueta para limpar.', erro: true);
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar coleta'),
        content: Text(
          'Deseja remover as ${_rolos.length} etiqueta(s) lida(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _rolos.clear());
    _mostrarMensagem('Coleta limpa.');
  }

  Future<void> _confirmarRegularizacao() async {
    if (_confirmandoRegularizacao || _rolos.isEmpty) return;

    setState(() => _confirmandoRegularizacao = true);

    try {
      final url = Uri.parse(
        '$_baseUrlNormalizada/rolos/regularizacao/confirmar',
      );

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'empresa': widget.empresaId,
              'usuario': 1,
              'rolos': _rolos.map((rolo) => rolo.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      final dados = jsonDecode(utf8.decode(response.bodyBytes));
      final mensagem = (dados['mensagem'] ?? '').toString().trim();
      final codigo = (dados['codigo'] ?? '').toString().trim();

      if (response.statusCode == 200 && dados['status'] == 'ok') {
        final total = int.tryParse(
          (dados['total'] ?? _rolos.length).toString(),
        );
        final texto = mensagem.isNotEmpty
            ? mensagem
            : total == 1
            ? 'Rolo regularizado com sucesso.'
            : '${total ?? _rolos.length} rolos regularizados com sucesso.';

        await _mostrarDialogoCentralizado(
          titulo: 'Regularização confirmada',
          mensagem: texto,
        );

        if (!mounted) return;
        setState(() => _rolos.clear());
        return;
      }

      final textoErro = [
        if (codigo.isNotEmpty) codigo,
        if (mensagem.isNotEmpty) mensagem else 'Falha ao regularizar rolo.',
      ].join('\n');

      await _mostrarDialogoCentralizado(
        titulo: 'Regularização não concluída',
        mensagem: textoErro,
        erro: true,
      );
    } catch (e) {
      await _mostrarDialogoCentralizado(
        titulo: 'Regularização não concluída',
        mensagem: 'Falha ao comunicar com a API.\n$e',
        erro: true,
      );
    } finally {
      if (mounted) {
        setState(() => _confirmandoRegularizacao = false);
      }
    }
  }

  Future<void> _mostrarDialogoCentralizado({
    required String titulo,
    required String mensagem,
    bool erro = false,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        icon: Icon(
          erro ? Icons.error_outline : Icons.check_circle_outline,
          color: erro ? Colors.red.shade700 : Colors.green.shade700,
          size: 34,
        ),
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
          'Regularização de rolos da filial',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _cabecalho(),
            SeparacaoBotaoLerEtiqueta(
              processando: _processandoLeitura || _confirmandoRegularizacao,
              habilitado: !_confirmandoRegularizacao,
              onPressed: _lerEtiqueta,
              textoProcessando: _confirmandoRegularizacao
                  ? 'Confirmando regularização...'
                  : 'Processando etiqueta...',
            ),
            Expanded(child: _listaColeta()),
            _rodape(),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: separacaoBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filial',
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.empresaId} - $_nomeFilial',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Leia as etiquetas dos rolos que já estão fisicamente nesta filial.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SeparacaoCardResumo(
                  titulo: 'Rolos lidos',
                  valor: _rolos.length.toString(),
                  cor: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SeparacaoCardResumo(
                  titulo: 'Confirmação',
                  valor: _confirmandoRegularizacao
                      ? 'Enviando'
                      : _rolos.isEmpty
                      ? 'Bloqueada'
                      : 'Liberada',
                  cor: _confirmandoRegularizacao
                      ? Colors.blue.shade800
                      : _rolos.isEmpty
                      ? Colors.orange.shade800
                      : Colors.green.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _listaColeta() {
    if (_rolos.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        decoration: separacaoBoxDecoration(),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'Nenhuma etiqueta lida nesta coleta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
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
              'Etiquetas coletadas: ${_rolos.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _rolos.length,
              itemBuilder: (context, index) => _linhaRolo(_rolos[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaRolo(_RoloRegularizacao rolo) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rolo.codigo,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chip('PROR ${rolo.prorId.toString().padLeft(6, '0')}'),
                    _chip('Produto ${rolo.produto}'),
                    _chip('Qtde ${_formatarQuantidade(rolo.quantidade)}'),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remover leitura',
            onPressed: () => _removerRolo(rolo),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _chip(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _rodape() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(10),
      decoration: separacaoBoxDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SeparacaoBotaoRodape(
                  icone: Icons.cleaning_services_outlined,
                  texto: 'Limpar coleta',
                  onTap: _limparColeta,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SeparacaoBotaoRodape(
                  icone: Icons.arrow_back,
                  texto: 'Voltar',
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _rolos.isNotEmpty && !_confirmandoRegularizacao
                  ? _confirmarRegularizacao
                  : null,
              icon: _confirmandoRegularizacao
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _confirmandoRegularizacao
                    ? 'Confirmando...'
                    : 'Confirmar regularização',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoloRegularizacao {
  final String codigo;
  final int prorId;
  final int produto;
  final double quantidade;

  const _RoloRegularizacao({
    required this.codigo,
    required this.prorId,
    required this.produto,
    required this.quantidade,
  });

  factory _RoloRegularizacao.fromLeitura(LeituraEtiquetaSeparacao leitura) {
    return _RoloRegularizacao(
      codigo: leitura.codigo,
      prorId: leitura.referencia,
      produto: leitura.produto,
      quantidade: _quantidadeRolo(leitura),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'pror_id': prorId,
      'produto': produto,
      'quantidade': quantidade,
    };
  }
}

double _quantidadeRolo(LeituraEtiquetaSeparacao leitura) {
  if (leitura.quantidade != null) return leitura.quantidade!;

  if (leitura.ehRolo && leitura.codigo.length == 18) {
    final quantidadeInteira = int.tryParse(leitura.codigo.substring(14));
    return (quantidadeInteira ?? 0) / 10;
  }

  return 0;
}

String _formatarQuantidade(double valor) {
  return valor.toStringAsFixed(1).replaceAll('.', ',');
}
