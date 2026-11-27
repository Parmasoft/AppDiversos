# Status — Etiquetas de Confecção

Atualizado em: **08/10/2026** (America/Sao_Paulo)  
Escopo: etiquetas de rolo, separação, conferência, faturamento e estoque do fluxo exclusivo de Confecção.

## Estado atual

O teste integrado F + C do Pedido de Venda 19900 foi concluído com sucesso quanto à identidade dos rolos, conferência, faturamento e estoque. O formato F22 é exclusivo da Confecção; o R18 legado da GramDecor permanece sem alteração. Há uma pendência isolada de precisão no registro-resumo da separação 608: `5,2619` versus a soma física e a baixa de `5,2620`.

Nada desta atualização documental altera banco, código ou configuração operacional.

## Decisões de arquitetura vigentes

### R18 legado da GramDecor: preservado

O banco e o estoque trabalham com quatro casas decimais. Isso foi comprovado por quantidades como `7,0050` e `0,5180`. A limitação estava no contrato R18:

```text
R + PROR_ID(6) + PRODUTO(7) + QUANTIDADE(4)
quantidade = Round(quantidade * 10)
```

Exemplo real: o `PROR_ID 12928`, com `7,0050`, possui o código `R01292810002450070`; o texto transporta somente `7,0`, embora o banco preserve `7,0050`.

Portanto, **não alterar** formato R, leitores R, `SP_RESOLVE_CODIGO_ROLO`, separação, conferência ou outra rotina legada da GramDecor para resolver requisito da Confecção. Reuso é permitido somente quando não muda o legado. Toda regra adicional da Confecção deve existir em caminho, componente, procedure e/ou script próprios.

### F22 exclusivo da Confecção

O contrato implantado no App/API é:

```text
F + PROR_ID(6) + PRODUTO(7) + QUANTIDADE(8)
quantidade codificada = quantidade × 10000
```

São 22 caracteres. O campo de oito dígitos permite de `0,0001` a `9.999,9999`; o App/API valida exatamente `F` seguido de 21 dígitos e decodifica os últimos oito por `10000`. F22 não é evolução nem substituição global do R18 e não deve ser tornado compatível com o fluxo GramDecor.

O `PROR_ID` é o CPF permanente do rolo. Produto e peso não são identidade suficiente: dois rolos podem ter ambos iguais. Reimpressão do mesmo CPF não cria entrada de estoque; etiquetagem, separação, conferência e futura carga devem preservar essa identidade.

### Isolamento da Confecção

O desenho aprovado mantém telas/classes/DataModules, balança, impressora, seções de INI (`[CONFECCAO_BALANCA]`, `[CONFECCAO_ARGOX]`), procedures e conferências de pedido/carga próprios quando forem necessários. Configuração, regra ou tela legada só pode ser reutilizada sem alteração de seu comportamento.

## Trabalho realizado em 05/10/2026

### Precisão e validação do F

O problema inicial era reconstruir/comparar texto de etiqueta a partir da quantidade, abordagem que perde precisão no R18. No F22 a validação passou a ser estrutural:

```text
etiquetagem -> separação aplicada -> PROR_ID separado -> conferência/carga do mesmo PROR_ID
```

Além de empresa, produto e quantidade impressos, deve ser validado que o `PROR_ID` existe, está ativo e está realmente vinculado à separação aplicada do pedido. Um rolo F válido do mesmo produto não pode ser aceito apenas por pertencer ao produto pedido.

Fontes rastreados nesta árvore:

- `../api/app.py`: `F22_ROLO_RE`, `resolver_codigo_f22()` e `GET /rolos/consultar-f22`; valida empresa, `PROR_ID`, produto, quantidade com `Decimal` e status do rolo sem usar o resolvedor R legado.
- `../api/app.py`: `/pedidos/separacao/salvar` aceita F22 separadamente, extrai o `PROR_ID` do código físico, persiste o código F no histórico, revalida produto/quantidade/rolo e recompõe o total do produto F pelas leituras revalidadas.
- `lib/pages/scanner_page.dart`: aceita F22 somente quando o chamador o solicita (`aceitarF22Pedidos`).
- `lib/pages/separacao_rolos_page.dart`: consulta o endpoint F22, evita repetição por `PROR_ID` e abre o scanner com F22 habilitado apenas na separação de pedido.

Os trechos legados R/C permaneceram como rotas próprias; C continua sem `PROR_ID` (`PVSR_PROR_ID=0`).

### Balança Toledo

Em homologação, a Toledo respondeu ao comando ASCII `R`, sem CR/LF, com `RWN0005.00kg`; o parser retornou corretamente `5,00`, e a tela foi ajustada à apresentação esperada. A configuração usada é temporária de homologação. Antes de implantação, é obrigatório parametrizar por estação modelo, porta, baud rate, data bits, paridade, stop bits e demais parâmetros, seguindo o padrão do Frente Fiscal. Durante o teste foi necessário restaurar temporariamente a configuração Toledo e preservar a alternativa para uso posterior.

### Script/Delphi

O comando de trabalho informa `actScript199 / 1.1.0.99` e objetos exclusivos de Confecção. Nesta cópia acessível não foram encontrados o arquivo do actScript, o repositório Delphi, classes, formulários, menus ou o registro de Controle de Versão; portanto não é possível afirmar daqui os objetos exatos nem se o script foi aplicado. A auditoria somente leitura confirmou que as tabelas usadas pelo fluxo estão presentes no banco de homologação (`TB_PRODUTO_ROLO`, `TB_CONFECCAO_ROLO_OPERACAO`, `TB_PEDIDO_VENDA_SEPARACAO*`), mas isso não substitui a verificação do Controle de Versão. Na retomada, conferir o fonte/registro original antes de alterar ou reaplicar qualquer script.

## Teste de ponta a ponta — Pedido 19900, empresa 10

### Preparação e separação

- Grampo `1000923 — GRAMPO EDANTEX 80/06 COM 10MIL`: etiqueta C `C01990010009230010000`, duas caixas.
- Malha `1000244 — MALHA AMARELA 100`: pedido inicialmente com `7,1600 MT`.
- Rolos produzidos:
  - `F012975100024400016180` — `PROR_ID 12975` — `1,6180 MT`;
  - `F012976100024400021200` — `PROR_ID 12976` — `2,1200 MT`;
  - `F012977100024400031420` — `PROR_ID 12977` — `3,1420 MT`.
- Foram separados propositalmente apenas `2,1200 + 3,1420 = 5,2620 MT`. A diferença original de `1,8980` foi intencional: o processo normal ajustou o pedido à quantidade efetivamente atendida. Não tratá-la como falha.

### Conferência decisiva

Primeiro foi lido o `PROR_ID 12975` (`1,6180`). Embora existente e do produto correto, não pertencia à separação do Pedido 19900 e foi recusado com **“Rolo não separado para este pedido.”**. Em seguida, 12976 e 12977 foram aceitos, assim como a etiqueta C do grampo. A tela encerrou em `2/2 — 100%`, Total Pedido `7,26`, Total Coletado `7,26`, Diferença `0,00`.

Isso confirma a regra: para F22, existência e produto não bastam; o vínculo prévio do `PROR_ID` à separação aplicada é obrigatório.

## Auditoria somente leitura posterior

Consultas de auditoria foram feitas sem DML e encerradas com `ROLLBACK`.

| Evidência | Resultado |
|---|---|
| Pedido 19900 faturado | itens oficiais: grampo `2,0000 CX`; malha `5,2620 MT` |
| Vínculos F da separação 608 | somente 12976 (`2,1200`) e 12977 (`3,1420`), total `5,2620` |
| Rolo 12975 | `PROR_STATUS='A'`, sem vínculo em `TB_PEDIDO_VENDA_SEPARACAO_ROLO` e sem saída de venda |
| Confecção | uma operação e uma entrada por rolo: 12975=`1,6180`, 12976=`2,1200`, 12977=`3,1420` |
| Baixa MALHA | `TB_PRODUTO_MOVIMENTO`, seq. 19, `SAI 5,2620`, origem `VENDA 19900` |
| Baixa GRAMPO | seq. 87, `SAI 2,0000`, origem `VENDA 19900` |
| Duplicidade | não encontrada: um vínculo por rolo F usado, uma entrada por rolo e uma saída de venda por produto |
| Razão MALHA | `23,6500 + 27,1000 - 23,0820 = 27,6680`, igual a `PRD_ESTOQUE` |
| Razão GRAMPO | `51,0000 + 1.348,0000 - 308,0000 = 1.091,0000`, igual a `PRD_ESTOQUE` |

As três entradas F somaram `6,8800`; a única saída da venda foi `5,2620`; o saldo líquido específico é `1,6180`, exatamente o rolo 12975. A tentativa rejeitada não possui log próprio de rejeição, mas não deixou efeito colateral detectável em vínculo, movimento ou saldo.

## Pendência única deste teste

Não confundir a falta intencional de `1,8980` com a pendência abaixo.

A separação 608 persistiu dados-resumo inconsistentes:

- cabeçalho: vendido `9,1600`, separado `7,2620`, diferença `-1,8980`;
- item MALHA: vendido `7,1600`, separado `5,2619`, diferença `-1,8980`;
- rolos efetivamente vinculados e baixa de estoque: `5,2620`.

A divergência de `0,0001` (`5,2619` x `5,2620`) não foi corrigida nem investigada nesta data. Próxima retomada, exclusivamente em leitura inicialmente:

1. reproduzir o `SELECT` e registrar tabela/campo exatos;
2. rastrear a rotina Delphi/SQL que grava/calcula `PVSI_QTDE_SEPARADA` e os totais;
3. verificar precisão, truncamento e conversões `Double`/`Float`/`Currency`;
4. determinar se a divergência é só informativa ou pode atingir etapa posterior;
5. somente então propor correção autorizada.

## Próxima retomada

1. Investigar a precisão `5,2619 x 5,2620` sem alterar dados.
2. Abrir o repositório Delphi/Controle de Versão para conferir `actScript199 / 1.1.0.99`, seus objetos, aplicação e os componentes exclusivos da Confecção.
3. Antes de implantação, concluir a parametrização da Toledo por estação.
4. Preservar R18/GramDecor e não ampliar F22 para caminhos legados.

## Atualizacao de 08/10/2026 - homologacao operacional de duas casas: Pedido 20119

### Cenario aprovado

O cenario da empresa `10`, Pedido `20119`, Separacao `609` e Conferencia `26`
foi homologado como **APROVADO NO CENARIO HOMOLOGADO**. A Conferencia foi
finalizada em 08/10/2026 08:17:06 com `5/5`, `100%`, Total Pedido `18,5400`,
Total Coletado `18,5400` e Diferenca `0,0000`.

Na separacao de pedidos, sete F22 (`PROR_ID 12978` a `12984`) foram vinculados
e depois conferidos corretamente pelo mesmo `PROR_ID`, produto, codigo F22 e
quantidade oficial. Nenhum rolo F22 foi duplicado ou vinculado indevidamente.
Etiquetas C foram processadas corretamente; tres leituras identicas de
`1,0000 CX` pertencem ao item de `3,0000 CX` e sao validas porque C e uma
etiqueta quantitativa, sem identidade fisica de rolo (`PVSR_PROR_ID=0`).

O ajuste automatico do pedido tambem foi validado: para o produto `1004774 -
MALHA MESCLADA 060`, o pedido original era `6,1500 MT` e o operador separou
propositalmente `6,0000 MT`. O ERP ajustou o Pedido de Venda para `6,0000 MT`
e preservou, na fotografia historica da Separacao, solicitado `6,1500`,
separado `6,0000` e diferenca `0,1500`. Esta diferenca e intencional, esperada
e validada; nao representa defeito.

### Precisao operacional vigente

A Confeccao passara a operar normalmente com **duas casas decimais**, de acordo
com a balanca e a necessidade atual. Isso nao reduz a capacidade estrutural:

- banco continua `NUMERIC(15,4)`;
- F22 permanece com oito digitos de quantidade e `quantidade * 10000`;
- formatos F22, C e R18 permanecem inalterados;
- valores persistidos nao podem ser arredondados ou truncados silenciosamente.

### Pendencia historica de quatro casas

O Pedido `19900`, Separacao `608`, permanece como pendencia documental: os
rolos F22 `2,1200 + 3,1420` somam `5,2620`, mas o resumo do item persistiu
`5,2619`; faturamento interno e saida de estoque foram `5,2620`. A causa nao
foi identificada nem corrigida. O teste 20119, feito com duas casas, nao
reproduziu `0,0001`, mas nao demonstra correcao nem impossibilidade do problema
em tres/quatro casas. Nao bloquear o avanco atual por esse caso isolado; antes
de homologar operacao com tres ou quatro casas, executar nova auditoria de
precisao em leitura.

Referencias cruzadas: resultado de conferencia, faturamento interno,
movimentacoes e saldos constam em
`E:\Repositorio_Parmasoft\ParmaDistribuidora\Source\Documentacao\STATUS_ETIQUETAS_CONFECCAO.md`.
Nenhum fonte Flutter/Python, banco, API, etiqueta ou configuracao foi alterado
por esta atualizacao documental.
