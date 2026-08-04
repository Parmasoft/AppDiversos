import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:padaria_app/services/carrinho_service.dart';
import 'package:padaria_app/services/api_service.dart';

class ProdutosTab extends StatefulWidget {
  const ProdutosTab({super.key});

  @override
  State<ProdutosTab> createState() => _ProdutosTabState();
}

class _ProdutosTabState extends State<ProdutosTab> {
  // Controllers
  final TextEditingController buscaCtrl = TextEditingController();
  final TextEditingController desc2Ctrl = TextEditingController();
  final TextEditingController desc3Ctrl = TextEditingController();
  final TextEditingController unidadeCtrl = TextEditingController();
  final TextEditingController precoCtrl = TextEditingController(); // preço unit
  final TextEditingController quantidadeCtrl = TextEditingController(text: '1');

  final carrinho = CarrinhoService();
  final FocusNode buscaFocus = FocusNode();

  // Autocomplete
  List<Map<String, dynamic>> sugestoes = [];
  Map<String, dynamic>? produtoSelecionado;
  bool carregandoBusca = false;

  final NumberFormat moeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  double subtotal = 0.0;

  bool get _podeAdicionar {
    final qtd = double.tryParse(quantidadeCtrl.text.replaceAll(',', '.')) ?? 0;
    return produtoSelecionado != null && qtd > 0;
  }

  OutlineInputBorder bordaPadrao() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: Colors.black26),
  );

  // Arredondamento monetário
  double _round2(double value) => double.parse(value.toStringAsFixed(2));

  void calcularSubtotal() {
    final qtd = double.tryParse(quantidadeCtrl.text.replaceAll(',', '.')) ?? 0;
    final preco = double.tryParse(precoCtrl.text.replaceAll(',', '.')) ?? 0;

    setState(() {
      subtotal = _round2(qtd * preco);
    });
  }

  Future<void> buscarProdutos(String texto) async {
    if (texto.trim().isEmpty) {
      setState(() => sugestoes = []);
      return;
    }

    setState(() => carregandoBusca = true);

    try {
      final q = Uri.encodeQueryComponent(texto);
      final resp = await ApiService.get('/produtos/busca?descricao=$q');

      final List<dynamic> lista = resp is List ? resp : [];
      setState(() {
        sugestoes = lista.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (_) {
      setState(() => sugestoes = []);
    } finally {
      setState(() => carregandoBusca = false);
    }
  }

  void selecionarProduto(Map<String, dynamic> p) {
    // tenta capturar preço com chaves comuns
    final precoNum =
        (p['preco'] ??
                p['preco_unitario'] ??
                p['preco_unit'] ??
                p['valor'] ??
                p['preco_venda'] ??
                0)
            as num;

    final preco = precoNum.toDouble();

    setState(() {
      produtoSelecionado = p;

      buscaCtrl.text = (p['descricao'] ?? '').toString();
      desc2Ctrl.text = (p['desc2'] ?? '').toString();
      desc3Ctrl.text = (p['desc3'] ?? '').toString();
      unidadeCtrl.text = (p['unidade'] ?? '').toString();

      precoCtrl.text = preco.toStringAsFixed(2).replaceAll('.', ',');

      sugestoes = [];
    });

    calcularSubtotal();
    FocusScope.of(context).unfocus();
  }

  void adicionarItem() {
    if (produtoSelecionado == null) return;

    final qtd = double.tryParse(quantidadeCtrl.text.replaceAll(',', '.')) ?? 0;
    final preco = double.tryParse(precoCtrl.text.replaceAll(',', '.')) ?? 0;

    if (qtd <= 0 || preco <= 0) return;

    carrinho.adicionarItem({
      'item_tipo': 'P',
      'id': produtoSelecionado!['id'],
      'descricao1': buscaCtrl.text.trim(),
      'descricao2': desc2Ctrl.text.trim(),
      'descricao3': desc3Ctrl.text.trim(),
      'unidade': unidadeCtrl.text.trim(),
      'quantidade': qtd,
      // ✅ Mantendo o padrão que está funcionando no seu carrinho/PDF
      'preco_unitario': preco,
      'subtotal': _round2(qtd * preco),
    });

    setState(() {
      buscaCtrl.clear();
      desc2Ctrl.clear();
      desc3Ctrl.clear();
      unidadeCtrl.clear();
      precoCtrl.clear();
      quantidadeCtrl.text = '1';
      subtotal = 0.0;
      produtoSelecionado = null;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      buscaFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    buscaCtrl.dispose();
    desc2Ctrl.dispose();
    desc3Ctrl.dispose();
    unidadeCtrl.dispose();
    precoCtrl.dispose();
    quantidadeCtrl.dispose();
    buscaFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              focusNode: buscaFocus,
              controller: buscaCtrl,
              decoration: InputDecoration(
                labelText: 'Buscar Produto',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: Colors.white,
                border: bordaPadrao(),
              ),
              onChanged: buscarProdutos,
            ),

            if (carregandoBusca)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: CircularProgressIndicator(),
              ),

            if (sugestoes.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sugestoes.length,
                  itemBuilder: (_, i) {
                    final p = sugestoes[i];
                    final desc = (p['descricao'] ?? '').toString();
                    return ListTile(
                      title: Text(desc),
                      onTap: () => selecionarProduto(p),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // ✅ Linha 1: Quantidade + Preço Unitário
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantidadeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantidade',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      filled: true,
                      fillColor: Colors.white,
                      border: bordaPadrao(),
                    ),
                    onChanged: (_) => calcularSubtotal(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    readOnly: true,
                    controller: precoCtrl,
                    decoration: InputDecoration(
                      labelText: 'Preço Unitário',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      filled: true,
                      fillColor: Colors.white,
                      border: bordaPadrao(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ✅ Linha 2: Total (Subtotal do item)
            TextField(
              readOnly: true,
              controller: TextEditingController(text: moeda.format(subtotal)),
              decoration: InputDecoration(
                labelText: 'Total',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: Colors.white,
                border: bordaPadrao(),
              ),
            ),

            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: _podeAdicionar ? adicionarItem : null,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _podeAdicionar ? Colors.white : Colors.black12,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _podeAdicionar ? Colors.black : Colors.black26,
                    ),
                  ),
                  child: Icon(
                    Icons.add,
                    color: _podeAdicionar ? Colors.black : Colors.black38,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
