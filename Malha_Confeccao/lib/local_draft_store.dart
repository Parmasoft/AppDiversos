import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

const localDraftStatus = 'RASCUNHO_LOCAL';
const localPendingSendStatus = 'PENDENTE_ENVIO';
const localSendingStatus = 'ENVIANDO';
const localReceivedStatus = 'RECEBIDO_EMPRESA';
const localSendErrorStatus = 'ERRO_ENVIO';
const provisionalClientStatus = 'PENDENTE_ENVIO';
const provisionalClientIdPrefix = 'local-client:';

class LocalDraftLine {
  const LocalDraftLine({
    required this.productId,
    required this.description,
    required this.unit,
    required this.quantity,
    this.unitPrice,
  });
  final String productId;
  final String description;
  final String unit;
  final double quantity;
  final String? unitPrice;
}

class LocalOrderDraft {
  const LocalOrderDraft({
    required this.localId,
    required this.companyId,
    required this.sellerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.lines,
    this.clientId,
    this.clientName,
    this.paymentMethodId,
    this.paymentMethodName,
    this.notes,
    this.deliveryDays,
    this.isManagerial,
    this.deliveryDate,
    this.receivedOrderId,
    this.remoteOrderId,
    this.sendError,
  });
  final String localId;
  final int companyId;
  final int sellerId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<LocalDraftLine> lines;
  final String? clientId;
  final String? clientName;
  final String? paymentMethodId;
  final String? paymentMethodName;
  final String? notes;
  final int? deliveryDays;
  final bool? isManagerial;
  final DateTime? deliveryDate;
  final int? receivedOrderId;
  final String? remoteOrderId;
  final String? sendError;
}

class LocalProvisionalClient {
  const LocalProvisionalClient({
    required this.localId,
    required this.companyId,
    required this.sellerId,
    required this.personType,
    required this.name,
    required this.document,
    required this.phone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.fantasyName,
    this.stateRegistration,
    this.email,
    this.whatsapp,
    this.zipCode,
    this.street,
    this.number,
    this.complement,
    this.neighborhood,
    this.city,
    this.state,
    this.officialClientId,
  });

  final String localId;
  final int companyId;
  final int sellerId;
  final String personType;
  final String name;
  final String document;
  final String phone;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? fantasyName;
  final String? stateRegistration;
  final String? email;
  final String? whatsapp;
  final String? zipCode;
  final String? street;
  final String? number;
  final String? complement;
  final String? neighborhood;
  final String? city;
  final String? state;
  final String? officialClientId;

  String get orderClientId => '$provisionalClientIdPrefix$localId';
}

abstract interface class LocalDraftStore {
  Future<LocalOrderDraft?> loadById({
    required String localId,
    required int companyId,
    required int sellerId,
  });
  Future<List<LocalOrderDraft>> listDrafts({
    required int companyId,
    required int sellerId,
  });
  Future<LocalOrderDraft> save(LocalOrderDraft draft);
  Future<LocalOrderDraft> updateSendState({
    required LocalOrderDraft draft,
    required String status,
    int? receivedOrderId,
    String? remoteOrderId,
    String? sendError,
  });
  Future<List<LocalProvisionalClient>> listProvisionalClients({
    required int companyId,
    required int sellerId,
  });
  Future<LocalProvisionalClient> saveProvisionalClient(
    LocalProvisionalClient client,
  );
}

class SqliteLocalDraftStore implements LocalDraftStore {
  SqliteLocalDraftStore({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _databasePath = databasePath;

  static const _databaseName = 'parma_gestor_malhas.sqlite';
  static const _schemaVersion = 7;
  static const _draftTable = 'local_order_draft';
  static const _lineTable = 'local_order_draft_line';
  static const _legacyDraftTable = 'local_order_draft_v1_backup';
  static const _legacyLineTable = 'local_order_draft_line_v1_backup';
  static const _provisionalClientTable = 'local_provisional_client';

  final DatabaseFactory _factory;
  final String? _databasePath;
  Database? _database;
  Future<Database>? _opening;

  Future<Database> get _db =>
      _database != null ? Future.value(_database) : _opening ??= _open();

  Future<Database> _open() async {
    try {
      final databasePath =
          _databasePath ?? path.join(await getDatabasesPath(), _databaseName);
      final database = await _factory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: _schemaVersion,
          onConfigure: (database) =>
              database.execute('PRAGMA foreign_keys = ON'),
          onCreate: (database, _) async {
            await _createOrderSchema(database);
            await _createProvisionalClientSchema(database);
          },
          onUpgrade: (database, oldVersion, _) async {
            if (oldVersion < 2) await _migrateV1ToV2(database);
            if (oldVersion < 3) await _createProvisionalClientSchema(database);
            if (oldVersion >= 2 && oldVersion < 4) {
              await _migrateV3ToV4(database);
            }
            if (oldVersion < 5) await _migrateV4ToV5(database);
            if (oldVersion == 5)
              await database.execute(
                'ALTER TABLE $_draftTable ADD remote_order_id TEXT',
              );
            // Bancos v1/v2 recebem a tabela provisoria ja no esquema atual
            // durante a criacao da versao 3; somente v3 a v6 precisam de DDL.
            if (oldVersion >= 3 && oldVersion < 7)
              await _migrateV6ToV7(database);
          },
        ),
      );
      _database = database;
      return database;
    } finally {
      _opening = null;
    }
  }

  Future<void> _createOrderSchema(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE $_draftTable (
        local_id TEXT PRIMARY KEY NOT NULL,
        company_id INTEGER NOT NULL,
        seller_id INTEGER NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('$localDraftStatus', '$localPendingSendStatus', '$localSendingStatus', '$localReceivedStatus', '$localSendErrorStatus')),
        client_id TEXT,
        client_name TEXT,
        payment_method_id TEXT,
        payment_method_name TEXT,
        notes TEXT,
        delivery_days INTEGER,
        managerial INTEGER,
        delivery_date TEXT,
        received_order_id INTEGER,
        remote_order_id TEXT,
        send_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE $_lineTable (
        local_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        description TEXT NOT NULL,
        unit TEXT NOT NULL,
        quantity REAL NOT NULL CHECK (quantity > 0),
        unit_price TEXT,
        PRIMARY KEY (local_id, product_id),
        FOREIGN KEY (local_id) REFERENCES $_draftTable(local_id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE INDEX local_order_draft_owner_updated_idx
      ON $_draftTable (company_id, seller_id, updated_at DESC)
    ''');
  }

  Future<void> _migrateV3ToV4(Database database) async {
    await database.execute(
      'ALTER TABLE $_draftTable ADD delivery_days INTEGER',
    );
    await database.execute('ALTER TABLE $_draftTable ADD managerial INTEGER');
    await database.execute('ALTER TABLE $_lineTable ADD unit_price TEXT');
  }

  Future<void> _migrateV4ToV5(Database database) async {
    // SQLite nao permite alterar um CHECK. Reconstruimos as duas tabelas na
    // mesma transacao de upgrade, preservando cada linha e seu local_id.
    const oldDraft = 'local_order_draft_v4_backup';
    const oldLine = 'local_order_draft_line_v4_backup';
    await database.execute(
      'DROP INDEX IF EXISTS local_order_draft_owner_updated_idx',
    );
    await database.execute('ALTER TABLE $_lineTable RENAME TO $oldLine');
    await database.execute('ALTER TABLE $_draftTable RENAME TO $oldDraft');
    await _createOrderSchema(database);
    await database.execute('''
      INSERT INTO $_draftTable (
        local_id, company_id, seller_id, status, client_id, client_name,
        payment_method_id, payment_method_name, notes, delivery_days,
        managerial, delivery_date, received_order_id, send_error, created_at, updated_at
      )
      SELECT local_id, company_id, seller_id, status, client_id, client_name,
        payment_method_id, payment_method_name, notes, delivery_days,
        managerial, NULL, NULL, NULL, created_at, updated_at
      FROM $oldDraft
    ''');
    await database.execute('''
      INSERT INTO $_lineTable (local_id, product_id, description, unit, quantity, unit_price)
      SELECT local_id, product_id, description, unit, quantity, unit_price FROM $oldLine
    ''');
    final copied = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM $_draftTable'),
    );
    final original = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM $oldDraft'),
    );
    if (copied != original)
      throw StateError('Falha ao preservar pedidos na migracao local.');
    await database.execute('DROP TABLE $oldLine');
    await database.execute('DROP TABLE $oldDraft');
  }

  Future<void> _createProvisionalClientSchema(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE $_provisionalClientTable (
        local_id TEXT PRIMARY KEY NOT NULL,
        company_id INTEGER NOT NULL,
        seller_id INTEGER NOT NULL,
        person_type TEXT NOT NULL CHECK (person_type IN ('PF', 'PJ')),
        name TEXT NOT NULL,
        document TEXT NOT NULL,
        phone TEXT NOT NULL,
        fantasy_name TEXT,
        state_registration TEXT,
        email TEXT,
        whatsapp TEXT,
        zip_code TEXT,
        street TEXT,
        number TEXT,
        complement TEXT,
        neighborhood TEXT,
        city TEXT,
        state TEXT,
        status TEXT NOT NULL CHECK (status = '$provisionalClientStatus'),
        official_client_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (company_id, seller_id, document)
      )
    ''');
    await database.execute('''
      CREATE INDEX local_provisional_client_owner_updated_idx
      ON $_provisionalClientTable (company_id, seller_id, updated_at DESC)
    ''');
  }

  Future<void> _migrateV6ToV7(Database database) async {
    for (final column in const [
      'state_registration TEXT', 'email TEXT', 'whatsapp TEXT',
      'zip_code TEXT', 'street TEXT', 'number TEXT', 'complement TEXT',
      'neighborhood TEXT', 'city TEXT', 'state TEXT',
    ]) {
      await database.execute('ALTER TABLE $_provisionalClientTable ADD $column');
    }
  }

  Future<void> _migrateV1ToV2(Database database) async {
    await database.transaction((transaction) async {
      await transaction.execute(
        'ALTER TABLE $_lineTable RENAME TO $_legacyLineTable',
      );
      await transaction.execute(
        'ALTER TABLE $_draftTable RENAME TO $_legacyDraftTable',
      );
      await _createOrderSchema(transaction);
      await transaction.execute('''
        INSERT INTO $_draftTable (
          local_id, company_id, seller_id, status, client_id, client_name,
          payment_method_id, payment_method_name, notes, created_at, updated_at
        ) SELECT local_id, company_id, seller_id, status, client_id, client_name,
          payment_method_id, payment_method_name, notes, created_at, updated_at
        FROM $_legacyDraftTable
      ''');
      await transaction.execute('''
        INSERT INTO $_lineTable (local_id, product_id, description, unit, quantity)
        SELECT local_id, product_id, description, unit, quantity FROM $_legacyLineTable
      ''');
      await transaction.execute('DROP TABLE $_legacyLineTable');
      await transaction.execute('DROP TABLE $_legacyDraftTable');
    });
  }

  Future<void> close() async {
    final pending = _opening;
    if (pending != null) await pending;
    final database = _database;
    _database = null;
    if (database != null && database.isOpen) await database.close();
  }

  @override
  Future<LocalOrderDraft?> loadById({
    required String localId,
    required int companyId,
    required int sellerId,
  }) async {
    final database = await _db;
    final headers = await database.query(
      _draftTable,
      where: 'local_id = ? AND company_id = ? AND seller_id = ?',
      whereArgs: [localId, companyId, sellerId],
      limit: 1,
    );
    return headers.isEmpty ? null : _withLines(database, headers.single);
  }

  @override
  Future<List<LocalOrderDraft>> listDrafts({
    required int companyId,
    required int sellerId,
  }) async {
    final database = await _db;
    final headers = await database.query(
      _draftTable,
      where: 'company_id = ? AND seller_id = ?',
      whereArgs: [companyId, sellerId],
      orderBy: 'updated_at DESC',
    );
    return Future.wait(headers.map((header) => _withLines(database, header)));
  }

  @override
  Future<List<LocalProvisionalClient>> listProvisionalClients({
    required int companyId,
    required int sellerId,
  }) async {
    final database = await _db;
    final rows = await database.query(
      _provisionalClientTable,
      where: 'company_id = ? AND seller_id = ?',
      whereArgs: [companyId, sellerId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(_provisionalClientFromRow).toList(growable: false);
  }

  Future<LocalOrderDraft> _withLines(
    DatabaseExecutor database,
    Map<String, Object?> header,
  ) async {
    final lines = await database.query(
      _lineTable,
      where: 'local_id = ?',
      whereArgs: [header['local_id']],
      orderBy: 'rowid ASC',
    );
    return _fromRows(header, lines);
  }

  @override
  Future<LocalOrderDraft> save(LocalOrderDraft draft) async {
    if (draft.lines.isEmpty)
      throw ArgumentError.value(
        draft.lines,
        'lines',
        'O rascunho precisa de itens.',
      );
    final database = await _db;
    return database.transaction((transaction) async {
      final current = await transaction.query(
        _draftTable,
        where: 'local_id = ?',
        whereArgs: [draft.localId],
        limit: 1,
      );
      if (current.isNotEmpty &&
          (current.single['company_id'] != draft.companyId ||
              current.single['seller_id'] != draft.sellerId)) {
        throw StateError('O rascunho pertence a outro vendedor.');
      }
      final stored = LocalOrderDraft(
        localId: draft.localId,
        companyId: draft.companyId,
        sellerId: draft.sellerId,
        status: current.isEmpty
            ? localDraftStatus
            : current.single['status']! as String,
        createdAt: current.isEmpty
            ? draft.createdAt
            : DateTime.parse(current.single['created_at']! as String),
        updatedAt: draft.updatedAt,
        lines: draft.lines,
        clientId: draft.clientId,
        clientName: draft.clientName,
        paymentMethodId: draft.paymentMethodId,
        paymentMethodName: draft.paymentMethodName,
        notes: draft.notes,
        deliveryDays: draft.deliveryDays,
        isManagerial: draft.isManagerial,
        deliveryDate: draft.deliveryDate,
        receivedOrderId: current.isEmpty
            ? draft.receivedOrderId
            : current.single['received_order_id'] as int?,
        remoteOrderId: current.isEmpty
            ? draft.remoteOrderId
            : current.single['remote_order_id'] as String?,
        sendError: current.isEmpty
            ? draft.sendError
            : current.single['send_error'] as String?,
      );
      final values = _headerValues(stored);
      if (current.isEmpty) {
        await transaction.insert(_draftTable, values);
      } else {
        await transaction.update(
          _draftTable,
          values,
          where: 'local_id = ?',
          whereArgs: [stored.localId],
        );
        await transaction.delete(
          _lineTable,
          where: 'local_id = ?',
          whereArgs: [stored.localId],
        );
      }
      for (final line in stored.lines) {
        await transaction.insert(_lineTable, {
          'local_id': stored.localId,
          'product_id': line.productId,
          'description': line.description,
          'unit': line.unit,
          'quantity': line.quantity,
          'unit_price': line.unitPrice,
        });
      }
      return stored;
    });
  }

  @override
  Future<LocalOrderDraft> updateSendState({
    required LocalOrderDraft draft,
    required String status,
    int? receivedOrderId,
    String? remoteOrderId,
    String? sendError,
  }) async {
    final database = await _db;
    await database.update(
      _draftTable,
      {
        'status': status,
        'received_order_id': receivedOrderId,
        'remote_order_id': remoteOrderId,
        'send_error': sendError,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [draft.localId],
    );
    return (await loadById(
      localId: draft.localId,
      companyId: draft.companyId,
      sellerId: draft.sellerId,
    ))!;
  }

  @override
  Future<LocalProvisionalClient> saveProvisionalClient(
    LocalProvisionalClient client,
  ) async {
    final database = await _db;
    return database.transaction((transaction) async {
      final current = await transaction.query(
        _provisionalClientTable,
        where: 'local_id = ?',
        whereArgs: [client.localId],
        limit: 1,
      );
      if (current.isNotEmpty &&
          (current.single['company_id'] != client.companyId ||
              current.single['seller_id'] != client.sellerId)) {
        throw StateError('O cliente pertence a outro vendedor.');
      }
      final duplicate = await transaction.query(
        _provisionalClientTable,
        columns: const ['local_id'],
        where:
            'company_id = ? AND seller_id = ? AND document = ? AND local_id <> ?',
        whereArgs: [
          client.companyId,
          client.sellerId,
          client.document,
          client.localId,
        ],
        limit: 1,
      );
      if (duplicate.isNotEmpty) {
        throw StateError(
          'Ja existe um cliente provisório com este CPF ou CNPJ.',
        );
      }
      final stored = LocalProvisionalClient(
        localId: client.localId,
        companyId: client.companyId,
        sellerId: client.sellerId,
        personType: client.personType,
        name: client.name,
        document: client.document,
        phone: client.phone,
        fantasyName: client.fantasyName,
        stateRegistration: client.stateRegistration,
        email: client.email,
        whatsapp: client.whatsapp,
        zipCode: client.zipCode,
        street: client.street,
        number: client.number,
        complement: client.complement,
        neighborhood: client.neighborhood,
        city: client.city,
        state: client.state,
        status: provisionalClientStatus,
        officialClientId: client.officialClientId,
        createdAt: current.isEmpty
            ? client.createdAt
            : DateTime.parse(current.single['created_at']! as String),
        updatedAt: client.updatedAt,
      );
      final values = _provisionalClientValues(stored);
      if (current.isEmpty) {
        await transaction.insert(_provisionalClientTable, values);
      } else {
        await transaction.update(
          _provisionalClientTable,
          values,
          where: 'local_id = ?',
          whereArgs: [stored.localId],
        );
      }
      return stored;
    });
  }

  Map<String, Object?> _headerValues(LocalOrderDraft draft) => {
    'local_id': draft.localId,
    'company_id': draft.companyId,
    'seller_id': draft.sellerId,
    'status': draft.status,
    'client_id': draft.clientId,
    'client_name': draft.clientName,
    'payment_method_id': draft.paymentMethodId,
    'payment_method_name': draft.paymentMethodName,
    'notes': draft.notes,
    'delivery_days': draft.deliveryDays,
    'managerial': draft.isManagerial == null
        ? null
        : (draft.isManagerial! ? 1 : 0),
    'delivery_date': draft.deliveryDate?.toIso8601String(),
    'received_order_id': draft.receivedOrderId,
    'remote_order_id': draft.remoteOrderId,
    'send_error': draft.sendError,
    'created_at': draft.createdAt.toUtc().toIso8601String(),
    'updated_at': draft.updatedAt.toUtc().toIso8601String(),
  };

  Map<String, Object?> _provisionalClientValues(
    LocalProvisionalClient client,
  ) => {
    'local_id': client.localId,
    'company_id': client.companyId,
    'seller_id': client.sellerId,
    'person_type': client.personType,
    'name': client.name,
    'document': client.document,
    'phone': client.phone,
    'fantasy_name': client.fantasyName,
    'state_registration': client.stateRegistration,
    'email': client.email,
    'whatsapp': client.whatsapp,
    'zip_code': client.zipCode,
    'street': client.street,
    'number': client.number,
    'complement': client.complement,
    'neighborhood': client.neighborhood,
    'city': client.city,
    'state': client.state,
    'status': client.status,
    'official_client_id': client.officialClientId,
    'created_at': client.createdAt.toUtc().toIso8601String(),
    'updated_at': client.updatedAt.toUtc().toIso8601String(),
  };

  LocalOrderDraft _fromRows(
    Map<String, Object?> header,
    List<Map<String, Object?>> lines,
  ) => LocalOrderDraft(
    localId: header['local_id']! as String,
    companyId: header['company_id']! as int,
    sellerId: header['seller_id']! as int,
    status: header['status']! as String,
    clientId: header['client_id'] as String?,
    clientName: header['client_name'] as String?,
    paymentMethodId: header['payment_method_id'] as String?,
    paymentMethodName: header['payment_method_name'] as String?,
    notes: header['notes'] as String?,
    deliveryDays: header['delivery_days'] as int?,
    isManagerial: header['managerial'] == null
        ? null
        : (header['managerial'] as int) == 1,
    deliveryDate: header['delivery_date'] == null
        ? ((header['delivery_days'] as int?) == null
              ? null
              : DateTime.parse(
                  header['created_at']! as String,
                ).add(Duration(days: header['delivery_days'] as int)))
        : DateTime.parse(header['delivery_date']! as String),
    receivedOrderId: header['received_order_id'] as int?,
    remoteOrderId: header['remote_order_id'] as String?,
    sendError: header['send_error'] as String?,
    createdAt: DateTime.parse(header['created_at']! as String),
    updatedAt: DateTime.parse(header['updated_at']! as String),
    lines: lines
        .map(
          (line) => LocalDraftLine(
            productId: line['product_id']! as String,
            description: line['description']! as String,
            unit: line['unit']! as String,
            quantity: (line['quantity']! as num).toDouble(),
            unitPrice: line['unit_price'] as String?,
          ),
        )
        .toList(growable: false),
  );

  LocalProvisionalClient _provisionalClientFromRow(Map<String, Object?> row) =>
      LocalProvisionalClient(
        localId: row['local_id']! as String,
        companyId: row['company_id']! as int,
        sellerId: row['seller_id']! as int,
        personType: row['person_type']! as String,
        name: row['name']! as String,
        document: row['document']! as String,
        phone: row['phone']! as String,
        fantasyName: row['fantasy_name'] as String?,
        stateRegistration: row['state_registration'] as String?,
        email: row['email'] as String?,
        whatsapp: row['whatsapp'] as String?,
        zipCode: row['zip_code'] as String?,
        street: row['street'] as String?,
        number: row['number'] as String?,
        complement: row['complement'] as String?,
        neighborhood: row['neighborhood'] as String?,
        city: row['city'] as String?,
        state: row['state'] as String?,
        status: row['status']! as String,
        officialClientId: row['official_client_id'] as String?,
        createdAt: DateTime.parse(row['created_at']! as String),
        updatedAt: DateTime.parse(row['updated_at']! as String),
      );
}

String newLocalDraftId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  // RFC 4122 UUID v4, which is the idempotency-key format of the cloud API.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
String newLocalProvisionalClientId() =>
    'client-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

class InMemoryLocalDraftStore implements LocalDraftStore {
  final Map<String, LocalOrderDraft> _drafts = {};
  final Map<String, LocalProvisionalClient> _provisionalClients = {};

  @override
  Future<LocalOrderDraft> updateSendState({
    required LocalOrderDraft draft,
    required String status,
    int? receivedOrderId,
    String? remoteOrderId,
    String? sendError,
  }) async {
    final stored = LocalOrderDraft(
      localId: draft.localId,
      companyId: draft.companyId,
      sellerId: draft.sellerId,
      status: status,
      createdAt: draft.createdAt,
      updatedAt: DateTime.now(),
      lines: draft.lines,
      clientId: draft.clientId,
      clientName: draft.clientName,
      paymentMethodId: draft.paymentMethodId,
      paymentMethodName: draft.paymentMethodName,
      notes: draft.notes,
      deliveryDays: draft.deliveryDays,
      isManagerial: draft.isManagerial,
      deliveryDate: draft.deliveryDate,
      receivedOrderId: receivedOrderId,
      remoteOrderId: remoteOrderId,
      sendError: sendError,
    );
    _drafts[_key(draft.companyId, draft.sellerId, draft.localId)] = stored;
    return stored;
  }

  @override
  Future<LocalOrderDraft?> loadById({
    required String localId,
    required int companyId,
    required int sellerId,
  }) async => _drafts[_key(companyId, sellerId, localId)];

  @override
  Future<List<LocalOrderDraft>> listDrafts({
    required int companyId,
    required int sellerId,
  }) async {
    final drafts = _drafts.values
        .where(
          (draft) => draft.companyId == companyId && draft.sellerId == sellerId,
        )
        .toList();
    drafts.sort((first, second) => second.updatedAt.compareTo(first.updatedAt));
    return drafts;
  }

  @override
  Future<LocalOrderDraft> save(LocalOrderDraft draft) async {
    final key = _key(draft.companyId, draft.sellerId, draft.localId);
    final previous = _drafts[key];
    final stored = LocalOrderDraft(
      localId: draft.localId,
      companyId: draft.companyId,
      sellerId: draft.sellerId,
      status: localDraftStatus,
      createdAt: previous?.createdAt ?? draft.createdAt,
      updatedAt: draft.updatedAt,
      lines: draft.lines,
      clientId: draft.clientId,
      clientName: draft.clientName,
      paymentMethodId: draft.paymentMethodId,
      paymentMethodName: draft.paymentMethodName,
      notes: draft.notes,
      deliveryDays: draft.deliveryDays,
      isManagerial: draft.isManagerial,
    );
    _drafts[key] = stored;
    return stored;
  }

  @override
  Future<List<LocalProvisionalClient>> listProvisionalClients({
    required int companyId,
    required int sellerId,
  }) async {
    final clients = _provisionalClients.values
        .where(
          (client) =>
              client.companyId == companyId && client.sellerId == sellerId,
        )
        .toList();
    clients.sort(
      (first, second) => second.updatedAt.compareTo(first.updatedAt),
    );
    return clients;
  }

  @override
  Future<LocalProvisionalClient> saveProvisionalClient(
    LocalProvisionalClient client,
  ) async {
    final duplicate = _provisionalClients.values.any(
      (existing) =>
          existing.companyId == client.companyId &&
          existing.sellerId == client.sellerId &&
          existing.document == client.document &&
          existing.localId != client.localId,
    );
    if (duplicate)
      throw StateError('Ja existe um cliente provisório com este CPF ou CNPJ.');
    final key = _key(client.companyId, client.sellerId, client.localId);
    final previous = _provisionalClients[key];
    final stored = LocalProvisionalClient(
      localId: client.localId,
      companyId: client.companyId,
      sellerId: client.sellerId,
      personType: client.personType,
      name: client.name,
      document: client.document,
      phone: client.phone,
      fantasyName: client.fantasyName,
      stateRegistration: client.stateRegistration,
      email: client.email,
      whatsapp: client.whatsapp,
      zipCode: client.zipCode,
      street: client.street,
      number: client.number,
      complement: client.complement,
      neighborhood: client.neighborhood,
      city: client.city,
      state: client.state,
      status: provisionalClientStatus,
      officialClientId: client.officialClientId,
      createdAt: previous?.createdAt ?? client.createdAt,
      updatedAt: client.updatedAt,
    );
    _provisionalClients[key] = stored;
    return stored;
  }

  String _key(int companyId, int sellerId, String localId) =>
      '$companyId:$sellerId:$localId';
}
