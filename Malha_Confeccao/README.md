# Atualização vigente — 22/10/2026

O estado atual do projeto e o encerramento do dia estão em [Documentos/ENCERRAMENTO_20261022.md](Documentos/ENCERRAMENTO_20261022.md).

- API local configurada para a Tekno Prime; login `EU`: empresa 1, vendedor 12.
- Novo Pedido usa consultas autenticadas e somente leitura para clientes, produtos touch e formas de pagamento.
- A pesquisa `MARIA` retorna zero para `EU` porque não há clientes correspondentes vinculados ao vendedor 12.
- Não existe gravação de pedidos, sincronização nem arquitetura externa de produção.

O conteúdo abaixo é histórico e deve ser interpretado conforme sua data.

# ParmaGestor — Pedidos de Malhas

Protótipo Flutter independente para vendedores externos da Confecção.

Nesta etapa, há somente três telas demonstrativas: Login, Início do Vendedor e Novo Pedido. Não há autenticação real, API, banco de dados, sincronização ou consulta financeira.

Consulte `Documentos/STATUS_APP_MALHAS.md` antes de iniciar integração externa.
