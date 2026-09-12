import '../models/requisicao_transferencia_item.dart';

bool itemSeparacaoTransferenciaConcluido(RequisicaoTransferenciaItem item) =>
    item.atendimentoTotal;

List<RequisicaoTransferenciaItem> ordenarItensSeparacaoTransferencia(
  Iterable<RequisicaoTransferenciaItem> itens,
) {
  final ordenados = itens
      .mapIndexed((indice, item) => _ItemOrdenado(indice, item))
      .toList(growable: false);

  ordenados.sort((a, b) {
    final aConcluido = itemSeparacaoTransferenciaConcluido(a.item);
    final bConcluido = itemSeparacaoTransferenciaConcluido(b.item);

    if (aConcluido != bConcluido) {
      return aConcluido ? 1 : -1;
    }

    final sequencia = a.item.sequencia.compareTo(b.item.sequencia);
    if (sequencia != 0) return sequencia;

    return a.indice.compareTo(b.indice);
  });

  return ordenados.map((ordenado) => ordenado.item).toList(growable: false);
}

class _ItemOrdenado {
  final int indice;
  final RequisicaoTransferenciaItem item;

  const _ItemOrdenado(this.indice, this.item);
}

extension _IterableMapIndexed<T> on Iterable<T> {
  Iterable<R> mapIndexed<R>(R Function(int index, T item) converter) sync* {
    var index = 0;
    for (final item in this) {
      yield converter(index, item);
      index++;
    }
  }
}
