class PedidoCompraRecebimento {
  final int empresa;
  final int pedidoId;
  final String status;
  final String dataEmissao;
  final int fornecedorId;
  final String fornecedorNome;
  final int totalItens;
  final int itensPendentes;
  final double quantidadeTotal;
  final double quantidadeRecebida;
  final double quantidadePendente;
  final String? numeroNota;

  const PedidoCompraRecebimento({
    required this.empresa,
    required this.pedidoId,
    required this.status,
    required this.dataEmissao,
    required this.fornecedorId,
    required this.fornecedorNome,
    required this.totalItens,
    required this.itensPendentes,
    required this.quantidadeTotal,
    required this.quantidadeRecebida,
    required this.quantidadePendente,
    required this.numeroNota,
  });

  String get numeroFormatado => pedidoId.toString().padLeft(6, '0');

  factory PedidoCompraRecebimento.fromJson(Map<String, dynamic> json) {
    final nota = (json['numero_nota'] ?? '').toString().trim();

    return PedidoCompraRecebimento(
      empresa: _comoInt(json['empresa']),
      pedidoId: _comoInt(json['pedido_id']),
      status: (json['status'] ?? '').toString().trim(),
      dataEmissao: (json['data_emissao'] ?? '').toString().trim(),
      fornecedorId: _comoInt(json['fornecedor_id']),
      fornecedorNome: (json['fornecedor_nome'] ?? '').toString().trim(),
      totalItens: _comoInt(json['total_itens']),
      itensPendentes: _comoInt(json['itens_pendentes']),
      quantidadeTotal: _comoDouble(json['quantidade_total']),
      quantidadeRecebida: _comoDouble(json['quantidade_recebida']),
      quantidadePendente: _comoDouble(json['quantidade_pendente']),
      numeroNota: nota.isEmpty ? null : nota,
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
