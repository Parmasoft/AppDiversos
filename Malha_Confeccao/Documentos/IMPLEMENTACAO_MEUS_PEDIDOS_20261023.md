# Meus Pedidos e múltiplos rascunhos locais — 23/10/2026

## Escopo concluído

- O botão `Meus Pedidos` da Home abre a lista local do vendedor autenticado.
- A lista mostra primeiro rascunhos pendentes, sem dados demonstrativos, e uma
  seção de enviados vazia até existir confirmação futura da API.
- Cada cartão mostra cliente, data da última alteração, número local, quantidade
  de produtos, totais separados por unidade e status `RASCUNHO_LOCAL`.
- Ao tocar em um cartão, o pedido correto é aberto para edição. O retorno à
  lista recarrega os dados salvos.
- `Novo pedido`, pela Home ou pela lista, inicia um rascunho novo. Salvar um
  pedido já aberto atualiza somente o seu `local_id`.
- Alterações que ainda não foram salvas são identificadas no pedido aberto. Ao
  tentar sair, o usuário escolhe entre continuar editando ou descartar.

## Migração SQLite segura

O banco passou da versão 1 para a 2. A versão anterior possuía uma chave única
por empresa/vendedor e, portanto, comportava um único rascunho.

A migração versionada renomeia temporariamente as tabelas antigas, cria as
tabelas v2 sem essa chave única, copia cabeçalhos e itens e só então remove as
tabelas temporárias. Assim, o rascunho existente é preservado. A v2 mantém a
chave primária `local_id`, o status local e o índice por empresa, vendedor e
data de atualização.

Os rascunhos continuam isolados por empresa e vendedor. Não há tokens, senhas,
preços, totais financeiros, API, Firebird, sincronização ou envio nesta etapa.

## Backup antes da migração

As cópias pré-migração foram preservadas em
`Documentos/Backup_Meus_Pedidos_20261023/` com extensão `.dart.bak`, fora da
análise Dart. Incluem `main.dart`, o store SQLite v1 e seu teste.

## Arquivos alterados

- `lib/local_draft_store.dart`
- `lib/main.dart`
- `test/local_draft_store_test.dart`
- `test/widget_test.dart`
- `Documentos/Backup_Meus_Pedidos_20261023/`

## Validação

- `flutter test`: 6 testes aprovados.
- A migração é testada a partir de um banco v1 real, com verificação de itens
  fracionados preservados, dois pedidos do mesmo vendedor, edição isolada,
  reabertura e isolamento entre vendedores.
- A interface é testada para listar e reabrir um rascunho pelo fluxo de Meus
  Pedidos até o carrinho.
- `flutter analyze`: sem erros. Permanecem cinco avisos preexistentes de código
  não usado e uma API de formulário depreciada, fora deste escopo.
- APK debug gerado em `build/app/outputs/flutter-apk/app-debug.apk`.

## Roteiro Samsung

1. Atualize o APK e entre com o vendedor que possui o rascunho antigo.
2. Abra `Meus Pedidos`; confirme que o rascunho existente aparece com os itens.
3. Crie um segundo pedido, salve e confirme que os dois cartões aparecem.
4. Reabra apenas um, altere a quantidade e salve. Confirme que o outro não foi
   modificado.
5. Feche o aplicativo completamente, abra novamente e confirme a lista.
6. Entre com outro vendedor e confirme que os rascunhos do primeiro não aparecem.
