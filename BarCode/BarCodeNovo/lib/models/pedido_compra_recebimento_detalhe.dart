class PedidoCompraRecebimentoDetalhe {
  final int empresa;
  final int pedidoId;
  final String status;
  final String? dataEmissao;
  final int fornecedorId;
  final String fornecedorNome;
  final String? dataRecebimento;
  final double valorTotal;
  final double valorRecebido;
  final String? numeroNota;
  final List<PedidoCompraRecebimentoItem> itens;

  const PedidoCompraRecebimentoDetalhe({
    required this.empresa,
    required this.pedidoId,
    required this.status,
    required this.dataEmissao,
    required this.fornecedorId,
    required this.fornecedorNome,
    required this.dataRecebimento,
    required this.valorTotal,
    required this.valorRecebido,
    required this.numeroNota,
    required this.itens,
  });

  String get numeroFormatado => pedidoId.toString().padLeft(6, '0');

  factory PedidoCompraRecebimentoDetalhe.fromJson(Map<String, dynamic> json) {
    final nota = (json['numero_nota'] ?? '').toString().trim();
    final emissao = (json['data_emissao'] ?? '').toString().trim();
    final recebimento = (json['data_recebimento'] ?? '').toString().trim();
    final itensJson = json['itens'];

    return PedidoCompraRecebimentoDetalhe(
      empresa: _comoInt(json['empresa']),
      pedidoId: _comoInt(json['pedido_id']),
      status: (json['status'] ?? '').toString().trim(),
      dataEmissao: emissao.isEmpty ? null : emissao,
      fornecedorId: _comoInt(json['fornecedor_id']),
      fornecedorNome: (json['fornecedor_nome'] ?? '').toString().trim(),
      dataRecebimento: recebimento.isEmpty ? null : recebimento,
      valorTotal: _comoDouble(json['valor_total']),
      valorRecebido: _comoDouble(json['valor_recebido']),
      numeroNota: nota.isEmpty ? null : nota,
      itens: itensJson is List
          ? itensJson
              .whereType<Map>()
              .map(
                (item) => PedidoCompraRecebimentoItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}

class PedidoCompraRecebimentoItem {
  final int sequencia;
  final int produto;
  final String descricao;
  final double quantidade;
  final double quantidadeRecebida;
  final double quantidadeNaoAtendida;
  final double saldo;
  final String status;

  const PedidoCompraRecebimentoItem({
    required this.sequencia,
    required this.produto,
    required this.descricao,
    required this.quantidade,
    required this.quantidadeRecebida,
    required this.quantidadeNaoAtendida,
    required this.saldo,
    required this.status,
  });

  factory PedidoCompraRecebimentoItem.fromJson(Map<String, dynamic> json) {
    return PedidoCompraRecebimentoItem(
      sequencia: _comoInt(json['sequencia']),
      produto: _comoInt(json['produto']),
      descricao: (json['descricao'] ?? '').toString().trim(),
      quantidade: _comoDouble(json['quantidade']),
      quantidadeRecebida: _comoDouble(json['quantidade_recebida']),
      quantidadeNaoAtendida: _comoDouble(json['quantidade_nao_atendida']),
      saldo: _comoDouble(json['saldo']),
      status: (json['status'] ?? '').toString().trim(),
    );
  }
}

int _comoInt(dynamic valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(valor?.toString() ?? '') ?? 0;
}

double _comoDouble(dynamic valor) {
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor?.toString().replaceAll(',', '.') ?? '') ?? 0;
}
