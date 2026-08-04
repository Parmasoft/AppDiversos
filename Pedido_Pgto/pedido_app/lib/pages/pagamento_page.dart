import 'dart:convert';
import 'dart:math' as math;
import 'package:pedido/pages/cliente_busca_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
//import 'package:pedido/pages/pagamento_prazo_page.dart';
import 'package:pedido/services/server_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PagamentoPage extends StatefulWidget {
  final int orcId;
  final int totalItensInicial;
  final double valorTotalInicial;
  final int vendedorId;
  final String vendedorDescricao;

  const PagamentoPage({
    super.key,
    required this.orcId,
    required this.totalItensInicial,
    required this.valorTotalInicial,
    required this.vendedorId,
    required this.vendedorDescricao,
  });

  @override
  State<PagamentoPage> createState() => _PagamentoPageState();
}

class _PagamentoPageState extends State<PagamentoPage> {
  final TextEditingController _valorPagoController = TextEditingController();
  final FocusNode _valorPagoFocusNode = FocusNode();
  final TextEditingController _clientePrazoController = TextEditingController();
  final TextEditingController _parcelasController = TextEditingController(
    text: "1",
  );
  final TextEditingController _intervaloController = TextEditingController(
    text: "30",
  );

  int? _clientePrazoId;
  bool _carregandoPrazo = false;
  final List<Map<String, dynamic>> _parcelasPrazo = [];

  final TextEditingController _vencimentoController = TextEditingController();
  DateTime? _dataVencimentoSelecionada;

  final List<Map<String, dynamic>> _formasPagamento = [
    {
      "id": 1,
      "descricao": "DINHEIRO",
      "especie_moeda": "DN",
      "forma_pagto_nfe": "01",
      "pix": "N",
    },
    {
      "id": 2,
      "descricao": "CARTÃO DE CRÉDITO",
      "especie_moeda": "CC",
      "forma_pagto_nfe": "03",
      "pix": "N",
    },
    {
      "id": 3,
      "descricao": "CARTÃO DE DÉBITO",
      "especie_moeda": "CD",
      "forma_pagto_nfe": "04",
      "pix": "N",
    },
    {
      "id": 4,
      "descricao": "PIX",
      "especie_moeda": "PX",
      "forma_pagto_nfe": "17",
      "pix": "S",
    },
    {
      "id": 5,
      "descricao": "PRAZO",
      "especie_moeda": "PZ",
      "forma_pagto_nfe": "05",
      "pix": "N",
    },
  ];

  int? _formaSelecionadaId;
  String _formaSelecionadaDescricao = "";
  bool _enviandoPagamento = false;

  final List<Map<String, dynamic>> _pagamentosLancados = [];

  String _tipoDesconto = "percentual";
  double _descontoPercentual = 0.0;
  double _descontoValor = 0.0;
  double _totalComDescontoManual = 0.0;

  @override
  void initState() {
    super.initState();
    _valorPagoController.text = _formatarValor(widget.valorTotalInicial);
    _valorPagoController.addListener(_onValorPagoAlterado);
  }

  void _onValorPagoAlterado() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _valorPagoController.removeListener(_onValorPagoAlterado);
    _valorPagoController.dispose();
    _valorPagoFocusNode.dispose();
    _clientePrazoController.dispose();
    _parcelasController.dispose();
    _intervaloController.dispose();
    _vencimentoController.dispose();
    super.dispose();
  }

  bool get _ehDinheiro => _formaSelecionadaId == 1;
  bool get _ehPix => _formaSelecionadaId == 4;
  bool get _ehPrazo => _formaSelecionadaId == 5;
  bool get _temPrazoGerado => _parcelasPrazo.isNotEmpty;

  //bool get _permiteDescontoNaForma => _ehDinheiro || _ehPix;
  bool get _permiteDescontoNaForma => _formaSelecionadaId != null;

  bool get _podeMexerDesconto {
    if (_enviandoPagamento || _carregandoPrazo) return false;
    if (_pagamentosLancados.isNotEmpty) return false;
    if (_temPrazoGerado || _temPrazoLancado) return false;
    return true;
  }

  Widget _buildBoxVendedor() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8DB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Vendedor",
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.vendedorDescricao,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  int get _quantidadeParcelasPrazo =>
      int.tryParse(_parcelasController.text.trim()) ?? 0;

  int get _intervaloPrazoDias =>
      int.tryParse(_intervaloController.text.trim()) ?? 0;

  bool get _temPrazoLancado =>
      _pagamentosLancados.any((pagamento) => pagamento["forma_pagto"] == 5);

  double get _totalOriginal => _arredondar2(widget.valorTotalInicial);

  bool get _temDesconto =>
      _descontoPercentual > 0 ||
      _descontoValor > 0 ||
      _totalComDescontoManual > 0;

  //bool get _descontoPermitido =>
  //_formaSelecionadaId == 1 || _formaSelecionadaId == 4;
  bool get _descontoPermitido => _formaSelecionadaId != null;

  double get _valorDescontoCalculado {
    if (!_temDesconto) return 0.0;

    if (_tipoDesconto == "percentual") {
      return _arredondar2((_totalOriginal * _descontoPercentual) / 100);
    }

    if (_tipoDesconto == "valor") {
      return _arredondar2(_descontoValor);
    }

    final desconto = _arredondar2(_totalOriginal - _totalComDescontoManual);
    return desconto > 0 ? desconto : 0.0;
  }

  double get _totalVenda {
    final total = _arredondar2(_totalOriginal - _valorDescontoCalculado);
    return total > 0 ? total : 0.0;
  }

  double get _percentualDescontoCalculado {
    if (_totalOriginal <= 0) return 0.0;
    return _arredondar2((_valorDescontoCalculado / _totalOriginal) * 100);
  }

  double get _totalFinalCalculado => _totalVenda;

  double _arredondar2(double valor) {
    return double.parse(valor.toStringAsFixed(2));
  }

  double _parseValor(String texto) {
    final valor = texto.trim();

    if (valor.isEmpty) return 0;

    if (valor.contains(',') && valor.contains('.')) {
      return double.tryParse(valor.replaceAll('.', '').replaceAll(',', '.')) ??
          0;
    }

    if (valor.contains(',')) {
      return double.tryParse(valor.replaceAll(',', '.')) ?? 0;
    }

    return double.tryParse(valor) ?? 0;
  }

  double get _valorDigitado =>
      _arredondar2(_parseValor(_valorPagoController.text));

  double get _totalLancado {
    final total = _pagamentosLancados.fold<double>(
      0,
      (soma, pagamento) =>
          soma + ((pagamento["valor_aplicado"] as num?)?.toDouble() ?? 0),
    );

    return _arredondar2(total);
  }

  double get _falta {
    final valor = _arredondar2(_totalVenda - _totalLancado);
    return valor > 0 ? valor : 0;
  }

  double get _trocoLancado {
    final total = _pagamentosLancados.fold<double>(
      0,
      (soma, pagamento) =>
          soma +
          math.max(
            0,
            ((pagamento["valor_recebido"] as num?)?.toDouble() ?? 0) -
                ((pagamento["valor_aplicado"] as num?)?.toDouble() ?? 0),
          ),
    );

    return _arredondar2(total);
  }

  double get _trocoPreview {
    if (!_ehDinheiro || _formaSelecionadaId == null) {
      return _trocoLancado;
    }

    final excedente = _arredondar2(_valorDigitado - _falta);

    if (excedente <= 0) {
      return _trocoLancado;
    }

    return _arredondar2(_trocoLancado + excedente);
  }

  bool get _podeAdicionarPagamento {
    if (_formaSelecionadaId == null) return false;
    if (_falta <= 0) return false;

    if (_ehPrazo) {
      if (_pagamentosLancados.isNotEmpty) return false;
      if (_dataVencimentoSelecionada == null) return false;
      return true;
    }

    if (_temPrazoLancado) return false;
    if (_valorDigitado <= 0) return false;

    if (!_ehDinheiro && _valorDigitado > _falta) {
      return false;
    }

    return true;
  }

  bool get _podeFinalizar {
    if (_temPrazoGerado) {
      return (_clientePrazoId ?? 0) > 0;
    }

    if (_pagamentosLancados.isEmpty) return false;
    return _falta <= 0;
  }

  String _formatarValor(double valor) {
    return _arredondar2(valor).toStringAsFixed(2).replaceAll('.', ',');
  }

  String _formatarValorApi(double valor) {
    return _arredondar2(valor).toStringAsFixed(2);
  }

  void _limparDesconto() {
    setState(() {
      _tipoDesconto = "percentual";
      _descontoPercentual = 0.0;
      _descontoValor = 0.0;
      _totalComDescontoManual = 0.0;
    });

    _atualizarCampoParaFalta();
  }

  void _aplicarDescontoPercentual(double percentual) {
    final percentualTratado = percentual < 0 ? 0.0 : percentual;

    setState(() {
      _tipoDesconto = "percentual";
      _descontoPercentual = percentualTratado;
      _descontoValor = 0.0;
      _totalComDescontoManual = 0.0;
    });

    _atualizarCampoParaFalta();
  }

  void _aplicarDescontoValor(double valor) {
    var valorTratado = valor < 0 ? 0.0 : valor;
    if (valorTratado > _totalOriginal) {
      valorTratado = _totalOriginal;
    }

    setState(() {
      _tipoDesconto = "valor";
      _descontoPercentual = 0.0;
      _descontoValor = _arredondar2(valorTratado);
      _totalComDescontoManual = 0.0;
    });

    _atualizarCampoParaFalta();
  }

  void _aplicarDescontoTotalFinal(double totalFinal) {
    var totalTratado = _arredondar2(totalFinal);

    if (totalTratado < 0) {
      totalTratado = 0.0;
    }

    if (totalTratado > _totalOriginal) {
      totalTratado = _totalOriginal;
    }

    setState(() {
      _tipoDesconto = "total_final";
      _descontoPercentual = 0.0;
      _descontoValor = 0.0;
      _totalComDescontoManual = totalTratado;
    });

    _atualizarCampoParaFalta();
  }

  String _formatarDataBr(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    return "$dia/$mes/$ano";
  }

  String _formatarDataApi(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    return "$ano-$mes-$dia";
  }

  double _normalizarDesconto(double valor) {
    if (valor.isNaN || valor.isInfinite) return 0.0;

    final ajustado = _arredondar2(valor);

    if (ajustado <= 0) return 0.0;
    if (ajustado >= _totalOriginal) return _totalOriginal;

    return ajustado;
  }

  double _calcularDescontoPorModo(int modo, String texto) {
    final valorInformado = _parseValor(texto);

    if (modo == 0) {
      return _totalOriginal * (valorInformado / 100.0);
    }

    if (modo == 1) {
      return valorInformado;
    }

    return _totalOriginal - valorInformado;
  }

  void _aplicarDescontoCalculado(
    double descontoCalculado, {
    required int modoSelecionado,
  }) {
    final descontoFinal = _normalizarDesconto(descontoCalculado);
    final percentualFinal = _totalOriginal <= 0
        ? 0.0
        : _arredondar2((descontoFinal / _totalOriginal) * 100.0);

    setState(() {
      _tipoDesconto = modoSelecionado == 0
          ? "percentual"
          : modoSelecionado == 1
          ? "valor"
          : "total_final";
      _descontoValor = descontoFinal;
      _descontoPercentual = percentualFinal;
      _totalComDescontoManual = modoSelecionado == 2
          ? _arredondar2(_totalOriginal - descontoFinal)
          : 0.0;
    });

    _atualizarCampoParaFalta();
    FocusScope.of(context).unfocus();
  }

  Future<void> _abrirDialogDesconto() async {
    if (!_podeMexerDesconto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "O desconto só pode ser alterado antes de lançar pagamentos.",
          ),
        ),
      );
      return;
    }

    //if (!_permiteDescontoNaForma) {
    //  ScaffoldMessenger.of(context).showSnackBar(
    //    const SnackBar(
    //      content: Text("Desconto permitido apenas em Dinheiro ou Pix."),
    //    ),
    //  );
    //  return;
    // }
    if (!_permiteDescontoNaForma) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Selecione uma forma de pagamento para aplicar desconto.",
          ),
        ),
      );
      return;
    }

    int modo = 0;
    if (_tipoDesconto == "valor") {
      modo = 1;
    } else if (_tipoDesconto == "total_final") {
      modo = 2;
    }

    final textoInicial = !_temDesconto
        ? ""
        : modo == 0
        ? _formatarValor(_percentualDescontoCalculado)
        : modo == 1
        ? _formatarValor(_valorDescontoCalculado)
        : _formatarValor(_totalVenda);

    final controller = TextEditingController(text: textoInicial);

    final descontoResultado = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            double descontoPreview = _calcularDescontoPorModo(
              modo,
              controller.text,
            );

            descontoPreview = _normalizarDesconto(descontoPreview);

            final totalFinalPreview = _arredondar2(
              _totalOriginal - descontoPreview,
            );

            final percentualPreview = _totalOriginal <= 0
                ? 0.0
                : _arredondar2((descontoPreview / _totalOriginal) * 100.0);

            String labelCampo;
            String hintCampo;

            if (modo == 0) {
              labelCampo = "Percentual";
              hintCampo = "Ex.: 5";
            } else if (modo == 1) {
              labelCampo = "Valor do desconto";
              hintCampo = "Ex.: 9,90";
            } else {
              labelCampo = "Total final desejado";
              hintCampo = "Ex.: 380,00";
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              contentPadding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              title: const Text("Desconto"),

              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 650,
                  maxHeight: 340,
                ),
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 86,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBotaoModoDesconto(
                              label: "%",
                              selecionado: modo == 0,
                              onTap: () {
                                setStateDialog(() {
                                  modo = 0;
                                  controller.text = percentualPreview > 0
                                      ? _formatarValor(percentualPreview)
                                      : "";
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildBotaoModoDesconto(
                              label: "R\$",
                              selecionado: modo == 1,
                              onTap: () {
                                setStateDialog(() {
                                  modo = 1;
                                  controller.text = descontoPreview > 0
                                      ? _formatarValor(descontoPreview)
                                      : "";
                                });
                              },
                            ),
                            const SizedBox(height: 10),

                            _buildBotaoModoDesconto(
                              label: "Final",
                              selecionado: modo == 2,
                              onTap: () {
                                setStateDialog(() {
                                  modo = 2;
                                  controller.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labelCampo,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6D5BAA),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: controller,
                              autofocus: true,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.done,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: hintCampo,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF7C66C3),
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF7C66C3),
                                    width: 2,
                                  ),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                              ),
                              onChanged: (_) => setStateDialog(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLinhaResumoDesconto(
                                "Total original",
                                _formatarValor(_totalOriginal),
                              ),
                              const SizedBox(height: 8),
                              _buildLinhaResumoDesconto(
                                "Desconto",
                                _formatarValor(descontoPreview),
                              ),
                              const SizedBox(height: 8),
                              _buildLinhaResumoDesconto(
                                "Percentual",
                                "${_formatarValor(percentualPreview)}%",
                              ),
                              const SizedBox(height: 8),
                              _buildLinhaResumoDesconto(
                                "Total final",
                                _formatarValor(totalFinalPreview),
                                destaque: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (_temDesconto)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, 0.0);
                    },
                    child: const Text("Limpar"),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, descontoPreview);
                  },
                  child: const Text("Aplicar"),
                ),
              ],
            );
          },
        );
      },
    );

    if (descontoResultado == null) return;

    if (descontoResultado <= 0) {
      _limparDesconto();
      return;
    }

    _aplicarDescontoCalculado(descontoResultado, modoSelecionado: modo);
  }

  Widget _buildBotaoModoDesconto({
    required String label,
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 42,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selecionado ? const Color(0xFFEDE7F6) : Colors.white,
          foregroundColor: Colors.black87,
          side: BorderSide(
            color: selecionado ? const Color(0xFF7C66C3) : Colors.black26,
            width: selecionado ? 1.6 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildLinhaResumoDesconto(
    String titulo,
    String valor, {
    bool destaque = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: destaque ? 16 : 15,
              fontWeight: destaque ? FontWeight.bold : FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          valor,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: destaque ? 18 : 15,
            fontWeight: destaque ? FontWeight.bold : FontWeight.w700,
            color: destaque ? Colors.green.shade800 : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildBlocoDesconto(bool tecladoAberto) {
    if (tecladoAberto || _temPrazoGerado) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildBoxInfo(
                titulo: "Total original",
                valor: _formatarValor(_totalOriginal),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBoxInfo(
                titulo: "Desconto",
                valor: _formatarValor(_valorDescontoCalculado),
                corValor: _temDesconto ? Colors.red : Colors.black54,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBoxInfo(
                titulo: "Total final",
                valor: _formatarValor(_totalVenda),
                corValor: Colors.green.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_podeMexerDesconto && _permiteDescontoNaForma)
                    ? _abrirDialogDesconto
                    : null,
                icon: const Icon(Icons.percent),
                label: Text(
                  _temDesconto ? "Editar desconto" : "Desconto",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_temDesconto) ...[
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _podeMexerDesconto ? () => _limparDesconto() : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                child: const Text("Limpar"),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            //_formaSelecionadaId == null
            //    ? "Escolha Dinheiro ou Pix para liberar desconto."
            //    : !_permiteDescontoNaForma
            //    ? "Desconto só é permitido em Dinheiro ou Pix."
            //    : _temDesconto
            //    ? "Desconto aplicado: ${_formatarValor(_valorDescontoCalculado)} (${_formatarValor(_percentualDescontoCalculado)}%)."
            //    : "Nenhum desconto aplicado.",
            _formaSelecionadaId == null
                ? "Escolha uma forma de pagamento para liberar desconto."
                : _temDesconto
                ? "Desconto aplicado: ${_formatarValor(_valorDescontoCalculado)} (${_formatarValor(_percentualDescontoCalculado)}%)."
                : "Nenhum desconto aplicado.",

            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selecionarVencimento() async {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dataInicial =
        _dataVencimentoSelecionada ?? hoje.add(const Duration(days: 30));

    final data = await showDatePicker(
      context: context,
      initialDate: dataInicial,
      firstDate: hoje,
      lastDate: DateTime(hoje.year + 5),
    );

    if (data == null) return;

    setState(() {
      _dataVencimentoSelecionada = data;
      _vencimentoController.text = _formatarDataBr(data);
    });
  }

  void _atualizarCampoParaFalta() {
    final valor = _falta > 0 ? _falta : 0.0;
    _valorPagoController.text = _formatarValor(valor);
    _valorPagoController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _valorPagoController.text.length,
    );
  }

  void _limparSelecaoForma() {
    _formaSelecionadaId = null;
    _formaSelecionadaDescricao = "";
    _dataVencimentoSelecionada = null;
    _vencimentoController.clear();
  }

  Future<void> _informarClientePrazo() async {
    if (_enviandoPagamento || _carregandoPrazo) return;

    FocusScope.of(context).unfocus();

    final cliente = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const ClienteBuscaPage(empresa: 1)),
    );

    if (cliente == null || !mounted) return;

    final clienteId =
        int.tryParse((cliente["id"] ?? cliente["codigo"] ?? "").toString()) ??
        0;

    if (clienteId <= 0) return;

    final descricao =
        (cliente["descricao"] ?? cliente["nome"] ?? cliente["fantasia"] ?? "")
            .toString()
            .trim();

    setState(() {
      _clientePrazoId = clienteId;
      _clientePrazoController.text = descricao.isNotEmpty
          ? "$clienteId - $descricao"
          : clienteId.toString();

      _parcelasPrazo.clear();
    });
  }

  Future<void> _gerarParcelasPrazo() async {
    if (_enviandoPagamento || _carregandoPrazo) return;

    if (_pagamentosLancados.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Remova os pagamentos simples antes de gerar o prazo."),
        ),
      );
      return;
    }

    if ((_clientePrazoId ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Informe o cliente do prazo.")),
      );
      return;
    }

    if (_quantidadeParcelasPrazo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Informe uma quantidade de parcelas válida."),
        ),
      );
      return;
    }

    if (_intervaloPrazoDias <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Informe um intervalo válido em dias.")),
      );
      return;
    }

    final ecfId = await _obterEcfId();

    if (ecfId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "ECF do tablet não configurado. Verifique a configuração do aparelho.",
          ),
        ),
      );
      return;
    }

    setState(() {
      _carregandoPrazo = true;
    });

    try {
      final url = Uri.parse(
        "${ServerConfig.baseUrl}/pdv/tablet/pagamento/prazo/simular",
      );

      final body = {
        "empresa": 1,
        "ecf_id": ecfId,
        "orc_id": widget.orcId,
        "cliente_id": _clientePrazoId,
        "quantidade_parcelas": _quantidadeParcelasPrazo,
        "intervalo_dias": _intervaloPrazoDias,
        "desconto": {
          "tipo": _tipoDesconto,
          "valor": _formatarValorApi(_valorDescontoCalculado),
          "percentual": _formatarValorApi(_percentualDescontoCalculado),
          "total_final": _formatarValorApi(_totalVenda),
          "subtotal": _formatarValorApi(_totalOriginal),
        },
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      dynamic jsonBody;
      if (response.body.isNotEmpty) {
        try {
          jsonBody = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          jsonBody = null;
        }
      }

      final sucesso =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          jsonBody is Map<String, dynamic> &&
          jsonBody["sucesso"] == true;

      if (!mounted) return;

      if (sucesso) {
        final parcelas = (jsonBody["parcelas"] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

        setState(() {
          _parcelasPrazo
            ..clear()
            ..addAll(parcelas);
        });

        return;
      }

      final mensagem = _extrairMensagemErro(jsonBody, response.statusCode);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao simular prazo: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _carregandoPrazo = false;
        });
      }
    }
  }

  Future<void> _finalizarVendaSimples(int ecfId) async {
    if (_pagamentosLancados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Adicione ao menos uma forma de pagamento."),
        ),
      );
      return;
    }

    if (_falta > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Ainda falta ${_formatarValor(_falta)} para completar a venda.",
          ),
        ),
      );
      return;
    }

    final url = Uri.parse(
      "${ServerConfig.baseUrl}/pdv/tablet/pagamento/finalizar",
    );

    final body = {
      "empresa": 1,
      "ecf_id": ecfId,
      "orc_id": widget.orcId,
      "usuario": 1,
      "vendedor_id": widget.vendedorId,
      "desconto": {
        "tipo": _tipoDesconto,
        "valor": _formatarValorApi(_valorDescontoCalculado),
        "percentual": _formatarValorApi(_percentualDescontoCalculado),
        "total_final": _formatarValorApi(_totalVenda),
        "subtotal": _formatarValorApi(_totalOriginal),
      },
      "pagamentos": _pagamentosLancados.map(_montarPagamentoApi).toList(),
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    dynamic jsonBody;
    if (response.body.isNotEmpty) {
      try {
        jsonBody = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        jsonBody = null;
      }
    }

    final sucesso =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        jsonBody is Map<String, dynamic> &&
        jsonBody["sucesso"] == true;

    if (sucesso) {
      if (!mounted) return;

      Navigator.pop(context, {
        "acao": "venda_finalizada",
        "orc_id": widget.orcId,
        "forma_pagamento_id": _pagamentosLancados.length == 1
            ? _pagamentosLancados.first["forma_pagto"]
            : null,
        "forma_pagamento_descricao": _descricaoFormasFinalizacao(),

        "valor_total": _totalVenda,
        "valor_pago": _totalLancado,
        "troco": _trocoPreview,

        "rec_id": jsonBody["rec_id"],
        "status": jsonBody["status"],
        "status_descricao": jsonBody["status_descricao"],
        "total_recebido": jsonBody["total_recebido"],
        "quantidade_pagamentos":
            jsonBody["quantidade_pagamentos"] ?? _pagamentosLancados.length,
      });
      return;
    }

    if (!mounted) return;

    final mensagem = _extrairMensagemErro(jsonBody, response.statusCode);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _finalizarVendaPrazo(int ecfId) async {
    if ((_clientePrazoId ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Informe o cliente do prazo.")),
      );
      return;
    }

    if (_parcelasPrazo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gere as parcelas antes de finalizar.")),
      );
      return;
    }

    final url = Uri.parse(
      "${ServerConfig.baseUrl}/pdv/tablet/pagamento/prazo/finalizar",
    );

    final body = {
      "empresa": 1,
      "ecf_id": ecfId,
      "orc_id": widget.orcId,
      "usuario": 1,
      "cliente_id": _clientePrazoId,
      "quantidade_parcelas": _quantidadeParcelasPrazo,
      "intervalo_dias": _intervaloPrazoDias,
      "desconto": {
        "tipo": _tipoDesconto,
        "valor": _formatarValorApi(_valorDescontoCalculado),
        "percentual": _formatarValorApi(_percentualDescontoCalculado),
        "total_final": _formatarValorApi(_totalVenda),
        "subtotal": _formatarValorApi(_totalOriginal),
      },
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    dynamic jsonBody;
    if (response.body.isNotEmpty) {
      try {
        jsonBody = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        jsonBody = null;
      }
    }

    final sucesso =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        jsonBody is Map<String, dynamic> &&
        jsonBody["sucesso"] == true;

    if (sucesso) {
      if (!mounted) return;

      Navigator.pop(context, {
        "acao": "venda_finalizada",
        "orc_id": widget.orcId,
        "forma_pagamento_id": 5,
        "forma_pagamento_descricao": "PRAZO",
        "valor_total": _totalVenda,
        "valor_pago": 0.0,
        "troco": 0.0,
        "status": jsonBody["status"],
        "status_descricao": jsonBody["status_descricao"],
        "cliente_id": _clientePrazoId,
        "a_prazo": true,
        "quantidade_pagamentos":
            jsonBody["quantidade_parcelas"] ?? _parcelasPrazo.length,
        "parcelas": jsonBody["parcelas"] ?? _parcelasPrazo,
      });
      return;
    }

    if (!mounted) return;

    final mensagem = _extrairMensagemErro(jsonBody, response.statusCode);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _selecionarForma(Map<String, dynamic> forma) async {
    final id = forma["id"] as int;
    final descricao = forma["descricao"] as String;

    //if (_temDesconto && id != 1 && id != 4) {
    //  ScaffoldMessenger.of(context).showSnackBar(
    //    const SnackBar(
    //      content: Text("Com desconto aplicado, use apenas Dinheiro ou Pix."),
    //    ),
    //  );
    //  return;
    // }

    if (_temDesconto &&
        _pagamentosLancados.isNotEmpty &&
        _pagamentosLancados.first["forma_pagto"] != id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Com desconto, mantenha a mesma forma até concluir a venda.",
          ),
        ),
      );
      return;
    }

    if (id == 5) {
      if (_pagamentosLancados.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Remova os pagamentos simples antes de usar o prazo.",
            ),
          ),
        );
        return;
      }

      if (_parcelasPrazo.isNotEmpty) {
        setState(() {
          _parcelasPrazo.clear();
        });
      }

      setState(() {
        _formaSelecionadaId = id;
        _formaSelecionadaDescricao = descricao;
      });

      _atualizarCampoParaFalta();
      FocusScope.of(context).unfocus();
      return;
    }

    if (_parcelasPrazo.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Existe um prazo gerado. Volte ao prazo ou limpe a simulação antes de usar outra forma.",
          ),
        ),
      );
      return;
    }

    setState(() {
      _formaSelecionadaId = id;
      _formaSelecionadaDescricao = descricao;
    });

    //if (!_descontoPermitido && _temDesconto) {
    //  _limparDesconto();
    //}

    _atualizarCampoParaFalta();

    if (id == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _valorPagoFocusNode.requestFocus();
        _valorPagoController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _valorPagoController.text.length,
        );
      });
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  Future<int?> _obterEcfId() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final valorInt = prefs.getInt('ecf_id');
      if (valorInt != null && valorInt > 0) {
        return valorInt;
      }
    } catch (_) {}

    try {
      final valorString = prefs.getString('ecf_id');
      if (valorString != null && valorString.trim().isNotEmpty) {
        final ecfConvertido = int.tryParse(valorString.trim());
        if (ecfConvertido != null && ecfConvertido > 0) {
          return ecfConvertido;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> _adicionarPagamento() async {
    if (_enviandoPagamento) return;

    if (_formaSelecionadaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione uma forma de pagamento.")),
      );
      return;
    }

    if (_falta <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("A venda já está totalmente lançada.")),
      );
      return;
    }

    //if (_temDesconto && !_descontoPermitido) {
    //  ScaffoldMessenger.of(context).showSnackBar(
    //    const SnackBar(
    //      content: Text("Desconto só pode ser usado em Dinheiro ou Pix."),
    //    ),
    //  );
    //  return;
    //}

    if (_ehPrazo) {
      if (_pagamentosLancados.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Nesta primeira fase, a venda a prazo não pode ser misturada com outras formas.",
            ),
          ),
        );
        return;
      }

      if (_dataVencimentoSelecionada == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Selecione a data de vencimento.")),
        );
        return;
      }

      final forma = _formasPagamento.firstWhere(
        (item) => item["id"] == _formaSelecionadaId,
      );

      final valorAplicado = _arredondar2(_falta);

      if (valorAplicado <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Não foi possível lançar este pagamento a prazo."),
          ),
        );
        return;
      }

      setState(() {
        _pagamentosLancados.add({
          "forma_pagto": forma["id"],
          "descricao": forma["descricao"],
          "especie_moeda": forma["especie_moeda"],
          "forma_pagto_nfe": forma["forma_pagto_nfe"],
          "pix": forma["pix"],
          "valor_recebido": 0.0,
          "valor_aplicado": valorAplicado,
          "vencimento": _formatarDataApi(_dataVencimentoSelecionada!),
          "vencimento_br": _formatarDataBr(_dataVencimentoSelecionada!),
          "a_prazo": true,
        });

        _limparSelecaoForma();
      });

      FocusScope.of(context).unfocus();
      return;
    }

    if (_temPrazoLancado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Já existe um lançamento a prazo. Remova-o antes de usar outra forma.",
          ),
        ),
      );
      return;
    }

    if (_valorDigitado <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Informe um valor válido.")));
      return;
    }

    if (!_ehDinheiro && _valorDigitado > _falta) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Para $_formaSelecionadaDescricao, informe no máximo ${_formatarValor(_falta)}.",
          ),
        ),
      );
      return;
    }

    final forma = _formasPagamento.firstWhere(
      (item) => item["id"] == _formaSelecionadaId,
    );

    final valorRecebido = _valorDigitado;
    final valorAplicado = _ehDinheiro
        ? _arredondar2(math.min(valorRecebido, _falta))
        : _arredondar2(valorRecebido);

    if (valorAplicado <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Não foi possível lançar este pagamento."),
        ),
      );
      return;
    }

    setState(() {
      _pagamentosLancados.add({
        "forma_pagto": forma["id"],
        "descricao": forma["descricao"],
        "especie_moeda": forma["especie_moeda"],
        "forma_pagto_nfe": forma["forma_pagto_nfe"],
        "pix": forma["pix"],
        "valor_recebido": valorRecebido,
        "valor_aplicado": valorAplicado,
      });

      _limparSelecaoForma();
    });

    _atualizarCampoParaFalta();
    FocusScope.of(context).unfocus();
  }

  void _removerPagamentoLancado(int index) {
    if (_enviandoPagamento) return;

    setState(() {
      _pagamentosLancados.removeAt(index);
      _limparSelecaoForma();
    });

    _atualizarCampoParaFalta();
  }

  Map<String, dynamic> _montarPagamentoApi(Map<String, dynamic> pagamento) {
    final valorAplicado =
        ((pagamento["valor_aplicado"] as num?)?.toDouble() ?? 0.0);

    final valorRecebido =
        ((pagamento["valor_recebido"] as num?)?.toDouble() ?? valorAplicado);

    final body = <String, dynamic>{
      "forma_pagto": pagamento["forma_pagto"],
      "descricao": pagamento["descricao"],
      "especie_moeda": pagamento["especie_moeda"],
      "forma_pagto_nfe": pagamento["forma_pagto_nfe"],
      "valor": _formatarValorApi(valorAplicado),
      "valor_recebido": _formatarValorApi(valorRecebido),
      "pix": pagamento["pix"],
    };

    if (pagamento["forma_pagto"] == 5) {
      body["vencimento"] = pagamento["vencimento"];
      body["a_prazo"] = true;
    }

    return body;
  }

  String _descricaoFormasFinalizacao() {
    if (_pagamentosLancados.isEmpty) return "";

    final descricoes = _pagamentosLancados
        .map((e) => e["descricao"]?.toString() ?? "")
        .where((e) => e.trim().isNotEmpty)
        .toList();

    if (descricoes.isEmpty) return "";
    if (descricoes.length == 1) return descricoes.first;

    return descricoes.join(" + ");
  }

  String _extrairMensagemErro(dynamic jsonBody, int statusCode) {
    if (jsonBody is Map<String, dynamic>) {
      final mensagem =
          jsonBody["mensagem"] ??
          jsonBody["erro"] ??
          jsonBody["message"] ??
          jsonBody["detail"];

      if (mensagem != null && mensagem.toString().trim().isNotEmpty) {
        return mensagem.toString();
      }
    }

    return "Não foi possível finalizar a venda. HTTP $statusCode.";
  }

  Future<void> _finalizarVenda() async {
    if (_enviandoPagamento || _carregandoPrazo) return;

    final ecfId = await _obterEcfId();

    if (ecfId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "ECF do tablet não configurado. Verifique a configuração do aparelho.",
          ),
        ),
      );
      return;
    }

    setState(() {
      _enviandoPagamento = true;
    });

    try {
      if (_temPrazoGerado) {
        await _finalizarVendaPrazo(ecfId);
      } else {
        await _finalizarVendaSimples(ecfId);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao finalizar venda: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _enviandoPagamento = false;
        });
      }
    }
  }

  Widget _buildBoxInfo({
    required String titulo,
    required String valor,
    Color? corValor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: corValor ?? Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormaPagamento(Map<String, dynamic> forma, bool tecladoAberto) {
    final id = forma["id"] as int;
    final descricao = forma["descricao"] as String;
    final selecionada = _formaSelecionadaId == id;

    return InkWell(
      onTap: _enviandoPagamento ? null : () => _selecionarForma(forma),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: tecladoAberto ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: selecionada ? const Color(0xFFFACC15) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selecionada ? Colors.amber.shade700 : Colors.black12,
            width: selecionada ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selecionada ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selecionada ? Colors.black : Colors.black45,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                descricao,
                style: TextStyle(
                  fontSize: tecladoAberto ? 15 : 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagamentoLancado(Map<String, dynamic> pagamento, int index) {
    final descricao = pagamento["descricao"]?.toString() ?? "";
    final valorAplicado =
        (pagamento["valor_aplicado"] as num?)?.toDouble() ?? 0.0;
    final valorRecebido =
        (pagamento["valor_recebido"] as num?)?.toDouble() ?? 0.0;
    final trocoLinha = _arredondar2(math.max(0, valorRecebido - valorAplicado));
    final vencimentoBr = pagamento["vencimento_br"]?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descricao,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vencimentoBr != null && vencimentoBr.trim().isNotEmpty
                      ? "Lançado: ${_formatarValor(valorAplicado)} • Venc.: $vencimentoBr"
                      : trocoLinha > 0
                      ? "Lançado: ${_formatarValor(valorAplicado)} • Troco: ${_formatarValor(trocoLinha)}"
                      : "Lançado: ${_formatarValor(valorAplicado)}",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _enviandoPagamento
                ? null
                : () => _removerPagamentoLancado(index),
            icon: const Icon(Icons.delete_outline),
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildParcelaPrazoGerada(Map<String, dynamic> parcela, int index) {
    final documento = parcela["documento"]?.toString() ?? "";
    final vencimento =
        parcela["vencimento_br"]?.toString() ??
        parcela["vencimento"]?.toString() ??
        "";
    final valor = (parcela["valor"] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              documento,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              "VENCIMENTO: $vencimento",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              "VALOR: ${_formatarValor(valor)}",
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParcelasGeradasPrazoGrande() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Parcelas geradas",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                _parcelasPrazo.length.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _parcelasPrazo.isEmpty
                ? const Center(
                    child: Text(
                      "Nenhuma parcela gerada ainda.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _parcelasPrazo.length,
                    itemBuilder: (context, index) {
                      return _buildParcelaPrazoGerada(
                        _parcelasPrazo[index],
                        index,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlocoDescontoPrazoCompacto(bool tecladoAberto) {
    if (tecladoAberto || _temPrazoGerado) {
      return _buildBoxInfo(
        titulo: "Total da venda",
        valor: _formatarValor(_totalVenda),
      );
    }

    return Column(
      children: [
        _buildBoxInfo(
          titulo: "Total original",
          valor: _formatarValor(_totalOriginal),
        ),
        const SizedBox(height: 8),
        _buildBoxInfo(
          titulo: "Desconto",
          valor: _formatarValor(_valorDescontoCalculado),
          corValor: _temDesconto ? Colors.red : Colors.black54,
        ),
        const SizedBox(height: 8),
        _buildBoxInfo(
          titulo: "Total final",
          valor: _formatarValor(_totalVenda),
          corValor: Colors.green.shade800,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (_podeMexerDesconto && _permiteDescontoNaForma)
                ? _abrirDialogDesconto
                : null,
            icon: const Icon(Icons.percent, size: 18),
            label: Text(
              _temDesconto ? "Editar" : "Desconto",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.black26),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumoDescontoPrazoLinha() {
    return Row(
      children: [
        Expanded(
          child: _buildBoxInfo(
            titulo: "Total original",
            valor: _formatarValor(_totalOriginal),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildBoxInfo(
            titulo: "Desconto",
            valor: _formatarValor(_valorDescontoCalculado),
            corValor: _temDesconto ? Colors.red : Colors.black54,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildBoxInfo(
            titulo: "Total final",
            valor: _formatarValor(_totalVenda),
            corValor: Colors.green.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildPainelEsquerdo(bool tecladoAberto) {
    final mostrandoPrazo = _ehPrazo || _temPrazoGerado;
    final paddingCard = tecladoAberto ? 10.0 : 14.0;
    final espacamentoTituloCampo = tecladoAberto ? 6.0 : 10.0;
    final espacamentoCampoTexto = tecladoAberto ? 4.0 : 8.0;
    final espacamentoTextoBotao = tecladoAberto ? 6.0 : 12.0;
    final paddingCampoVertical = tecladoAberto ? 12.0 : 18.0;
    final fonteCampo = tecladoAberto ? 20.0 : 24.0;
    final paddingBotaoVertical = tecladoAberto ? 10.0 : 14.0;

    Widget buildCampoPrazoLateral({
      required String label,
      required TextEditingController controller,
    }) {
      return TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (_) {
          if (_parcelasPrazo.isNotEmpty) {
            setState(() {
              _parcelasPrazo.clear();
            });
          }
        },
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: tecladoAberto ? 10 : 14,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.black12),
          ),
        ),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      );
    }

    Widget buildBotoesPrazo() {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: (_podeMexerDesconto && _permiteDescontoNaForma)
                  ? _abrirDialogDesconto
                  : null,
              icon: const Icon(Icons.percent, size: 18),
              label: Text(
                _temDesconto ? "Editar desconto" : "Desconto",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: EdgeInsets.symmetric(vertical: paddingBotaoVertical),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: (_enviandoPagamento || _carregandoPrazo)
                  ? null
                  : _gerarParcelasPrazo,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFACC15),
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: Colors.black38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: EdgeInsets.symmetric(vertical: paddingBotaoVertical),
              ),
              child: _carregandoPrazo
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      "Gerar Parcelas",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: tecladoAberto ? 15 : 16,
                      ),
                    ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                padding: EdgeInsets.all(paddingCard),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!mostrandoPrazo) ...[
                      const Text(
                        "Valor Pago",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: espacamentoTituloCampo),
                    ],
                    if (mostrandoPrazo) ...[
                      const Text(
                        "Cliente",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _clientePrazoController,
                        readOnly: true,
                        onTap: _informarClientePrazo,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: "Toque para informar o cliente",
                          suffixIcon: IconButton(
                            onPressed: _informarClientePrazo,
                            icon: const Icon(Icons.search),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: paddingCampoVertical,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF7C3AED),
                              width: 2,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: tecladoAberto ? 18 : 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: espacamentoCampoTexto),
                      if (!tecladoAberto)
                        Text(
                          _parcelasPrazo.isEmpty
                              ? "Informe o cliente, as parcelas e clique em gerar."
                              : "Parcelas geradas. Agora você já pode finalizar a venda a prazo.",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (!tecladoAberto && !_temPrazoGerado) ...[
                        SizedBox(height: espacamentoTextoBotao),
                        _buildResumoDescontoPrazoLinha(),
                        SizedBox(height: espacamentoTextoBotao),
                        buildBotoesPrazo(),
                      ],
                    ] else ...[
                      TextField(
                        controller: _valorPagoController,
                        focusNode: _valorPagoFocusNode,
                        readOnly: !_ehDinheiro || _enviandoPagamento,
                        showCursor: _ehDinheiro && !_enviandoPagamento,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        autofocus: false,
                        onEditingComplete: () {
                          FocusScope.of(context).unfocus();
                        },
                        onSubmitted: (_) {
                          FocusScope.of(context).unfocus();
                        },
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: paddingCampoVertical,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF7C3AED),
                              width: 2,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: fonteCampo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: espacamentoCampoTexto),
                      if (!tecladoAberto)
                        Text(
                          _formaSelecionadaId == null
                              ? "Selecione a forma e informe o valor para lançar."
                              : _ehDinheiro
                              ? _trocoPreview > _trocoLancado
                                    ? "Troco previsto: ${_formatarValor(_trocoPreview)}. Será lançado apenas o restante."
                                    : "Digite o valor recebido em dinheiro."
                              : _temDesconto
                              ? "Desconto aplicado: ${_formatarValor(_valorDescontoCalculado)}. Informe o valor nesta forma."
                              : "Informe o valor que será lançado nesta forma.",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      SizedBox(height: espacamentoTextoBotao),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              (_podeAdicionarPagamento && !_enviandoPagamento)
                              ? _adicionarPagamento
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFACC15),
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: const Color(0xFFE5E7EB),
                            disabledForegroundColor: Colors.black38,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: paddingBotaoVertical,
                            ),
                          ),
                          child: Text(
                            "Adicionar Pagamento",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: tecladoAberto ? 15 : 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: mostrandoPrazo
                  ? Column(
                      children: [
                        buildCampoPrazoLateral(
                          label: "Parcelas",
                          controller: _parcelasController,
                        ),
                        const SizedBox(height: 8),
                        buildCampoPrazoLateral(
                          label: "Intervalo",
                          controller: _intervaloController,
                        ),
                      ],
                    )
                  : _buildBoxInfo(
                      titulo: "Total da venda",
                      valor: _formatarValor(_totalVenda),
                    ),
            ),
          ],
        ),

        if (!mostrandoPrazo && !tecladoAberto && !_temPrazoGerado) ...[
          const SizedBox(height: 10),
          _buildBlocoDesconto(tecladoAberto),
        ],

        if (mostrandoPrazo && _temPrazoGerado) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildBoxInfo(
                  titulo: "Cliente",
                  valor: _clientePrazoId?.toString() ?? "--",
                  corValor: Colors.black87,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBoxInfo(
                  titulo: "Parcelas",
                  valor: _quantidadeParcelasPrazo.toString(),
                  corValor: Colors.blue.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBoxInfo(
                  titulo: "Intervalo",
                  valor: "${_intervaloPrazoDias} dias",
                  corValor: Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildParcelasGeradasPrazoGrande()),
        ] else if (!mostrandoPrazo) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildBoxInfo(
                  titulo: "Pago",
                  valor: _formatarValor(_totalLancado),
                  corValor: Colors.green.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBoxInfo(
                  titulo: "Falta",
                  valor: _formatarValor(_falta),
                  corValor: Colors.blue.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBoxInfo(
                  titulo: "Troco",
                  valor: _formatarValor(_trocoPreview),
                  corValor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBotaoVoltarFlutuante() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 8, top: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _enviandoPagamento ? null : () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back, color: Colors.black, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPainelDireito(bool tecladoAberto) {
    final mostrandoPrazo = _ehPrazo || _temPrazoGerado;
    final paddingPainel = tecladoAberto ? 10.0 : 14.0;
    final espacamentoTitulo = tecladoAberto ? 4.0 : 12.0;
    final espacamentoForma = tecladoAberto ? 4.0 : 8.0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        paddingPainel,
        tecladoAberto ? 10.0 : paddingPainel,
        paddingPainel,
        tecladoAberto ? 8.0 : paddingPainel,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Formas de Pagamento",
            style: TextStyle(
              fontSize: tecladoAberto ? 17 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: espacamentoTitulo),

          if (tecladoAberto)
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                itemCount: _formasPagamento.length,
                itemBuilder: (context, index) {
                  final forma = _formasPagamento[index];
                  return _buildFormaPagamento(forma, tecladoAberto);
                },
                separatorBuilder: (_, __) => SizedBox(height: espacamentoForma),
              ),
            )
          else ...[
            ..._formasPagamento.map((forma) {
              return Padding(
                padding: EdgeInsets.only(bottom: espacamentoForma),
                child: _buildFormaPagamento(forma, tecladoAberto),
              );
            }),
            if (!mostrandoPrazo) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Pagamentos lançados",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    _pagamentosLancados.length.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _pagamentosLancados.isEmpty
                    ? const Center(
                        child: Text(
                          "Nenhum pagamento lançado ainda.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _pagamentosLancados.length,
                        itemBuilder: (context, index) {
                          return _buildPagamentoLancado(
                            _pagamentosLancados[index],
                            index,
                          );
                        },
                      ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRodape(bool tecladoAberto) {
    if (tecladoAberto) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _enviandoPagamento
                  ? null
                  : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                "Voltar",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: (_podeFinalizar && !_enviandoPagamento)
                  ? _finalizarVenda
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFACC15),
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: Colors.black38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: _enviandoPagamento
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      "Finalizar Venda",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    final tecladoAberto = MediaQuery.of(context).viewInsets.bottom > 0;
    final layoutVertical = largura < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
              child: Column(
                children: [
                  Expanded(
                    child: layoutVertical
                        ? Column(
                            children: [
                              Expanded(
                                child: _buildPainelDireito(tecladoAberto),
                              ),
                              const SizedBox(height: 12),
                              _buildPainelEsquerdo(tecladoAberto),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 8,
                                child: _buildPainelEsquerdo(tecladoAberto),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: _buildPainelDireito(tecladoAberto),
                              ),
                            ],
                          ),
                  ),
                  if (!tecladoAberto) const SizedBox(height: 16),
                  _buildRodape(tecladoAberto),
                ],
              ),
            ),
          ),
          _buildBotaoVoltarFlutuante(),
        ],
      ),
    );
  }
}
