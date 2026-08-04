import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseProvider {
  DatabaseProvider._internal();
  static final DatabaseProvider instance = DatabaseProvider._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'padaria.db');

    print('🚨 SQLITE PATH => $path');

    return await openDatabase(
      path,
      version: 2, // 🔴 IMPORTANTE: subimos a versão
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ==================================================
  // CRIAÇÃO INICIAL DO BANCO
  // ==================================================
  Future<void> _onCreate(Database db, int version) async {
    // =========================
    // TABELA PEDIDO
    // =========================
    await db.execute('''
      CREATE TABLE pedido (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_pedido INTEGER NOT NULL,
        cliente TEXT,
        contato TEXT,
        forma_pagamento TEXT,
        data_entrega TEXT,
        hora_entrega TEXT,
        observacoes TEXT,
        foto_bolo_local TEXT,
        total REAL,
        status TEXT NOT NULL
      )
    ''');

    // =========================
    // TABELA ITENS DO PEDIDO
    // =========================
    await db.execute('''
      CREATE TABLE pedido_item (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pedido_id INTEGER,
        item_tipo TEXT,
        descricao1 TEXT,
        descricao2 TEXT,
        descricao3 TEXT,
        unidade TEXT,
        quantidade REAL,
        preco_unitario REAL,
        subtotal REAL,
        rec_id INTEGER,
        observacao TEXT
      )
    ''');

    // =========================
    // TABELA RECHEIOS (LOCAL)
    // =========================
    await db.execute('''
      CREATE TABLE tb_recheio (
        id INTEGER PRIMARY KEY, -- REC_ID do Firebird
        descricao TEXT NOT NULL,
        ativo INTEGER NOT NULL
      )
    ''');
  }

  // ==================================================
  // ATUALIZAÇÕES DE VERSÃO
  // ==================================================
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE tb_recheio (
          id INTEGER PRIMARY KEY,
          descricao TEXT NOT NULL,
          ativo INTEGER NOT NULL
        )
      ''');
    }
  }
}
