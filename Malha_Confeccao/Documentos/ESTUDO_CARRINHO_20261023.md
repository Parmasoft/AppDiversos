# Estudo do carrinho — 23/10/2026

## Escopo desta etapa

Foram inspecionados apenas para leitura os projetos `E:\Jorginho\Pedido` e `E:\Jorginho\Pedido_Pgto`. Nenhum arquivo dos projetos de referência, da API, do Firebird ou do Delphi foi alterado. Este estudo não implementa carrinho novo nem gravação de pedido.

## Onde está o carrinho

Os dois projetos possuem carrinho completo.

| Elemento | Pedido | Pedido_Pgto |
| --- | --- | --- |
| Modelo de item | `pedido_app/lib/models/item_carrinho.dart` | `pedido_app/lib/models/item_carrinho.dart` |
| Estado e botão/contador | `pedido_app/lib/pages/menu_page.dart` | `pedido_app/lib/pages/menu_page.dart` |
| Tela do carrinho | `pedido_app/lib/pages/carrinho_page.dart` | `pedido_app/lib/pages/carrinho_page.dart` |
| Inclusão de produtos | `pedido_app/lib/pages/produtos_page.dart` e `pedido_app/lib/pages/produto_busca_page.dart` | `pedido_app/lib/pages/produtos_page.dart` e `pedido_app/lib/pages/produto_busca_page.dart` |

Em ambos, a `MenuPage` mantém a lista mutável de `ItemCarrinho`, agrega o mesmo produto ainda não existente e abre a `CarrinhoPage` com `MaterialPageRoute`. O `Pedido` mostra uma barra inferior condicional com ícone de carrinho e a quantidade de linhas. O `Pedido_Pgto` mantém uma barra inferior de carrinho mais completa, com estado vazio, resumo e ação “Ver carrinho”.

## Comparação

O `Pedido` é menor e mais direto, mas seu carrinho é voltado a finalizar a comanda em endpoint próprio e a exclusão local é simples. Não há fluxo visual de consulta de venda já existente.

O `Pedido_Pgto` contém a evolução mais adequada como referência de interface e comportamento: diferencia visualização de edição (`somenteVisualizacao`), recarrega os itens da API quando necessário, trata quantidade fracionada/unidade, oferece edição/exclusão e navega para pagamento. As transições existentes são pontuais (`MaterialPageRoute` e `AnimatedPadding` em modal); não há uma animação de carrinho que deva ser copiada.

## Recomendação para o App de Malhas

Usar o desenho funcional do `Pedido_Pgto` como referência, porém recriado em componentes próprios do App de Malhas:

1. Modelo local de linha baseado no atual `_OrderLine`, sem campos de preço ou integração de gravação.
2. Estado do rascunho concentrado em uma tela/controlador do pedido, sem reutilizar módulos dos referenciais.
3. Barra inferior com contador de linhas e acesso à visualização do rascunho.
4. Tela de carrinho com editar quantidade e excluir linha, preservando unidades e os dados já lidos da API.
5. Navegação com `MaterialPageRoute`; animações discretas apenas depois da validação do fluxo.

O botão de finalizar deve permanecer ausente ou explicitamente não operacional até que a gravação seja autorizada e contratada por API.

## Alterações realizadas nesta etapa

- Removido somente o aviso “Dados exclusivamente fictícios para avaliação visual.” da aba Pedido.
- Atualizados os cartões de produto da aba Itens: duas colunas preservadas, borda reforçada, sombra discreta de alto-relevo, ícone com fundo e destaque/animação na seleção.

## Validação técnica

- `flutter analyze`: executado; não apontou erro, mas há 7 avisos preexistentes de elementos não utilizados e um uso de API deprecada em `lib/main.dart`.
- `flutter test`: executado; a única suíte falhou antes de alcançar as telas alteradas porque `test/widget_test.dart:25` ainda espera o texto “Entrar no modo demonstrativo”, que não existe na tela atual. Não foi alterado por estar fora deste escopo visual.

## Próximo passo recomendado

Validar visualmente os cartões em aparelho Samsung e aprovar o modelo de carrinho inspirado no `Pedido_Pgto`. Após a aprovação, detalhar o rascunho local e a tela de revisão sem implementar gravação real de pedidos.
