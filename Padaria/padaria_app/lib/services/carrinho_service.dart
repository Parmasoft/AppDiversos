class CarrinhoService {
  static final CarrinhoService _instance = CarrinhoService._internal();
  factory CarrinhoService() => _instance;
  CarrinhoService._internal();

  final List<Map<String, dynamic>> _itens = [];

  List<Map<String, dynamic>> get itens => _itens;
  bool get vazio => _itens.isEmpty;

  double get total {
    double soma = 0.0;
    for (final item in _itens) {
      soma += item['subtotal'] ?? 0.0;
    }
    return _round2(soma);
  }

  void adicionarItem(Map<String, dynamic> item) {
    // ================================
    // 🔥 PADRONIZAÇÃO DEFINITIVA
    // ================================

    // Produto / bolo
    item['descricao1'] ??= '';

    // 🔁 MIGRAÇÃO AUTOMÁTICA (se vier legado)
    if (item.containsKey('recheio1') && item['descricao2'] == null) {
      item['descricao2'] = item['recheio1'];
    }

    if (item.containsKey('recheio2') && item['descricao3'] == null) {
      item['descricao3'] = item['recheio2'];
    }

    // Remove lixo antigo para não confundir mais ninguém
    item.remove('recheio1');
    item.remove('recheio2');
    item.remove('recheio3');

    // Garante existência dos campos
    item['descricao2'] ??= '';
    item['descricao3'] ??= '';

    // ================================
    // 🔢 CÁLCULOS
    // ================================
    final quantidade = (item['quantidade'] ?? 0.0).toDouble();
    final precoUnitario = (item['preco_unitario'] ?? item['preco'] ?? 0.0)
        .toDouble();

    final subtotal = _round2(quantidade * precoUnitario);

    item['preco_unitario'] = _round2(precoUnitario);
    item['subtotal'] = subtotal;

    _itens.add(item);
  }

  void removerItem(int index) {
    if (index >= 0 && index < _itens.length) {
      _itens.removeAt(index);
    }
  }

  void limpar() {
    _itens.clear();
  }

  double _round2(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}
