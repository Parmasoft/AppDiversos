import 'package:busca_ean_novo/models/pedido_compra_leitura_etiqueta.dart';
import 'package:busca_ean_novo/services/pedido_compra_recebimento_rascunho_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('persiste, restaura e apaga rascunho por empresa e pedido', () async {
    final banco = PedidoCompraRecebimentoRascunhoStore.abrirBancoNoCaminho(
      inMemoryDatabasePath,
    );
    final store = PedidoCompraRecebimentoRascunhoStore(abrirBanco: () => banco);
    final sessao = PedidoCompraLeituraSessao(
      concluidoLocalmente: true,
      leituras: [
        PedidoCompraLeituraEtiqueta(
          codigo: 'R00000110028190800',
          tipo: 'R',
          produto: 1002819,
          quantidade: 80,
          horario: DateTime.utc(2026, 9, 16, 15),
        ),
        PedidoCompraLeituraEtiqueta(
          codigo: 'C00000110028190080000',
          tipo: 'C',
          produto: 1002819,
          quantidade: 720,
          horario: DateTime.utc(2026, 9, 16, 15, 1),
        ),
      ],
    );

    await store.salvarSessao(
      empresa: 10,
      pedido: 909,
      item: 2,
      produto: 1002819,
      sessao: sessao,
    );

    final restaurado = await store.carregarPedido(empresa: 10, pedido: 909);
    expect(restaurado[2]?.produto, 1002819);
    expect(restaurado[2]?.sessao.concluidoLocalmente, isTrue);
    expect(restaurado[2]?.sessao.quantidadeLida, 800);
    expect(restaurado[2]?.sessao.leituras.map((leitura) => leitura.tipo), [
      'R',
      'C',
    ]);

    await store.apagarPedido(empresa: 10, pedido: 909);
    expect(await store.carregarPedido(empresa: 10, pedido: 909), isEmpty);
    await store.fechar();
  });

  test('mantem o mesmo operacao_guid ate apagar o rascunho', () async {
    final banco = PedidoCompraRecebimentoRascunhoStore.abrirBancoNoCaminho(
      inMemoryDatabasePath,
    );
    final store = PedidoCompraRecebimentoRascunhoStore(abrirBanco: () => banco);
    var geracoes = 0;

    final primeiro = await store.obterOuCriarOperacaoGuid(
      empresa: 10,
      pedido: 907,
      criarGuid: () => '11111111-1111-4111-8111-111111111111-${geracoes++}',
    );
    final segundo = await store.obterOuCriarOperacaoGuid(
      empresa: 10,
      pedido: 907,
      criarGuid: () => '22222222-2222-4222-8222-222222222222-${geracoes++}',
    );

    expect(segundo, primeiro);
    expect(geracoes, 1);
    await store.apagarPedido(empresa: 10, pedido: 907);
    final aposApagar = await store.obterOuCriarOperacaoGuid(
      empresa: 10,
      pedido: 907,
      criarGuid: () => '33333333-3333-4333-8333-333333333333-${geracoes++}',
    );
    expect(aposApagar, isNot(primeiro));
    expect(geracoes, 2);
    await store.fechar();
  });

  test('migra rascunho v1 sem perder leituras e passa a guardar o guid', () async {
    final diretorio = await Directory.systemTemp.createTemp('pc_rascunho_');
    final caminho = path.join(diretorio.path, 'rascunhos.db');
    final antigo = await openDatabase(
      caminho,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pc_rec_rascunho_item (
            empresa INTEGER NOT NULL, pedido INTEGER NOT NULL,
            item INTEGER NOT NULL, produto INTEGER NOT NULL,
            concluido_localmente INTEGER NOT NULL DEFAULT 0,
            atualizado_em TEXT NOT NULL,
            PRIMARY KEY (empresa, pedido, item)
          )
        ''');
        await db.execute('''
          CREATE TABLE pc_rec_rascunho_leitura (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            empresa INTEGER NOT NULL, pedido INTEGER NOT NULL,
            item INTEGER NOT NULL, produto INTEGER NOT NULL,
            codigo TEXT NOT NULL, tipo TEXT NOT NULL,
            quantidade REAL NOT NULL, horario TEXT NOT NULL
          )
        ''');
      },
    );
    await antigo.insert('pc_rec_rascunho_item', {
      'empresa': 10, 'pedido': 907, 'item': 1, 'produto': 8899,
      'concluido_localmente': 1, 'atualizado_em': '2026-09-16T19:00:00Z',
    });
    await antigo.insert('pc_rec_rascunho_leitura', {
      'empresa': 10, 'pedido': 907, 'item': 1, 'produto': 8899,
      'codigo': 'R_TESTE', 'tipo': 'R', 'quantidade': 2000.0,
      'horario': '2026-09-16T19:00:00Z',
    });
    await antigo.close();

    final store = PedidoCompraRecebimentoRascunhoStore(
      abrirBanco: () => PedidoCompraRecebimentoRascunhoStore.abrirBancoNoCaminho(caminho),
    );
    final restaurado = await store.carregarPedido(empresa: 10, pedido: 907);
    final guid = await store.obterOuCriarOperacaoGuid(
      empresa: 10,
      pedido: 907,
      criarGuid: () => '44444444-4444-4444-8444-444444444444',
    );

    expect(restaurado[1]?.sessao.quantidadeLida, 2000);
    expect(restaurado[1]?.sessao.concluidoLocalmente, isTrue);
    expect(guid, '44444444-4444-4444-8444-444444444444');
    await store.fechar();
    await diretorio.delete(recursive: true);
  });
}
import 'dart:io';

import 'package:path/path.dart' as path;
