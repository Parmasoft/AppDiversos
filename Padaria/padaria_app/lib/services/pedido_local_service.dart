import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:padaria_app/services/api_service.dart';
import 'package:padaria_app/services/numeracao_pedido_service.dart';
import 'package:padaria_app/services/recheio_service.dart';
import 'database_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

class PedidoLocalService {
  Future<Database> get _db async => DatabaseProvider.instance.database;

  // ==================================================
  // LISTAGENS
  // ==================================================
  Future<List<Map<String, dynamic>>> listarPedidosPendentes() async {
    final db = await _db;
    return db.query('pedido', orderBy: 'id DESC');
  }

  Future<double> buscarPrecoRecheioPorDescricao(String descricao) async {
    if (descricao.trim().isEmpty) return 0.0;

    final db = await _db;

    final res = await db.query(
      'tb_recheio',
      columns: ['id'], // id = REC_ID
      where: 'descricao = ? AND ativo = 1',
      whereArgs: [descricao],
      limit: 1,
    );

    if (res.isEmpty) return 0.0;

    // 🔥 preço vem do Firebird via API, então precisamos buscar lá
    final lista = await RecheioService.buscar(descricao);
    if (lista.isEmpty) return 0.0;

    return (lista.first['preco_kg'] as num).toDouble();
  }

  Future<void> salvarPedido({
    required Map<String, dynamic> cabecalho,
    required List<Map<String, dynamic>> itens,
  }) async {
    final db = await _db;

    await db.transaction((txn) async {
      // 🔑 1️⃣ GERA O NÚMERO DO PEDIDO
      final numeroPedido = await NumeracaoPedidoService.proximoNumero();

      // 2️⃣ INSERE O PEDIDO JÁ NUMERADO
      final pedidoId = await txn.insert('pedido', {
        ...cabecalho,
        'numero_pedido': numeroPedido, // ✅ ESSENCIAL
        'status': 'PENDENTE', // ou ENVIAR, conforme seu fluxo
      });

      // 3️⃣ INSERE OS ITENS
      for (final item in itens) {
        await txn.insert('pedido_item', {
          'pedido_id': pedidoId,
          'item_tipo': item['item_tipo'],
          'descricao1': item['descricao1'],
          'descricao2': item['descricao2'],
          'descricao3': item['descricao3'],
          'unidade': item['unidade'],
          'quantidade': item['quantidade'],
          'preco_unitario': item['preco_unitario'],
          'subtotal': item['subtotal'],
          'rec_id': item['rec_id'],
          'observacao': item['observacao'],
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> listarItensDoPedido(int pedidoId) async {
    final db = await _db;
    return db.query(
      'pedido_item',
      where: 'pedido_id = ?',
      whereArgs: [pedidoId],
    );
  }

  // ==================================================
  // RECHEIOS (SQLITE)
  // ==================================================
  Future<List<String>> listarRecheios() async {
    final db = await _db;

    final result = await db.query(
      'tb_recheio', // ⚠️ ajuste o nome exato da tabela
      where: 'ativo = ?',
      whereArgs: [1],
      orderBy: 'descricao',
    );

    return result.map((e) => e['descricao'].toString()).toList();
  }

  // ==================================================
  // SINCRONIZAR RECHEIOS (API → SQLITE)
  // ==================================================
  Future<void> sincronizarRecheios() async {
    final db = await _db;

    // 🔹 Busca na API
    final uri = Uri.parse('${ApiService.baseUrl}/recheios/sync');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Erro ao sincronizar recheios');
    }

    final List dados = json.decode(response.body);

    // 🔹 Limpa tabela local (controle total)
    await db.delete('tb_recheio');

    // 🔹 Insere novamente
    for (final r in dados) {
      await db.insert('tb_recheio', {
        'id': r['id'],
        'descricao': r['descricao'],
        'ativo': r['ativo'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ==================================================
  // 🔎 DEBUG SQLITE (TEMPORÁRIO – NÃO ALTERA LÓGICA)
  // ==================================================

  Future<void> debugMostrarItem(int itemId) async {
    final db = await _db;

    final result = await db.rawQuery(
      '''
      SELECT
        id,
        pedido_id,
        quantidade,
        preco_unitario,
        subtotal
      FROM pedido_item
      WHERE id = ?
      ''',
      [itemId],
    );

    debugPrint('🟡 DEBUG SQLITE ITEM [$itemId]: $result');
  }

  Future<void> debugMostrarItensDoPedido(int pedidoId) async {
    final db = await _db;

    final result = await db.rawQuery(
      '''
      SELECT
        id,
        quantidade,
        preco_unitario,
        subtotal
      FROM pedido_item
      WHERE pedido_id = ?
      ''',
      [pedidoId],
    );

    debugPrint('🟡 DEBUG SQLITE ITENS DO PEDIDO [$pedidoId]: $result');
  }

  Future<void> debugMostrarTotalPedido(int pedidoId) async {
    final db = await _db;

    final result = await db.rawQuery(
      '''
      SELECT
        id,
        total
      FROM pedido
      WHERE id = ?
      ''',
      [pedidoId],
    );

    debugPrint('🟡 DEBUG SQLITE TOTAL PEDIDO [$pedidoId]: $result');
  }

  // ==================================================
  // STATUS DO PEDIDO
  // ==================================================
  Future<void> atualizarStatusPedido(int pedidoId, String status) async {
    final db = await _db;
    await db.update(
      'pedido',
      {'status': status},
      where: 'id = ?',
      whereArgs: [pedidoId],
    );
  }

  // ==================================================
  // BOLO – ATUALIZA ITEM
  // ==================================================
  Future<void> atualizarItemBoloQuantidade({
    required int itemId,
    required double novaQuantidade,
    required double novoSubtotal,
    String? descricao2,
    String? descricao3,
  }) async {
    final db = await _db;

    await db.update(
      'pedido_item',
      {
        'quantidade': novaQuantidade,
        'subtotal': novoSubtotal,
        'descricao2': descricao2,
        'descricao3': descricao3,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );

    // 🔎 DEBUG TEMPORÁRIO
    await debugMostrarItem(itemId);
  }

  // ==================================================
  // RECALCULA TOTAL
  // ==================================================
  Future<void> recalcularTotalPedido(int pedidoId) async {
    final db = await _db;

    final result = await db.rawQuery(
      'SELECT SUM(subtotal) as total FROM pedido_item WHERE pedido_id = ?',
      [pedidoId],
    );

    final total = (result.first['total'] as num?)?.toDouble() ?? 0.0;

    await db.update(
      'pedido',
      {'total': total},
      where: 'id = ?',
      whereArgs: [pedidoId],
    );
  }

  // ==================================================
  // 🖨️ IMPRESSÃO TÉRMICA 79mm (API FLASK)
  // ==================================================
  static Future<bool> imprimirTermico79mm({
    required Map<String, dynamic> cabecalho,
    required List<Map<String, dynamic>> itens,
  }) async {
    final payload = {'cabecalho': cabecalho, 'itens': itens};

    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/imprimir/termico'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    return response.statusCode == 200;
  }
}
