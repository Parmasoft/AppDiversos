double calcularSubtotalBolo({
  required double quantidade,
  required double precoBase,
  required double precoRecheio1,
  required double precoRecheio2,
}) {
  final precoFinal = [
    precoBase,
    precoRecheio1,
    precoRecheio2,
  ].reduce((a, b) => a > b ? a : b);

  final subtotal = quantidade * precoFinal;

  return double.parse(subtotal.toStringAsFixed(2));
}
