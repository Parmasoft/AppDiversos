class RequisicaoTransferenciaLeitura {
  final int empresaMatriz;
  final int requisicao;
  final int sequencia;
  final int itemRequisicao;
  final int produto;
  final String codigoLido;
  final String tipoEtiqueta;
  final int? roloId;
  final double quantidade;
  final String dataLeitura;

  const RequisicaoTransferenciaLeitura({
    required this.empresaMatriz,
    required this.requisicao,
    required this.sequencia,
    required this.itemRequisicao,
    required this.produto,
    required this.codigoLido,
    required this.tipoEtiqueta,
    required this.roloId,
    required this.quantidade,
    required this.dataLeitura,
  });

  bool get ehRolo => tipoEtiqueta == 'R';

  String get descricaoTipo => ehRolo ? 'Etiqueta R' : 'Etiqueta C';

  factory RequisicaoTransferenciaLeitura.fromJson(Map<String, dynamic> json) {
    final rolo = json['rolo_id'];

    return RequisicaoTransferenciaLeitura(
      empresaMatriz: _comoInt(json['empresa_matriz']),
      requisicao: _comoInt(json['requisicao']),
      sequencia: _comoInt(json['sequencia']),
      itemRequisicao: _comoInt(json['item_requisicao']),
      produto: _comoInt(json['produto']),
      codigoLido: (json['codigo_lido'] ?? '').toString().trim(),
      tipoEtiqueta: (json['tipo_etiqueta'] ?? '').toString().trim(),
      roloId: rolo == null ? null : _comoInt(rolo),
      quantidade: _comoDouble(json['quantidade']),
      dataLeitura: (json['data_leitura'] ?? '').toString().trim(),
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
