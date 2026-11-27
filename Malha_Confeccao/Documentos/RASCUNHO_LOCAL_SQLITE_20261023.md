# Rascunho local SQLite — 23/10/2026

## Escopo concluído

O carrinho passa a oferecer **Salvar rascunho** exclusivamente no aparelho.
Não há envio de pedido, sincronização, gravação pela API, alteração no Firebird
ou persistência de token e senha.

## Comportamento

- O rodapé do carrinho mantém a quantidade de produtos diferentes e os totais
  separados por unidade de medida.
- O botão amarelo `Salvar rascunho` só aparece com itens no carrinho e só
  confirma sucesso depois que a transação SQLite é concluída.
- Cada rascunho recebe identificador local, estado `RASCUNHO_LOCAL`, data de
  criação e data de atualização.
- Um novo toque em salvar para a mesma empresa e vendedor atualiza o mesmo
  rascunho; não cria uma segunda linha de cabeçalho.
- Ao abrir novamente `Novo Pedido`, o aplicativo localiza automaticamente o
  rascunho ativo da empresa e do vendedor autenticados e recompõe cliente,
  forma de pagamento, observações e itens.
- Rascunhos são isolados pela chave `empresa:vendedor`. Não existe tela de
  lista nesta etapa.

## Dados locais gravados

Cabeçalho: identificador local, empresa, vendedor, status, cliente, forma de
pagamento, observações e datas. Itens: identificador real do produto,
descrição, unidade e quantidade `REAL` positiva. Quantidades fracionadas são
mantidas como `double`; a interface as apresenta no formato pt-BR.

Não são gravados access token, senha, preço ou total financeiro.

## Arquivos

- `lib/local_draft_store.dart`: banco SQLite e contratos do rascunho.
- `lib/main.dart`: recuperação automática, ação de salvar e rodapé do carrinho.
- `test/local_draft_store_test.dart`: persistência, reabertura, atualização e
  isolamento entre vendedores.
- `test/widget_test.dart`: interação do botão no carrinho.

## Validação em 23/10/2026

- `flutter test`: aprovado, 5 testes.
- `flutter analyze`: sem erros; 5 avisos já existentes no arquivo de interface
  (elementos não usados e uma API de formulário depreciada), não relacionados
  ao SQLite.
- APK debug gerado em `build/app/outputs/flutter-apk/app-debug.apk`.

## Roteiro de homologação Samsung

1. Entre com um vendedor, monte o carrinho com um item inteiro e outro
   fracionado, informe cliente/pagamento/observação e toque em `Salvar rascunho`.
2. Feche o aplicativo completamente e abra-o de novo com o mesmo vendedor.
3. Abra `Novo Pedido` e confirme os dados, itens, unidades e totais.
4. Edite uma quantidade, salve novamente e repita a abertura: deve haver um
   único rascunho atualizado.
5. Entre com outro vendedor da mesma empresa: o rascunho anterior não deve ser
   exibido.
