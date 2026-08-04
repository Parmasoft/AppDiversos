import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class RolosPage extends StatefulWidget {
  final String baseUrl;
  final int empresaId;
  final Map<String, dynamic> produto;

  const RolosPage({
    super.key,
    required this.baseUrl,
    required this.empresaId,
    required this.produto,
  });

  @override
  State<RolosPage> createState() => _RolosPageState();
}

class _RolosPageState extends State<RolosPage> {
  final _qtdCtrl = TextEditingController();
  final _qtdFocus = FocusNode();
  final _keyboardFocus = FocusNode();

  final List<double> _rolos = [];

  bool _salvando = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocus.requestFocus();
        _qtdFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _qtdCtrl.dispose();
    _qtdFocus.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  String get _descricao => widget.produto["descricao"]?.toString() ?? "";
  String get _unidade => widget.produto["unidade"]?.toString() ?? "";
  int get _produtoId {
    return int.tryParse(widget.produto["produto_id"].toString()) ?? 0;
  }

  double _totalRolos() {
    double total = 0;
    for (final r in _rolos) {
      total += r;
    }
    return total;
  }

  String _formatarQtd(double valor) {
    final f = NumberFormat("#,##0.00", "pt_BR");
    return f.format(valor);
  }

  double? _parseQtd(String texto) {
    var limpo = texto.trim();

    if (limpo.isEmpty) return null;

    // Se veio com vírgula, tratamos vírgula como decimal.
    // Ex: 37,35 -> 37.35
    if (limpo.contains(",")) {
      limpo = limpo.replaceAll(".", "");
      limpo = limpo.replaceAll(",", ".");
    }

    // Se veio somente com ponto, mantemos ponto como decimal.
    // Ex: 37.35 -> 37.35
    return double.tryParse(limpo);
  }

  String _montarCodigoRolo(double quantidade) {
    final produtoFmt = _produtoId.toString().padLeft(8, "0");
    final quantidadeCent = (quantidade * 100).round();
    final quantidadeFmt = quantidadeCent.toString().padLeft(6, "0");

    return "ROLO$produtoFmt$quantidadeFmt";
  }

  void _adicionarRolo() {
    final qtd = _parseQtd(_qtdCtrl.text);

    if (qtd == null || qtd <= 0) {
      return;
    }

    setState(() {
      _rolos.insert(0, qtd);
      _qtdCtrl.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocus.requestFocus();
        _qtdFocus.requestFocus();
      }
    });
  }

  void _removerRolo(int index) {
    setState(() {
      _rolos.removeAt(index);
    });
  }

  Future<void> _salvarRolos() async {
    if (_rolos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Inclua pelo menos um rolo."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final url = Uri.parse("${widget.baseUrl}/rolos/salvar");

      final resp = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "empresa": widget.empresaId,
              "produto_id": _produtoId,
              "un": _unidade,
              "prateleira": "",
              "usuario": 1,
              "rolos": _rolos,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final dados = jsonDecode(resp.body);

      if (!mounted) return;

      if (resp.statusCode == 200 && dados["status"] == "ok") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dados["mensagem"] ?? "Rolos salvos com sucesso."),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _rolos.clear();
          _qtdCtrl.clear();
        });

        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dados["mensagem"] ?? "Erro ao salvar rolos."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erro de conexão ao salvar rolos."),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  Widget _cabecalhoProduto() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
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
              Expanded(
                child: Text(
                  "Código: $_produtoId",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
              Text(
                "UN: $_unidade",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _descricao,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _linhaRolo(int index, double quantidade) {
    return Card(
      margin: const EdgeInsets.all(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _formatarQtd(quantidade),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: () => _removerRolo(index),
              icon: const Icon(Icons.delete, color: Colors.red, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumoRolos(double total) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white70,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        "Rolos: ${_rolos.length}   |   Total: ${_formatarQtd(total)}",
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalRolos();

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          "Rolos: ${_rolos.length}  |  Total: ${_formatarQtd(total)}",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 8),
            child: TextButton.icon(
              onPressed: _salvando ? null : _salvarRolos,
              icon: _salvando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save, size: 20),
              label: Text(
                _salvando ? "..." : "Salvar",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
            ),
          ),
        ],
      ),

      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF9E3), Color(0xFFEDEDED)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _cabecalhoProduto(),

                    const SizedBox(height: 12),

                    KeyboardListener(
                      focusNode: _keyboardFocus,
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey ==
                                LogicalKeyboardKey.numpadEnter) {
                          _adicionarRolo();
                        }
                      },
                      child: TextField(
                        controller: _qtdCtrl,
                        focusNode: _qtdFocus,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _adicionarRolo(),
                        decoration: InputDecoration(
                          labelText: "Metragem do rolo",
                          hintText: "Ex: 67,30",
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.straighten),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _rolos.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 4,
                            childAspectRatio: 3.8,
                          ),
                      itemBuilder: (_, index) {
                        return _linhaRolo(index, _rolos[index]);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
