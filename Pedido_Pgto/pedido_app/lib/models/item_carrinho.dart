class ItemCarrinho {
  final int id;
  final String descricao;
  final double preco;
  final String fotoUrl;
  double quantidade;
  bool existente;
  final int? sequencialItem;
  final String unidadeVenda;
  final bool fracionado;

  ItemCarrinho({
    required this.id,
    required this.descricao,
    required this.preco,
    required this.fotoUrl,
    required this.quantidade,
    required this.existente,
    this.sequencialItem,
    this.unidadeVenda = 'UN',
    this.fracionado = false,
  });

  double get total => preco * quantidade;

  String get quantidadeFormatada {
    final texto = quantidade.toStringAsFixed(3).replaceAll('.', ',');
    return texto.replaceFirst(RegExp(r',?0+$'), '');
  }
}
