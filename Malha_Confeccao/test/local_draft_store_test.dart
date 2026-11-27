import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:parma_gestor_malhas/local_draft_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'migra o rascunho v1 e permite varios pedidos isolados por vendedor',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'malhas_draft_test_',
      );
      final databasePath = path.join(directory.path, 'rascunhos.sqlite');
      final factory = databaseFactoryFfi;
      final createdAt = DateTime.utc(2026, 10, 23, 12);
      SqliteLocalDraftStore? store;

      try {
        final legacy = await factory.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (database, _) async {
              await database.execute('''
            CREATE TABLE local_order_draft (
              local_id TEXT PRIMARY KEY NOT NULL,
              draft_key TEXT NOT NULL UNIQUE,
              company_id INTEGER NOT NULL,
              seller_id INTEGER NOT NULL,
              status TEXT NOT NULL,
              client_id TEXT, client_name TEXT,
              payment_method_id TEXT, payment_method_name TEXT,
              notes TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
            )
          ''');
              await database.execute('''
            CREATE TABLE local_order_draft_line (
              local_id TEXT NOT NULL, product_id TEXT NOT NULL,
              description TEXT NOT NULL, unit TEXT NOT NULL, quantity REAL NOT NULL,
              PRIMARY KEY (local_id, product_id)
            )
          ''');
            },
          ),
        );
        await legacy.insert('local_order_draft', {
          'local_id': 'v1-preservado',
          'draft_key': '7:15',
          'company_id': 7,
          'seller_id': 15,
          'status': localDraftStatus,
          'client_id': 'cli-1',
          'client_name': 'Cliente legado',
          'payment_method_id': 'pg-1',
          'payment_method_name': 'Boleto',
          'notes': 'Não perder',
          'created_at': createdAt.toIso8601String(),
          'updated_at': createdAt.toIso8601String(),
        });
        await legacy.insert('local_order_draft_line', {
          'local_id': 'v1-preservado',
          'product_id': 'produto-kg',
          'description': 'Malha KG',
          'unit': 'KG',
          'quantity': 125.85,
        });
        await legacy.close();

        store = SqliteLocalDraftStore(
          factory: factory,
          databasePath: databasePath,
        );
        final migrated = await store.listDrafts(companyId: 7, sellerId: 15);
        expect(migrated, hasLength(1));
        expect(migrated.single.localId, 'v1-preservado');
        expect(migrated.single.clientName, 'Cliente legado');
        expect(migrated.single.lines.single.quantity, 125.85);

        await store.save(
          _draft(
            id: 'pedido-2',
            company: 7,
            seller: 15,
            client: 'Cliente novo',
            quantity: 80,
            unit: 'UN',
            time: createdAt.add(const Duration(minutes: 1)),
          ),
        );
        await store.save(
          _draft(
            id: 'v1-preservado',
            company: 7,
            seller: 15,
            client: 'Cliente legado editado',
            quantity: 126.25,
            unit: 'KG',
            time: createdAt.add(const Duration(minutes: 2)),
          ),
        );
        final ownDrafts = await store.listDrafts(companyId: 7, sellerId: 15);
        expect(ownDrafts, hasLength(2));
        expect(ownDrafts.first.localId, 'v1-preservado');
        expect(ownDrafts.first.lines.single.quantity, 126.25);
        expect(ownDrafts.last.localId, 'pedido-2');
        expect(ownDrafts.last.lines.single.quantity, 80);

        expect(await store.listDrafts(companyId: 7, sellerId: 16), isEmpty);
        await store.save(
          _draft(
            id: 'pedido-outro-vendedor',
            company: 7,
            seller: 16,
            client: 'Isolado',
            quantity: 1,
            unit: 'UN',
            time: createdAt.add(const Duration(minutes: 3)),
          ),
        );
        expect(
          await store.listDrafts(companyId: 7, sellerId: 16),
          hasLength(1),
        );
        expect(
          await store.listDrafts(companyId: 7, sellerId: 15),
          hasLength(2),
        );

        await store.close();
        store = SqliteLocalDraftStore(
          factory: factory,
          databasePath: databasePath,
        );
        final afterReopen = await store.loadById(
          localId: 'v1-preservado',
          companyId: 7,
          sellerId: 15,
        );
        expect(afterReopen, isNotNull);
        expect(afterReopen!.clientName, 'Cliente legado editado');
        expect(afterReopen.lines.single.quantity, 126.25);
      } finally {
        await store?.close();
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    },
  );

  test('salva clientes provisórios isolados e recupera após reabrir', () async {
    final directory = await Directory.systemTemp.createTemp(
      'malhas_client_test_',
    );
    final databasePath = path.join(directory.path, 'clientes.sqlite');
    SqliteLocalDraftStore? store;
    final time = DateTime.utc(2026, 10, 23, 13);
    try {
      store = SqliteLocalDraftStore(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      final client = await store.saveProvisionalClient(
        _client(
          id: 'cliente-1',
          company: 7,
          seller: 15,
          document: '52998224725',
          time: time,
        ),
      );
      expect(
        client.orderClientId,
        '$provisionalClientIdPrefix${client.localId}',
      );
      expect(
        await store.listProvisionalClients(companyId: 7, sellerId: 16),
        isEmpty,
      );
      await expectLater(
        store.saveProvisionalClient(
          _client(
            id: 'cliente-duplicado',
            company: 7,
            seller: 15,
            document: '52998224725',
            time: time,
          ),
        ),
        throwsStateError,
      );
      await store.saveProvisionalClient(
        _client(
          id: 'cliente-outro-vendedor',
          company: 7,
          seller: 16,
          document: '52998224725',
          time: time,
        ),
      );
      await store.close();
      store = SqliteLocalDraftStore(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      final afterReopen = await store.listProvisionalClients(
        companyId: 7,
        sellerId: 15,
      );
      expect(afterReopen, hasLength(1));
      expect(afterReopen.single.name, 'Cliente provisório');
      expect(afterReopen.single.officialClientId, isNull);
    } finally {
      await store?.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });
  test('migra cliente provisório v6 para os campos opcionais v7', () async {
    final directory = await Directory.systemTemp.createTemp('malhas_v7_test_');
    final databasePath = path.join(directory.path, 'clientes.sqlite');
    SqliteLocalDraftStore? store;
    final time = DateTime.utc(2026, 11, 10, 12);
    try {
      final legacy = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (database, _) => database.execute('''
            CREATE TABLE local_provisional_client (
              local_id TEXT PRIMARY KEY NOT NULL, company_id INTEGER NOT NULL,
              seller_id INTEGER NOT NULL, person_type TEXT NOT NULL,
              name TEXT NOT NULL, document TEXT NOT NULL, phone TEXT NOT NULL,
              fantasy_name TEXT, status TEXT NOT NULL, official_client_id TEXT,
              created_at TEXT NOT NULL, updated_at TEXT NOT NULL
            )
          '''),
        ),
      );
      await legacy.close();
      store = SqliteLocalDraftStore(factory: databaseFactoryFfi, databasePath: databasePath);
      await store.saveProvisionalClient(LocalProvisionalClient(
        localId: 'cliente-v7', companyId: 7, sellerId: 15, personType: 'PJ',
        name: 'Cliente ampliado', document: '12345678901234', phone: '11999999999',
        email: 'cliente@exemplo.com', zipCode: '01001000', street: 'Rua A',
        city: 'Sao Paulo', state: 'SP', status: provisionalClientStatus,
        createdAt: time, updatedAt: time,
      ));
      await store.close();
      store = SqliteLocalDraftStore(factory: databaseFactoryFfi, databasePath: databasePath);
      final client = (await store.listProvisionalClients(companyId: 7, sellerId: 15)).single;
      expect(client.email, 'cliente@exemplo.com');
      expect(client.zipCode, '01001000');
      expect(client.state, 'SP');
    } finally {
      await store?.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });
}

LocalOrderDraft _draft({
  required String id,
  required int company,
  required int seller,
  required String client,
  required double quantity,
  required String unit,
  required DateTime time,
}) => LocalOrderDraft(
  localId: id,
  companyId: company,
  sellerId: seller,
  status: localDraftStatus,
  createdAt: time,
  updatedAt: time,
  clientId: 'cliente-$id',
  clientName: client,
  lines: [
    LocalDraftLine(
      productId: 'produto-$id',
      description: 'Produto $id',
      unit: unit,
      quantity: quantity,
    ),
  ],
);

LocalProvisionalClient _client({
  required String id,
  required int company,
  required int seller,
  required String document,
  required DateTime time,
}) => LocalProvisionalClient(
  localId: id,
  companyId: company,
  sellerId: seller,
  personType: 'PF',
  name: 'Cliente provisório',
  document: document,
  phone: '31999999999',
  status: provisionalClientStatus,
  createdAt: time,
  updatedAt: time,
);
