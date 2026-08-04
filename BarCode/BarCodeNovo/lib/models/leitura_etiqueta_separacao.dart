enum TipoEtiquetaSeparacao { rolo, conferencia }

class LeituraEtiquetaSeparacao {
  final String codigo;
  final TipoEtiquetaSeparacao tipo;
  final int referencia;
  final int produto;
  final String quantidadeCodificada;
  final double? quantidade;

  const LeituraEtiquetaSeparacao({
    required this.codigo,
    required this.tipo,
    required this.referencia,
    required this.produto,
    required this.quantidadeCodificada,
    required this.quantidade,
  });

  bool get ehRolo => tipo == TipoEtiquetaSeparacao.rolo;

  String get descricaoTipo => ehRolo ? 'Etiqueta R' : 'Etiqueta C';

  static LeituraEtiquetaSeparacao? identificar(String valor) {
    final codigo = valor.trim().toUpperCase();

    if (RegExp(r'^R\d{17}$').hasMatch(codigo)) {
      return LeituraEtiquetaSeparacao(
        codigo: codigo,
        tipo: TipoEtiquetaSeparacao.rolo,
        referencia: int.tryParse(codigo.substring(1, 7)) ?? 0,
        produto: int.tryParse(codigo.substring(7, 14)) ?? 0,
        quantidadeCodificada: codigo.substring(14, 18),
        quantidade: null,
      );
    }

    if (RegExp(r'^C(\d{18}|\d{20})$').hasMatch(codigo)) {
      final quantidadeCodificada = codigo.substring(14);
      final quantidadeInteira = int.tryParse(quantidadeCodificada) ?? 0;
      final divisor = codigo.length == 19 ? 100.0 : 10000.0;

      return LeituraEtiquetaSeparacao(
        codigo: codigo,
        tipo: TipoEtiquetaSeparacao.conferencia,
        referencia: int.tryParse(codigo.substring(1, 7)) ?? 0,
        produto: int.tryParse(codigo.substring(7, 14)) ?? 0,
        quantidadeCodificada: quantidadeCodificada,
        quantidade: quantidadeInteira / divisor,
      );
    }

    return null;
  }
}
