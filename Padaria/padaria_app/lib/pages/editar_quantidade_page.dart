import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:padaria_app/services/pedido_local_service.dart';
import '../services/recheio_service.dart';

class EditarQuantidadePage extends StatefulWidget {
  final Map<String, dynamic> item;
  final double precoKg;

  const EditarQuantidadePage({
    super.key,
    required this.item,
    required this.precoKg,
  });

  @override
  State<EditarQuantidadePage> createState() => _EditarQuantidadePageState();
}

class _EditarQuantidadePageState extends State<EditarQuantidadePage> {
  late TextEditingController quantidadeCtrl;
  late TextEditingController recheio1Ctrl;
  late TextEditingController recheio2Ctrl;

  late FocusNode focoRecheio1;
  late FocusNode focoRecheio2;

  List<Map<String, dynamic>> sugestoes1 = [];
  List<Map<String, dynamic>> sugestoes2 = [];

  double precoRecheio1 = 0.0;
  double precoRecheio2 = 0.0;

  double subtotal = 0.0;

  @override
  void initState() {
    super.initState();

    widget.item['descricao2'] ??= '';
    widget.item['descricao3'] ??= '';

    quantidadeCtrl = TextEditingController(
      text: (widget.item['quantidade'] ?? 0).toString(),
    );

    recheio1Ctrl = TextEditingController(text: widget.item['descricao2']);
    recheio2Ctrl = TextEditingController(text: widget.item['descricao3']);

    focoRecheio1 = FocusNode();
    focoRecheio2 = FocusNode();

    // ✅ Usa o subtotal salvo
    subtotal = (widget.item['subtotal'] as num?)?.toDouble() ?? 0.0;

    // ✅ Carrega preços dos recheios já salvos
    if (recheio1Ctrl.text.isNotEmpty || recheio2Ctrl.text.isNotEmpty) {
      _carregarPrecosIniciais();
    }
  }

  @override
  void dispose() {
    quantidadeCtrl.dispose();
    recheio1Ctrl.dispose();
    recheio2Ctrl.dispose();
    focoRecheio1.dispose();
    focoRecheio2.dispose();
    super.dispose();
  }

  // ==================================================
  // BUSCA RECHEIOS (AUTOCOMPLETE)
  // ==================================================
  Future<void> _buscarRecheio1(String texto) async {
    if (texto.length < 3) {
      setState(() => sugestoes1 = []);
      return;
    }
    sugestoes1 = await RecheioService.buscar(texto);
    setState(() {});
  }

  Future<void> _buscarRecheio2(String texto) async {
    if (texto.length < 3) {
      setState(() => sugestoes2 = []);
      return;
    }
    sugestoes2 = await RecheioService.buscar(texto);
    setState(() {});
  }

  // ==================================================
  // CARREGA PREÇOS DOS RECHEIOS JÁ SALVOS
  // ==================================================
  Future<void> _carregarPrecosIniciais() async {
    precoRecheio1 = await PedidoLocalService().buscarPrecoRecheioPorDescricao(
      recheio1Ctrl.text,
    );

    precoRecheio2 = await PedidoLocalService().buscarPrecoRecheioPorDescricao(
      recheio2Ctrl.text,
    );

    //_recalcularSubtotal();
    setState(() {});
  }

  // ==================================================
  // SUBTOTAL PELO RECHEIO MAIS CARO
  // ==================================================
  void _recalcularSubtotal() {
    final qtd =
        double.tryParse(quantidadeCtrl.text.replaceAll(',', '.')) ?? 0.0;

    final precos = [widget.precoKg, precoRecheio1, precoRecheio2];

    final precoFinal = precos.reduce((a, b) => a > b ? a : b);

    subtotal = qtd * precoFinal;
    setState(() {});
  }

  void _salvar() {
    final qtd =
        double.tryParse(quantidadeCtrl.text.replaceAll(',', '.')) ?? 0.0;

    final precos = [widget.precoKg, precoRecheio1, precoRecheio2];

    final precoFinal = precos.reduce((a, b) => a > b ? a : b);
    final novoSubtotal = qtd * precoFinal;

    widget.item['quantidade'] = qtd;
    widget.item['descricao2'] = recheio1Ctrl.text.trim();
    widget.item['descricao3'] = recheio2Ctrl.text.trim();
    //widget.item['subtotal'] = novoSubtotal; // 🔥 SEMPRE NOVO
    widget.item['subtotal'] = subtotal;

    Navigator.pop(context, widget.item);
  }

  InputBorder _borda() =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(6));

  Widget _listaSugestoes({
    required List<Map<String, dynamic>> lista,
    required TextEditingController ctrl,
    required FocusNode foco,
    required void Function(double preco) onSelect,
  }) {
    if (lista.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: lista.map((r) {
          return ListTile(
            title: Text(r['descricao']),
            onTap: () {
              ctrl.text = r['descricao'];
              onSelect((r['preco_kg'] as num?)?.toDouble() ?? 0.0);
              lista.clear();
              FocusScope.of(context).requestFocus(foco);
              _recalcularSubtotal();
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moeda = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Quantidade')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // QUANTIDADE
            TextField(
              controller: quantidadeCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Quantidade (KG)',
                filled: true,
                fillColor: Colors.white,
                border: _borda(),
              ),
              onChanged: (_) => _recalcularSubtotal(),
            ),

            const SizedBox(height: 12),

            // RECHEIO 1
            TextField(
              controller: recheio1Ctrl,
              focusNode: focoRecheio1,
              decoration: InputDecoration(
                labelText: 'Recheio 1',
                filled: true,
                fillColor: Colors.white,
                border: _borda(),
              ),
              onTap: () {
                recheio1Ctrl.clear();
                precoRecheio1 = 0;
                sugestoes1.clear();
                setState(() {});
              },
              onChanged: _buscarRecheio1,
            ),

            _listaSugestoes(
              lista: sugestoes1,
              ctrl: recheio1Ctrl,
              foco: focoRecheio1,
              onSelect: (p) => precoRecheio1 = p,
            ),

            const SizedBox(height: 12),

            // RECHEIO 2
            TextField(
              controller: recheio2Ctrl,
              focusNode: focoRecheio2,
              decoration: InputDecoration(
                labelText: 'Recheio 2 (opcional)',
                filled: true,
                fillColor: Colors.white,
                border: _borda(),
              ),
              onTap: () {
                recheio2Ctrl.clear();
                precoRecheio2 = 0;
                sugestoes2.clear();
                setState(() {});
              },
              onChanged: _buscarRecheio2,
            ),

            _listaSugestoes(
              lista: sugestoes2,
              ctrl: recheio2Ctrl,
              foco: focoRecheio2,
              onSelect: (p) => precoRecheio2 = p,
            ),

            const SizedBox(height: 20),

            Text(
              'Cliente: ${widget.item['cliente'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Pedido: ${widget.item['pedidoId'] ?? ''}'),

            const SizedBox(height: 12),

            Text(
              widget.item['descricao1'] ?? '',
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            Text(
              'Subtotal: ${moeda.format(subtotal)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _salvar,
                    child: const Text('Salvar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
