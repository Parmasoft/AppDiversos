# Retomada controlada — 10/11/2026

## Homologação controlada do fluxo externo — 12/11/2026

**Escopo:** exclusivamente o banco de homologação Firebird Tekno Prime; não
equivale a homologação de produção ou operação permanente do Agente.

O responsável informou a compilação e instalação no Samsung S20 de APK release
ARM64 com 16,9 MB. O cadastro de cliente provisório ampliado foi testado no
aparelho e o pedido recebido nº 29 foi localizado no painel Delphi e auditado
por consultas somente leitura no Firebird de homologação.

### Resultado aprovado

- A migration Firebird
  `AgenteMalhas/migrations/20261110_0001_cliente_provisorio_dados_ampliados.sql`
  foi aplicada exclusivamente em `E:\Dados Clientes\Tekno Prime\DADOS.FDB`.
  As dez colunas foram validadas com os `VARCHAR` e tamanhos previstos. O RAR
  `DADOS.rar` disponível no diretório do banco passou no teste de integridade.
- O pedido nº 29 está em `TB_MALHA_PEDIDO_RECEBIDO`, empresa 1, origem
  `FLUTTER`, situação `RECEBIDO`, com cliente provisório vinculado e um evento
  `RECEBIDO`. Há uma única ocorrência para a chave idempotente
  empresa/origem/ID-local; o hash de conteúdo foi gravado.
- O snapshot confere com o painel: cliente provisório Jorginho Parmasoft,
  vendedora CYNNARA GRACIANO LAUD, pagamento CHEQUE, item MALHA BRANCA 60 CM,
  400 UN a R$ 19,90, subtotal e total de R$ 7.960,00, prazo de 30 dias,
  previsão de 12/12/2026 e gerencial `S`. A observação gravada é exatamente
  `T3STE DE OBSERVAÇÃO JORGINHO`.
- Os dez campos ampliados do cliente provisório foram gravados e não estão
  vazios: inscrição estadual, e-mail, WhatsApp, CEP, logradouro, número,
  complemento, bairro, cidade e UF. Nome, documento e telefone também estão
  vinculados ao mesmo cliente provisório; valores pessoais completos não são
  reproduzidos nesta documentação.
- O Agente foi iniciado pelo procedimento manual documentado. O log registra
  início às 10:50:40, gravação Firebird às 10:50:42 e confirmação do Agente às
  10:50:43.

### Limites da evidência

- O payload original da API DigitalOcean não foi consultado nesta auditoria;
  portanto os campos ampliados foram comprovados como gravados no Firebird,
  mas não comparados byte a byte com o payload remoto.
- O log do Agente registra o identificador da fila/claim da API, não o UUID
  local do Firebird. O ACK é fortemente corroborado pela sequência temporal e
  pela situação `RECEBIDO`, mas a associação direta na API não foi verificada
  nesta etapa.
- Não foram alterados API, PostgreSQL, Flutter, Delphi, tabelas oficiais,
  regras comerciais ou dados do pedido. O Agente não foi declarado serviço
  permanente.

### Próxima etapa proposta — Delphi

1. Exibir em modo somente leitura os dados completos do cliente provisório no
   painel, tratando nulos como não informados.
2. Antes de qualquer código de conversão, definir e auditar as regras oficiais
   de empresa, CPF/CNPJ, duplicidade, obrigatórios, transação e retorno ao
   pedido. Natália deve conferir o cadastro e realizar a análise Serasa antes
   de autorizar a conversão.
3. Preservar o vínculo do pedido recebido ao cliente oficial após uma futura
   conversão, sem recriar pedido, recalcular snapshots ou alterar a chave de
   idempotência.
4. A consulta financeira no aplicativo do vendedor permanece apenas como
   planejamento futuro para clientes autorizados; não foi implementada.

Foi corrigida exclusivamente a ordem das declarações locais em `test/widget_test.dart`: `completeRequiredOrderDetails` agora é declarada antes de `pumpOrder`, sem alteração de corpo, chamadas ou comportamento esperado dos testes.

## Validação desta retomada

As tentativas de `flutter analyze`, `flutter test` e `flutter test test/local_draft_store_test.dart` foram iniciadas. Neste ambiente, cada comando permaneceu processando sem emitir saída por mais de um minuto (a análise ultrapassou três minutos); as execuções foram encerradas apenas nos respectivos processos Flutter/Dart da validação. Portanto, esta retomada não confirma resultado novo para análise, suíte completa ou os três testes SQLite. A última confirmação registrada, anterior a esta correção, permanece: os três testes de `test/local_draft_store_test.dart` estavam aprovados.

Nenhuma API, PostgreSQL, Agente, Firebird, Delphi, migration ou APK foi alterado.

# Validação Flutter — 10/11/2026

O bloqueio do Flutter foi identificado como árvores órfãs de tentativas anteriores de `flutter analyze`, `flutter test` e `dart format`. Foram encerradas exclusivamente após conferência dos respectivos comandos; os processos do VS Code foram preservados. `flutter analyze` concluiu em 7 s e encontrou 27 avisos/informações preexistentes e um erro em `test/widget_test.dart`: a função local `completeRequiredOrderDetails` é chamada antes de sua declaração. O erro não pertence à ampliação do cadastro e não foi corrigido nesta etapa.

`flutter test` concluiu em 3 s com falha exclusiva no mesmo `widget_test.dart`. Os três testes de `test/local_draft_store_test.dart` foram aprovados, inclusive o novo teste de migração SQLite v6→v7, persistência dos campos opcionais e reabertura. Foi corrigida a condição da migration para que bancos v1/v2, que já recebem a tabela provisória no esquema atual, não tentem adicionar colunas duplicadas. Nenhum APK, banco, serviço ou configuração foi alterado.

# Atualização de implementação — 10/11/2026

O cadastro provisório passou a transportar opcionalmente inscrição estadual, e-mail, WhatsApp e endereço completo (CEP, logradouro, número, complemento, bairro, cidade e UF). A migração SQLite é compatível (versão 7); o script Firebird está versionado em `AgenteMalhas/migrations/20261110_0001_cliente_provisorio_dados_ampliados.sql` e não foi executado. A conversão para cliente fixo segue exclusivamente no Delphi e permanece pendente de auditoria.

# Atualização de encerramento — 22/10/2026

O estado vigente do App de Malhas, incluindo integração local, produtos touch, formas de pagamento, auditoria de clientes e pendências, está em [ENCERRAMENTO_20261022.md](ENCERRAMENTO_20261022.md). Este arquivo preserva o histórico e as referências arquiteturais anteriores.

O histórico abaixo foi preservado sem alteração.

# Status — ParmaGestor: Pedidos de Malhas

Atualizado em 21/10/2026.

## Escopo entregue nesta etapa

Protótipo Flutter independente com navegação demonstrativa entre:

1. Login, com rotação contínua da marca, campos de usuário/senha e modo demonstrativo explícito.
2. Início do vendedor, com Novo Pedido, quatro atalhos, resumo e navegação inferior.
3. Novo Pedido, com cliente, vendedor, múltiplos produtos, quantidade, valor unitário, prazo, pagamento, indicação comercial, entrega e observações.

Os valores e nomes exibidos são fictícios. O botão de entrada não autentica, e salvar pedido não grava nem transmite dados.

Em 21/10/2026, a Tela Inicial do Vendedor recebeu o layout visual aprovado: fundo amarelo-creme/cinza, sem cabeçalho, botão Novo Pedido em grafite, cartões brancos elevados, resumo de três indicadores e navegação inferior clara. Não foram adicionadas integrações ou regras de negócio.

## Referências protegidas e distinção

| Referência | Papel no projeto | Situação |
| --- | --- | --- |
| `E:\Jorginho\BarCode\BarCodeNovo` | Referência visual Flutter: paleta clara/amarela, navegação mobile e conceito de marca rotativa. | Somente leitura; nenhum arquivo foi copiado ou alterado. |
| `E:\Jorginho\AppMotorista` | Referência técnica para uso externo: API em nuvem, sessão, armazenamento local e fila de sincronização. | Somente leitura; nenhum arquivo foi alterado. |
| `E:\Jorginho\Malha_Confeccao` | Projeto independente do app de pedidos. | Único diretório de desenvolvimento. |

## Auditoria do AppMotorista (evidência em fontes e documentação)

### Funcionalidades comprovadas no código e em testes locais

- O app móvel é Flutter e separa configuração, rede, autenticação, armazenamento, viagens e sincronização.
- A configuração de URL e timeout é feita por `dart-define`; há teste apontando o cliente para endpoint HTTPS de homologação.
- Existem sessão com access token/refresh token, renovação e armazenamento pelo `flutter_secure_storage`; não há registro de senha ou token em log no README.
- A API de nuvem mantém o banco PostgreSQL isolado do Firebird. A documentação determina uso atrás de Nginx/HTTPS e bind local no processo.
- A API de nuvem valida sessão Bearer e deriva tenant/motorista da credencial, não do JSON enviado pelo aplicativo.
- O app mantém SQLite local para viagens e uma outbox com estados `pending`, `sending`, `retry`, `synced`, `rejected` e `conflict`.
- Há identificadores UUID de operação e lógica de retry/recuperação de envio interrompido. Na nuvem, há contratos canônicos, recibos idempotentes, locks e testes de login/sessão em banco de teste.

Essas afirmações significam que há implementação e cobertura automatizada local; não equivalem a homologação externa em produção.

### Componentes e padrões potencialmente reutilizáveis

- Estrutura em camadas: telas → serviços/repositórios → transporte HTTP → armazenamento local.
- `flutter_secure_storage` para sessão e tokens.
- Outbox transacional em SQLite, com GUID imutável por operação, tentativas, erro e estado terminal.
- Idempotência do lado servidor, usando uma chave de operação do cliente e recibo persistido.
- Refresh de sessão e bloqueio local de ações quando a sessão expira.
- Contratos versionados e validação no servidor antes de gravar projeções.

Nada disso foi incorporado nesta etapa visual.

### Pendências técnicas e alerta de autenticação externa

- A documentação da API de nuvem declara que produção ainda exige validação de integração em PostgreSQL real, migrations, concorrência e infraestrutura de produção.
- O README da API de nuvem anteriormente descrevia que não havia login/ponte de sessão; há fontes e testes posteriores para login móvel, mas não há registro de homologação externa concluída no material auditado.
- Há duas linhas de implementação: uma API local ligada ao Firebird e a API de nuvem isolada. O app de malhas não deve presumir que qualquer uma possa ser usada sem uma análise e homologação específicas.
- Não foi identificada uma prova documental de operação em produção de ponta a ponta (celular externo → HTTPS público → login → refresh → autorização de dados) para liberar esse desenho sem testes próprios.

## Recomendação para a futura integração externa

1. Criar uma API de malhas própria, publicada exclusivamente por HTTPS, com banco de integração próprio. Nunca expor o Firebird ou conectá-lo diretamente ao celular.
2. Autenticar usuário e senha somente no servidor; associar o usuário autenticado ao vendedor do ParmaGestor no servidor e derivar essa identidade do token em cada requisição.
3. Validar no servidor a carteira de clientes, preços autorizados, dados financeiros e permissão de segunda via de boleto. O aplicativo deve somente exibir dados já autorizados.
4. Persistir um pedido offline com GUID gerado uma única vez, versão do payload, data local e snapshot comercial. Ao sincronizar, enviar a mesma chave de idempotência em toda repetição.
5. Preservar o payload original aceito pelo servidor como documento imutável; correções devem gerar evento/versão posterior, não sobrescrever o pedido enviado.
6. Tratar cliente provisório como estado explícito no servidor e bloquear sua conversão em Pedido de Venda até regularização.
7. Homologar login, expiração/renovação, revogação, escopo de carteira, perda de rede, retomada, duplicidade e concorrência antes de produção.
