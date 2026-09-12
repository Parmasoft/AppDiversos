import 'package:busca_ean_novo/models/requisicao_transferencia_item.dart';
import 'package:busca_ean_novo/utils/requisicao_transferencia_separacao_ordenacao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ordenarItensSeparacaoTransferencia', () {
    test('move o item 1 concluido para depois dos pendentes', () {
      final itens = [
        _item(sequencia: 1, situacao: 'TOTAL'),
        _item(sequencia: 2, situacao: 'NAO_ATENDIDO'),
        _item(sequencia: 3, situacao: 'NAO_ATENDIDO'),
      ];

      final ordenados = ordenarItensSeparacaoTransferencia(itens);

      expect(_sequencias(ordenados), [2, 3, 1]);
    });

    test('mantem item 2 pendente acima quando o item 3 conclui antes dele', () {
      final itens = [
        _item(sequencia: 1, situacao: 'TOTAL'),
        _item(sequencia: 2, situacao: 'NAO_ATENDIDO'),
        _item(sequencia: 3, situacao: 'TOTAL'),
      ];

      final ordenados = ordenarItensSeparacaoTransferencia(itens);

      expect(_sequencias(ordenados), [2, 1, 3]);
    });

    test('mantem item parcialmente separado entre os pendentes', () {
      final itens = [
        _item(sequencia: 1, situacao: 'TOTAL'),
        _item(sequencia: 2, situacao: 'PARCIAL'),
        _item(sequencia: 3, situacao: 'NAO_ATENDIDO'),
      ];

      final ordenados = ordenarItensSeparacaoTransferencia(itens);

      expect(_sequencias(ordenados), [2, 3, 1]);
    });

    test('ordena novamente a lista recebida ao reabrir a tela', () {
      final itens = [
        _item(sequencia: 1, situacao: 'TOTAL'),
        _item(sequencia: 3, situacao: 'PARCIAL'),
        _item(sequencia: 2, situacao: 'NAO_ATENDIDO'),
      ];

      final ordenados = ordenarItensSeparacaoTransferencia(itens);

      expect(_sequencias(ordenados), [2, 3, 1]);
    });

    test('nao altera a lista de origem quando a confirmacao falha', () {
      final itens = [
        _item(sequencia: 1, situacao: 'TOTAL'),
        _item(sequencia: 2, situacao: 'NAO_ATENDIDO'),
      ];

      final ordenados = ordenarItensSeparacaoTransferencia(itens);

      expect(_sequencias(ordenados), [2, 1]);
      expect(_sequencias(itens), [1, 2]);
    });
  });
}

RequisicaoTransferenciaItem _item({
  required int sequencia,
  required String situacao,
}) {
  final solicitada = 10.0;
  final separada = switch (situacao) {
    'TOTAL' => 10.0,
    'PARCIAL' => 5.0,
    'EXCEDENTE' => 12.0,
    _ => 0.0,
  };

  return RequisicaoTransferenciaItem(
    empresaMatriz: 1,
    requisicao: 9,
    sequencia: sequencia,
    produto: 1000 + sequencia,
    descricao: 'Produto $sequencia',
    unidade: 'UN',
    quantidadeSolicitada: solicitada,
    quantidadeSeparada: separada,
    quantidadeConferida: 0,
    quantidadeRecebida: 0,
    quantidadeFaltante: separada >= solicitada ? 0 : solicitada - separada,
    quantidadeExcedente: separada > solicitada ? separada - solicitada : 0,
    situacaoAtendimento: situacao,
    status: 'A',
    observacao: '',
  );
}

List<int> _sequencias(List<RequisicaoTransferenciaItem> itens) =>
    itens.map((item) => item.sequencia).toList(growable: false);
