import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parma_gestor_malhas/local_draft_store.dart';
import 'package:parma_gestor_malhas/main.dart';

void main() {
  Future<void> completeRequiredOrderDetails(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pagamento para teste').last);
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.text('Sim'));
    await tester.pump();
  }

  Future<void> pumpOrder(
    WidgetTester tester, {
    LocalDraftStore? draftStore,
    bool initialClient = true,
    bool completeRequiredDetails = true,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: NewOrderScreen(
          accessToken: 'token-de-teste',
          companyId: 1,
          sellerId: 10,
          initialClientId: initialClient ? 'cliente-teste' : null,
          initialClientName: initialClient ? 'Cliente teste' : null,
          useInMemoryCatalog: true,
          draftStore: draftStore ?? InMemoryLocalDraftStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (completeRequiredDetails) await completeRequiredOrderDetails(tester);
  }

  Future<void> openQuantityEntry(WidgetTester tester, Finder product) async {
    await tester.tap(product);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quantity-entry-input')), findsOneWidget);
  }

  Future<void> pumpMyOrders(
    WidgetTester tester,
    InMemoryLocalDraftStore store,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyOrdersScreen(
          accessToken: 'token-de-teste',
          companyId: 1,
          sellerId: 10,
          draftStore: store,
          useInMemoryCatalog: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('carrinho exibe estado vazio amigável', (tester) async {
    await pumpOrder(tester);

    await tester.tap(find.byTooltip('Abrir carrinho'));
    await tester.pumpAndSettle();

    expect(find.text('Seu carrinho está vazio.'), findsOneWidget);
  });

  testWidgets('campos obrigatórios bloqueiam o acesso aos itens', (
    tester,
  ) async {
    await pumpOrder(
      tester,
      initialClient: false,
      completeRequiredDetails: false,
    );
    await completeRequiredOrderDetails(tester);
    await tester.tap(find.text('Itens'));
    await tester.pump();
    expect(find.text('Selecione um cliente.'), findsOneWidget);
    expect(find.text('SELECIONE A MALHA'), findsNothing);

    await pumpOrder(tester, completeRequiredDetails: false);
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.text('Sim'));
    await tester.tap(find.text('Itens'));
    await tester.pump();
    expect(find.text('Selecione a forma de pagamento.'), findsWidgets);
    expect(find.text('SELECIONE A MALHA'), findsNothing);

    await pumpOrder(tester, completeRequiredDetails: false);
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pagamento para teste').last);
    await tester.tap(find.text('Sim'));
    await tester.tap(find.text('Itens'));
    await tester.pump();
    expect(find.text('Informe um prazo de entrega válido.'), findsOneWidget);
    expect(find.text('SELECIONE A MALHA'), findsNothing);

    await pumpOrder(tester, completeRequiredDetails: false);
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pagamento para teste').last);
    await tester.enterText(find.byType(TextField).at(1), 'invalido');
    await tester.tap(find.text('Sim'));
    await tester.tap(find.text('Itens'));
    await tester.pump();
    expect(find.text('Informe um prazo de entrega válido.'), findsOneWidget);

    await pumpOrder(tester, completeRequiredDetails: false);
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pagamento para teste').last);
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.text('Itens'));
    await tester.pump();
    expect(find.text('Informe se o pedido é gerencial.'), findsWidgets);
    expect(find.text('SELECIONE A MALHA'), findsNothing);
  });

  testWidgets('campos obrigatórios válidos permitem acessar e retornar dos itens', (
    tester,
  ) async {
    await pumpOrder(tester);
    await tester.tap(find.text('Itens'));
    await tester.pumpAndSettle();
    expect(find.text('SELECIONE A MALHA'), findsOneWidget);

    await tester.tap(find.text('Pedido'));
    await tester.pump();
    expect(find.text('Cliente teste'), findsOneWidget);
  });

  testWidgets('contadores classificam os estados persistidos dos pedidos', (
    tester,
  ) async {
    final cases = <({List<String> statuses, String pending, String sent})>[
      (
        statuses: [
          localPendingSendStatus,
          localReceivedStatus,
          localReceivedStatus,
          localReceivedStatus,
          localReceivedStatus,
        ],
        pending: '1 pedido pendente',
        sent: '4 enviados',
      ),
      (
        statuses: [
          localDraftStatus,
          localPendingSendStatus,
          localSendingStatus,
          localSendErrorStatus,
        ],
        pending: '4 pedidos pendentes',
        sent: '0 enviados',
      ),
      (
        statuses: [localReceivedStatus, localReceivedStatus],
        pending: '0 pedidos pendentes',
        sent: '2 enviados',
      ),
      (
        statuses: const [],
        pending: '0 pedidos pendentes',
        sent: '0 enviados',
      ),
      (
        statuses: [localSendErrorStatus],
        pending: '1 pedido pendente',
        sent: '0 enviados',
      ),
      (
        statuses: [localSendingStatus],
        pending: '1 pedido pendente',
        sent: '0 enviados',
      ),
    ];

    for (var caseIndex = 0; caseIndex < cases.length; caseIndex++) {
      final current = cases[caseIndex];
      final store = InMemoryLocalDraftStore();
      for (var orderIndex = 0;
          orderIndex < current.statuses.length;
          orderIndex++) {
        final saved = await store.save(
          _counterDraft(
            id: 'contador-$caseIndex-$orderIndex',
            status: current.statuses[orderIndex],
          ),
        );
        if (current.statuses[orderIndex] != localDraftStatus) {
          await store.updateSendState(
            draft: saved,
            status: current.statuses[orderIndex],
          );
        }
      }

      await pumpMyOrders(tester, store);

      expect(find.text(current.pending), findsOneWidget);
      expect(find.text(current.sent), findsOneWidget);
    }
  });

  testWidgets('contadores são recarregados após a mudança de estado', (
    tester,
  ) async {
    final store = InMemoryLocalDraftStore();
    final draft = await store.save(
      _counterDraft(id: 'contador-atualizacao', status: localPendingSendStatus),
    );
    await pumpMyOrders(tester, store);
    expect(find.text('1 pedido pendente'), findsOneWidget);
    expect(find.text('0 enviados'), findsOneWidget);

    await store.updateSendState(
      draft: draft,
      status: localReceivedStatus,
      remoteOrderId: 'api-123',
    );
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(find.text('0 pedidos pendentes'), findsOneWidget);
    expect(find.text('1 enviado'), findsOneWidget);
  });

  testWidgets('Meus Pedidos mostra pendentes antes dos pedidos recebidos', (
    tester,
  ) async {
    final store = InMemoryLocalDraftStore();

    Future<void> saveWithStatus(String clientName, String status) async {
      final saved = await store.save(
        _counterDraft(id: clientName, status: status, clientName: clientName),
      );
      if (status != localDraftStatus) {
        await store.updateSendState(draft: saved, status: status);
      }
    }

    await saveWithStatus('Recebido A', localReceivedStatus);
    await saveWithStatus('Pendente B', localPendingSendStatus);
    await saveWithStatus('Recebido C', localReceivedStatus);
    await saveWithStatus('Erro D', localSendErrorStatus);
    await pumpMyOrders(tester, store);

    final pendingB = tester.getTopLeft(find.text('Pendente B')).dy;
    final errorD = tester.getTopLeft(find.text('Erro D')).dy;
    final receivedA = tester.getTopLeft(find.text('Recebido A')).dy;
    final receivedC = tester.getTopLeft(find.text('Recebido C')).dy;
    expect(pendingB, lessThan(receivedA));
    expect(errorD, lessThan(receivedA));
    expect(pendingB, lessThan(receivedC));
    expect(errorD, lessThan(receivedC));
    expect(find.text('2 pedidos pendentes'), findsOneWidget);
    expect(find.text('2 enviados'), findsOneWidget);

    final pendingDraft = (await store.listDrafts(companyId: 1, sellerId: 10))
        .firstWhere((draft) => draft.clientName == 'Pendente B');
    await store.updateSendState(
      draft: pendingDraft,
      status: localReceivedStatus,
      remoteOrderId: 'api-pendente-b',
    );
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Erro D')).dy,
      lessThan(tester.getTopLeft(find.text('Pendente B')).dy),
    );
    expect(find.text('1 pedido pendente'), findsOneWidget);
    expect(find.text('3 enviados'), findsOneWidget);
  });

  testWidgets('inclui, acumula, edita e exclui itens no mesmo rascunho', (
    tester,
  ) async {
    await pumpOrder(tester);

    await tester.enterText(find.byType(TextField).at(2), 'Entrega em lote');
    await tester.tap(find.text('Itens'));
    await tester.pumpAndSettle();

    await openQuantityEntry(
      tester,
      find.text('Malha algodão penteado — Branco'),
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('R\$ 24,90'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '2,5');
    await tester.tap(find.text('Adicionar ao carrinho'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-item-count')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('cart-item-count')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    await tester.pump();

    await openQuantityEntry(
      tester,
      find.text('Malha algodão penteado — Branco'),
    );
    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('Adicionar ao carrinho'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Abrir carrinho'));
    await tester.pumpAndSettle();
    expect(find.text('3,5 KG', findRichText: true), findsOneWidget);
    expect(find.text('Total em KG: 3,5'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar quantidade'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('4 KG', findRichText: true), findsOneWidget);
    expect(find.text('Total em KG: 4'), findsOneWidget);

    await tester.tap(find.byTooltip('Excluir item'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Deseja realmente excluir o item Malha algodão penteado — Branco do carrinho?',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<IconButton>(find.byTooltip('Excluir item')).color,
      Colors.red.shade700,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('4 KG'), findsOneWidget);

    await tester.tap(find.byTooltip('Excluir item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir item'));
    await tester.pump();
    expect(find.text('Seu carrinho está vazio.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-item-count')), findsNothing);

    await tester.tap(find.text('Pedido'));
    await tester.pump();
    expect(find.text('Entrega em lote'), findsOneWidget);
  });

  testWidgets('confirma inclusao no carrinho sem aceitar quantidade invalida', (
    tester,
  ) async {
    await pumpOrder(tester);
    await tester.tap(find.text('Itens'));
    await tester.pumpAndSettle();
    await openQuantityEntry(tester, find.textContaining('Branco'));

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Adicionar ao carrinho'));
    await tester.pump();
    expect(find.byKey(const Key('cart-add-success-confirmation')), findsNothing);
    expect(find.byKey(const Key('quantity-entry-input')), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('Adicionar ao carrinho'));
    await tester.tap(find.text('Adicionar ao carrinho'));
    // O segundo toque ocorre enquanto a primeira inclusão ainda está em curso.
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      find.byKey(const Key('cart-add-success-confirmation')),
      findsOneWidget,
    );
    expect(find.text('Item adicionado ao carrinho!'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('cart-item-count')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('cart-add-success-confirmation')), findsNothing);
  });

  testWidgets('separa os totais de KG e UN', (tester) async {
    await pumpOrder(tester);
    await tester.tap(find.text('Itens'));
    await tester.pumpAndSettle();

    await openQuantityEntry(
      tester,
      find.text('Malha algodão penteado — Branco'),
    );
    await tester.enterText(find.byType(TextField), '125,85');
    await tester.tap(find.text('Adicionar ao carrinho'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('cart-item-count')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Malha viscolycra — Preto'));
    await tester.pumpAndSettle();
    await openQuantityEntry(
      tester,
      find.text('Malha viscolycra — Preto'),
    );
    await tester.enterText(find.byType(TextField), '80');
    await tester.tap(find.text('Adicionar ao carrinho'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('cart-item-count')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Abrir carrinho'));
    await tester.pumpAndSettle();
    expect(find.text('Total KG: 125,85'), findsOneWidget);
    expect(find.text('Total UN: 80'), findsOneWidget);
  });

  testWidgets('salva o rascunho local a partir do rodapÃ© do carrinho', (
    tester,
  ) async {
    final store = InMemoryLocalDraftStore();
    await pumpOrder(tester, draftStore: store);
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.text('Sim'));
    await tester.tap(find.text('Itens'));
    await tester.pumpAndSettle();
    await openQuantityEntry(tester, find.textContaining('Branco'));
    await tester.enterText(find.byType(TextField), '2,5');
    await tester.tap(find.text('Adicionar ao carrinho'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Abrir carrinho'));
    await tester.pumpAndSettle();

    expect(find.text('Total financeiro: R\$ 62,25'), findsOneWidget);

    await tester.tap(find.text('Salvar pedido'));
    await tester.pump();

    expect(find.text('Pedido salvo com sucesso!'), findsOneWidget);
    expect(find.text('Pedido armazenado neste aparelho.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Pedido salvo com sucesso!'), findsNothing);
    expect(find.text('Pedido salvo neste aparelho.'), findsNothing);
    final drafts = await store.listDrafts(companyId: 1, sellerId: 10);
    expect(drafts, hasLength(1));
    final draft = drafts.single;
    expect(draft.status, 'RASCUNHO_LOCAL');
    expect(draft.lines.single.quantity, 2.5);
    expect(draft.lines.single.unit, 'kg');
    expect(draft.deliveryDays, 5);
    expect(draft.isManagerial, isTrue);
  });

  testWidgets('Meus Pedidos lista e abre o rascunho selecionado', (
    tester,
  ) async {
    final store = InMemoryLocalDraftStore();
    await store.save(
      LocalOrderDraft(
        localId: 'pedido-lista',
        companyId: 1,
        sellerId: 10,
        status: localDraftStatus,
        createdAt: DateTime.utc(2026, 10, 23, 12),
        updatedAt: DateTime.utc(2026, 10, 23, 12),
        clientId: 'cliente-1',
        clientName: 'Cliente da lista',
        lines: const [
          LocalDraftLine(
            productId: 'malha-1',
            description: 'Malha recuperada',
            unit: 'KG',
            quantity: 125.85,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MyOrdersScreen(
          accessToken: 'token-de-teste',
          companyId: 1,
          sellerId: 10,
          draftStore: store,
          useInMemoryCatalog: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cliente da lista'), findsOneWidget);
    expect(find.text('125,85 KG'), findsOneWidget);
    expect(find.text('Ver motivo do erro'), findsNothing);
    await tester.tap(find.text('Cliente da lista'));
    await tester.pumpAndSettle();

    expect(find.text('Novo Pedido'), findsOneWidget);
    await tester.tap(find.byTooltip('Abrir carrinho'));
    await tester.pumpAndSettle();
    expect(find.text('125,85 KG'), findsOneWidget);
  });

  testWidgets('Meus Pedidos mostra o motivo gravado sem reenviar o pedido', (
    tester,
  ) async {
    final store = InMemoryLocalDraftStore();
    const detail = 'HttpException: Sessão inválida ou expirada.';
    final savedDraft = await store.save(
      LocalOrderDraft(
        localId: 'pedido-com-erro',
        companyId: 1,
        sellerId: 10,
        status: localSendErrorStatus,
        createdAt: DateTime.utc(2026, 10, 26, 12),
        updatedAt: DateTime.utc(2026, 10, 26, 12),
        clientName: 'Cliente com erro',
        sendError: detail,
        lines: const [
          LocalDraftLine(
            productId: 'malha-1',
            description: 'Malha com erro',
            unit: 'KG',
            quantity: 1,
          ),
        ],
      ),
    );
    await store.updateSendState(
      draft: savedDraft,
      status: localSendErrorStatus,
      sendError: detail,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MyOrdersScreen(
          accessToken: 'token-de-teste',
          companyId: 1,
          sellerId: 10,
          draftStore: store,
          useInMemoryCatalog: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver motivo do erro'));
    await tester.pumpAndSettle();

    expect(find.text('Motivo do erro de envio'), findsOneWidget);
    expect(find.text(detail), findsOneWidget);
    expect(
      (await store.listDrafts(companyId: 1, sellerId: 10)).single.sendError,
      detail,
    );
  });

  testWidgets('Meus Pedidos informa ausência de detalhe de erro', (tester) async {
    final store = InMemoryLocalDraftStore();
    final savedDraft = await store.save(
      LocalOrderDraft(
        localId: 'pedido-sem-detalhe',
        companyId: 1,
        sellerId: 10,
        status: localSendErrorStatus,
        createdAt: DateTime.utc(2026, 10, 26, 12),
        updatedAt: DateTime.utc(2026, 10, 26, 12),
        clientName: 'Cliente sem detalhe',
        lines: const [
          LocalDraftLine(
            productId: 'malha-1',
            description: 'Malha sem detalhe',
            unit: 'KG',
            quantity: 1,
          ),
        ],
      ),
    );
    await store.updateSendState(
      draft: savedDraft,
      status: localSendErrorStatus,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MyOrdersScreen(
          accessToken: 'token-de-teste',
          companyId: 1,
          sellerId: 10,
          draftStore: store,
          useInMemoryCatalog: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver motivo do erro'));
    await tester.pumpAndSettle();

    expect(find.text('Detalhe do erro não disponível'), findsOneWidget);
  });

  testWidgets('pedido antigo sem preço informa o motivo sem enviar', (
    tester,
  ) async {
    final store = InMemoryLocalDraftStore();
    await store.save(
      LocalOrderDraft(
        localId: 'pedido-sem-preco',
        companyId: 1,
        sellerId: 10,
        status: localDraftStatus,
        createdAt: DateTime.utc(2026, 10, 26, 12),
        updatedAt: DateTime.utc(2026, 10, 26, 12),
        clientId: '1',
        clientName: 'Cliente antigo',
        paymentMethodId: '1',
        deliveryDays: 7,
        deliveryDate: DateTime.utc(2026, 11, 2),
        isManagerial: false,
        lines: const [
          LocalDraftLine(
            productId: '1',
            description: 'Malha histórica',
            unit: 'KG',
            quantity: 1,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MyOrdersScreen(
          accessToken: 'token-de-teste',
          companyId: 1,
          sellerId: 10,
          draftStore: store,
          useInMemoryCatalog: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enviar pedido'));
    await tester.pumpAndSettle();

    final draft = (await store.listDrafts(companyId: 1, sellerId: 10)).single;
    expect(draft.status, localSendErrorStatus);
    expect(draft.sendError, contains('não possui preço unitário salvo'));
    expect(draft.remoteOrderId, isNull);
    expect(draft.lines.single.unitPrice, isNull);
    expect(draft.lines.single.quantity, 1);
    await tester.tap(find.text('Ver motivo do erro'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'não possui preço unitário salvo',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('salvamento retorna para a rota inicial sem mensagem residual', (
    tester,
  ) async {
    final store = InMemoryLocalDraftStore();
    await store.save(
      LocalOrderDraft(
        localId: 'pedido-retorno',
        companyId: 1,
        sellerId: 10,
        status: localDraftStatus,
        createdAt: DateTime.utc(2026, 10, 23, 12),
        updatedAt: DateTime.utc(2026, 10, 23, 12),
        lines: const [
          LocalDraftLine(
            productId: 'malha-1',
            description: 'Malha retorno',
            unit: 'UN',
            quantity: 2,
            unitPrice: '10.00',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NewOrderScreen(
                      accessToken: 'token-de-teste',
                      companyId: 1,
                      sellerId: 10,
                      draftId: 'pedido-retorno',
                      draftStore: store,
                      useInMemoryCatalog: true,
                    ),
                  ),
                ),
                child: const Text('Home principal'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Home principal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.tap(find.text('Sim'));
    await tester.tap(find.byTooltip('Abrir carrinho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar pedido'));
    await tester.pump();
    expect(find.text('Pedido salvo com sucesso!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Home principal'), findsOneWidget);
    expect(find.text('Pedido salvo com sucesso!'), findsNothing);
  });

  testWidgets('falha ao salvar nao navega nem exibe sucesso', (tester) async {
    await pumpOrder(tester, draftStore: _FailingDraftStore());
    await tester.tap(find.text('Itens'));
    await tester.pumpAndSettle();
    await openQuantityEntry(tester, find.textContaining('Branco'));
    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('Adicionar ao carrinho'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Abrir carrinho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar pedido'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Pedido salvo com sucesso!'), findsNothing);
    expect(find.text('Carrinho'), findsOneWidget);
  });

  testWidgets('Meus Clientes pesquisa, lista e abre dados somente leitura', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyClientsScreen(
          accessToken: 'token-de-teste',
          companyId: 1,
          sellerId: 10,
          clientLookup: (_) async => const [
            ClientRecord(
              code: '100',
              name: 'Confecção Áurea',
              fantasyName: 'Áurea',
            ),
            ClientRecord(code: '200', name: 'Outro cliente', fantasyName: ''),
          ],
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'aurea');
    await tester.pumpAndSettle();

    expect(find.text('1 cliente encontrado'), findsOneWidget);
    expect(find.text('Confecção Áurea'), findsOneWidget);
    expect(find.text('Código 100'), findsOneWidget);
    await tester.tap(find.text('Confecção Áurea'));
    await tester.pumpAndSettle();
    expect(find.text('Dados do Cliente'), findsOneWidget);
    expect(find.text('Nome fantasia'), findsOneWidget);
  });

  testWidgets('Meus Clientes exibe lista vazia e falha de consulta', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyClientsScreen(
          accessToken: 'token-de-teste',
          companyId: 1,
          sellerId: 10,
          clientLookup: (_) async => const [],
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pumpAndSettle();
    expect(
      find.text('Nenhum cliente encontrado para esta pesquisa.'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MyClientsScreen(
          accessToken: 'token-de-teste',
          companyId: 1,
          sellerId: 10,
          clientLookup: (_) => Future.error(StateError('falha')),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '');
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pumpAndSettle();
    expect(find.textContaining('consultar os clientes'), findsOneWidget);
  });

  testWidgets('Home abre Meus Clientes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SellerHomeScreen(
          accessToken: 'token-de-teste',
          companyId: 1,
          sellerId: 10,
        ),
      ),
    );
    await tester.tap(find.text('Meus Clientes'));
    await tester.pumpAndSettle();
    expect(find.text('Meus Clientes'), findsOneWidget);
  });
  test('valida documentos de pessoa física e jurídica', () {
    expect(isValidCpf('529.982.247-25'), isTrue);
    expect(isValidCpf('111.111.111-11'), isFalse);
    expect(isValidCnpj('04.252.011/0001-10'), isTrue);
    expect(isValidCnpj('11.111.111/1111-11'), isFalse);
  });
}

LocalOrderDraft _counterDraft({
  required String id,
  required String status,
  String? clientName,
}) =>
    LocalOrderDraft(
      localId: id,
      companyId: 1,
      sellerId: 10,
      status: status,
      createdAt: DateTime.utc(2026, 10, 27, 12),
      updatedAt: DateTime.utc(2026, 10, 27, 12),
      clientName: clientName,
      lines: const [
        LocalDraftLine(
          productId: 'produto-contador',
          description: 'Malha para contador',
          unit: 'KG',
          quantity: 1,
        ),
      ],
    );

class _FailingDraftStore implements LocalDraftStore {
  @override
  Future<LocalOrderDraft?> loadById({
    required String localId,
    required int companyId,
    required int sellerId,
  }) async => null;

  @override
  Future<List<LocalOrderDraft>> listDrafts({
    required int companyId,
    required int sellerId,
  }) async => const [];

  @override
  Future<LocalOrderDraft> save(LocalOrderDraft draft) =>
      Future.error(StateError('falha simulada'));

  @override
  Future<LocalOrderDraft> updateSendState({
    required LocalOrderDraft draft,
    required String status,
    int? receivedOrderId,
    String? remoteOrderId,
    String? sendError,
  }) => Future.error(StateError('falha simulada'));

  @override
  Future<List<LocalProvisionalClient>> listProvisionalClients({
    required int companyId,
    required int sellerId,
  }) async => const [];

  @override
  Future<LocalProvisionalClient> saveProvisionalClient(
    LocalProvisionalClient client,
  ) => Future.error(StateError('falha simulada'));
}
