class ItemCarrinho {
  final int id;
  final String descricao;
  final double preco;
  final String fotoUrl;
  int quantidade;
  bool existente;

  ItemCarrinho({
    required this.id,
    required this.descricao,
    required this.preco,
    required this.fotoUrl,
    required this.quantidade,
    this.existente = false,
  });

  double get total => preco * quantidade;
}
