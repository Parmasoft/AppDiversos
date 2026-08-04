# Último ponto de parada técnico

Atualizado em: **14/07/2026**  
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

> A navegação e a tela de separação de Requisições estão aprovadas. O Controle de Versão contém `167f`, `167g` e `167h`; o `167h` compilou e define o índice de rolo ativo, `SP_INICIA_SEP_TRANSF_REQ` e `SP_SALVA_LEITURA_TRANSF_REQ`. API e Flutter já possuem o fluxo de assumir, consultar item e salvar leituras em transação única, sem autenticação e com usuário temporário 1. Ainda falta comprovar a aplicação pelo WES e fazer o teste ponta a ponta de persistência. Antes disso há um incidente aberto na impressão de etiquetas de Pedido: `TfrxBarcode2DView not found`. A inclusão de `frxBarcode` não resolveu; a correção mínima proposta é retirar o bloco 2D aparentemente de teste do DFM e reverter o uses, mas isso ainda aguarda autorização.
