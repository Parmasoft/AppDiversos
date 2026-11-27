# Meus Clientes — 23/10/2026

## Implementação

- O botão `Meus Clientes` da Home abre a nova tela com cabeçalho amarelo,
  pesquisa, contador, cartões e rolagem vertical.
- A tela reutiliza `GET /api/v1/catalogo/clientes?termo=...` e o mesmo Bearer
  token utilizado no Novo Pedido. Não existe uma segunda regra de autorização
  nem filtro de vendedor controlado pelo Flutter.
- A API determina empresa e vendedor a partir da sessão do token. Os campos
  retornados e exibidos são `id`, `nome` e `fantasia`; cidade e UF não são
  retornados e, por isso, não são inventados.
- O toque no cartão abre uma visualização cadastral somente leitura.
- `+ Novo Cliente (em breve)` permanece propositalmente indisponível, sem
  cadastro, gravação ou chamada à API.

## Limitação conhecida da API existente

A consulta atual exige ao menos três caracteres e retorna até 30 resultados no
servidor. A tela mostra todos os resultados recebidos, sem qualquer limite
adicional. A comparação local dos resultados normaliza maiúsculas/minúsculas e
acentos; a busca inicial continua sujeita à collation do Firebird/API.

## Segurança

O endpoint usa `empresa` e `vendedor` extraídos pelo servidor da sessão Bearer.
O aplicativo não envia esses valores como filtros livres.

## Arquivos alterados

- `lib/main.dart`
- `test/widget_test.dart`

## Validação

- `flutter test`: 11 testes aprovados, cobrindo pesquisa, listagem, detalhe,
  vazio, erro e navegação pela Home.
- `flutter analyze`: sem erros; 5 avisos preexistentes fora deste escopo.
- `python -m unittest tests.test_catalog_routes`: 3 testes aprovados,
  incluindo empresa e vendedor derivados da sessão na rota de clientes.
