# Consolidação do desenvolvimento — App de Malhas Confecção

**Data:** 23/10/2026  
**Escopo:** registro consolidado do desenvolvimento e da auditoria realizada nesta data. Este documento não representa envio, recepção, sincronização ou conversão comercial implementados.

## Aplicativo local

O Flutter usa uma API local autenticada para login, clientes vinculados ao vendedor, produtos e formas de pagamento. Empresa e vendedor não são escolhidos livremente pelo cliente móvel: são derivados da sessão e a API mantém a autorização comercial. A conectividade permanece restrita ao desenvolvimento local por USB/ADB reverse na porta 5056.

No Novo Pedido, o vendedor informa cliente, pagamento, observações, prazo de entrega em dias corridos, previsão calculada e Gerencial (Sim/Não, obrigatório). O cliente pode ser oficial ou provisório local. Produtos mantêm unidade comercial, quantidade positiva inteira ou fracionada conforme a regra existente e preço unitário não editável.

O preço comercial vem de `TB_PRODUTO.PRD_PRECO_VENDA` através de `GET /api/v1/catalogo/produtos-touch`, serializado como decimal textual. O aplicativo calcula subtotal e total por escala inteira/`BigInt`, não por ponto flutuante. Se o preço estiver ausente ou inválido, ele é exibido como indisponível; não é convertido em zero e o pedido não pode ser salvo com total financeiro incorreto.

O carrinho possui duas colunas de seleção na aba Itens, acúmulo do mesmo produto, edição, exclusão confirmada, lixeira vermelha, totais quantitativos por unidade e total financeiro. Cliente, pagamento e observações são preservados na navegação.

## SQLite e pedidos locais

O armazenamento local está na versão 4 e conserva compatibilidade com pedidos anteriores. Ele mantém múltiplos pedidos por empresa/vendedor, cliente e itens, quantidades e unidades, preços decimais textuais, prazo, gerencial, observações e identificador local do pedido. Salvar novamente atualiza o mesmo pedido; Novo Pedido pode criar outro sem sobrescrever os existentes.

Os clientes provisórios permanecem em estrutura local separada, com identificador estável prefixado no pedido, dados PF/PJ, situação pendente e campo preparado para futuro ID oficial. Não são tratados como clientes Firebird. O isolamento por empresa/vendedor é obrigatório tanto para pedidos quanto para clientes provisórios.

Meus Pedidos mostra somente o que existe localmente como pendente de envio. Meus Clientes reaproveita a consulta oficial já autorizada pela API e agrega o cliente provisório do usuário autenticado, com identificação visual distinta. Não há pedidos demonstrativos, preços fictícios, senha ou token armazenado junto ao pedido.

## Evidências de validação

- `flutter test`: 13 testes aprovados.
- API: `py -3 -m unittest discover -s api/tests -v`: 12 testes aprovados.
- `flutter analyze`: sem erros; 22 avisos/informações preexistentes de estilo, itens não usados e API Flutter depreciada.
- APK debug: `build/app/outputs/flutter-apk/app-debug.apk`, gerado em 23/10/2026 às 16:00.

O usuário já informou como homologados no Samsung o carrinho, SQLite com múltiplos pedidos e isolamento, confirmação/retorno à Home e Meus Clientes. A validação manual específica da correção de preços e do layout comercial atual continua pendente. O histórico detalhado está em [CORRECAO_PRECOS_E_LAYOUT_20261023.md](CORRECAO_PRECOS_E_LAYOUT_20261023.md).

## Recepção no ParmaGestor: conclusão da auditoria

A recepção tradicional existe e deve ser preservada. Ela usa `TB_RECEPCAO_PEDIDO` e `TB_RECEPCAO_PEDIDO_ITEM`, telas Delphi de recepção, controles comerciais e conversão para Pedido de Venda. Esse fluxo pressupõe regras convencionais, cliente oficial, tabela/preço e controles de crédito; portanto, não é adequado como destino direto de pedidos de Malhas com cliente provisório.

A decisão técnica recomendada é uma recepção exclusiva para Malhas, reaproveitando a infraestrutura Delphi, FireDAC, HTML/CSS/JavaScript e WebView2 do Painel de Estoque Confecção no ParmaDistribuidora. A arquitetura e as etapas estão documentadas em:

- `E:\PARMASOFT_INTEGRACAO\Documentos\ARQUITETURA_RECEPCAO_MALHAS_20261023.md`
- `E:\PARMASOFT_INTEGRACAO\Documentos\PROXIMAS_ETAPAS_RECEPCAO_MALHAS_20261023.md`

## Limitações explícitas

- Sem envio ou sincronização de clientes/pedidos.
- Sem painel implementado e sem tabelas Firebird novas.
- Sem conversão para Pedido de Venda, emissão fiscal ou alteração comercial automática.
- Preços recebidos futuramente serão snapshots comerciais; o servidor deverá validar novamente antes de qualquer ação operacional.

## Ponto de retomada

A única próxima ação proposta é redigir o DDL Firebird 2.5 das quatro tabelas exclusivas de recepção para revisão humana, sem executá-lo. A implantação posterior deverá passar por conferência do banco-alvo no IBExpert Database Comparer.
