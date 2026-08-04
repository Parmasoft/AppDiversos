class RequisicaoTransferenciaItem {
  final int empresaMatriz;
  final int requisicao;
  final int sequencia;
  final int produto;
  final String descricao;
  final String unidade;
  final double quantidadeSolicitada;
  final double quantidadeSeparada;
  final double quantidadeConferida;
  final double quantidadeRecebida;
  final double quantidadeFaltante;
  final double quantidadeExcedente;
  final String situacaoAtendimento;
  final String status;
  final String observacao;

  const RequisicaoTransferenciaItem({
    required this.empresaMatriz,
    required this.requisicao,
    required this.sequencia,
    required this.produto,
    required this.descricao,
    required this.unidade,
    required this.quantidadeSolicitada,
    required this.quantidadeSeparada,
    required this.quantidadeConferida,
    required this.quantidadeRecebida,
    required this.quantidadeFaltante,
    required this.quantidadeExcedente,
    required this.situacaoAtendimento,
    required this.status,
    required this.observacao,
  });

  factory RequisicaoTransferenciaItem.fromJson(Map<String, dynamic> json) {
    final quantidadeSolicitada = _comoDouble(json['quantidade_solicitada']);
    final quantidadeSeparada = _comoDouble(json['quantidade_separada']);
    final quantidadeFaltante = _comoDouble(
      json['quantidade_faltante'] ?? json['quantidade_restante'],
    );
    final quantidadeExcedente = _comoDouble(json['quantidade_excedente']);

    return RequisicaoTransferenciaItem(
      empresaMatriz: _comoInt(json['empresa_matriz']),
      requisicao: _comoInt(json['requisicao']),
      sequencia: _comoInt(json['sequencia']),
      produto: _comoInt(json['produto']),
      descricao: (json['descricao'] ?? '').toString().trim(),
      unidade: (json['unidade'] ?? '').toString().trim(),
      quantidadeSolicitada: quantidadeSolicitada,
      quantidadeSeparada: quantidadeSeparada,
      quantidadeConferida: _comoDouble(json['quantidade_conferida']),
      quantidadeRecebida: _comoDouble(json['quantidade_recebida']),
      quantidadeFaltante: quantidadeFaltante,
      quantidadeExcedente: quantidadeExcedente,
      situacaoAtendimento:
          (json['situacao_atendimento'] ??
                  _situacaoAtendimento(quantidadeSolicitada, quantidadeSeparada))
              .toString()
              .trim(),
      status: (json['status'] ?? '').toString().trim(),
      observacao: (json['observacao'] ?? '').toString().trim(),
    );
  }

  bool get atendimentoTotal => situacaoAtendimento == 'TOTAL';
  bool get atendimentoParcial => situacaoAtendimento == 'PARCIAL';
  bool get naoAtendido => situacaoAtendimento == 'NAO_ATENDIDO';
  bool get atendimentoExcedente => situacaoAtendimento == 'EXCEDENTE';

  String get rotuloAtendimento {
    if (atendimentoExcedente) return 'EXCEDENTE';
    if (atendimentoParcial) return 'PARCIAL';
    if (naoAtendido) return 'NAO ATENDIDO';
    return 'TOTAL';
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

String _situacaoAtendimento(double solicitada, double separada) {
  final solicitada4 = _quantidade4(solicitada);
  final separada4 = _quantidade4(separada);

  if (separada4 > solicitada4) return 'EXCEDENTE';
  if (separada4 == solicitada4) return 'TOTAL';
  if (separada4 > 0) return 'PARCIAL';
  return 'NAO_ATENDIDO';
}

int _quantidade4(double valor) => (valor * 10000).round();
