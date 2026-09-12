# Status - App Motorista / Carga

Atualizado em: 26/08/2026
Atualizado por: Codex
Fonte de verdade: fontes Delphi do projeto, controle de versao e testes registrados na sessao.

Este documento registra o ponto oficial de continuidade do projeto App Motorista / Carga. A secao mais recente abaixo prevalece como ponto de retomada; as secoes posteriores permanecem como historico consolidado do proprio STATUS.

## Fechamento do dia - Flutter V1 Bloco 1 no celular fisico - 25/08/2026

### Estado atual

**FLUTTER V1 BLOCO 1 FUNCIONAL NO APARELHO FISICO / HOMOLOGACAO VISUAL E OPERACIONAL EM ANDAMENTO.**

- Projeto Flutter V1 Bloco 1 criado em `E:\Jorginho\AppMotorista\AppMotorista`.
- API oficial em `E:\Jorginho\AppMotorista\ApiMotorista`.
- Projeto Flutter compilando.
- `flutter analyze` executado sem problemas.
- 9 testes automatizados aprovados.
- Teste manual iniciado em celular Android fisico.
- Comunicacao local funcionando por USB com `adb reverse tcp:5055 tcp:5055`.
- O App conseguiu comunicar com a API.
- A autenticacao manual funcionou.
- A tela `Minhas Viagens/Cargas` abriu e as viagens/cargas estao sendo retornadas.
- Paradas/clientes estao sendo exibidos.
- Pedidos das paradas estao sendo exibidos.
- Ao abrir o pedido, os itens/ocorrencias podem ser visualizados.
- O fluxo basico do Flutter esta funcional no aparelho fisico.
- Ainda existem ajustes visuais e operacionais a fazer nas telas; o Bloco 1 ainda nao esta totalmente homologado.
- Preservar obrigatoriamente a diretriz `MOBILE FIRST`: fonte grande, tela limpa, poucas informacoes e acoes evidentes para o motorista.
- Scanner e leitura C/R ainda NAO foram iniciados no Flutter.
- Offline e outbox ainda NAO foram iniciados.
- API pela Internet/HTTPS ainda NAO foi implantada; o teste atual e exclusivamente local via USB/ADB reverse.

### PROXIMO PASSO DO JORGINHO

Continuar amanha a homologacao visual e operacional das telas no celular fisico, enviando prints e observacoes.

### PROXIMO PASSO DO CODEX

Ajustar somente o que for identificado no teste manual e, depois de homologar o Bloco 1, preparar o proximo bloco de leitura C/R.

### NAO REFAZER

- arquitetura Flutter;
- autenticacao;
- sessao/refresh;
- API de viagens;
- Manifesto;
- backend C/R ja homologado;
- testes automaticos ja aprovados;
- investigacao de caminhos ja documentados.

### Documentacao deste fechamento

- A diretriz permanente `MOBILE FIRST + ALTA LEGIBILIDADE + MINIMO DE INFORMACAO` ja esta registrada em `Documentacao/AGENTS.md`; o arquivo nao foi alterado novamente.
- O manual grande `App_Motorista_Carga.docx` nao foi atualizado porque a homologacao visual e operacional do Bloco 1 continua em andamento.

## Ponto oficial de continuidade - Flutter V1 Bloco 1 - 25/08/2026

### Estado exato

**FLUTTER V1 BLOCO 1 IMPLEMENTADO E VALIDADO AUTOMATICAMENTE / AGUARDANDO TESTE MANUAL DO JORGINHO.**

- Flutter iniciado.
- Projeto oficial criado em `E:\Jorginho\AppMotorista\AppMotorista`.
- API oficial preservada em `E:\Jorginho\AppMotorista\ApiMotorista`.
- Ultimo script de banco continua sendo `actScript171 / 1.1.0.71`, ja homologado.
- Nenhum banco, fonte Delphi ou fonte da API foi alterado neste bloco.
- Scanner e leitura C/R no Flutter ainda NAO foram iniciados.
- O manual grande `App_Motorista_Carga.docx` nao foi atualizado, conforme a regra de atualiza-lo somente depois da homologacao do bloco Flutter.

### Padrao visual permanente

O App Motorista e mobile-first e deve sempre apresentar alta legibilidade e o minimo de informacao. As telas deste bloco usam fontes grandes, alto contraste, cartoes amplos, botoes com area de toque confortavel, uma informacao dominante por tela e detalhes secundarios sob demanda.

Nao transformar telas do ERP em grids de celular. Antes de mostrar um campo, confirmar se o motorista precisa dele para executar a entrega. O objetivo permanente e:

```text
TELA LIMPA
LETRAS GRANDES
POUCAS INFORMACOES
ACOES OBVIAS
SEM POLUICAO VISUAL
```

### Ambiente confirmado

```text
Flutter 3.38.5 stable
Dart 3.10.4
Projeto: E:\Jorginho\AppMotorista\AppMotorista
API:     E:\Jorginho\AppMotorista\ApiMotorista
Base URL padrao do emulador Android: http://10.0.2.2:5055
```

A URL, o ambiente e o timeout ficam centralizados por `dart-define`; IP/URL nao foram espalhados pelas telas ou repositories.

### Implementado no Bloco 1

- arquitetura simples separada em `core`, `auth`, `viagens`, `storage`, `network`, `models`, `repositories`, `services`, `screens` e `widgets`;
- login mobile com usuario, senha, avancar/enviar pelo teclado, loading e mensagem sem revelar se o usuario existe;
- consumo de `POST /api/v1/motorista/sessoes`;
- sessao persistida com `flutter_secure_storage`, sem `SharedPreferences` comum;
- restauracao da sessao ao abrir o App;
- renovacao por `POST /api/v1/motorista/sessoes/renovar`;
- refresh unico e controlado, com apenas uma repeticao segura da requisicao que recebeu 401;
- limpeza da sessao e retorno ao login quando o refresh falha;
- tela `Minhas viagens` por `GET /api/v1/motorista/viagens`, sem enviar motorista, empresa ou transportador como filtro;
- detalhe por `GET /api/v1/motorista/viagens/{manifesto_guid}`;
- paradas na ordem devolvida pela API, inclusive cliente sem coordenadas;
- tela de parada com cliente dominante, cidade/UF, endereco e pedidos;
- tela de pedido com numero dominante, totais de etiquetas pendentes e entregues;
- visualizacao das ocorrencias esperadas C/R, sem scanner e sem mudanca P -> E;
- ocorrencias C iguais permanecem em linhas independentes;
- ocorrencia R preserva e mostra `ROLO_ID` sob demanda;
- tratamento amigavel de timeout, falta de conexao, 401, 403, 404, erro do servidor e JSON invalido;
- logs de desenvolvimento limitados a metodo, endpoint e tempo, sem senha ou tokens.

### Fontes criados/alterados no projeto Flutter

Configuracao e entrada:

- `pubspec.yaml`, `pubspec.lock`, `README.md`;
- `android/app/src/main/AndroidManifest.xml`;
- `lib/main.dart`, `lib/app.dart`;
- `lib/core/config/app_config.dart`;
- `lib/core/errors/api_exception.dart`;
- `lib/core/network/api_client.dart`;
- `lib/core/network/api_transport.dart`;
- `lib/core/network/http_api_transport.dart`;
- `lib/core/theme/app_theme.dart`;
- `lib/core/utils/display_format.dart`;
- `lib/core/widgets/async_message.dart`.

Autenticacao e armazenamento:

- `lib/auth/models/session.dart`;
- `lib/auth/repositories/auth_repository.dart`;
- `lib/auth/services/session_controller.dart`;
- `lib/auth/screens/login_screen.dart`;
- `lib/storage/session_storage.dart`;
- `lib/storage/secure_session_storage.dart`.

Viagens:

- `lib/viagens/models/trip_summary.dart`;
- `lib/viagens/models/trip_detail.dart`;
- `lib/viagens/repositories/trips_repository.dart`;
- `lib/viagens/services/trips_service.dart`;
- `lib/viagens/screens/trips_screen.dart`;
- `lib/viagens/screens/trip_detail_screen.dart`;
- `lib/viagens/screens/stop_screen.dart`;
- `lib/viagens/screens/order_screen.dart`.

Testes:

- `test/helpers/fakes.dart`;
- `test/auth/login_widget_test.dart`;
- `test/auth/session_controller_test.dart`;
- `test/network/auth_repository_test.dart`;
- `test/viagens/trip_models_test.dart`.

Documentacao alterada nesta rodada:

- `Documentacao/AGENTS.md`;
- `Documentacao/STATUS_APP_MOTORISTA_CARGA.md`.

### Validacao automatizada executada

No projeto oficial `E:\Jorginho\AppMotorista\AppMotorista`:

```text
flutter pub get  -> OK
flutter analyze  -> No issues found
flutter test     -> 9 testes aprovados
```

Os testes cobrem login/repository, armazenamento e restauracao da sessao, refresh, repeticao unica apos 401, encerramento da sessao no segundo 401 sem loop, parse do resumo de viagens, parse do Manifesto, C repetida como ocorrencias independentes e R com `ROLO_ID` preservado.

### Ajuste local da API e credencial temporaria - 25/08/2026

- Causa confirmada do erro local: existia `.env.example`, mas nao havia `.env` local e o BAT nao carregava as variaveis; por isso `FB_DATABASE` chegava vazio a `app.config.Config`.
- Criado `E:\Jorginho\AppMotorista\ApiMotorista\.env` local, fora de repositorio Git, com a mesma conexao Firebird usada na homologacao. A senha Firebird nao foi incorporada a fonte versionado nem registrada neste STATUS.
- Atualizado `E:\Jorginho\AppMotorista\ApiMotorista\iniciar_api_motorista.bat` para carregar e validar o `.env` antes de ativar a API por `run.py` na porta 5055.
- A conexao foi aberta pela propria `app.database.connect`; `SELECT 1 FROM RDB$DATABASE` retornou sucesso no banco `E:\Dados Clientes\GramDecor\Dados.FDB`, charset `ISO8859_1`.
- Por autorizacao expressa posterior, o motorista homologado `MOTAPP_ID = 1` foi preservado e recebeu a credencial temporaria local `A / A`. Foram alterados somente `MOTAPP_LOGIN` e `MOTAPP_SENHA_HASH`, usando `werkzeug.security.generate_password_hash` (`scrypt:32768:8:1`), sem senha em texto puro no banco.
- Permanecem confirmados: motorista ativo, vinculo ativo com a empresa 10, Manifesto 5 atribuido, carga 504 e Manifesto liberado.
- A credencial `A / A` deve ser substituida antes de qualquer implantacao real.
- Flutter, ADB, endpoints, regras de autenticacao, Delphi, DDL e demais registros nao foram alterados.
- Proximo passo do Jorginho: fechar a janela antiga da API e abrir novamente `iniciar_api_motorista.bat`; depois repetir o login no celular.

### Ponto exato da parada

O codigo e os testes automaticos estao prontos. Nenhum emulador foi aberto, nenhum APK foi instalado e nenhum teste visual ou operacional manual foi executado. A continuidade deve comecar exclusivamente pela homologacao manual abaixo.

### Proximo passo do Jorginho

O teste manual inicial sera feito em aparelho Android fisico conectado por USB, com Depuracao USB ativa e `adb reverse tcp:5055 tcp:5055`. Foram criados:

- API: `E:\Jorginho\AppMotorista\ApiMotorista\iniciar_api_motorista.bat`;
- celular: `E:\Jorginho\AppMotorista\AppMotorista\iniciar_app_celular.bat`.

Executar primeiro o BAT da API e, depois que a porta 5055 estiver ativa, o BAT do celular. O segundo BAT detecta o aparelho fisico autorizado, configura o ADB reverse e inicia o Flutter com `API_BASE_URL=http://127.0.0.1:5055`, sem iniciar emulador.

### Proximo passo do Codex

Depois do retorno do Jorginho, corrigir somente incompatibilidades ou problemas visuais comprovados, repetir `flutter analyze` e `flutter test`, atualizar este STATUS e aguardar a homologacao do Bloco 1. Nao iniciar scanner automaticamente.

### Pendencias

- homologacao manual do Bloco 1 pelo Jorginho;
- somente depois da homologacao, atualizar `App_Motorista_Carga.docx`;
- scanner, camera, leitura C/R, mudanca P -> E, offline completo, outbox, entrega parcial, nao entrega, avaria, recusa, estorno, GPS continuo, mapa, tracking, assinatura e foto pertencem a blocos futuros.

### Itens que NAO devem ser refeitos

- nao recriar o projeto Flutter;
- nao redescobrir o contrato da API;
- nao alterar backend sem incompatibilidade real comprovada na integracao;
- nao refazer Manifesto, motorista App, autenticacao, atribuicao/liberacao, API de viagens ou Conferencia Normal C/R;
- nao recriar nem reaplicar `actScript169`, `actScript170` ou `actScript171`;
- nao substituir o armazenamento seguro por `SharedPreferences`;
- nao consolidar ocorrencias C iguais;
- nao iniciar scanner ou qualquer bloco futuro antes de homologar este Bloco 1;
- nao abrir automaticamente `_HISTORICO_NAO_LER` nem reconstruir contexto por busca ampla.

## Ponto oficial de continuidade - Conferencia Normal de Entrega C/R - 25/08/2026

### Situacao

**CONFERENCIA NORMAL DE ENTREGA C/R HOMOLOGADA NO BACKEND E NA API LOCAL.**

- Nao iniciar Flutter automaticamente.
- Nao refazer auditorias de manifesto, motorista, autenticacao ou API de viagens.
- Nao recriar nem reaplicar `actScript169`, `actScript170` ou `actScript171`.
- O proximo agente deve ler esta secao antes de consultar qualquer outro documento ou historico.

### Fechamento consolidado dos blocos

```text
actScript169 - Manifesto de entrega homologado.
actScript170 - Identidade do motorista App, autenticacao, atribuicao e liberacao homologadas.
actScript171 - Conferencia Normal de Entrega C/R homologada.
```

Tambem estao homologados:

- autenticacao e renovacao de sessao do motorista;
- atribuicao do motorista e liberacao do manifesto;
- listagem e snapshot da API de viagens;
- leitura C/R pela API oficial;
- C repetida consumida por multiplicidade de ocorrencias do manifesto;
- R individual consumida pelo `ROLO_ID` exato;
- censuras por carga, parada e pedido;
- idempotencia e conflito de `OPERACAO_GUID`;
- concorrencia;
- ledger append-only e tentativas/replays;
- conclusao normal de pedido e parada;
- rollback.

Flutter ainda nao foi iniciado.

### Proximo bloco

```text
PRÓXIMO BLOCO:
FLUTTER APP MOTORISTA V1
```

Esse bloco permanece apenas definido como proxima etapa. Nao iniciar Flutter nesta rodada nem automaticamente em nova sessao sem a solicitacao correspondente.

### Ambiente efetivamente usado

```text
Workspace Delphi:
E:\Repositorio_Parmasoft\ParmaDistribuidora\Source

Global compartilhado:
E:\Repositorio_Parmasoft\Global\Source

Banco de homologacao local:
localhost:E:\Dados Clientes\GramDecor\DADOS.FDB

API oficial do App Motorista:
E:\Jorginho\AppMotorista\ApiMotorista
```

O repositorio Parmasoft encontrado e SVN. Nao existe repositorio Git nesse workspace e o cliente de linha de comando SVN nao estava instalado; por isso o estado foi conferido por arquivos, timestamps, fontes e banco, sem alegar `git status` limpo.

### Ultimo actScript e banco

```text
actScript171
versao 1.1.0.71
TB_CONTROLE_VERSAO.CTR_STATUS = A
CTR_ERROS vazio
```

O SQL foi primeiro validado integralmente pelo parser do Firebird 2.5 em transacao revertida. Depois da compilacao do ParmaGestor, foi aplicado pelo mecanismo oficial de Controle de Versao, chamando as rotinas reais `UClassControleVersao.AtualizarScript` e `UClassControleVersao.ExecutarScript`.

Objetos validados depois da aplicacao:

- generator `GEN_CARGA_MANIFESTO_TENT_ID`;
- tabela append-only `TB_CARGA_MANIFESTO_TENTATIVA`;
- campos `CARGMOP_MOTORISTA_APP`, `CARGMOP_SESSAO_APP`, `CARGMOP_PENDENTES_PEDIDO` e `CARGMOP_PENDENTES_PARADA`;
- constraints, FKs e checks do ledger/tentativa;
- indices `IX_CARGMOP_MOTOR_DATA`, `IX_CARGMT_GUID_DATA` e `IX_CARGMT_MANIF_CONTEXTO` ativos;
- triggers `TG_CARGMOP_PROTEGE` e `TG_CARGMT_PROTEGE` ativos;
- exception `EX_CARGMT_IMUTAVEL`;
- procedure `SP_REG_ENTREGA_MANIFESTO`, com 15 entradas e 10 saidas;
- grants da procedure conferidos no catalogo.

### Compilacao Delphi

- Projeto: `ParmaGestor.dproj`.
- Configuracao: `Debug / Win32`.
- Resultado: sucesso, codigo de saida `0`.
- Executavel de validacao: `E:\Repositorio_Parmasoft\ParmaDistribuidora\Source\Win32\Debug\ParmaGestor.exe`.
- Permaneceram somente warnings/hints legados do ERP, ACBr, RTTI/inlining e recursos duplicados.
- Nenhum erro introduzido por `actScript171` ou pelas alteracoes Delphi desta rodada.

### Regra backend homologada

`SP_REG_ENTREGA_MANIFESTO` e a autoridade transacional para a leitura normal C/R. Foram homologados:

- C unica: `P -> E`;
- C repetida ate o numero exato de ocorrencias pendentes;
- leitura C adicional bloqueada com `TODAS_OCORRENCIAS_ENTREGUES`;
- R individual aceita e releitura bloqueada com `ROLO_JA_ENTREGUE`;
- `OUTRO_PEDIDO`;
- `OUTRA_PARADA`;
- `OUTRA_CARGA`;
- `NAO_PERTENCE_CARGA`;
- mesmo `OPERACAO_GUID` e mesmo payload como replay, sem novo consumo;
- mesmo GUID com payload diferente como `OPERACAO_GUID_CONFLITO`;
- concorrencia real com duas conexoes Firebird;
- conclusao automatica do pedido;
- conclusao da parada somente depois de todos os pedidos;
- motorista incorreto e motorista inativo;
- manifesto nao liberado;
- rollback completo;
- ledger normal, recusado, conflito e replay;
- imutabilidade das tentativas pela trigger.

No teste concorrente persistido, duas conexoes usaram o mesmo GUID e payload. A primeira consumiu uma ocorrencia C; a segunda aguardou o lock e recebeu replay da mesma operacao. Esse teste deixou intencionalmente:

```text
OPERACAO_GUID A1710000-0000-0000-0000-000000000001
1 operacao consolidada
2 tentativas (normal + replay)
codigo C00258510003850010000
9 ocorrencias pendentes de 10
```

Todos os demais cenarios de homologacao do backend foram executados com prefixo `B171` e revertidos. A verificacao posterior confirmou zero operacoes/tentativas `B171`, pedidos/paradas restaurados e sessoes de teste 4/5 devolvidas aos valores revogados originais.

### Endpoint oficial

```http
POST /api/v1/motorista/viagens/{manifesto_guid}/paradas/{parada}/pedidos/{pedido}/leituras
```

Fluxo implementado:

```text
HTTP
-> token Bearer e sessao
-> app.viagens.delivery
-> app.viagens.repository
-> SP_REG_ENTREGA_MANIFESTO
-> commit/rollback Firebird
```

A API:

- deriva motorista, sessao e dispositivo da autenticacao;
- nao aceita empresa, motorista, status final ou ocorrencia escolhida pelo celular;
- normaliza GUID/codigo, data/hora, fuso e decimais;
- canonicaliza o payload e calcula SHA-256 no servidor;
- usa versao de payload `1`;
- devolve resultado, codigo estavel, mensagem, operacao, ocorrencia GUID, tipo, pedido, pendencias e flag de replay;
- responde HTTP 409 apenas para conflito de idempotencia; recusas de negocio processadas retornam HTTP 200 com `resultado = RECUSADA`.

### Homologacao HTTP

O conjunto de fontes depois incorporado a API oficial foi exercitado no staging com o Flask test client e conexao Firebird real, mantendo todos os efeitos HTTP numa transacao externa de homologacao. Depois da copia, SHA-256 confirmou que os seis arquivos alterados no staging e na API oficial eram identicos. Foram provados por HTTP:

- login e autenticacao;
- listagem e snapshot da viagem;
- bloqueio sem token;
- rejeicao de campo de identidade pertencente ao servidor;
- C unica;
- nove leituras restantes da C repetida e a decima adicional bloqueada;
- R e releitura de R;
- outro pedido, outra parada, outra carga e codigo inexistente;
- replay identico;
- conflito do mesmo GUID com payload alterado;
- pedido concluido;
- parada com varios pedidos somente concluida no momento correto;
- motorista incorreto, motorista inativo e manifesto G;
- 19 operacoes e 21 tentativas visiveis dentro da transacao.

Depois da inspecao, a transacao HTTP foi revertida. Uma nova conexao confirmou zero operacoes e zero tentativas com prefixo `C171`; nenhum login, leitura, pedido, parada ou ledger HTTP permaneceu no banco.

Validacoes da API oficial:

- 5 testes unitarios: sucesso;
- analise sintatica AST: 16 arquivos Python, sucesso;
- teste HTTP/Firebird real: sucesso;
- `compileall` na pasta oficial nao conseguiu gravar `__pycache__` por permissao do sandbox, mas os mesmos fontes foram importados e executados pelos testes sem escrita; isso nao representa erro de sintaxe ou execucao.

### Arquivos alterados nesta sequencia

Delphi/versionamento:

- `E:\Repositorio_Parmasoft\Global\Source\Model\UDmControleVersao.pas`;
- `E:\Repositorio_Parmasoft\Global\Source\Model\UDmControleVersao.dfm`;
- `E:\Repositorio_Parmasoft\ParmaDistribuidora\Source\Controller\UClassConfereCarga.pas`;
- `E:\Repositorio_Parmasoft\ParmaDistribuidora\Source\View\Mov\UManConfereRecebTransfReqCarga.pas`;
- `E:\Repositorio_Parmasoft\ParmaDistribuidora\Source\View\Mov\UManConfereRecebTransfReqCarga.dfm`;
- `E:\Repositorio_Parmasoft\ParmaDistribuidora\Source\View\UPrincipal.dfm`.

API oficial:

- `E:\Jorginho\AppMotorista\ApiMotorista\app\auth\security.py`;
- `E:\Jorginho\AppMotorista\ApiMotorista\app\viagens\routes.py`;
- `E:\Jorginho\AppMotorista\ApiMotorista\app\viagens\delivery.py`;
- `E:\Jorginho\AppMotorista\ApiMotorista\app\viagens\repository.py`;
- `E:\Jorginho\AppMotorista\ApiMotorista\tests\test_delivery.py`;
- `E:\Jorginho\AppMotorista\ApiMotorista\README.md`.

Continuidade:

- `Documentacao\STATUS_APP_MOTORISTA_CARGA.md`;
- `Documentacao\AGENTS.md`.

Auxiliares removidos depois da incorporacao e da homologacao:

- `act171_homologacao_tmp.sql`;
- `embed_act171_tmp.ps1`;
- `controle_versao_runner_tmp.dpr` e `Win32\ControleVersaoRunner`;
- staging e scripts temporarios da homologacao HTTP C/R.

### Proximo passo do Jorginho

Nenhuma acao manual e necessaria para concluir esta homologacao. Preservar/registrar os fontes Delphi e a pasta oficial da API no mecanismo de backup/versionamento usado pelo projeto. Quando desejar continuar, solicitar explicitamente o bloco `FLUTTER APP MOTORISTA V1`.

### Proximo passo do Codex

Na proxima tarefa do App Motorista:

1. ler primeiro este STATUS;
2. conferir apenas o estado fisico dos arquivos diretamente citados pela nova tarefa;
3. nao varrer `_HISTORICO_NAO_LER`, anexos ou sessoes antigas para reconstruir contexto;
4. partir do contrato C/R ja homologado e do ultimo script `actScript171 / 1.1.0.71`;
5. usar `actScript172` somente se uma nova evolucao estrutural realmente for autorizada e necessaria;
6. nao iniciar Flutter sem autorizacao expressa.

### Itens que nao devem ser refeitos

- auditoria conceitual de volumes, etiquetas, manifesto e paradas;
- auditoria do recebimento da filial;
- modelagem e geracao do manifesto (`actScript169`);
- identidade, sessao, atribuicao, liberacao e API de viagens (`actScript170`);
- desenho, parser, incorporacao, compilacao, aplicacao ou homologacao de `actScript171`;
- testes backend C/R listados nesta secao;
- implementacao de login, refresh, listagem/snapshot de viagem ou endpoint de leitura;
- buscas amplas no repositorio, em `Documentacao` ou na pasta historica para recuperar o que ja esta registrado aqui.

### Pendencias no ponto de passagem

- Nenhuma pendencia tecnica permanece na Conferencia Normal de Entrega C/R homologada.
- O Flutter App Motorista V1 e o proximo bloco, ainda nao iniciado.
- Evolucoes posteriores como parcialidade, falta, recusa, avaria, cliente fechado, nao localizado e estorno operacional continuam fora deste fechamento e exigem bloco proprio.

## Estado geral

- Bloco A aprovado funcionalmente: ciclo pre-finalizacao de `TB_CARGA_PARADA`.
- Bloco B aprovado estruturalmente e compilado: origem geografica da viagem via empresa expedidora e snapshot em `TB_CARGA`.
- Roteirizacao V1 e setas `Subir` e `Descer` homologadas funcionalmente na carga real 525.
- Abertura da Visao da Viagem protegida: snapshot e sincronizacao somente com `CARG_STATUS = 'A'`.
- Premissa multiempresa confirmada: matriz e filiais podem criar e executar suas proprias cargas.
- Persistencia da ordem manual confirmada ao fechar e reabrir a tela.
- Ainda pendente: teste final do congelamento do planejamento apos a carga ser efetivamente finalizada.
- Ajuste visual da Visao da Viagem implementado e compilado; aguarda nova homologacao visual do Jorge.

## Bloco A - ciclo pre-finalizacao das paradas

### Regra funcional aprovada

- `TB_CARGA_PARADA` pode existir antes da finalizacao da carga.
- Ao entrar no planejamento de Ordem de Entrega de uma carga ainda editavel, as paradas precisam existir.
- A chave funcional da parada e `Carga + Cliente`.
- Uma carga com varios pedidos do mesmo cliente deve manter uma unica parada para esse cliente.
- Os pedidos do mesmo cliente permanecem vinculados dentro da mesma parada.
- A geracao/sincronizacao precisa ser idempotente: abrir a tela varias vezes nao pode duplicar paradas nem vinculos de pedidos.
- Se um novo pedido/cliente for incluido na carga antes da finalizacao, a sincronizacao deve criar a parada/vinculo correspondente.
- Se um pedido for retirado antes da finalizacao, o vinculo deve ser removido; paradas sem mais pedidos devem ser tratadas corretamente.
- Sempre que possivel, preservar `CARGPA_ORDEM_PLANEJADA` ja ajustada manualmente.
- `CARGI_ORDEM_ENTREGA` nao sera fonte principal da nova ordem oficial da V1.
- Na finalizacao, `SP_GERA_CARGA_PARADAS` pode continuar sendo chamada como conferencia/sincronizacao final, mas nao pode destruir a ordem planejada.

### Campos de ordem definidos

- `CARGPA_ORDEM_SUGERIDA`: ultima sugestao automatica calculada pelo sistema.
- `CARGPA_ORDEM_PLANEJADA`: ordem definida/oficial da V1, ajustavel pelo usuario.
- `CARGPA_ORDEM_REALIZADA`: uso futuro para execucao do App Motorista.
- `CARGPA_ORDEM_DEFINIDA`: nao criar.

### Banco / versionamento

- Script criado: `actScript167x`.
- Versao: `1.1.0.67x`.
- `actScript167w` foi preservado como historico ja distribuido/aplicado.
- `actScript167x` recria/evolui `SP_GERA_CARGA_PARADAS`.
- `FK_CARGPAP_CARGA_ITEM` foi alterada para `ON DELETE CASCADE`.
- A procedure foi ajustada para ciclo pre-finalizacao e sincronizacao idempotente.

### Testes do Bloco A

- Teste partindo de base com `167w` ja aplicado.
- Confirmada criacao/sincronizacao de paradas antes da finalizacao.
- Confirmado que abrir a rotina novamente nao duplica paradas/pedidos.
- Confirmada preservacao de `CARGPA_ORDEM_PLANEJADA` quando possivel.
- Confirmado tratamento de inclusao/remocao de pedido antes da finalizacao.
- Confirmada compilacao apos ajustes do bloco.

## Bloco B - origem geografica da viagem

### Regra funcional aprovada

- A localizacao permanente pertence a empresa expedidora.
- A carga guarda um snapshot da localizacao usada como origem naquela viagem.
- Depois de materializado, o snapshot da carga nunca deve acompanhar automaticamente alteracoes posteriores na empresa.
- Exemplo: carga 505 nasce com coordenada X; depois a empresa e corrigida para Y; carga 505 permanece com X, novas cargas usam Y.
- Nao criar FK ou mecanismo que faca o snapshot acompanhar a empresa.

### TB_EMPRESA

Campos adicionados conceitualmente e implementados no versionamento:

- `EMP_LATITUDE`
- `EMP_LONGITUDE`
- `EMP_ORIGEM_COORDENADA`
- `EMP_PRECISAO_COORDENADA`
- `EMP_COORD_DATA_HORA`
- `EMP_COORD_USUARIO`
- `EMP_COORD_CONFIRMADA`

Padrao adotado:

- Latitude/Longitude seguem o padrao de `TB_CLIENTE`: `NUMERIC(18,8)`.
- `EMP_COORD_CONFIRMADA` aceita somente:
  - `S`: confirmada;
  - `N`: nao confirmada.
- Nao foram criados status adicionais na V1.

### Cadastro de Empresas

- Foi criada aba runtime `Geolocalizacao` em `UManEmpresa`.
- A experiencia segue o conceito do Cadastro de Clientes:
  - Latitude/Longitude nao editadas livremente;
  - botao `Colar Localizacao`;
  - validacao Cidade/UF;
  - mapa somente para visualizacao;
  - situacao/origem;
  - nao sobrescrever silenciosamente localizacao ja confirmada.
- O mapa usa `UClienteGeoMap.pas`, com mensagem configuravel para empresa sem localizacao.
- Nao houve refatoracao ampla do Cadastro de Clientes.

### UClassGeolocalizacao.pas

Unit generica criada em:

- `E:\Repositorio_Parmasoft\Global\Source\Controller\UClassGeolocalizacao.pas`

Responsabilidades mantidas genericas:

- extrair coordenadas de texto/link;
- formatar coordenada para URL;
- normalizar coordenada conforme cadastro;
- normalizar texto para comparacao;
- converter estado brasileiro para UF;
- consultar Nominatim por `geocodejson`;
- obter cidade/UF por coordenada.

### Snapshot em TB_CARGA

Campos implementados:

- `CARG_ORIGEM_LATITUDE`
- `CARG_ORIGEM_LONGITUDE`
- `CARG_ORIGEM_COORDENADA`

Regra:

- `LAT + LONG` existentes: preservar e retornar sucesso.
- `LAT + LONG` ambos `NULL`: buscar empresa expedidora com coordenada confirmada e copiar.
- Somente uma coordenada preenchida: erro explicito de inconsistencia.
- Empresa sem geolocalizacao confirmada: falha explicita; nao criar snapshot silenciosamente.
- Depois de materializado, nunca atualizar automaticamente.

### GarantirSnapshotOrigemCarga

Rotina implementada em:

- `E:\Repositorio_Parmasoft\ParmaDistribuidora\Source\Controller\UClassCarga.pas`

Contrato final:

- `function GarantirSnapshotOrigemCarga(const AEmpresa, ACarga: Integer; out AMensagem: string): Boolean;`
- Retorna `True` quando o snapshot ja existe completo ou quando foi criado com sucesso.
- Retorna `False` com mensagem quando empresa/carga nao foram informadas, carga nao existe, empresa nao possui geolocalizacao confirmada, snapshot esta parcial/inconsistente ou houve excecao.

### Banco / versionamento

- Script criado: `actScript167y`.
- Versao: `1.1.0.67y`.
- Objetos alterados:
  - `TB_EMPRESA`: campos de geolocalizacao.
  - `TB_CARGA`: campos do snapshot minimo da origem.
  - `CK_EMP_COORD_CONFIRMADA`: check `EMP_COORD_CONFIRMADA IN ('S', 'N')`.
- `actScript167y` ainda nao foi aplicado na base real.

### Testes do Bloco B

- SQL do `167y` aplicado somente em base de teste/copia existente.
- Metadata confirmada:
  - `EMP_LATITUDE` e `EMP_LONGITUDE`: `NUMERIC(18,8)`.
  - `CARG_ORIGEM_LATITUDE` e `CARG_ORIGEM_LONGITUDE`: `NUMERIC(18,8)`.
  - `EMP_COORD_CONFIRMADA`: `VARCHAR(1) DEFAULT 'N' NOT NULL`.
  - Constraint: `CK_EMP_COORD_CONFIRMADA`.
- Teste transacional com rollback confirmou:
  - snapshot nulo foi materializado a partir da empresa confirmada;
  - snapshot existente foi preservado;
  - snapshot com somente uma coordenada foi identificado como inconsistente;
  - empresa sem geolocalizacao confirmada nao materializa snapshot.
- Compilacao `ParmaGestor.dproj Debug/Win32`: OK.

## Regras definitivas da V1 da rota

- O sistema tera duas sugestoes:
  - `Proximo -> Longe`;
  - `Longe -> Proximo`.
- A origem do calculo sera sempre o snapshot da empresa gravado na carga.
- Clientes/paradas com geolocalizacao valida participam do calculo.
- Clientes/paradas sem geolocalizacao:
  - ficam sempre no final da lista sugerida;
  - nao recebem distancia ficticia;
  - nao participam do calculo geografico;
  - mantem entre si ordem estavel, preferencialmente a ordem planejada/original existente;
  - exibem `SEM LOCALIZACAO`.
- Se todos os clientes estiverem sem geolocalizacao:
  - nao ha calculo geografico util;
  - manter ordem planejada/original;
  - avisar que nenhuma parada possui localizacao;
  - permitir reordenacao manual pelas setas.
- Distancia em linha reta e aceita na V1 como sugestao, nao como roteirizacao rodoviaria.
- Em empate ou distancia praticamente igual, usar ordem planejada/original existente como desempate deterministico.
- Quando uma sugestao for aplicada:
  - gravar sequencia em `CARGPA_ORDEM_SUGERIDA`;
  - inicialmente copiar a mesma sequencia para `CARGPA_ORDEM_PLANEJADA`.
- Quando o usuario usar setas para subir/descer:
  - alterar somente `CARGPA_ORDEM_PLANEJADA`;
  - renumerar 1..N;
  - preservar `CARGPA_ORDEM_SUGERIDA`.
- O motorista/expedicao pode reorganizar qualquer parada pelas setas, inclusive paradas sem localizacao.
- A decisao humana prevalece sobre a sugestao automatica.
- Depois de Finalizar Carga:
  - bloquear `Proximo -> Longe`;
  - bloquear `Longe -> Proximo`;
  - bloquear setas;
  - nao recalcular;
  - nao reordenar;
  - preservar `CARGPA_ORDEM_PLANEJADA`.
- Nao havera recalculo de rota durante a viagem, pois a disposicao fisica da mercadoria no caminhao segue a ordem definida antes da saida.

## Pendencia descoberta - Carga da Transferencia de Requisicao

Nova pendencia conceitual registrada em 14/08/2026:

- A retirada nao pode existir somente por requisicao inteira.
- Deve ser estudada retirada item/volume da carga, sem excluir o item da requisicao original.
- Exemplo: requisicao com 71 itens; 70 embarcam e 1 nao cabe.
- Os 70 itens permanecem na carga.
- Somente o que nao embarcou fica de fora.
- O saldo nao embarcado deve continuar pendente/rastreavel para transporte posterior.
- Auditar posteriormente a integracao dessa regra com o mecanismo `AT`.
- Regra conceitual: deleta da carga, nao da requisicao.

## Ponto de retomada

- Nao gerar `gbak`, `.fbk`, nova copia `.FDB` ou backup automatico.
- Nao alterar mais codigo antes de nova autorizacao.
- Na proxima sessao, aplicar `167x` e `167y` somente quando autorizado.
- Jorge fara homologacao visual da Geolocalizacao da Empresa e uma regressao rapida no Cliente.
- Confirmar o snapshot da origem em uma carga.
- Depois iniciar o Bloco C - Ordem de Entrega, com:
  - dois sentidos de sugestao;
  - clientes sem localizacao no final;
  - setas manuais;
  - congelamento apos finalizacao.

## Ajuste final antes da homologacao - 20/08/2026

Esta secao substitui o ponto de retomada de 14/08/2026 como estado operacional mais recente.

### Regra definitiva de planejamento e congelamento

- O planejamento da viagem existe somente enquanto `CARG_STATUS = 'A'`.
- Com a carga aberta, o sistema pode garantir o snapshot da origem, sincronizar/materializar paradas e vinculos, calcular sugestoes e permitir ajuste manual.
- As setas alteram, entre os tres campos de ordem, somente `CARGPA_ORDEM_PLANEJADA`.
- `CARGPA_ORDEM_SUGERIDA` e `CARGPA_ORDEM_REALIZADA` permanecem preservadas.
- `CARGPA_DH_ALTERACAO` e `CARGPA_VERSAO` acompanham normalmente uma alteracao legitima da parada.
- Depois que `CARG_STATUS <> 'A'`, o planejamento fica congelado.
- Uma carga fechada e aberta na Visao da Viagem deve apenas ler as paradas persistidas.
- Nao sincronizar, materializar, incluir/remover vinculos, recalcular sugestao ou alterar a ordem planejada de carga fechada.
- O futuro registro da execucao da viagem, inclusive `CARGPA_ORDEM_REALIZADA`, nunca podera reescrever `CARGPA_ORDEM_PLANEJADA`.

### Correcao aplicada

- Arquivo: `View\Mov\UManCargaViagem.pas`.
- Metodo: `TFrmManCargaViagem.AbrirConsulta`.
- Antes: `GarantirSnapshotOrigemCarga` e `SincronizarParadasCarga` eram chamadas antes da leitura de `CARG_STATUS`.
- Agora: a carga e consultada primeiro; snapshot e sincronizacao sao executados exclusivamente quando `CARG_STATUS = 'A'`.
- Quando a carga nao esta aberta, a tela consulta somente as paradas ja persistidas e os quatro controles de planejamento permanecem desabilitados.
- `SP_GERA_CARGA_PARADAS` nao foi alterada.

### Setas

- `MoverParadaCarga` e os botoes `Subir` e `Descer` foram preservados, sem recriacao.
- A unidade movimentada continua sendo parada/cliente, inclusive quando um pedido esta selecionado.
- A movimentacao continua sendo de uma posicao, com renumeracao `1..N`, transacao, rollback e manutencao da selecao.
- Primeira parada nao sobe; ultima parada nao desce.

## REGRA MULTIEMPRESA — MATRIZ E FILIAIS

Premissa definitiva do projeto:

- A carga pertence a empresa que a criou/expediu.
- A viagem parte da empresa expedidora daquela carga.
- `TB_EMPRESA` fornece a localizacao permanente da empresa da carga.
- `TB_CARGA` guarda o snapshot da origem daquela viagem.
- A origem da sugestao e o snapshot da empresa expedidora; os destinos sao as paradas da mesma `Empresa + Carga`.
- Matriz e filiais utilizam a mesma arquitetura e podem montar e executar suas proprias cargas.
- Empresa 10 e somente um cenario conveniente de homologacao, nunca uma regra funcional.
- Nenhuma consulta, movimentacao, snapshot, sincronizacao ou sugestao pode misturar empresas.
- A auditoria dos fontes confirmou uso de `Empresa + Carga` e nao encontrou codigo fixo de empresa no fluxo examinado.
- A homologacao multiempresa futura devera contemplar ao menos uma carga da matriz e uma carga de filial, ambas criadas pelo fluxo normal.

### Compilacao e estado da homologacao

- Projeto: `ParmaGestor.dproj`.
- Configuracao: `Debug / Win32`.
- Resultado em 20/08/2026: sucesso, codigo de saida `0`.
- Permaneceram somente warnings e hints antigos do ERP, ACBr e dependencias.
- Nenhum `INSERT`, `UPDATE`, `DELETE`, alteracao de status, reabertura de carga ou fabricacao de paradas foi executado para teste.
- Carga 505 nao foi alterada.
- Homologacao funcional da roteirizacao V1, das setas e da persistencia: **CONCLUIDA NA CARGA 525**.
- Teste de congelamento apos finalizacao: **AINDA PENDENTE**.

## Homologacao funcional - Carga 525

- Cenario real criado pelo fluxo normal: `Empresa 10 + Carga 525`, `CARG_STATUS = 'A'`, com 11 paradas/clientes.
- Empresa expedidora: GRANDECOR LTDA / GRANDECOR NOVA UBA, UBA/MG.
- Snapshot utilizado: latitude `-21.0945`, longitude `-42.9701`, origem `A`.
- O snapshot da carga corresponde a empresa expedidora; nenhuma premissa de matriz foi introduzida.
- A V1 calcula distancia geografica em linha reta da origem da carga para cada parada, pela formula de Haversine, em quilometros.
- `Proximo -> Longe` e `Longe -> Proximo` coincidiram com a reproducao matematica independente.
- A unidade de ordenacao e parada/cliente. Cidades repetidas possuem posicoes proprias e nao quebram a sequencia.
- `Subir`, `Descer` e o ajuste manual foram homologados funcionalmente pelo proprietario.
- A persistencia foi confirmada ao fechar e reabrir a tela.
- `CARGPA_ORDEM_SUGERIDA` permaneceu preservada.
- `CARGPA_ORDEM_PLANEJADA` refletiu a decisao manual.
- `CARGPA_ORDEM_REALIZADA` permaneceu `NULL`.
- A premissa multiempresa permanece definitiva: matriz e filiais podem possuir suas proprias cargas.

Sequencia matematica confirmada em `Proximo -> Longe`:

1. Divinesia - 12,149499 km;
2. Rodeiro - 15,529476 km;
3. Visconde do Rio Branco - 16,301509 km;
4. Visconde do Rio Branco - 17,161044 km;
5. Vicosa - 38,612724 km;
6. Cataguases - 43,318100 km;
7. Cataguases - 44,192385 km;
8. Muriae - 62,296267 km;
9. Leopoldina - 72,942793 km;
10. Juiz de Fora - 82,239361 km;
11. Juiz de Fora - 82,974439 km.

`Longe -> Proximo` apresentou exatamente a sequencia inversa. Nao houve empate entre as 11 paradas.

## Evolucao da Visao da Viagem - fase visual e operacional

A tela atual esta funcionalmente boa, mas visualmente ainda simples. Isso nao e falha tecnica do bloco homologado; e uma evolucao de interface aprovada pelo proprietario.

Direcao aprovada para a proxima fase:

- representacao grafica do percurso com origem e paradas A, B, C, D etc.;
- quilometragem ate cada cliente e apanhado das distancias por parada;
- visao acumulada e total estimado de quilometros da viagem;
- figura lateral dinamica, reorganizada junto com a sugestao automatica ou com as setas;
- sequencia e informacoes de distancia acompanhando a ordem atual;
- futura visao operacional da posicao do motorista, entregas concluidas e paradas pendentes.

### V1 atual - ja existe e funciona

- distancia geografica em linha reta;
- calculo `origem da carga -> cada parada`;
- sugestao `Proximo -> Longe`;
- sugestao `Longe -> Proximo`;
- ajuste manual por setas;
- persistencia da ordem planejada.

### Fase futura - ideia aprovada, ainda nao implementada

- total estimado de quilometros da rota;
- distancia entre paradas consecutivas;
- percurso visual dinamico;
- rastreamento operacional e status do motorista;
- identificacao de quem ja recebeu e de quem permanece pendente;
- acompanhamento online do pedido pelo cliente;
- comunicacao por WhatsApp, e-mail e SMS;
- assinatura digital;
- foto do canhoto;
- leitura de codigo de barras, alinhada a direcao ja prevista para o projeto;
- prova de entrega e comunicacao ao cliente.

Observacao estrategica: total percorrido, trechos `A -> B -> C`, percurso encadeado e posicao do motorista exigem camada adicional de roteirizacao/execucao. Nao confundir a atual ordem sugerida por proximidade da origem com uma rota operacional completa.

## Ponto de parada - 20/08/2026

- Roteirizacao V1 homologada funcionalmente na carga 525.
- Setas e ajuste manual homologados funcionalmente.
- Persistencia homologada.
- Auditoria matematica validada.
- Premissa multiempresa preservada.
- Tela Visao da Viagem aprovada funcionalmente.
- Proxima etapa desejada: melhoria visual e operacional da tela.
- Ainda pendente: teste do congelamento do planejamento apos finalizacao da carga.
- Nenhuma implementacao foi realizada nesta atualizacao documental.

Nao iniciar implementacao da fase visual/operacional antes de autorizacao. O proximo teste funcional e o congelamento do planejamento apos a finalizacao real da carga.

## Evolucao visual da Visao da Viagem - 21/08/2026

Esta secao substitui somente o ponto de retomada visual anterior. O historico e a homologacao funcional da V1 permanecem preservados.

### Estado

**IMPLEMENTADA / AGUARDANDO HOMOLOGACAO VISUAL E FUNCIONAL DO JORGE**

### Arquivos alterados

- `View\Mov\UManCargaViagem.pas`;
- `View\Mov\UManCargaViagem.dfm`;
- `Documentacao\STATUS_APP_MOTORISTA_CARGA.md`.

`Controller\UClassCarga.pas` foi somente auditado. Nenhum metodo homologado do controlador foi recriado ou alterado.

### Layout e componentes

- A arvore existente foi preservada para manter o agrupamento oficial de uma parada/cliente com um ou varios pedidos.
- A sequencia da viagem ocupa o lado esquerdo.
- O lado direito recebeu `grpRota` e `pbRota` para a representacao esquematica da rota.
- O resumo da viagem foi reorganizado no lado direito inferior e recebeu `edtTotalKm`.
- A janela passou a permitir redimensionamento; o resize apenas invalida o desenho e nao consulta nem altera a viagem.
- Nao existe botao `Atualizar Mapa`, `Recarregar Mapa` ou equivalente.

### Fonte visual unica e sincronismo automatico

- Foi criado `AtualizarVisualizacaoViagem` como ponto central de leitura e atualizacao visual.
- A consulta continua ordenada por `CARGPA_ORDEM_PLANEJADA` e `CARGPA_ID`.
- `CarregarViagem` cria um unico modelo visual de paradas a partir dessa consulta e, no mesmo carregamento, reconstrui a arvore.
- Trechos, total e `pbRota` derivam desse mesmo modelo; nao existe uma segunda ordem independente para o mapa.
- Ao abrir a tela, `AtualizarVisualizacaoViagem` carrega cabecalho, ordem, arvore, trechos, total e mapa automaticamente.
- `Proximo -> Longe` e `Longe -> Proximo` chamam a atualizacao central somente depois do sucesso retornado por `AplicarSugestaoOrdemParadasCarga`.
- `Subir` e `Descer` chamam a atualizacao central somente quando `MoverParadaCarga` retorna sucesso e `AMovimentou = True`.
- A parada selecionada e preservada depois das sugestoes e dos movimentos.
- Falha, rollback ou limite sem movimentacao nao altera arvore, modelo visual, total ou mapa.

### Calculos somente para exibicao

- A origem e lida exclusivamente de `CARG_ORIGEM_LATITUDE` e `CARG_ORIGEM_LONGITUDE`, no snapshot de `TB_CARGA`.
- Cada parada usa `CARGPA_LATITUDE` e `CARGPA_LONGITUDE` do snapshot de `TB_CARGA_PARADA`, com coordenada confirmada e limites geograficos validos.
- `CalcularDistanciaKm` replica a formula de Haversine usada na V1, com raio medio terrestre de `6371.0088 km`.
- `CalcularTrechosViagem` calcula `ORIGEM -> 1`, `1 -> 2`, ate `N-1 -> N` na ordem atualmente carregada.
- O total estimado e a soma dos trechos que possuem os dois pontos validos.
- Se qualquer trecho estiver indisponivel, o resumo identifica o resultado como `PARCIAL ... (INCOMPLETO)` ou `INCOMPLETO`; nunca apresenta uma soma parcial como total completo.
- Parada sem localizacao permanece em sua ordem, aparece diferenciada no mapa e seus trechos exibem `-- km`.
- Nenhuma distancia foi gravada no banco.

### Desenho

- `pbRotaPaint` desenha `ORIGEM` e as paradas numeradas em percurso serpenteado, sem pretensao geografica ou rodoviaria.
- Cada linha usa a distancia do trecho correspondente; o ponto exibe a cidade quando ha espaco.
- O desenho usa bitmap em memoria para reduzir cintilacao e e recalculado graficamente conforme o espaco disponivel.
- O evento de resize chama apenas `Invalidate`; a sequencia e os calculos permanecem os ja carregados.

### Regras preservadas

- `CARGPA_ORDEM_PLANEJADA`, `CARGPA_ORDEM_SUGERIDA` e `CARGPA_ORDEM_REALIZADA` preservados conforme a V1.
- `MoverParadaCarga`, sugestoes, unidade parada/cliente, multiempresa e bloqueio por `CARG_STATUS` preservados.
- Carga com `CARG_STATUS <> 'A'` continua somente leitura, sem sincronizacao ou materializacao; a rota historica e desenhada a partir da ordem persistida.
- `SP_GERA_CARGA_PARADAS`, banco, procedures, scripts de versionamento, status e finalizacao nao foram alterados.
- Nao foram adicionados API externa, mapa rodoviario, navegador ou biblioteca.

### Validacao executada

- Compilacao completa de `ParmaGestor.dproj`, `Debug / Win32`: sucesso, codigo de saida `0`.
- Permaneceram warnings e hints antigos do ERP, ACBr e dependencias; nenhum erro de compilacao na nova tela.
- Auditoria estatica PAS/DFM confirmou os eventos, componentes e a ausencia de botao manual de atualizacao.
- Nenhum `INSERT`, `UPDATE`, `DELETE`, SQL modificador, WES ou teste funcional contra banco foi executado nesta etapa.
- Os nove cenarios funcionais e visuais solicitados permanecem para homologacao manual do Jorge em cargas criadas pelo fluxo normal.

## Ajuste visual da lista e do mapa - 21/08/2026

Esta secao substitui as decisoes de apresentacao da secao visual imediatamente anterior, sem apagar seu historico. As regras funcionais, o sincronismo automatico e os calculos daquela implementacao permanecem validos.

### Estado

**AJUSTE VISUAL IMPLEMENTADO / AGUARDANDO NOVA HOMOLOGACAO DO JORGE**

### Lista da esquerda

- O `TTreeView` foi substituido por `TListView` em `ViewStyle = vsReport`.
- A lista possui quatro colunas reais e separadas: `Seq.`, `Pedido`, `Cliente` e `Cidade / UF`.
- Cada linha principal representa uma unica parada/cliente, preservando a arquitetura `1 carga + 1 cliente = 1 parada`.
- Quando a parada possui mais de um pedido, os numeros sao agregados na coluna `Pedido`; a parada nao e multiplicada nem movimentada parcialmente.
- O texto corrido com `LOCALIZADO` foi removido da linha principal.
- Paradas sem localizacao confirmada usam texto vermelho discreto e uma legenda no rodape da lista.
- Um `TImageList` de um pixel de largura e 28 pixels de altura controla o espacamento vertical sem introduzir icone artificial.
- O cabecalho nativo do modo relatorio separa as quatro colunas sem produzir uma grade visual pesada.
- `lvViagemDrawItem`, com `OwnerDraw`, desenha a linha completa em branco ou cinza claro e reserva o azul exclusivamente para a linha selecionada, independentemente do tema do Windows.
- A coluna `Seq.` usa o pequeno marcador circular azul da imagem modelo, sem transformar as demais linhas em selecao.
- O conteudo das quatro colunas usa linha unica com elipse somente quando a largura realmente se esgota; cliente e cidade nao quebram verticalmente.
- O fundo do texto e desenhado de forma transparente e a cor da linha e restaurada depois do marcador de sequencia; assim, a selecao nao produz blocos brancos sobre Pedido, Cliente ou Cidade/UF.
- O destaque da linha selecionada usa amarelo muito claro com texto escuro, substituindo o azul forte sem perder a identificacao da parada corrente.
- `AjustarColunasLista` recalcula as larguras das colunas conforme a area disponivel.
- `Cidade / UF` passa a ocupar exatamente o restante util do `TListView`; nao fica uma faixa residual depois da quarta coluna.
- A barra vertical e ocultada quando todas as paradas ja cabem na area visivel e permanece disponivel quando houver necessidade real de rolagem.
- A selecao continua armazenando o `CARGPA_ID`; `Subir` e `Descer` continuam movimentando a parada completa.

### Novo desenho do mapa

- O desenho serpenteado por linhas foi removido.
- `pbRotaPaint` mantem os angulos das paradas avancando uniformemente ao redor do painel, preservando o sentido circular; a `ORIGEM` fica em posicao propria antes do ponto 1.
- A sequencia continua sendo ligada estritamente como `ORIGEM -> 1 -> 2 -> ... -> N`; somente as coordenadas graficas mudaram.
- Uma variacao radial matematica aproxima ou afasta alguns nos do centro, formando um percurso aberto com entradas e saidas semelhante ao modelo, sem obrigar as paradas a uma elipse rigida.
- Os raios horizontal e vertical foram ampliados para aproveitar as laterais, o topo e a base do painel, mantendo alguns pontos internos para o efeito de estrela.
- A origem grafica inicia no canto superior esquerdo e o no selecionado usa o mesmo amarelo suave da lista.
- Quando uma legenda externa ultrapassaria uma borda, ela muda para o lado interno do no; cidades quebradas em duas linhas permanecem centralizadas e sem corte.
- Os nos cresceram para 32 pixels de diametro e receberam sombra, preenchimento claro, contorno de dois pixels e numero centralizado.
- A origem usa cor verde; parada selecionada recebe destaque amarelo suave; parada sem localizacao usa contorno tracejado vermelho.
- As distancias ficam em etiquetas brancas arredondadas, proximas ao ponto medio de cada trecho e deslocadas perpendicularmente ao segmento, reduzindo colisao com nos e cidades.
- Os nomes das cidades sao posicionados conforme o quadrante de cada no e mudam para o lado interno quando a borda nao comporta a legenda.
- Cidades longas sao quebradas de forma controlada em ate duas linhas, em vez de truncadas diretamente.
- A selecao de uma linha invalida o mapa para destacar imediatamente o mesmo ponto.
- O resize recalcula somente a geometria grafica do mapa; nao consulta, persiste ou reordena a viagem.

### Sincronismo e escopo preservados

- `AtualizarVisualizacaoViagem` continua sendo a unica rotina central de recarga visual.
- `Proximo -> Longe`, `Longe -> Proximo`, `Subir` e `Descer` continuam atualizando lista, numeros, trechos, total e mapa somente depois do sucesso da operacao persistida.
- Nao foi criado botao de atualizar ou recarregar mapa.
- Haversine, total estimado, tratamento de trechos incompletos, origem da carga e ordem planejada nao foram alterados.
- `Controller\UClassCarga.pas`, banco, procedures, versionamento, status e finalizacao nao foram alterados.

### Validacao

- `ParmaGestor.dproj`, `Debug / Win32`: compilacao completa com sucesso, codigo de saida `0`.

- Permaneceram somente warnings e hints historicos do ERP, ACBr e dependencias.
- Nenhum banco ou carga real foi alterado para esta validacao.
- A comparacao visual final depende de nova abertura da tela pelo Jorge no ERP.

## Ajuste final do mapa - 21/08/2026

### Estado

**AJUSTE FINAL DO MAPA IMPLEMENTADO / AGUARDANDO HOMOLOGACAO VISUAL DO JORGE**

- Nesta rodada, a grade da esquerda e o resumo da viagem permaneceram congelados.
- O mapa usa dois raios explicitos e alterna externo/interno ate a virada lateral da rota. Depois da virada, a alternancia e invertida para abrir os trechos do retorno.
- No exemplo com onze paradas, os pontos 5 e 6 permanecem externos; o 6 fica abaixo do 5, o 7 passa ao raio interno e o 8 retorna ao externo. Assim, o trecho `6 -> 7` ganha leitura horizontal e libera espaco para cidade e km.
- A margem de seguranca corresponde a aproximadamente 8% do painel; laterais, topo e base passam a ser efetivamente utilizados.
- A origem permanece em area propria no canto superior esquerdo e nao participa da alternancia dos raios.
- Depois do posicionamento, cada no e comparado ao anterior. Distancias visuais inferiores a 76 pixels sao corrigidas antes do desenho.
- As cidades continuam orientadas pelo quadrante, com inversao de lado nas bordas, quebra controlada e centralizacao das duas linhas.
- Cada quilometragem permanece no ponto medio do trecho, com deslocamento perpendicular aumentado para 15 pixels e fundo branco proprio.
- Ordem, Haversine, total, persistencia, banco, procedures, botoes e sincronismo automatico nao foram alterados.
- `ParmaGestor.dproj`, `Debug / Win32`: compilacao completa com sucesso, codigo de saida `0`.

## Modo ampliado do mapa - 21/08/2026

### Estado

**MODO AMPLIAR MAPA IMPLEMENTADO / AGUARDANDO HOMOLOGACAO VISUAL DO JORGE**

- Foi adicionado o botao discreto `Ampliar Mapa` no canto superior direito do quadro da rota.
- Ao ampliar, a grade da esquerda e o painel `Resumo da Viagem` sao apenas ocultados; o painel direito e o `grpRota` passam a ocupar a area util disponivel.
- O mesmo botao muda para `Restaurar` e reexibe os dois paineis com seus alinhamentos e dimensoes normais.
- A selecao da parada, `FParadas`, a ordem carregada, as consultas e o estado da carga nao sao descartados durante a alternancia.
- Existe um unico `TPaintBox` (`pbRota`) e uma unica rotina de desenho (`pbRotaPaint`) para os modos normal e ampliado.
- O redesenho ocorre somente depois do realinhamento dos paineis. A rotina rele `Width` e `Height` atuais e recalcula margens, raios, nos, cidades e quilometragens para a nova area.
- `AtualizarVisualizacaoViagem` continua invalidando o mesmo mapa. Sugestoes e movimentos persistidos atualizam diretamente o mapa mesmo quando ele esta ampliado.
- O resize continua sendo apenas grafico e usa as dimensoes atuais do `PaintBox`.
- Grade aprovada, resumo, Haversine, total estimado, ordem, sugestao, persistencia, banco, procedures e regras da carga nao foram alterados.
- `ParmaGestor.dproj`, `Debug / Win32`: compilacao completa com sucesso, codigo de saida `0`.

## Paleta visual do mapa - 21/08/2026

### Estado

**CORES DO MAPA AJUSTADAS / AGUARDANDO HOMOLOGACAO VISUAL DO JORGE**

- Paradas com localizacao confirmada usam preenchimento verde pastel muito claro, contorno verde suave e numero escuro.
- Paradas sem localizacao confirmada usam preenchimento amarelo pastel muito claro, contorno ocre discreto e numero escuro.
- A origem confirmada segue a familia verde; se a origem nao possuir coordenada valida, segue a familia amarela.
- O nome da cidade permanece em cor neutra mesmo quando a parada nao possui localizacao.
- A selecao nao substitui a cor semantica do no. Um halo externo em tom ameixa discreto identifica a parada selecionada sobre o verde ou o amarelo.
- A legenda passou a informar: `Verde-claro = Localizacao confirmada | Amarelo-claro = Sem localizacao confirmada`.
- A mesma paleta e aplicada pelo unico `pbRotaPaint` nos modos normal e ampliado.
- Posicoes, raios, afastamento, distancias, Haversine, total, botoes, sincronismo, persistencia e banco nao foram alterados.
- `ParmaGestor.dproj`, `Debug / Win32`: compilacao completa com sucesso, codigo de saida `0`.

## Ajustes finos finais da Visao da Viagem - 21/08/2026

### Estado

**AJUSTE FINAL IMPLEMENTADO / AGUARDANDO HOMOLOGACAO FINAL DO JORGE**

- `pbRotaPaint` registra, a cada desenho, somente o `CARGPA_ID` e o centro grafico de cada no no cache visual `FNosMapa`.
- No modo ampliado, `pbRotaMouseDown` faz o hit-test circular com o clique. Quando encontra um no, seleciona o item do `TListView` que possui o mesmo `CARGPA_ID` e invalida o mapa.
- O clique fora dos nos nao altera a selecao anterior.
- `Subir` e `Descer` continuam lendo `ParadaSelecionada`; como a selecao por clique atualiza o mesmo item da lista, usam automaticamente a parada escolhida no mapa.
- `MoverParada` continua chamando `AtualizarVisualizacaoViagem(vParada)` depois do sucesso, mantendo o mesmo cliente selecionado na nova ordem.
- No modo ampliado, `Fechar [ESC]` chama `AplicarModoMapaAmpliado(False)` e nao fecha o formulario. No modo normal, preserva o fechamento anterior.
- Trechos sem quilometragem calculavel continuam desenhando a linha, mas nao criam texto, caixa ou marcador de km.
- Cores, geometria, Haversine, total, sugestoes, atualizacao automatica, banco, procedures e versionamento nao foram alterados.
- Por orientacao do Jorge, nao foram executados testes funcionais nem alteradas cargas. Foi realizada somente a validacao por compilacao.
- `ParmaGestor.dproj`, `Debug / Win32`: compilacao completa com sucesso, codigo de saida `0`.

## Acesso ao App Motorista no cadastro de Transportador - 26/08/2026

### Estado

**IMPLEMENTADO / AGUARDANDO HOMOLOGACAO MANUAL DO JORGE**

- O cadastro de Transportador recebeu, dentro de `Dados Principais` e sem nova aba, a area discreta `Acesso ao App Motorista` com `Usa App Motorista`, `Usuario` e `Senha`.
- A fonte oficial do checkbox e o vinculo do transportador na empresa corrente em `TB_MOTORISTA_APP_EMPRESA`: `MOTAPPE_TRANSPORTADOR` identifica o transportador e `MOTAPPE_ATIVO = 'S'` significa acesso habilitado.
- Na inclusao de um acesso sao criados o motorista em `TB_MOTORISTA_APP` e o vinculo ativo na empresa/transportador em `TB_MOTORISTA_APP_EMPRESA`, dentro da mesma transacao do cadastro do Transportador.
- Em acesso existente, a tela carrega o login e nunca carrega a senha original. Senha vazia preserva `MOTAPP_SENHA_HASH`; senha informada substitui o hash.
- O login continua obedecendo a unicidade global ja definida por `UX_MOTAPP_LOGIN`, com validacao previa por `UPPER(TRIM(MOTAPP_LOGIN))`. Um login existente nao e apropriado por outro transportador; portanto o usuario de homologacao `MOTAPP_ID = 1`, login `A`, nao e reutilizado para Paulo.
- A senha e persistida somente como hash compativel com a autenticacao oficial da API: `scrypt:32768:8:1`, salt criptografico aleatorio e chave derivada de 64 bytes. Nao existe armazenamento ou recuperacao de senha em texto puro.
- Ao desmarcar `Usa App Motorista`, o vinculo empresa/motorista e inativado sem exclusao. O motorista global e inativado somente quando nao resta outro vinculo ativo, preservando historico e eventual acesso legitimo a outra empresa.
- Reativar um vinculo existente reutiliza o mesmo `MOTAPP_ID`; nao cria motorista duplicado.
- Foi adicionada protecao para interromper a carga quando houver mais de um motorista App ligado ao mesmo transportador na empresa, evitando selecionar um vinculo ambiguo.

### Arquivos alterados

- `View\Cad\UManTransportador.pas`
- `View\Cad\UManTransportador.dfm`
- `Controller\UClassTransportador.pas`
- `Controller\UClassMotoristaApp.pas` (novo)
- `ParmaGestor.dpr`
- `ParmaGestor.dproj`
- `Documentacao\STATUS_APP_MOTORISTA_CARGA.md`

### Banco e versionamento

- Nenhuma alteracao estrutural foi necessaria: as tabelas, chaves, generator e indice unico do script `1.1.0.70` ja atendem ao cadastro.
- Nenhum script de versao foi criado.
- Nenhum `INSERT`, `UPDATE` ou `DELETE` de homologacao foi executado durante a implementacao.
- Confirmacao final somente por `SELECT`: empresa 10 / transportador 22 (`PAULO HENRIQUE GONCALVES`) continua com zero vinculos App; `MOTAPP_ID = 1` continua login `A`, ativo, vinculo ativo com empresa 10 e `MOTAPPE_TRANSPORTADOR` nulo.

### Validacao

- `ParmaGestor.dproj`, `Debug / Win32`: compilacao completa e link com sucesso em saida temporaria, sem erros do codigo novo.
- O destino normal `..\Bin\ParmaGestor.exe` nao foi substituido porque o executavel esta aberto pelo processo do ERP; a validacao foi concluida apontando `DCC_ExeOutput` para pasta temporaria.
- Permaneceram warnings e hints historicos do ERP, ACBr e dependencias.
- Conferencia de Carga, `F12`, Manifesto, procedures, atribuicao automatica, API, Flutter e `Minhas viagens` nao foram alterados.

### Proximo passo de homologacao

- Fechar/recompilar o executavel em uso e, no cadastro da empresa 10 / transportador 22, marcar `Usa App Motorista` e informar manualmente o login e a senha definidos para Paulo.
- O proximo bloco funcional permanece sendo o fluxo normal de `F12 -> gerar Manifesto -> atribuir automaticamente pelo transportador -> liberar`, sem implementacao nesta etapa.

## Liberacao automatica do Manifesto no fechamento da Conferencia de Carga - 26/08/2026

### Estado

**IMPLEMENTADO / AGUARDANDO HOMOLOGACAO MANUAL DO JORGE**

- Na tela normal `View\Mov\UManConfereCarga`, o fechamento operacional nao possui F12: ocorre em `edtCodigoKeyDown` quando a leitura do ultimo item deixa a lista de pendencias vazia.
- O evento chama `TConfereCarga.FinalizarConferencia`, que preserva a sequencia existente `SP_FIN_CONFERE_CARGA -> SP_GERA_CARGA_PARADAS -> SP_GERA_CARGA_MANIFESTO`.
- A nova etapa foi inserida somente depois do retorno `OK` de `SP_GERA_CARGA_MANIFESTO` e antes do `Commit`, reutilizando a mesma `TFDTransaction` do fechamento.
- O Manifesto retornado pela geracao e validado pela mesma empresa, carga e conferencia. Manifesto ausente interrompe o fechamento com erro claro; nenhum Manifesto e fabricado pelo Delphi.
- O transportador e lido da fonte oficial `TB_CARGA.CARG_TRANSPORTADOR`.
- A resolucao do motorista considera apenas vinculo da mesma empresa e transportador com `TB_MOTORISTA_APP_EMPRESA.MOTAPPE_ATIVO = 'S'`, confirmando tambem `TB_MOTORISTA_APP.MOTAPP_ATIVO = 'S'`.
- Com exatamente um motorista valido e Manifesto em `G`, o Delphi chama a procedure oficial `SP_LIBERA_CARGA_MANIFESTO(Empresa, Manifesto, MOTAPP_ID, Usuario)`. A procedure continua responsavel pelas regras de liberacao e pela mudanca `G -> L`.
- Com transportador sem vinculo App ativo, a rotina encerra sem erro, o fechamento e confirmado normalmente e o Manifesto permanece sem liberacao para o App.
- Mais de um vinculo App ativo para a mesma empresa/transportador bloqueia o fechamento com mensagem de inconsistencia; nenhum registro e escolhido arbitrariamente.
- Vinculo ativo apontando para motorista global inativo tambem bloqueia o fechamento com mensagem de inconsistencia.
- Manifesto ja `L` ou `F` para o mesmo motorista e tratado de forma idempotente, sem nova chamada da procedure. Se estiver atribuido a outro motorista, a rotina bloqueia e nao sobrescreve a atribuicao.
- Qualquer falha da liberacao obrigatoria para transportador com App participa do mesmo rollback do fechamento, evitando estado intermediario silencioso.

### Arquivos alterados

- `Controller\UClassConfereCarga.pas`
- `Documentacao\STATUS_APP_MOTORISTA_CARGA.md`

### Banco e versionamento

- Nenhuma alteracao estrutural foi necessaria; `TB_MOTORISTA_APP_EMPRESA.MOTAPPE_TRANSPORTADOR` e `SP_LIBERA_CARGA_MANIFESTO` existentes atendem ao fluxo.
- Nenhum script de versao foi criado.
- Nenhum dado real foi alterado durante a implementacao e validacao.
- Confirmacao somente por `SELECT`: empresa 10 / carga 526 permanece com transportador 22; existe um unico vinculo ativo para `MOTAPP_ID = 4`, motorista global ativo; Manifesto 7 permanece em `G`, sem motorista atribuido.

### Validacao

- `ParmaGestor.dproj`, `Debug / Win32`: compilacao completa e link com sucesso, codigo de saida `0`.
- O executavel e os DCUs da validacao foram direcionados para pasta temporaria, sem substituir o ParmaGestor em uso.
- Permaneceram somente warnings e hints historicos do ERP e das dependencias; nao houve erro no codigo novo.
- Flutter, API, endpoint `Minhas viagens`, cadastro de Transportador, login/senha, usuario temporario `A/A`, banco e cargas reais nao foram alterados.

### Proximo passo de homologacao

- Jorge deve usar uma carga normal com o transportador 22 / Paulo, concluir a leitura do ultimo item na Conferencia de Carga e confirmar, por consulta ou pelo App, que o Manifesto passa de `G` para `L`, recebe `CARGM_MOTORISTA_APP = 4` e aparece em `Minhas viagens` do Paulo.
- Tambem deve ser preservado o cenario de transportador terceirizado sem vinculo App: a conferencia finaliza normalmente e o Manifesto permanece sem liberacao para o App.

## Retirada definitiva do usuario temporario A/A - 26/08/2026

### Estado

**CONCLUIDO / USUARIO DE HOMOLOGACAO RETIRADO DE USO**

- Por autorizacao expressa, o `MOTAPP_ID = 1`, nome `Motorista Homologacao`, login `A`, foi desativado sem exclusao fisica.
- Banco utilizado: `localhost:E:\Dados Clientes\GramDecor\DADOS.FDB`.
- Os valores oficiais existentes foram preservados: `N` para motorista/vinculo inativo e `R` para sessao revogada com `MOTAPPS_DH_REVOGACAO` preenchida.
- A operacao foi executada em uma unica transacao: `TB_MOTORISTA_APP.MOTAPP_ATIVO` passou de `S` para `N`; o unico vinculo do motorista na empresa 10 passou de `MOTAPPE_ATIVO = S` para `N`; as seis sessoes que ainda estavam em `MOTAPPS_STATUS = A` passaram para `R`.
- As tres sessoes anteriormente revogadas foram preservadas. Ao final, as nove sessoes historicas do motorista estao em `R` e nenhuma permanece ativa ou renovavel.
- Nenhuma senha, login, GUID, hash de sessao ou registro historico foi apagado.

### Validacao

- `MOTAPP_ID 1 ativo?`: nao; `MOTAPP_ATIVO = N`.
- `Vinculo ativo?`: nao; empresa 10 / motorista 1 permanece registrado com `MOTAPPE_ATIVO = N`.
- `Sessoes validas?`: zero; nao existe sessao do motorista 1 em status `A`.
- `Login A ainda autentica?`: nao; teste HTTP real em `POST /api/v1/motorista/sessoes` com `A/A` retornou `401` e nao criou sessao.
- Renovacao de sessao nao e mais possivel: a API exige sessao `A` com refresh vigente e motorista global `S`; o motorista esta `N` e todas as sessoes estao `R`.
- `Manifesto 5 preservado?`: sim; comparacao integral antes/depois confirmou o mesmo registro, empresa 10, carga 504, status `L`, motorista App 1 e data de liberacao inalterados.
- `Carga 504 preservada?`: sim; comparacao integral antes/depois confirmou o mesmo registro, ainda em status `F`.
- O Manifesto 5 nao foi transferido, a Carga 504 nao foi alterada e nenhuma referencia historica ao motorista 1 foi removida.

### Fontes, banco e versionamento

- Flutter, API e Delphi nao foram alterados.
- O unico arquivo de fonte/documentacao alterado nesta etapa foi `Documentacao\STATUS_APP_MOTORISTA_CARGA.md`.
- Nao houve alteracao estrutural e nenhum script de versao foi criado.
- Foram alterados somente os tres conjuntos de dados explicitamente autorizados: status global do motorista 1, status do seu vinculo empresarial e status/data de revogacao das sessoes `A` desse motorista.
- O acesso real do Paulo e a Carga 527, ja homologados manualmente pelo Jorge, nao foram alterados nesta etapa.

### Proximo passo

- Nenhuma acao tecnica adicional e necessaria para o usuario temporario `A/A`. O App deve continuar sendo homologado exclusivamente com os acessos reais cadastrados por transportador.
