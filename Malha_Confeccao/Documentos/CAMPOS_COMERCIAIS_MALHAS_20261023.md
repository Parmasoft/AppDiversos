# Campos comerciais — App de Malhas

Data: 23/10/2026

## Entrega

- API: `GET /api/v1/catalogo/produtos-touch` passou a retornar `preco_unitario` a partir de `TB_PRODUTO.PRD_PRECO_VENDA`, mantendo empresa derivada da sessão e sem tabela de preço por cliente.
- O valor é serializado como texto decimal; preço nulo, negativo ou inválido retorna `null`, nunca zero presumido.
- Pedido: prazo em dias corridos, data prevista derivada da criação do pedido e seleção obrigatória de Gerencial (Sim/Não).
- Itens/carrinho: preço unitário somente leitura, subtotal e total financeiro; os cálculos monetários usam escala inteira/`BigInt`, evitando ponto flutuante financeiro.
- SQLite v4: preserva pedidos e clientes provisórios. Novas colunas do cabeçalho (`delivery_days`, `managerial`) e preço decimal textual do item (`unit_price`) são incrementais; pedidos antigos permanecem acessíveis.

## Arquivos alterados

- `api/app/catalog/service.py`
- `api/tests/test_catalog_routes.py`
- `lib/main.dart`
- `lib/local_draft_store.dart`
- `test/widget_test.dart`

## Validação

- API: `python -m unittest tests.test_catalog_routes -v` — 3 testes aprovados.
- Flutter: `flutter test` — 13 testes aprovados.
- `flutter analyze`: sem erros; 4 avisos e informações de lint não bloqueantes.
- APK debug: `build/app/outputs/flutter-apk/app-debug.apk`.
- Inclui migração/reabertura, isolamento, prazo/Gerencial no salvamento e total financeiro de quantidade fracionada.

## Limites intencionais

Não houve envio, sincronização, recepção, conversão em pedido comercial, alteração Firebird ou mudança no projeto ParmaGestor integrado. O servidor futuro deverá recalcular e validar o preço comercial recebido.
