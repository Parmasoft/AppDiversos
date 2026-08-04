import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:padaria_app/services/carrinho_service.dart';
import 'package:padaria_app/services/api_service.dart';

class BolosTab extends StatefulWidget {
  const BolosTab({super.key});

  @override
  State<BolosTab> createState() => _BolosTabState();
}

class _BolosTabState extends State<BolosTab> {
  final CarrinhoService carrinho = CarrinhoService();

  // Descrição do bolo
  final TextEditingController descricaoCtrl = TextEditingController();

  // Recheio 1
  final TextEditingController recheioCtrl = TextEditingController();
  int? recheioIdSelecionado;
  double precoKg1 = 0.0;
  List<Map<String, dynamic>> sugestoesRecheio1 = [];
  Timer? _debounce1;

  // Recheio 2
  final TextEditingController recheio2Ctrl = TextEditingController();
  double precoKg2 = 0.0;
  List<Map<String, dynamic>> sugestoesRecheio2 = [];
  Timer? _debounce2;

  final TextEditingController pesoCtrl = TextEditingController();
  final TextEditingController precoKgCtrl = TextEditingController();

  double total = 0.0;

  OutlineInputBorder bordaPadrao() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: Colors.black26),
  );

  double _round2(double value) => double.parse(value.toStringAsFixed(2));

  double _parseDecimal(String value) {
    var v = value.trim();
    if (v.isEmpty) return 0.0;

    if (v.contains(',')) {
      v = v.replaceAll('.', '').replaceAll(',', '.');
    } else {
      v = v.replaceAll(',', '');
    }

    return double.tryParse(v) ?? 0.0;
  }

  bool get _recheio1SelecionadoValido =>
      recheioIdSelecionado != null &&
      precoKg1 > 0 &&
      recheioCtrl.text.trim().isNotEmpty;

  bool get _pesoValido => _parseDecimal(pesoCtrl.text) > 0;

  bool get _podeAdicionar =>
      descricaoCtrl.text.trim().isNotEmpty &&
      _recheio1SelecionadoValido &&
      _pesoValido;

  @override
  void initState() {
    super.initState();
    pesoCtrl.addListener(calcularTotal);
  }

  @override
  void dispose() {
    descricaoCtrl.dispose();
    recheioCtrl.dispose();
    recheio2Ctrl.dispose();
    pesoCtrl.dispose();
    precoKgCtrl.dispose();
    _debounce1?.cancel();
    _debounce2?.cancel();
    super.dispose();
  }

  // =========================
  // BUSCA RECHEIOS
  // =========================
  Future<void> buscarRecheio1(String texto) async {
    _debounce1?.cancel();
    _debounce1 = Timer(const Duration(milliseconds: 250), () async {
      if (texto.trim().isEmpty) {
        setState(() => sugestoesRecheio1 = []);
        return;
      }

      try {
        final q = Uri.encodeQueryComponent(texto);
        final resp = await ApiService.get('/recheios/busca?descricao=$q');

        final List<dynamic> lista = resp is List ? resp : [];
        setState(() {
          sugestoesRecheio1 = lista
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      } catch (_) {
        setState(() => sugestoesRecheio1 = []);
      }
    });
  }

  Future<void> buscarRecheio2(String texto) async {
    _debounce2?.cancel();
    _debounce2 = Timer(const Duration(milliseconds: 250), () async {
      if (texto.trim().isEmpty) {
        setState(() => sugestoesRecheio2 = []);
        return;
      }

      try {
        final q = Uri.encodeQueryComponent(texto);
        final resp = await ApiService.get('/recheios/busca?descricao=$q');

        final List<dynamic> lista = resp is List ? resp : [];
        setState(() {
          sugestoesRecheio2 = lista
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      } catch (_) {
        setState(() => sugestoesRecheio2 = []);
      }
    });
  }

  void selecionarRecheio1(Map<String, dynamic> r) {
    setState(() {
      recheioIdSelecionado = r['id'];
      recheioCtrl.text = (r['descricao'] ?? '').toString();
      precoKg1 = (r['preco_kg'] as num).toDouble();
      sugestoesRecheio1 = [];
    });

    _atualizarPrecoKgPeloMaior();
    FocusScope.of(context).unfocus();
  }

  void selecionarRecheio2(Map<String, dynamic> r) {
    setState(() {
      recheio2Ctrl.text = (r['descricao'] ?? '').toString();
      precoKg2 = (r['preco_kg'] as num).toDouble();
      sugestoesRecheio2 = [];
    });

    _atualizarPrecoKgPeloMaior();
    FocusScope.of(context).unfocus();
  }

  void _limparRecheio2() {
    setState(() {
      recheio2Ctrl.clear();
      precoKg2 = 0.0;
      sugestoesRecheio2 = [];
    });
    _atualizarPrecoKgPeloMaior();
  }

  double _maiorPrecoKg() => (precoKg1 > precoKg2) ? precoKg1 : precoKg2;

  void _atualizarPrecoKgPeloMaior() {
    final maior = _maiorPrecoKg();
    precoKgCtrl.text = maior <= 0
        ? ''
        : maior.toStringAsFixed(2).replaceAll('.', ',');
    calcularTotal();
  }

  void calcularTotal() {
    final peso = _parseDecimal(pesoCtrl.text);
    final preco = _maiorPrecoKg();

    setState(() {
      total = _round2(peso * preco);
    });
  }

  // =========================
  // ADICIONAR BOLO (🔥 CORRIGIDO)
  // =========================
  void adicionarBolo() {
    if (!_recheio1SelecionadoValido) return;
    if (!_pesoValido) return;

    final desc = descricaoCtrl.text.trim();
    if (desc.isEmpty) return;

    final peso = _parseDecimal(pesoCtrl.text);
    final precoKg = _maiorPrecoKg();
    if (precoKg <= 0) return;

    final recheio1 = recheioCtrl.text.trim();
    final recheio2 = recheio2Ctrl.text.trim();

    if (recheio2.isNotEmpty &&
        recheio1.toLowerCase() == recheio2.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recheio 2 não pode ser igual ao Recheio 1.'),
        ),
      );
      return;
    }

    // 🔥 CONTRATO FINAL DO SISTEMA
    carrinho.adicionarItem({
      'item_tipo': 'B',
      'descricao1': desc,
      'descricao2': recheio1,
      //'descricao3': recheio2.isEmpty ? null : recheio2,
      'descricao3': recheio2,
      'unidade': 'KG',
      'quantidade': peso,
      'preco_unitario': precoKg,
      'subtotal': _round2(peso * precoKg),
    });

    setState(() {
      descricaoCtrl.clear();
      recheioCtrl.clear();
      recheio2Ctrl.clear();
      pesoCtrl.clear();
      precoKgCtrl.clear();

      recheioIdSelecionado = null;
      precoKg1 = 0.0;
      precoKg2 = 0.0;

      sugestoesRecheio1 = [];
      sugestoesRecheio2 = [];
      total = 0.0;
    });

    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: descricaoCtrl,
              decoration: InputDecoration(
                labelText: 'Descrição do bolo',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: Colors.white,
                border: bordaPadrao(),
              ),
            ),
            const SizedBox(height: 12),

            // Recheio 1
            TextField(
              controller: recheioCtrl,
              decoration: InputDecoration(
                labelText: 'Recheio 1 (obrigatório)',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: Colors.white,
                border: bordaPadrao(),
              ),
              onChanged: buscarRecheio1,
            ),

            if (sugestoesRecheio1.isNotEmpty)
              ...sugestoesRecheio1.map(
                (r) => ListTile(
                  title: Text(r['descricao'].toString()),
                  onTap: () => selecionarRecheio1(r),
                ),
              ),

            const SizedBox(height: 12),

            // Recheio 2
            TextField(
              controller: recheio2Ctrl,
              decoration: InputDecoration(
                labelText: 'Recheio 2 (opcional)',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: Colors.white,
                border: bordaPadrao(),
              ),

              //onChanged: buscarRecheio2,
              onChanged: (v) {
                if (v.trim().isEmpty) {
                  _limparRecheio2(); // 🔥 ESSENCIAL
                } else {
                  buscarRecheio2(v);
                }
              },
            ),

            if (sugestoesRecheio2.isNotEmpty)
              ...sugestoesRecheio2.map(
                (r) => ListTile(
                  title: Text(r['descricao'].toString()),
                  onTap: () => selecionarRecheio2(r),
                ),
              ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pesoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*([.,]\d{0,3})?$'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Quantidade (KG)',
                      filled: true,
                      fillColor: Colors.white,
                      border: bordaPadrao(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    readOnly: true,
                    controller: precoKgCtrl,
                    decoration: InputDecoration(
                      labelText: 'Preço Unitário (KG)',
                      filled: true,
                      fillColor: Colors.white,
                      border: bordaPadrao(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              'Total: R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _podeAdicionar ? adicionarBolo : null,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
