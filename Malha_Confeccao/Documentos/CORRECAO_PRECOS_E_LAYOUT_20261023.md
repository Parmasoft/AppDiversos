# Correção de preços e layout — 23/10/2026

## Diagnóstico confirmado

A API local em `127.0.0.1:5056` estava em execução desde 13:21, enquanto a
alteração que inclui `TB_PRODUTO.PRD_PRECO_VENDA` em
`GET /api/v1/catalogo/produtos-touch` foi gravada às 15:35. Assim, o Samsung
consultava uma instância anterior, que não enviava `preco_unitario`.

A API foi reiniciada pelo inicializador local existente e passou a atender às
15:55, sempre restrita a `127.0.0.1`.

Foi realizada consulta somente leitura pelo acesso já configurado e validado o
contrato da rota usando sessão simulada, sem expor credenciais ou tokens. Para
empresa 1, a rota retornou as strings decimais abaixo:

| Produto | `preco_unitario` |
| --- | ---: |
| 4573 | `319.9` |
| 4582 | `349.9` |
| 4760 | `49.9` |
| 4585 | `349.9` |

O filtro de empresa permanece derivado exclusivamente da sessão autenticada.

## Correções realizadas

- `api/app/catalog/service.py`: mantém a consulta de `PRD_PRECO_VENDA` e a
  serialização como string decimal, sem `float`.
- `api/tests/test_catalog_service.py`: novos testes da consulta e da
  serialização decimal; preço nulo ou inválido é retornado como indisponível,
  nunca convertido em zero.
- `lib/main.dart`:
  - preço unitário, subtotal e total usam cálculo em escala inteira;
  - itens sem preço válido exibem indisponibilidade e não podem ser adicionados
    nem salvos;
  - itens antigos sem preço continuam acessíveis, mas o total financeiro fica
    indisponível e o botão Salvar pedido é bloqueado até a atualização do
    catálogo/itens; nenhum preço é inventado ou substituído por R$ 0,00;
  - área de inclusão reorganizada em quantidade + preço unitário, total do
    item e botão de adição;
  - cartões do carrinho exibem preço unitário e subtotal;
  - prazo e previsão de entrega ficam lado a lado; a previsão é somente
    leitura;
  - título alterado para `GERENCIAL?` e removido somente o texto explicativo.
- `test/widget_test.dart`: valida preço unitário e subtotal no fluxo Flutter.

Não houve alteração de Firebird, Delphi, envio, sincronização, painel ou
reprecificação de pedidos já salvos.

## Validação executada

- `flutter test`: 13 testes aprovados.
- `py -3 -m unittest discover -s api/tests -v`: 12 testes aprovados.
- `flutter analyze`: sem erros; permanecem 22 avisos/informações preexistentes
  de estilo, elementos legados e APIs Flutter depreciadas.
- `flutter build apk --debug`: concluído em 23/10/2026 às 16:00. Artefato:
  `build/app/outputs/flutter-apk/app-debug.apk`.

## Homologação pendente no Samsung

1. Atualizar/instalar o APK debug gerado nesta entrega.
2. Confirmar no Novo Pedido, aba Itens, os preços dos quatro produtos acima.
3. Adicionar, por exemplo, 10 UN do produto 4573 e conferir R$ 319,90
   unitário e R$ 3.199,00 no subtotal/total do carrinho.
4. Abrir um pedido local anterior sem preço: deve mostrar indisponibilidade e
   impedir o salvamento, sem mostrar R$ 0,00.

