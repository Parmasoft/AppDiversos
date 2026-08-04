class RequisicaoTransferencia {
  final int empresaMatriz;
  final String nomeMatriz;
  final int id;
  final int empresaSolicitante;
  final String nomeSolicitante;
  final String emissao;
  final String lancamento;
  final int usuario;
  final String status;
  final String tipo;
  final String observacao;
  final int quantidadeItens;
  final double quantidadeTotal;

  const RequisicaoTransferencia({
    required this.empresaMatriz,
    required this.nomeMatriz,
    required this.id,
    required this.empresaSolicitante,
    required this.nomeSolicitante,
    required this.emissao,
    required this.lancamento,
    required this.usuario,
    required this.status,
    required this.tipo,
    required this.observacao,
    required this.quantidadeItens,
    required this.quantidadeTotal,
  });

  String get numeroFormatado => id.toString().padLeft(6, '0');
  bool get ehPendenciaAt => tipo.toUpperCase() == 'AT';

  factory RequisicaoTransferencia.fromJson(Map<String, dynamic> json) {
    return RequisicaoTransferencia(
      empresaMatriz: _comoInt(json['empresa_matriz']),
      nomeMatriz: (json['nome_matriz'] ?? '').toString().trim(),
      id: _comoInt(json['requisicao']),
      empresaSolicitante: _comoInt(json['empresa_solicitante']),
      nomeSolicitante: (json['nome_solicitante'] ?? '').toString().trim(),
      emissao: (json['emissao'] ?? '').toString().trim(),
      lancamento: (json['lancamento'] ?? '').toString().trim(),
      usuario: _comoInt(json['usuario']),
      status: (json['status'] ?? '').toString().trim(),
      tipo: (json['tipo'] ?? 'NR').toString().trim(),
      observacao: (json['observacao'] ?? '').toString().trim(),
      quantidadeItens: _comoInt(json['quantidade_itens']),
      quantidadeTotal: _comoDouble(json['quantidade_total']),
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
