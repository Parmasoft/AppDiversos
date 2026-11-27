import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/pedido_compra_leitura_etiqueta.dart';

class PedidoCompraRascunhoItem {
  final int item;
  final int produto;
  final PedidoCompraLeituraSessao sessao;

  const PedidoCompraRascunhoItem({
    required this.item,
    required this.produto,
    required this.sessao,
  });
}

class PedidoCompraRecebimentoRascunhoStore {
  static const _nomeBanco = 'pedido_compra_recebimento_rascunhos.db';
  static const _versao = 2;

  final Future<Database> Function() _abrirBanco;

  PedidoCompraRecebimentoRascunhoStore({
    Future<Database> Function()? abrirBanco,
  }) : _abrirBanco = abrirBanco ?? _abrirBancoPadrao;

  static Future<Database> _abrirBancoPadrao() async {
    final diretorio = await getDatabasesPath();
    return abrirBancoNoCaminho(path.join(diretorio, _nomeBanco));
  }

  static Future<Database> abrirBancoNoCaminho(String caminho) {
    return openDatabase(
      caminho,
      version: _versao,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pc_rec_rascunho_pedido (
            empresa INTEGER NOT NULL,
            pedido INTEGER NOT NULL,
            operacao_guid TEXT NOT NULL,
            PRIMARY KEY (empresa, pedido)
          )
        ''');
        await db.execute('''
          CREATE TABLE pc_rec_rascunho_item (
            empresa INTEGER NOT NULL,
            pedido INTEGER NOT NULL,
            item INTEGER NOT NULL,
            produto INTEGER NOT NULL,
            concluido_localmente INTEGER NOT NULL DEFAULT 0,
            atualizado_em TEXT NOT NULL,
            PRIMARY KEY (empresa, pedido, item)
          )
        ''');
        await db.execute('''
          CREATE TABLE pc_rec_rascunho_leitura (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            empresa INTEGER NOT NULL,
            pedido INTEGER NOT NULL,
            item INTEGER NOT NULL,
            produto INTEGER NOT NULL,
            codigo TEXT NOT NULL,
            tipo TEXT NOT NULL,
            quantidade REAL NOT NULL,
            horario TEXT NOT NULL,
            FOREIGN KEY (empresa, pedido, item)
              REFERENCES pc_rec_rascunho_item (empresa, pedido, item)
              ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_pc_rec_rascunho_leitura_item
          ON pc_rec_rascunho_leitura (empresa, pedido, item)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE pc_rec_rascunho_pedido (
              empresa INTEGER NOT NULL,
              pedido INTEGER NOT NULL,
              operacao_guid TEXT NOT NULL,
              PRIMARY KEY (empresa, pedido)
            )
          ''');
        }
      },
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<String> obterOuCriarOperacaoGuid({
    required int empresa,
    required int pedido,
    required String Function() criarGuid,
  }) async {
    final db = await _abrirBanco();
    return db.transaction((txn) async {
      final existente = await txn.query(
        'pc_rec_rascunho_pedido',
        columns: ['operacao_guid'],
        where: 'empresa = ? AND pedido = ?',
        whereArgs: [empresa, pedido],
        limit: 1,
      );
      if (existente.isNotEmpty) {
        return existente.single['operacao_guid'] as String;
      }
      final guid = criarGuid();
      await txn.insert('pc_rec_rascunho_pedido', {
        'empresa': empresa,
        'pedido': pedido,
        'operacao_guid': guid,
      });
      return guid;
    });
  }

  Future<void> salvarSessao({
    required int empresa,
    required int pedido,
    required int item,
    required int produto,
    required PedidoCompraLeituraSessao sessao,
  }) async {
    final db = await _abrirBanco();
    await db.transaction((txn) async {
      await txn.insert('pc_rec_rascunho_item', {
        'empresa': empresa,
        'pedido': pedido,
        'item': item,
        'produto': produto,
        'concluido_localmente': sessao.concluidoLocalmente ? 1 : 0,
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'pc_rec_rascunho_leitura',
        where: 'empresa = ? AND pedido = ? AND item = ?',
        whereArgs: [empresa, pedido, item],
      );
      for (final leitura in sessao.leituras) {
        await txn.insert('pc_rec_rascunho_leitura', {
          'empresa': empresa,
          'pedido': pedido,
          'item': item,
          'produto': produto,
          'codigo': leitura.codigo,
          'tipo': leitura.tipo,
          'quantidade': leitura.quantidade,
          'horario': leitura.horario.toUtc().toIso8601String(),
        });
      }
    });
  }

  Future<Map<int, PedidoCompraRascunhoItem>> carregarPedido({
    required int empresa,
    required int pedido,
  }) async {
    final db = await _abrirBanco();
    final itens = await db.query(
      'pc_rec_rascunho_item',
      where: 'empresa = ? AND pedido = ?',
      whereArgs: [empresa, pedido],
      orderBy: 'item',
    );
    final leituras = await db.query(
      'pc_rec_rascunho_leitura',
      where: 'empresa = ? AND pedido = ?',
      whereArgs: [empresa, pedido],
      orderBy: 'item, id',
    );
    final porItem = <int, List<PedidoCompraLeituraEtiqueta>>{};
    for (final linha in leituras) {
      final item = linha['item'] as int;
      (porItem[item] ??= []).add(
        PedidoCompraLeituraEtiqueta(
          codigo: linha['codigo'] as String,
          tipo: linha['tipo'] as String,
          produto: linha['produto'] as int,
          quantidade: (linha['quantidade'] as num).toDouble(),
          horario: DateTime.parse(linha['horario'] as String).toLocal(),
        ),
      );
    }
    return {
      for (final linha in itens)
        linha['item'] as int: PedidoCompraRascunhoItem(
          item: linha['item'] as int,
          produto: linha['produto'] as int,
          sessao: PedidoCompraLeituraSessao(
            leituras: List.unmodifiable(
              porItem[linha['item'] as int] ?? const [],
            ),
            concluidoLocalmente: (linha['concluido_localmente'] as int) == 1,
          ),
        ),
    };
  }

  Future<void> apagarPedido({required int empresa, required int pedido}) async {
    final db = await _abrirBanco();
    await db.transaction((txn) async {
      await txn.delete(
        'pc_rec_rascunho_leitura',
        where: 'empresa = ? AND pedido = ?',
        whereArgs: [empresa, pedido],
      );
      await txn.delete(
        'pc_rec_rascunho_item',
        where: 'empresa = ? AND pedido = ?',
        whereArgs: [empresa, pedido],
      );
      await txn.delete(
        'pc_rec_rascunho_pedido',
        where: 'empresa = ? AND pedido = ?',
        whereArgs: [empresa, pedido],
      );
    });
  }

  Future<void> fechar() async {
    final db = await _abrirBanco();
    if (!db.isOpen) return;
    await db.close();
  }
}
