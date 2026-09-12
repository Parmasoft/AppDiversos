# Último ponto de parada técnico

Atualizado em: **01/09/2026**  
Projetos envolvidos: **ERP Delphi Parmasoft**, **API Flask** e **aplicativo Flutter BarCodeNovo**.

## 1. Finalidade deste documento

Este arquivo consolida o estado real encontrado no código, as decisões tomadas durante o desenvolvimento do módulo de Requisição de Transferência, os testes já informados, os pontos ainda não comprovados e a próxima etapa segura.

Antes de qualquer nova alteração, devem ser lidos integralmente:

- `C:\Repositorio_Nuvem\ParmaDistribuidora\Source\Documentacao\AGENTS.md`;
- `C:\Repositorio_Nuvem\ParmaDistribuidora\Source\Documentacao\STATUS_REQUISICAO_TRANSFERENCIA.md`;
- este arquivo.

Os arquivos atuais no disco continuam sendo a fonte de verdade. Não executar WES, SQL de alteração, movimentação de estoque ou mudança adicional de status sem autorização expressa para a etapa.

## 2. Caminhos principais

- ERP Delphi: `C:\Repositorio_Nuvem\ParmaDistribuidora`
- Controle de Versão do banco: `C:\Repositorio_Nuvem\Global\Source\Model\UDmControleVersao.pas/.dfm`
- Documentação do ERP: `C:\Repositorio_Nuvem\ParmaDistribuidora\Source\Documentacao`
- Aplicativo Flutter: `C:\Projetos Flutter\BarCode\BarCodeNovo`
- API Flask ativa no desenvolvimento: `C:\Projetos Flutter\BarCode\api\app.py`
- Banco indicado na documentação: `C:\Parmasoft\Dados\GramDecor\Dados.fdb`
- Saída Debug/Win32 do ERP: `C:\Repositorio_Nuvem\ParmaDistribuidora\Bin\ParmaGestor.exe`

Sempre conferir `get_connection()` em `api/app.py` antes de assumir qual banco está sendo acessado.

## 3. Fluxo funcional oficial

O módulo novo é independente da transferência de estoque antiga.

Fluxo oficial:

1. A filial cria a requisição.
2. A filial inclui, altera ou exclui fisicamente itens enquanto a capa está em `A`.
3. A matriz libera a requisição, fazendo `A -> L`.
4. O operador assume a separação no aplicativo, fazendo `L -> S` por procedure.
5. Os produtos são separados por leituras de etiquetas `C` ou `R`.
6. Futuramente ocorrerá `S -> C` para carga.
7. Futuramente a filial fará a conferência/recebimento e o processo chegará a `F`.

Status oficiais:

- `A`: aberta;
- `L`: liberada para separação;
- `S`: em separação;
- `C`: em carga;
- `F`: finalizada;
- `X`: cancelada.

O cadastro e a separação implementados até este ponto **não movimentam estoque**.

## 4. Decisões consolidadas

### 4.1 Decisões vigentes

- A navegação superior `Pedidos / Requisições` foi aprovada.
- O módulo de Requisições permanece dentro do aplicativo existente; não será criado outro aplicativo.
- O funcionamento de Separação de Pedidos deve ser preservado.
- Scanner, parser de etiquetas e componentes visuais podem ser compartilhados, mas tabelas, regras, status e endpoints de Requisições permanecem separados dos de Pedidos.
- A tela de separação do item da requisição segue o padrão visual da tela de Separação de Pedidos.
- A identificação visual/local das etiquetas `C` e `R` foi testada e aprovada.
- A etiqueta `C` oficial para Requisições possui exatamente 21 caracteres:
  - `C + requisição(6) + produto(7) + quantidade x 10000(7)`.
- O formato antigo de etiqueta `C` com 19 caracteres não deve ser aceito em Requisições.
- A etiqueta `R` possui exatamente 18 caracteres.
- A validação no Flutter serve para resposta rápida; a validação definitiva pertence à procedure, dentro da transação.
- O início da separação não é silencioso: ao tocar no primeiro item de uma requisição `L`, o aplicativo pergunta se o usuário deseja iniciar a separação.
- A mudança `L -> S` ocorre somente após retorno positivo de `SP_INICIA_SEP_TRANSF_REQ`.
- Requisições em `S` devem continuar aparecendo para retomada pelo operador do fluxo atual.
- O salvamento de várias leituras usa uma única transação da API: ou todas são aceitas e há um único `commit`, ou qualquer falha causa `rollback` total.
- O Flutter não envia nem controla o total separado como fonte de verdade; a procedure atualiza e retorna os totais.
- Ainda não implementar `S -> C`, finalização, recebimento ou movimentação de estoque.

### 4.2 Identidade do operador

A discussão de autenticação foi congelada.

Decisão vigente:

- não implementar login no aplicativo;
- não implementar token;
- não implementar sessão;
- não criar infraestrutura nova de autenticação;
- continuar usando `P_USUARIO` conforme o padrão simples atual do ERP/aplicativo;
- tratar eventual autenticação individual em projeto futuro separado.

Estado concreto do Flutter: `RequisicaoTransferenciaService.daConfiguracao()` define atualmente `usuarioAtual: 1`. Isso é uma solução temporária do padrão atual, não autenticação concluída.

### 4.3 Decisões antigas que não devem ser retomadas

- O tutorial antigo menciona `TRQ_STATUS = 'P'`. Essa informação foi superada; o fluxo oficial usa `A -> L -> S -> C -> F`, além de `X`.
- A proposta intermediária de login com sessão/token foi explicitamente desconsiderada por enquanto.
- A fase inicial somente visual, que proibia persistência e `L -> S`, já foi superada pela autorização posterior para implementar API e Flutter sobre o `actScript167h`.

## 5. Estado do ERP Delphi — Requisição de Transferência

A etapa de cadastro/persistência dos itens da filial foi informada pelo desenvolvedor como concluída e testada.

Arquivos principais:

- `Source/Controller/UClassTransfReq.pas`
- `Source/Model/UDMTransfReq.pas`
- `Source/Model/UDMTransfReq.dfm`
- `Source/View/Mov/UMovTransfReq.pas`
- `Source/View/Mov/UMovTransfReq.dfm`
- `Source/View/Mov/UManTransfReq.pas`
- `Source/View/Mov/UManTransfReq.dfm`
- `Source/View/Mov/UManTransfReqItem.pas`
- `Source/View/Mov/UManTransfReqItem.dfm`
- `Source/View/Mov/UManImpressaoEtiquetaTransfReq.pas`
- `Source/View/Rel/URelTransfReqEtiquetas.pas`

Comportamento consolidado da filial:

- inclusão, alteração e exclusão de item ficam centralizadas em `TClassTransfReq.FinalizarCadastroItem`;
- cada item é persistido individualmente, sem depender da confirmação final da capa;
- inclusão chama `SP_INC_ITEM_TRANSF_REQ`;
- alteração chama `SP_ALTERA_ITEM_TRANSF_REQ`;
- exclusão em `A` é física, parametrizada e restrita à empresa solicitante;
- inclusão e alteração usam `P_OBSERVACAO`;
- inclusão rejeita produto inativo;
- unidade usa `PRD_UN_VENDA` e, se vazia, `PRD_UN_COMPRA`;
- alteração permite somente quantidade e observação;
- quantidade deve ser maior que zero;
- totais consideram itens com `TRQI_STATUS <> 'C'`;
- confirmação da filial exige item ativo, mas mantém a capa em `A`;
- a matriz é responsável por `A -> L` através de `Liberar Separação`;
- `F10` exclui fisicamente o item durante a elaboração em `A` e foi informado como testado com sucesso.

Não alterar `TDMBase`, `TGlobal`, formulários padrão ou infraestrutura compartilhada para continuar este módulo.

## 6. Controle de Versão do banco

Fonte ativa:

- `C:\Repositorio_Nuvem\Global\Source\Model\UDmControleVersao.pas`
- `C:\Repositorio_Nuvem\Global\Source\Model\UDmControleVersao.dfm`

No fonte principal estão declarados, ordenados e implementados:

- `actScript167f` / `1.1.0.67f`;
- `actScript167g` / `1.1.0.67g`;
- `actScript167h` / `1.1.0.67h`.

O `actScript167h` foi incluído e compilado com sucesso, conforme confirmação do desenvolvedor.

### 6.1 actScript167f

Cria, de forma protegida, as estruturas próprias da separação de Requisições:

- `TB_TRANSF_REQ_SEPARACAO`;
- `TB_TRANSF_REQ_SEP_LEITURA`.

`TB_TRANSF_REQ_SEPARACAO` armazena empresa matriz, requisição, status da separação, início/usuário, finalização/usuário e observações. A chave primária é `TRQS_EMPRESA_MATRIZ + TRQS_REQUISICAO`.

`TB_TRANSF_REQ_SEP_LEITURA` armazena empresa, requisição, sequência, item, produto, código completo, tipo `C/R`, documento de origem, rolo, quantidade, status `A/E`, inclusão/usuário, estorno/usuário e observações.

### 6.2 actScript167g

Atualiza:

- `SP_INC_ITEM_TRANSF_REQ`;
- `SP_ALTERA_ITEM_TRANSF_REQ`.

Inclui `P_OBSERVACAO`, grava `TRQI_OBSERVACAO`, aplica fallback de unidade e limita a alteração a quantidade solicitada e observação, preservando validações da requisição em `A`.

### 6.3 actScript167h

Contém:

1. verificação preventiva de rolos `R` ativos duplicados por `TRQL_EMPRESA_MATRIZ + TRQL_ROLO_ID`;
2. interrupção com mensagem clara se houver duplicidade, sem escolher ou estornar registros automaticamente;
3. índice único calculado `UQ_TRQL_ROLO_ATIVO`;
4. `SP_INICIA_SEP_TRANSF_REQ`;
5. `SP_SALVA_LEITURA_TRANSF_REQ`;
6. grants das tabelas/procedures envolvidas e `EXECUTE` para `SYSDBA`;
7. registro da versão `1.1.0.67h`.

Regra exata do índice:

- somente etiqueta `R`;
- somente leitura com `TRQL_STATUS = 'A'`;
- somente `TRQL_ROLO_ID` não nulo;
- etiquetas `C` e leituras estornadas produzem `NULL`;
- empresa matriz e rolo compõem juntos a chave única.

### 6.4 Situação de aplicação

O código dos scripts existe no Controle de Versão, mas **não há confirmação neste ponto de parada de que o WES tenha aplicado `167f`, `167g` e `167h` no banco usado pela API**.

O Codex não executou WES, `CREATE`, `ALTER`, `GRANT`, procedures de gravação ou SQL de alteração.

Antes do teste completo, o desenvolvedor deve confirmar pelo fluxo normal do WES:

- status atualizado e sem erros para `167f`, `167g` e `167h`;
- existência das duas tabelas;
- existência do índice `UQ_TRQL_ROLO_ATIVO`;
- existência das duas procedures do `167h`;
- grants aplicados.

## 7. Estado da API Flask

Arquivo alterado:

- `C:\Projetos Flutter\BarCode\api\app.py`

Endpoints exclusivos de Requisição implementados:

### GET `/transferencias/requisicoes`

Parâmetros:

- `empresa`;
- `usuario`.

Lista requisições `L` e requisições `S` que possuam separação ativa para o usuário informado. Sem usuário positivo, lista somente `L`.

### GET `/transferencias/requisicoes/detalhe`

Parâmetros:

- `empresa`;
- `requisicao`;
- `usuario`.

Permite capa e itens ativos de requisições `L`; para `S`, exige separação ativa e, quando informado, o usuário da separação.

### POST `/transferencias/requisicoes/assumir`

JSON:

- `empresa`;
- `requisicao`;
- `usuario`.

Abre transação explícita, chama `SP_INICIA_SEP_TRANSF_REQ`, faz `commit` somente com `RETORNO = OK` e executa `rollback` em erro/conflito. Não faz `UPDATE` direto de `TB_TRANSF_REQ`.

### GET `/transferencias/requisicoes/item-separacao`

Parâmetros:

- `empresa`;
- `requisicao`;
- `item`.

Retorna o item, quantidades e leituras ativas persistidas. Exige requisição `S` e registro ativo em `TB_TRANSF_REQ_SEPARACAO`.

Observação: essa rota não recebe `usuario` e não filtra `TRQS_USUARIO_INICIO`. No modelo temporário sem autenticação isso permite consultar um item com separação ativa, embora lista e detalhe usem o usuário. A gravação continua dependendo de `P_USUARIO` e da validação da procedure. Esse ponto deve ser reavaliado quando o projeto de autenticação for retomado.

### POST `/transferencias/requisicoes/item-separacao/salvar`

JSON:

- `empresa`;
- `requisicao`;
- `item`;
- `usuario`;
- `codigos_lidos`.

Abre uma única transação, chama `SP_SALVA_LEITURA_TRANSF_REQ` para cada código sem commits intermediários, recarrega item e leituras e somente então faz um único `commit`. Qualquer leitura rejeitada causa `rollback` total.

O módulo de Pedidos não usa esses endpoints e não foi misturado às tabelas de Requisições.

Pendência operacional da API:

- confirmar que o processo iniciado é realmente `api/app.py`, pois também existe `appNovaGramDecor.py`;
- conferir `api/iniciar_api.bat`, anteriormente identificado com caminho antigo;
- confirmar IP e porta atuais; o IP da máquina pode mudar;
- a porta configurada no código é `5001`;
- o comentário “consultas somente de leitura” acima das rotas ficou desatualizado após a criação dos POSTs, mas não afeta a execução.

## 8. Estado do Flutter

### 8.1 Navegação principal aprovada

Arquivo:

- `lib/main.dart`

Estado atual:

- `_moduloSelecionado` alterna entre `Pedidos` e `Requisições`;
- a faixa superior usa o amarelo do sistema `0xFFFFE000`;
- a opção selecionada usa `0xFFFFFBE6`;
- a área da logo foi reduzida para 22% da altura disponível;
- a logo usa largura 145;
- título, imagem do scanner e botão `Buscar Produto` foram reposicionados para liberar espaço do rodapé;
- no módulo Pedidos permanecem `Ler Etiqueta` e `Separação` no rodapé;
- no módulo Requisições o conteúdo central é substituído pela lista de requisições disponíveis.

A navegação atual foi aprovada pelo desenvolvedor.

### 8.2 Arquivos do módulo de Requisições

Modelos:

- `lib/models/requisicao_transferencia.dart`
- `lib/models/requisicao_transferencia_item.dart`
- `lib/models/requisicao_transferencia_leitura.dart`

Serviço:

- `lib/services/requisicao_transferencia_service.dart`

Telas:

- `lib/pages/requisicoes_transferencia_page.dart`
- `lib/pages/requisicao_transferencia_detalhe_page.dart`
- `lib/pages/requisicao_transferencia_item_separacao_page.dart`

Compartilhados com o padrão de Pedidos:

- `lib/pages/scanner_page.dart`
- `lib/models/leitura_etiqueta_separacao.dart`
- `lib/widgets/separacao_produto_widgets.dart`
- componentes também utilizados em `lib/pages/separacao_rolos_page.dart`.

### 8.3 Fluxo implementado no aplicativo

1. Lista requisições `L` e retomáveis em `S`.
2. Abre capa e itens.
3. Ao tocar em item de requisição `L`, pede confirmação.
4. Confirmação chama `/transferencias/requisicoes/assumir`.
5. Somente após sucesso e recarga em `S` abre a tela do produto.
6. Tela carrega `Pedido`, `Coleta`, `Falta` e leituras persistidas.
7. `Ler Etiqueta` abre o mesmo `ScannerPage` usado pelo fluxo existente.
8. Leituras válidas ficam em lista pendente separada das gravadas.
9. `Salvar Produto` envia somente os códigos pendentes.
10. Em sucesso, substitui os dados pelos retornados do banco e limpa as pendentes.
11. Em erro, conserva as pendentes e não altera os totais exibidos.
12. Ao voltar para o detalhe, recarrega capa e itens.

### 8.4 Validações locais

Etiqueta `C` no módulo de Requisições:

- regex `^C\d{20}$`;
- 21 caracteres;
- referência igual à requisição aberta;
- produto igual ao item aberto;
- quantidade positiva;
- quantidade não pode ultrapassar o saldo considerando leituras já pendentes.

Etiqueta `R`:

- regex `^R\d{17}$`;
- 18 caracteres;
- produto igual ao item aberto;
- quantidade local extraída do trecho final;
- duplicidade local verificada contra pendentes e leituras persistidas;
- validação definitiva do rolo fica na procedure.

O parser compartilhado ainda reconhece etiquetas `C` de 19 ou 21 caracteres para preservar compatibilidade com Pedidos. A tela de Requisições aplica a restrição adicional e aceita somente 21.

### 8.5 Configuração atual

`RequisicaoTransferenciaService.daConfiguracao()` usa:

- `api_base_url` do `SharedPreferences`, com fallback `http://192.168.0.250:5001`;
- `empresa_id` do `SharedPreferences`, com fallback `1`;
- `usuarioAtual = 1` temporariamente.

Na tela de configuração, testar a comunicação não basta: é necessário também salvar a configuração.

## 9. Testes e validações já registrados

Confirmados pelo desenvolvedor ou pela execução anterior:

- cadastro/persistência dos itens Delphi testado;
- exclusão `F10` testada;
- navegação Flutter `Pedidos / Requisições` aprovada;
- listagem e detalhe de requisições `L` apareceram no aparelho;
- teste anterior usou aparelho Samsung `SM_G980F` e empresa matriz `10`;
- requisições como `000008`, `000009` e `000011` foram visualizadas;
- tela visual de separação do item abriu;
- scanner abriu;
- identificação visual/local das etiquetas `C` e `R` foi aprovada;
- `actScript167h` foi incluído e o projeto de Controle de Versão compilou com sucesso;
- a API e os arquivos Flutter de persistência existem atualmente no disco.

Ainda não deve ser considerado comprovado:

- aplicação de `167f`, `167g` e `167h` pelo WES no banco usado pela API;
- existência real no banco das tabelas, índice, procedures e grants;
- teste completo `L -> S -> leitura -> salvar -> fechar -> reabrir` contra o banco atualizado;
- rollback de um lote com uma leitura válida e outra inválida;
- bloqueio de rolo duplicado entre Requisições e Separação de Pedidos;
- retomada por usuário e concorrência real entre dois operadores;
- emissão e leitura ponta a ponta de uma etiqueta `C` de Requisição;
- fluxo `S -> C`, carga, recebimento e estoque, pois não fazem parte desta versão.

## 10. Onde confirmar a persistência após um teste

Sem executar SQL automaticamente, os pontos de conferência são:

- `TB_TRANSF_REQ_SEPARACAO`: confirma que a requisição foi assumida, com status da separação, data e usuário;
- `TB_TRANSF_REQ_SEP_LEITURA`: confirma cada etiqueta `C/R` gravada, seu item, produto, rolo, quantidade, usuário, data e status;
- `TB_TRANSF_REQ_ITEM.TRQI_QTDE_SEPARADA`: confirma o total separado acumulado do item;
- `TB_TRANSF_REQ.TRQ_STATUS`: deve estar `S` depois de assumir a separação;
- os totais retornados pela API e mostrados como `Coleta` e `Falta` devem coincidir com o banco.

A tabela principal para confirmar a gravação de cada leitura é `TB_TRANSF_REQ_SEP_LEITURA`.

## 11. Incidente paralelo atual — impressão de etiquetas de Pedido

Este incidente é separado do módulo de Requisição, mas está aberto e deve ser resolvido antes de considerar o ERP estável após o novo Build.

Erro reproduzido pelo desenvolvedor, inclusive após Build completo:

`Class TfrxBarcode2DView not found.`

Tela afetada:

- impressão de etiquetas do Pedido de Venda.

Estado dos arquivos:

- `Source/View/Rel/URelPedidoVendaEtiquetas.pas`, linha 92, está atualmente com:
  - `UClassGlobal, UClassPedidoVenda, UDMPedidoVenda, frxBarcode;`
- `Source/View/Rel/URelPedidoVendaEtiquetas.dfm`, linhas 474–490, continua contendo:
  - `Barcode2D1: TfrxBarcode2DView`;
  - QR fixo `C1930P1ZZ2297Q134`.

Diagnóstico:

- adicionar `frxBarcode` compilou, mas não resolveu o erro;
- `frxBarcode` disponível em `C:\Program Files (x86)\FastReports\LibD23` é o módulo de código de barras 1D;
- o pacote referencia `frxBarcode2D`, porém o runtime/DCU 2D não está disponível nessa instalação;
- o componente 2D ocorre apenas nesse DFM e contém um valor fixo com aparência de teste;
- o DFM não foi alterado durante a tentativa de correção;
- depois que o erro persistiu, nenhum outro arquivo foi corrigido.

Correção mínima recomendada, ainda pendente de autorização expressa:

1. remover somente o bloco `Barcode2D1` das linhas 474–490 de `URelPedidoVendaEtiquetas.dfm`;
2. remover novamente `frxBarcode` do `uses` de implementação de `URelPedidoVendaEtiquetas.pas`;
3. fazer Build Debug/Win32;
4. abrir Pedido -> Imprimir Etiquetas e confirmar que o relatório volta a abrir;
5. se surgir erro diferente, parar e apresentar antes de qualquer nova correção.

Alternativa não recomendada para este ponto: reinstalar/recompilar o FastReport com suporte 2D. Isso ampliaria muito o escopo e mexeria em configuração compartilhada para resolver um componente aparentemente indevido em uma tela de Pedidos já fechada.

## 12. Pendências ordenadas

### Prioridade imediata

1. Obter autorização para a correção mínima do relatório de etiquetas de Pedido descrita na seção 11.
2. Compilar e testar exclusivamente a abertura/impressão das etiquetas de Pedido.
3. Não fazer correções adicionais se aparecer outro erro sem apresentá-lo primeiro.

### Retomada da persistência de Requisições

1. O desenvolvedor executar o WES pelo processo normal.
2. Confirmar aplicação sem erros de `167f`, `167g` e `167h`.
3. Confirmar tabelas, índice, procedures e grants.
4. Iniciar a API correta (`api/app.py`).
5. Conferir e salvar URL/empresa no aplicativo.
6. Fazer o teste ponta a ponta descrito na seção 13.
7. Registrar qualquer mensagem real retornada pelas procedures sem contorná-la no Flutter ou na API.

### Futuro, fora do escopo atual

- autenticação individual do operador;
- token/sessão;
- estorno/cancelamento de leitura pela interface;
- conclusão da separação;
- `S -> C`;
- carga;
- conferência/recebimento na filial;
- `C -> F`;
- movimentação de estoque;
- notificações.

## 13. Próxima etapa recomendada e roteiro de teste

Depois de corrigir e validar o incidente de Pedido e depois que o WES estiver confirmado, executar no aplicativo:

1. Emitir uma etiqueta `C` oficial de Requisição com 21 caracteres.
2. Abrir `Requisições` e confirmar que uma requisição `L` aparece.
3. Abrir o detalhe.
4. Tocar em um item.
5. Cancelar a confirmação uma vez e verificar que a requisição permanece `L`.
6. Tocar novamente, confirmar e verificar a mudança para `S`.
7. Confirmar que a requisição continua aparecendo na lista para retomada.
8. Abrir o item e conferir `Pedido`, `Coleta`, `Falta` e leituras anteriores.
9. Ler a etiqueta `C` correta e verificar que aparece como pendente.
10. Salvar Produto e aguardar a resposta real da API.
11. Verificar atualização de `Coleta` e `Falta`.
12. Voltar, reabrir o item e confirmar que a leitura agora aparece como gravada.
13. Repetir com uma etiqueta `R` válida.
14. Tentar reler o mesmo rolo e confirmar rejeição.
15. Testar etiqueta de outro produto.
16. Testar etiqueta `C` de outra requisição.
17. Testar quantidade superior ao saldo.
18. Enviar, no mesmo salvamento, uma leitura válida e outra inválida e confirmar rollback total.
19. Conferir `TB_TRANSF_REQ_SEPARACAO`, `TB_TRANSF_REQ_SEP_LEITURA`, `TRQI_QTDE_SEPARADA` e `TRQ_STATUS`.
20. Não avançar para carga ou estoque.

## 14. Restrições para a próxima sessão

- Não executar SQL ou WES sem autorização expressa.
- Não alterar banco diretamente.
- Não modificar `TDMBase`, `TGlobal`, `TFrmManPadrao`, `TFrmMovPadrao` ou infraestrutura compartilhada.
- Não mexer na transferência de estoque antiga.
- Não misturar tabelas ou endpoints de Pedidos e Requisições.
- Não implementar autenticação nesta versão.
- Não implementar `S -> C` ou estoque.
- Não afirmar que algo foi aplicado no banco ou testado funcionalmente sem evidência real.
- Antes de editar, informar os arquivos e o impacto.
- Depois de editar, listar exatamente os arquivos modificados e fornecer teste manual.

## 15. Resumo curto para retomada

## 16. RegularizaÃ§Ã£o de rolos antigos das filiais

Atualizado em: **05/08/2026**.

Segunda etapa autorizada com escopo controlado:

- identificar no aplicativo se a empresa configurada em `empresa_id` Ã© matriz ou filial;
- consultar `TB_EMPRESA.EMP_TIPO` pela API, sem lista fixa de empresas;
- mostrar o botÃ£o `Regularizar rolos da filial` somente quando `EMP_TIPO = 'F'`;
- criar a tela visual inicial de regularizaÃ§Ã£o;
- navegar da tela principal para a nova tela.

Regra multiempresa registrada para as prÃ³ximas etapas:

- o cadastro de produtos Ã© centralizado na matriz;
- filiais nÃ£o cadastram, copiam, replicam nem alteram produto por esta rotina;
- o mesmo cÃ³digo de produto Ã© usado na matriz e nas filiais;
- a regularizaÃ§Ã£o futura deve apenas cadastrar a identidade do rolo na `TB_PRODUTO_ROLO` da filial, preservando `PROR_ID`, produto, quantidade, unidade e cÃ³digo de barras originais;
- a existÃªncia histÃ³rica do rolo na matriz nÃ£o deve ser tratada, por si sÃ³, como duplicidade indevida.

TambÃ©m fica registrado que futuras rotas de validaÃ§Ã£o/confirmaÃ§Ã£o deverÃ£o consultar novamente `TB_EMPRESA.EMP_TIPO` e recusar empresas que nÃ£o sejam filial com a mensagem:

`Esta operaÃ§Ã£o Ã© permitida somente para empresas filiais.`

NÃ£o faz parte desta etapa:

- leitura de etiquetas;
- validaÃ§Ã£o de rolos;
- criaÃ§Ã£o ou alteraÃ§Ã£o de procedure de gravaÃ§Ã£o;
- `INSERT` ou `UPDATE` em `TB_PRODUTO_ROLO`;
- movimentaÃ§Ã£o de estoque;
- alteraÃ§Ã£o de status na matriz;
- qualquer alteraÃ§Ã£o em cadastro de produto.

### 16.1 Reaproveitamento do fluxo de leitura existente

Auditoria feita nesta etapa:

- nÃ£o foi localizada no Flutter atual uma tela especÃ­fica de recebimento da filial;
- o fluxo Flutter disponÃ­vel com leitura operacional de etiquetas Ã© o de separaÃ§Ã£o de requisiÃ§Ãµes;
- a API Flask atual tambÃ©m nÃ£o expÃµe rota de recebimento da filial;
- a gravaÃ§Ã£o de rolos recebidos na filial existe no banco pela procedure `SP_CAD_ROLOS_RECEB_TRANSF`, mas nÃ£o deve ser chamada pela regularizaÃ§Ã£o de rolos antigos.

Componentes Flutter candidatos a reaproveitamento:

- `lib/pages/scanner_page.dart`: usa `mobile_scanner`, `MobileScannerController`, `DetectionSpeed.noDuplicates`, cÃ¢mera traseira, formatos `code128` e `qrCode`, debounce local e retorno do cÃ³digo lido por `Navigator.pop`;
- `lib/models/leitura_etiqueta_separacao.dart`: interpreta etiqueta `R` no formato `R + PROR_ID(6) + produto(7) + quantidade(4)`;
- `LeituraEtiquetaSeparacao.identificar`: extrai `referencia` como `PROR_ID`, `produto`, `quantidadeCodificada` e tipo da etiqueta;
- `lib/pages/requisicao_transferencia_separacao_page.dart` e `lib/pages/requisicao_transferencia_item_separacao_page.dart`: contÃªm o padrÃ£o de abrir scanner, validar formato, bloquear rolo repetido na coleta atual/persistida, adicionar leitura pendente e exibir mensagens por `SnackBar`;
- `lib/widgets/separacao_produto_widgets.dart`: fornece decoraÃ§Ãµes e botÃµes usados nas telas de separaÃ§Ã£o, Ãºteis como referÃªncia visual.

Partes que podem ser reaproveitadas na prÃ³xima etapa, se autorizado:

- componente fÃ­sico de leitura pela cÃ¢mera;
- parser de etiqueta `R`;
- extraÃ§Ã£o de `PROR_ID`, produto e quantidade;
- bloqueio local de leitura duplicada na coleta;
- padrÃ£o de lista com leituras pendentes/gravadas;
- mensagens objetivas ao operador.

Partes que nÃ£o devem ser reaproveitadas diretamente:

- `RequisicaoTransferenciaService.salvarLeituras`;
- rota `/transferencias/requisicoes/item-separacao/salvar`;
- procedure `SP_SALVA_LEITURA_TRANSF_REQ`;
- procedure `SP_CAD_ROLOS_RECEB_TRANSF`;
- tabelas `TB_TRANSF_REQ_RECEB` e `TB_TRANSF_REQ_RECEB_VOLUME`;
- qualquer finalizaÃ§Ã£o de recebimento, carga, alteraÃ§Ã£o de status de requisiÃ§Ã£o ou movimentaÃ§Ã£o de estoque.

RecomendaÃ§Ã£o tÃ©cnica para a prÃ³xima etapa:

- manter `ScannerPage` como componente compartilhado;
- extrair, se necessÃ¡rio, a parte genÃ©rica de validaÃ§Ã£o/quantidade de `LeituraEtiquetaSeparacao` para helper reutilizÃ¡vel;
- criar modelos e service prÃ³prios para regularizaÃ§Ã£o, sem depender dos modelos de requisiÃ§Ã£o;
- deixar a validaÃ§Ã£o definitiva e a gravaÃ§Ã£o futura em rotas/procedures prÃ³prias de regularizaÃ§Ã£o.

### 16.2 Leitura e coleta temporária

Terceira etapa autorizada e implementada em **05/08/2026**, com escopo limitado à leitura física de etiquetas `R` e montagem de coleta temporária em memória.

Arquivos alterados nesta etapa:

- `lib/pages/scanner_page.dart`;
- `lib/pages/regularizacao_rolos_filial_page.dart`;
- `ULTIMO_PONTO_DE_PARADA.md`.

O que foi implementado:

- botão `Ler Etiqueta` na tela de regularização de rolos da filial;
- abertura da câmera usando o `ScannerPage` já existente;
- reaproveitamento de `LeituraEtiquetaSeparacao.identificar` para interpretar etiquetas;
- aceitação somente de etiquetas de rolo `R`;
- rejeição de etiquetas `C` com a mensagem `Nesta rotina são permitidas somente etiquetas de rolo.`;
- rejeição de leituras inválidas com a mensagem `Etiqueta inválida.`;
- bloqueio de leitura repetida dentro da coleta atual com a mensagem `Esta etiqueta já foi lida nesta coleta.`;
- lista temporária em memória exibindo código completo, `PROR_ID`, produto e quantidade;
- contador de rolos lidos;
- remoção individual de rolo da coleta;
- limpeza da coleta com confirmação;
- botão visual `Confirmar regularização` mantido desabilitado.

Detalhe técnico:

- `ScannerPage` ganhou a opção `aceitarQualquerCodigo`, com valor padrão `false`, para permitir que a tela de regularização receba também códigos inválidos e mostre a mensagem correta ao operador.
- Os fluxos existentes continuam usando o comportamento padrão do scanner.
- A quantidade do rolo é calculada a partir da parte final da etiqueta `R`, mantendo o padrão já auditado: quantidade codificada dividida por 10.

Limites preservados:

- não foi criada rota nova na API para validação de rolos;
- não houve chamada de procedure;
- não houve `INSERT`, `UPDATE` ou `DELETE`;
- não houve acesso novo a `TB_PRODUTO_ROLO`;
- não houve chamada a `SP_CAD_ROLOS_RECEB_TRANSF`;
- não houve uso de tabelas `TB_TRANSF_REQ_RECEB` ou `TB_TRANSF_REQ_RECEB_VOLUME`;
- não houve finalização de recebimento, alteração de status de requisição ou movimentação de estoque;
- não houve cadastro, cópia, replicação ou alteração de produto.

### 16.3 Confirmação e gravação pela API Python

Quarta etapa ajustada e implementada em **05/08/2026**, somente nos projetos:

- Flutter: `E:\Jorginho\BarCode\BarCodeNovo`;
- API Python: `E:\Jorginho\BarCode\api`.

Não foi acessado nem alterado:

- Delphi;
- WES;
- Controle de Versão;
- actScript;
- estrutura do banco;
- tabelas, colunas, generators ou procedures.

Arquivos alterados nesta etapa:

- `../api/app.py`;
- `lib/main.dart`;
- `lib/pages/regularizacao_rolos_filial_page.dart`;
- `ULTIMO_PONTO_DE_PARADA.md`.

Rota criada:

- `POST /rolos/regularizacao/confirmar`.

Payload esperado:

```json
{
  "empresa": 12,
  "usuario": 1,
  "rolos": [
    {
      "codigo": "R00878110023360100",
      "pror_id": 8781,
      "produto": 1002336,
      "quantidade": 10.0
    }
  ]
}
```

Validações implementadas na API:

- empresa destino informada;
- empresa destino existe;
- `TB_EMPRESA.EMP_TIPO = 'F'`;
- empresa matriz resolvida por `TB_EMPRESA.EMP_EMPRESA_MATRIZ`;
- etiqueta no formato `R + PROR_ID(6) + produto(7) + quantidade(4)`;
- `PROR_ID`, produto e quantidade da coleta conferem com a etiqueta;
- rolo original existe na matriz;
- `PROR_STATUS` do rolo original na matriz deve ser `T`;
- produto do rolo original confere com a etiqueta;
- quantidade do rolo original confere com a etiqueta;
- código de barras original confere integralmente com a etiqueta;
- produto existe e está ativo na filial;
- rolo ainda não existe na filial destino;
- código de barras ainda não existe na filial destino com outro rolo;
- rolo/código não existe em outra empresa diferente da matriz e da filial destino;
- mesmo código de barras não está associado a outro `PROR_ID`;
- mesmo `PROR_ID` não existe com produto, quantidade ou código incompatível;
- lista enviada não contém código ou `PROR_ID` repetido;
- bloqueio em memória contra duplo envio da mesma coleta enquanto a operação está em andamento.

SQL principal de validação:

```sql
SELECT F.EMP_ID, COALESCE(F.EMP_TIPO, ''), F.EMP_EMPRESA_MATRIZ, M.EMP_ID
FROM TB_EMPRESA F
LEFT JOIN TB_EMPRESA M ON M.EMP_ID = F.EMP_EMPRESA_MATRIZ
WHERE F.EMP_ID = ?;

SELECT PROR_PRODUTO, PROR_QUANTIDADE, PROR_UN, PROR_CODIGO_BARRAS,
       PROR_STATUS, PROR_IMPRESSO, PROR_DT_IMPRESSAO, PROR_USUARIO_IMP,
       PROR_LOTE
FROM TB_PRODUTO_ROLO
WHERE PROR_EMPRESA = ?
  AND PROR_ID = ?;

SELECT COUNT(*)
FROM TB_PRODUTO
WHERE PRD_EMPRESA = ?
  AND PRD_ID = ?
  AND COALESCE(PRD_STATUS, 'A') = 'A';

SELECT FIRST 1 PROR_ID, PROR_CODIGO_BARRAS
FROM TB_PRODUTO_ROLO
WHERE PROR_EMPRESA = ?
  AND (PROR_ID = ? OR PROR_CODIGO_BARRAS = ?);

SELECT FIRST 1 PROR_EMPRESA, PROR_ID
FROM TB_PRODUTO_ROLO
WHERE PROR_EMPRESA <> ?
  AND PROR_EMPRESA <> ?
  AND (PROR_ID = ? OR PROR_CODIGO_BARRAS = ?);

SELECT FIRST 1 PROR_EMPRESA, PROR_ID
FROM TB_PRODUTO_ROLO
WHERE PROR_CODIGO_BARRAS = ?
  AND PROR_ID <> ?;

SELECT FIRST 1 PROR_EMPRESA
FROM TB_PRODUTO_ROLO
WHERE PROR_ID = ?
  AND (
    PROR_PRODUTO <> ?
    OR ABS(COALESCE(PROR_QUANTIDADE, 0) - ?) > 0.0001
    OR COALESCE(PROR_CODIGO_BARRAS, '') <> ?
  );
```

SQL de inserção usado pela API, somente após validação integral da lista:

```sql
INSERT INTO TB_PRODUTO_ROLO (
    PROR_EMPRESA,
    PROR_ID,
    PROR_PRODUTO,
    PROR_QUANTIDADE,
    PROR_UN,
    PROR_CODIGO_BARRAS,
    PROR_STATUS,
    PROR_IMPRESSO,
    PROR_DT_CADASTRO,
    PROR_USUARIO_CAD,
    PROR_PRATELEIRA,
    PROR_DT_IMPRESSAO,
    PROR_USUARIO_IMP,
    PROR_OBSERVACAO,
    PROR_LOTE
)
VALUES (?, ?, ?, ?, ?, ?, 'A', 'S', CURRENT_TIMESTAMP, ?, NULL, ?, ?, NULL, ?);
```

Campos preservados da matriz na filial:

- `PROR_ID`;
- `PROR_PRODUTO`;
- `PROR_QUANTIDADE`;
- `PROR_UN`;
- `PROR_CODIGO_BARRAS`;
- `PROR_DT_IMPRESSAO`;
- `PROR_USUARIO_IMP`;
- `PROR_LOTE`.

Campos definidos pela regularização:

- `PROR_EMPRESA` = filial atual;
- `PROR_STATUS = 'A'`;
- `PROR_IMPRESSO = 'S'`;
- `PROR_DT_CADASTRO = CURRENT_TIMESTAMP`;
- `PROR_USUARIO_CAD` = usuário enviado pela API;
- `PROR_PRATELEIRA = NULL`;
- `PROR_OBSERVACAO = NULL`.

Regra adotada para status da matriz:

- somente aceita o rolo original quando `PROR_STATUS = 'T'`;
- não altera status da matriz;
- não transforma rolo ativo da matriz em transferido;
- se o status for diferente de `T`, a API rejeita a regularização e informa o rolo para auditoria.

Auditoria por `SELECT` da etiqueta visual `R00878110023360100`:

- matriz vinculada da empresa 12: empresa 10;
- na matriz 10: `PROR_ID = 8781`, produto `1002336`, quantidade `10`, unidade `MT`, código `R00878110023360100`, status `T`, impresso `S`, lote `1925`;
- na filial 12: não foi localizado registro por `PROR_ID` ou código;
- em outra empresa/filial: localizado na empresa 13 com status `A`.

Portanto, essa etiqueta visual não deve ser usada como prova de inclusão real. Pela regra nova, ela deve ser recusada pela API por já existir em outra filial/empresa.

Flutter atualizado:

- a tela `regularizacao_rolos_filial_page.dart` recebeu `baseUrl`;
- o botão `Confirmar regularização` fica habilitado quando há pelo menos uma etiqueta;
- durante o envio, o botão fica bloqueado e mostra processamento;
- a coleta só é limpa após sucesso confirmado;
- sucesso e erro usam diálogo centralizado com botão `OK`;
- erro mantém a coleta intacta para remoção/correção do item.

Ponto de parada após testes no aparelho:

- implementação Flutter/API pronta para a rotina de regularização;
- censuras testadas e aprovadas no aparelho;
- rolo ainda não transferido na matriz foi bloqueado corretamente;
- rolo já cadastrado em outra filial foi bloqueado corretamente;
- mensagens de erro foram exibidas em diálogo centralizado;
- coleta foi preservada após erro;
- primeiro `INSERT` válido ainda não foi homologado;
- teste de inclusão válida permanece pendente por falta de etiqueta física legítima de rolo antigo que esteja realmente na filial e cumpra todas as condições;
- não fabricar, simular ou usar etiqueta artificial apenas para forçar gravação;
- teste futuro deve ser feito com um único rolo físico legítimo, com backup e `SELECT` antes/depois.

> A navegação e a tela de separação de Requisições estão aprovadas. O Controle de Versão contém `167f`, `167g` e `167h`; o `167h` compilou e define o índice de rolo ativo, `SP_INICIA_SEP_TRANSF_REQ` e `SP_SALVA_LEITURA_TRANSF_REQ`. API e Flutter já possuem o fluxo de assumir, consultar item e salvar leituras em transação única, sem autenticação e com usuário temporário 1. Ainda falta comprovar a aplicação pelo WES e fazer o teste ponta a ponta de persistência. Antes disso há um incidente aberto na impressão de etiquetas de Pedido: `TfrxBarcode2DView not found`. A inclusão de `frxBarcode` não resolveu; a correção mínima proposta é retirar o bloco 2D aparentemente de teste do DFM e reverter o uses, mas isso ainda aguarda autorização.

## 17. Pendencia para retomada - regularizacao de rolos antigos

Atualizado em: **06/08/2026**.

Pedido do Jorge: deixar esta tarefa como pendencia para amanha. Nao executar agora.

Escopo correto confirmado:

- Delphi: `E:\Repositorio_Parmasoft\ParmaDistribuidora`;
- Flutter/API: `E:\Jorginho\BarCode`;
- banco local de teste GramDecor: `E:\Dados Clientes\GramDecor\Dados.fdb`;
- arquivo principal da API: `E:\Jorginho\BarCode\api\app.py`;
- endpoint envolvido: `POST /rolos/regularizacao/confirmar`.

Restricoes para a retomada:

- alterar somente fonte, quando autorizado;
- nao alterar banco manualmente;
- nao executar `UPDATE`, `INSERT` ou `DELETE` avulso por SQL;
- nao chamar endpoint em banco real;
- nao publicar API;
- nao gerar APK ou instalador;
- nao fazer deploy;
- ao final, retornar diff, analise e validacao local.

Diagnostico ja confirmado por leitura de fonte:

- a rotina atual usa `validar_rolo_regularizacao()`;
- hoje a API exige que o rolo original da matriz esteja com `PROR_STATUS = 'T'`;
- se o status da matriz for diferente de `T`, retorna: `Rolo original nao esta transferido na matriz.`;
- a mensagem nao indica rolo inexistente, porque rolo inexistente tem mensagem propria;
- a exigencia de `T` bloqueia rolos antigos enviados fisicamente antes da implantacao do fluxo novo.

Caso real informado/testado em Muriae:

- etiqueta: `R00762410041070400`;
- `PROR_ID = 7624`;
- produto `1004107`;
- quantidade `40,0`;
- empresa matriz `10`;
- empresa destino `11 - Muriae`;
- mensagem recebida: `Rolo original nao esta transferido na matriz.`

Resultado encontrado somente no banco local de teste, copia de 31/07/2026:

- rolo 7624 existe na empresa 10;
- produto confere com a etiqueta;
- quantidade confere com a etiqueta;
- codigo de barras confere com a etiqueta;
- `PROR_STATUS = 'A'`;
- nao foi localizado nas empresas 11, 12 ou 13.

Pendencia tecnica para implementar quando autorizado:

- ajustar apenas a validacao de status da matriz para aceitar `PROR_STATUS in ('A', 'T')`;
- manter bloqueio para qualquer outro status;
- manter todas as demais validacoes: filial valida, matriz encontrada, produto, quantidade, unidade, codigo de barras, existencia na filial atual, existencia em outras filiais e duplicidade de codigo/ID;
- se matriz estiver `A`, validar tudo, atualizar matriz para `T` e criar o rolo na filial com status `A`;
- se matriz ja estiver `T`, nao atualizar matriz novamente, validar tudo e criar o rolo na filial com status `A`, desde que ainda nao exista em nenhuma filial;
- preservar produto, quantidade, unidade, codigo de barras, lote, impressao e demais campos usados pela regra atual;
- garantir atomicidade: update da matriz e insert da filial na mesma transacao quando estiverem na mesma conexao/banco, com commit unico e rollback total em falha;
- garantir idempotencia contra segundo clique ou nova tentativa: nao duplicar rolo na filial e nao alterar matriz indevidamente.

Cenarios conceituais para validar localmente:

- matriz `A`, sem filial: deve regularizar, matriz vira `T`, filial recebe `A`;
- matriz `T`, sem filial: deve regularizar, matriz permanece `T`, filial recebe `A`;
- matriz com outro status: deve bloquear;
- produto divergente: deve bloquear;
- quantidade divergente: deve bloquear;
- codigo de barras divergente: deve bloquear;
- ja existe na filial 11: deve bloquear duplicidade;
- existe em outra filial 12 ou 13: deve bloquear;
- falha entre atualizar matriz e inserir filial: rollback total;
- segundo clique/segunda confirmacao: nao duplicar.

Observacao importante:

Esta alteracao nao deve mexer no fluxo normal de recebimento, carregamento, separacao, requisicao ou demais rotinas de rolo. E uma regra especifica para regularizacao de rolos antigos fisicamente enviados antes do fluxo novo.

## 18. Encerramento oficial - actScripts 174/175 e App de Etiquetas - 31/08/2026

Esta seção é o ponto de continuidade mais recente e prevalece sobre os estados
de parada e pendências datados de 06/08/2026 ou anteriores quando tratarem dos
mesmos assuntos. O histórico anterior foi preservado, mas não deve ser usado
para reabrir trabalho já homologado.

### 18.1 actScript174 e F12 do recebimento

- O `actScript174 / 1.1.0.74` foi aplicado e homologado no banco real. Não deve
  ser alterado ou reaberto.
- O Recebimento 7 e a Carga 7 foram finalizados com status `F`; as Requisições
  31 e 37 também ficaram em `F`.
- A conferência terminou com 40 volumes esperados, 40 recebidos, zero pendentes
  e quantidade total 1513,6000.
- O F12 regularizou automaticamente o conflito legado: o cadastro histórico da
  empresa 11 foi renumerado de `PROR_ID 10256` para `PROR_ID 11487`, com código
  canônico `R01148700076010010`, preservando produto 7601, quantidade 1,0000,
  unidade JG, lote 2395 e status `A`.
- O alias ativo preserva a etiqueta física antiga
  `R01025600076010010` e a resolve para o novo cadastro 11487.
- A empresa 10 / `PROR_ID 10256` permaneceu intacta: produto 1004349,
  quantidade 49,4000 MT, lote 2414, status `T` e código
  `R01025610043490494`.
- Os 40 movimentos de entrada, total 1513,6000, decorreram exclusivamente da
  finalização normal do recebimento. A renumeração não gerou movimento de
  estoque próprio e não deixou estado parcial.

### 18.2 actScript175 - Requisição de Transferência

- O `actScript175 / 1.1.0.75` foi aplicado pelo Controle de Versão e homologado
  manualmente em 31/08/2026.
- Procedure alterada: `SP_INC_ITEM_TRANSF_REQ`.
- Regra anterior deixada pelo 173:
  `COALESCE(PRD_STATUS, 'A') IN ('A', 'P')`.
- Regra definitiva homologada:
  `COALESCE(PRD_STATUS, 'A') <> 'I'`.
- `A`, `P`, `L`, `B`, demais estados operacionais e `NULL` são permitidos;
  somente `I` é bloqueado. `NULL` mantém o tratamento histórico equivalente a
  `A`.
- O teste manual de inclusão normal da Requisição foi concluído com sucesso:
  produtos utilizáveis foram incluídos e produto inativo foi recusado.
- Os `actScripts 173` e `174` não foram alterados por essa correção.

### 18.3 App de Etiquetas/API

- Fonte oficial alterada e homologada: `E:\Jorginho\BarCode\api\app.py`.
- Causa encerrada: `/produtos/buscar` e `/produto` censuravam qualquer produto
  que não estivesse com `PRD_STATUS = 'A'`.
- Regra definitiva em toda a fronteira operacional auditada:
  `COALESCE(PRD_STATUS, 'A') <> 'I'`. A regra trata somente `PRD_STATUS` e não
  altera status de rolo, requisição, item, separação, carga, recebimento,
  leitura, manifesto ou pedido.
- Pontos cobertos: `/produto`, `/produtos/buscar`, validação de regularização,
  `/rolos/salvar`, etiqueta C em `/gondola`, `/rolos/pendentes`, impressão
  oficial/i9/QR, impressão por produto, reimpressão/preview e
  `/rolos/consultar-codigo`.
- Testes técnicos concluídos: sintaxe Python válida, cenários funcionais da API
  aprovados, 5/5 testes Dart aprovados e `flutter analyze` sem erro relacionado
  à correção. Os avisos/informações remanescentes eram preexistentes.
- Teste operacional manual concluído em 31/08/2026: produtos válidos com status
  diferente de `A` apareceram no App e as etiquetas foram impressas com
  sucesso. O produto `I` permaneceu bloqueado.
- Não houve alteração no Flutter, geração de APK, alteração de banco ou novo
  actScript para a correção do App/API.

### 18.4 Estado final e continuidade

- Requisição de Transferência/`actScript175`: homologada e encerrada.
- App de Etiquetas/API: homologado operacionalmente e encerrado.
- Recebimento 7/`actScript174`: homologado em produção e encerrado; não reabrir.
- Não há pendência funcional nos blocos encerrados nesta seção.
- Pendências históricas de outros módulos eventualmente descritas nas seções
  anteriores permanecem fora deste encerramento e só devem ser tratadas se uma
  nova tarefa específica confirmar que ainda são atuais.

## 19. Etiqueta C com quantidade acima do formato - 01/09/2026

### 19.1 Sintoma e causa comprovada

- Na separação da Requisição na GramDecor, uma etiqueta C com quantidade
  `2.000` era vista pela câmera, mas não era processada pelo aplicativo e não
  apresentava mensagem.
- O contrato oficial possui exatamente 21 caracteres:
  `C(1) + requisição(6) + produto(7) + quantidade(7)`.
- A quantidade é codificada por `Round(Quantidade * 10.000)`.
- `999,9999` gera `9.999.999` e ocupa os 7 caracteres disponíveis.
- `1.000,0000` gera `10.000.000`, e `2.000,0000` gera `20.000.000`; ambas
  exigem 8 caracteres e fazem a etiqueta Delphi chegar a 22 caracteres.
- O scanner entrega o conteúdo ao Flutter, mas o parser rejeita o tamanho fora
  do contrato antes de retornar a leitura à tela. A API não é chamada.

### 19.2 Decisão vigente

- Limite atual por etiqueta C: `999,9999`.
- Nenhum arquivo Delphi, Flutter, API ou objeto de banco foi alterado para esse
  caso.
- Não aumentar campo, mudar parser ou alterar o formato da etiqueta sem nova
  autorização.
- A regra operacional para quantidades superiores será decidida com a
  GramDecor, provavelmente usando múltiplas etiquetas.
- Estado: **PENDENTE DE DECISÃO OPERACIONAL**.
