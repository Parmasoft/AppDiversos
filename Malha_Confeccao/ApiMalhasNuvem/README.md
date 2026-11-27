# ApiMalhasNuvem

API local e independente para a futura comunicacao externa do App de Malhas.
Usa PostgreSQL em producao e SQLite somente nos testes. Nao se conecta ao
Firebird.

## Publicação pelo Agente Malhas

Os endpoints internos `POST /api/v1/agente/vendedores/snapshot` e
`POST /api/v1/agente/catalogo/snapshots` recebem somente `Authorization:
Bearer <token-tecnico>`. A credencial é exclusiva do agente, vinculada a uma
empresa em `malhas_agente_credencial` e persistida como digest HMAC; ela não
é uma sessão de vendedor.

Ambos validam empresa, estrutura, revisão e hash canônico do conteúdo. A
mesma revisão/conteúdo retorna `repetido: true`; revisão antiga ou conteúdo
divergente é rejeitado. As projeções de catálogo são substituídas dentro de
uma única transação e não possuem nenhuma operação sobre `malhas_pedido` ou
`malhas_pedido_item`: valores de pedidos recebidos permanecem originais.

Execute as migrações Alembic até `20261024_0002` antes de habilitar o Agente.

## Recepção pelo Agente (25/10/2026)

`POST /api/v1/agente/pedidos/claim` e `POST /api/v1/agente/pedidos/{id}/ack` aceitam exclusivamente o Bearer técnico do Agente. O claim reserva atomicamente um pedido da empresa, devolve o payload original e o vendedor de origem, e expira em 120 segundos por padrão. O ack é permitido somente ao agente que detém a reserva e é idempotente após o processamento. A implementação reutiliza os campos de `malhas_pedido`; não exige migration.
