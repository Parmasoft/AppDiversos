# Nomenclatura visual de pedido — 23/10/2026

Foram alterados exclusivamente os textos apresentados ao vendedor.

- `Salvar rascunho` passou a ser `Salvar pedido`.
- A confirmação central agora informa `Pedido salvo com sucesso!`.
- O status visível dos pedidos locais é `Pendente de envio`.
- A lista usa `Pedidos pendentes`, com singular e plural corretos.
- Estados vazios e mensagens de erro agora usam `pedido`.

O texto `Pedido armazenado neste aparelho.` foi preservado. O status interno
`RASCUNHO_LOCAL`, tabelas, colunas, classes, migração SQLite e lógica de
salvamento/recuperação não foram modificados.

Validação: `flutter test` com 8 testes aprovados; `flutter analyze` sem erros
e com 5 avisos preexistentes fora deste escopo.
