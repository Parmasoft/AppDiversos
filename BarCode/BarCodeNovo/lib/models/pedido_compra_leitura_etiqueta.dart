import 'leitura_etiqueta_separacao.dart';

class PedidoCompraLeituraEtiqueta {
  final String codigo;
  final String tipo;
  final int produto;
  final double quantidade;
  final DateTime horario;

  const PedidoCompraLeituraEtiqueta({
    required this.codigo,
    required this.tipo,
    required this.produto,
    required this.quantidade,
    required this.horario,
  });

  factory PedidoCompraLeituraEtiqueta.daLeitura(
    LeituraEtiquetaSeparacao leitura,
  ) {
    final quantidade = leitura.quantidade ?? _quantidadeRolo(leitura);

    return PedidoCompraLeituraEtiqueta(
      codigo: leitura.codigo,
      tipo: leitura.ehRolo ? 'R' : 'C',
      produto: leitura.produto,
      quantidade: quantidade,
      horario: DateTime.now(),
    );
  }
}

class PedidoCompraLeituraSessao {
  final List<PedidoCompraLeituraEtiqueta> leituras;
  final bool concluidoLocalmente;

  const PedidoCompraLeituraSessao({
    required this.leituras,
    this.concluidoLocalmente = false,
  });

  double get quantidadeLida => leituras.fold(
    0,
    (total, leitura) => total + leitura.quantidade,
  );
}

double _quantidadeRolo(LeituraEtiquetaSeparacao leitura) {
  if (!leitura.ehRolo || leitura.codigo.length != 18) return 0;

  final quantidadeInteira = int.tryParse(leitura.codigo.substring(14));
  return (quantidadeInteira ?? 0) / 10;
}
