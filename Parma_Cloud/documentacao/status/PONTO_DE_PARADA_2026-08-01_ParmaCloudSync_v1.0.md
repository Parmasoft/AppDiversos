# Ponto de Parada - 01/08/2026

Projeto: ParmaCloudSync v1.0
Cliente piloto: Fabri Tecidos
Status: aprovado tecnicamente em homologacao; pendente instalacao controlada no servidor real da Fabri Tecidos

## Resumo Geral

Nesta data foi concluida a homologacao tecnica do ParmaCloudSync v1.0 em ambiente Windows 10 do escritorio, usando copia/backup do banco da Fabri Tecidos.

Foram validados:

- leitura do `config.ini`;
- conexao com Firebird;
- consulta de produtos;
- envio em lotes;
- comunicacao com a API;
- execucao continua;
- tolerancia a API indisponivel;
- execucao como Servico do Windows;
- inicializacao automatica apos reiniciar o Windows;
- API da nuvem executando permanentemente via systemd/Gunicorn;
- recuperacao automatica apos reiniciar o Ubuntu;
- sincronizacao limpa de 2.958 produtos;
- login e consulta de produtos pelo navegador.

O servico ainda precisa ser instalado no servidor real da Fabri Tecidos. O codigo e o procedimento correto de implantacao estao aprovados.

## Ambiente Windows de Homologacao

Sistema operacional:

- Windows 10.

Pasta do projeto:

- `C:\Parmasoft_Cloud`

Python definitivo para o Servico do Windows:

- Python 3.11.9 de 32 bits;
- instalado para todos os usuarios;
- caminho: `C:\Python311-32`

Banco usado na homologacao:

- Firebird em `127.0.0.1/3050`;
- arquivo: `C:\Dados_Clientes\Fabri_Tecidos\DADOS.FDB`

Dependencias:

- `fdb==2.0.2`;
- `requests==2.32.5`;
- `pywin32==306`.

O `venv` continuou existindo e pode ser usado para testes manuais, mas nao deve ser usado para instalar ou hospedar o Servico do Windows.

## Descoberta Critica - Erro 1053

Inicialmente, o servico foi instalado com:

```bat
venv\Scripts\python.exe servico_windows.py --startup auto install
```

A instalacao era concluida, mas o inicio falhava com erro 1053:

```text
O servico nao respondeu a requisicao de inicio ou controle em tempo habil.
```

O modo debug retornava:

```text
PythonService was unable to locate the service manager.
Please see the event log for details.
```

O problema foi reproduzido em Windows 11 e Windows 10, descartando causa especifica do sistema operacional.

O diagnostico confirmou:

- `ImagePath`: `C:\Parmasoft_Cloud\venv\pythonservice.exe`;
- `PythonClass`: `C:\Parmasoft_Cloud\servico_windows.ParmaCloudSyncService`;
- conta: `LocalSystem`.

O Python do `venv` conseguia importar `servicemanager`, localizado em:

```text
C:\Parmasoft_Cloud\venv\Lib\site-packages\win32\servicemanager.pyd
```

Mesmo assim, o host `pythonservice.exe` do `venv` nao carregava corretamente o runtime do pywin32 no contexto do Servico do Windows. A falha ocorria antes de criar a aplicacao e antes de configurar o logger, por isso nenhum registro novo aparecia em `logs\ParmaCloudSync.log`.

## Correcao Definitiva do Runtime Windows

O pywin32 foi instalado no Python global dedicado:

```bat
C:\Python311-32\python.exe -m pip install pywin32==306
```

O pos-instalador foi executado fora do `venv` e em Prompt elevado:

```bat
C:\Python311-32\python.exe C:\Python311-32\Scripts\pywin32_postinstall.py -install
```

Resultado confirmado:

```text
The pywin32 extensions were successfully installed.
```

O Python global passou a importar corretamente:

- `servicemanager`;
- `win32serviceutil`.

Depois, todas as dependencias do `requirements.txt` foram instaladas no Python global dedicado:

```bat
cd /d C:\Parmasoft_Cloud
C:\Python311-32\python.exe -m pip install -r requirements.txt
```

Validacao:

```bat
C:\Python311-32\python.exe -c "import fdb, requests, servicemanager, win32serviceutil; print('RUNTIME GLOBAL OK')"
```

Resultado:

```text
RUNTIME GLOBAL OK
```

## Procedimento Correto Para Instalar o Servico

O Servico do Windows deve ser instalado pelo Python global dedicado.

Nao usar:

```bat
venv\Scripts\python.exe servico_windows.py --startup auto install
```

Usar:

```bat
cd /d C:\Parmasoft_Cloud
C:\Python311-32\python.exe servico_windows.py --startup auto install
```

Apos a instalacao, o comando:

```bat
sc qc ParmaCloudSync
```

deve mostrar o caminho binario equivalente a:

```text
C:\Python311-32\pythonservice.exe
```

Dados do servico:

- nome tecnico: `ParmaCloudSync`;
- nome exibido: `ParmaCloudSync - ParmaSoft`;
- inicializacao: `AUTO_START`;
- conta: `LocalSystem`.

## Comandos Oficiais do Servico Windows

Todos os comandos administrativos do servico devem usar o Python global:

```bat
C:\Python311-32\python.exe servico_windows.py --startup auto install
C:\Python311-32\python.exe servico_windows.py start
C:\Python311-32\python.exe servico_windows.py stop
C:\Python311-32\python.exe servico_windows.py restart
C:\Python311-32\python.exe servico_windows.py debug
C:\Python311-32\python.exe servico_windows.py remove
sc query ParmaCloudSync
sc qc ParmaCloudSync
```

O `venv` pode continuar sendo usado para testes manuais:

```bat
venv\Scripts\python.exe main.py --testar-conexao
venv\Scripts\python.exe main.py --uma-vez
```

Mas nunca deve ser usado como host do Servico do Windows.

## Testes Aprovados do Servico Windows

Foram aprovados:

1. Importacao das dependencias.
2. Conexao com o Firebird.
3. Instalacao do servico.
4. Modo debug.
5. Inicio manual.
6. Parada controlada.
7. Restart do servico.
8. Execucao sem Prompt aberto.
9. Permanencia como `RUNNING` com a API desligada.
10. Nova tentativa automatica a cada 300 segundos.
11. Inicializacao automatica apos reiniciar o Windows.

Estado confirmado:

```text
ESTADO: 4 RUNNING
```

Quando a API estava desligada, o log registrou:

- falha de comunicacao;
- o ciclo falhou;
- uma nova tentativa ocorreria no proximo intervalo;
- espera de 300 segundos;
- o servico permaneceu em execucao.

Isso confirmou que indisponibilidade temporaria de internet/API nao derruba o Servico do Windows.

## API Permanente na DigitalOcean

Servidor:

- Ubuntu 24.04.4 LTS

IP:

- `165.227.77.226`

Pasta da aplicacao:

- `/var/www/cotacao`

Aplicacao Flask:

- `/var/www/cotacao/api_nuvem.py`

Objeto Flask:

- `api_nuvem:app`

Venv da nuvem:

- `/var/www/cotacao/venv`

Python do venv:

- Python 3.12.3

Gunicorn:

- versao 25.1.0

Servicos relacionados:

- `firebird3.0.service`;
- `nginx.service`;
- `parmasoft-portal.service`.

Foi criado o servico:

```text
/etc/systemd/system/parmasoft-portal.service
```

Conteudo final aprovado:

```ini
[Unit]
Description=ParmaSoft Portal e API de Sincronizacao
After=network-online.target firebird3.0.service
Wants=network-online.target
Requires=firebird3.0.service

[Service]
Type=simple
WorkingDirectory=/var/www/cotacao
ExecStart=/var/www/cotacao/venv/bin/gunicorn \
    --workers 2 \
    --bind 0.0.0.0:5000 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    api_nuvem:app
Restart=always
RestartSec=5
KillSignal=SIGTERM
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

O servico foi habilitado e iniciado com:

```bash
systemctl daemon-reload
systemctl enable --now parmasoft-portal.service
```

Estado aprovado:

```bash
systemctl is-active parmasoft-portal.service
```

Resultado:

```text
active
```

## Decisao Sobre Workers do Gunicorn

Inicialmente foi usado:

```text
--workers 1
```

Com apenas um worker sincrono, uma sincronizacao real podia ocupar o unico worker, fazendo outra consulta HTTP aguardar.

O teste interno do Flask retornou corretamente:

```text
STATUS: 405
```

O teste isolado do Gunicorn na porta 5001 tambem retornou:

```text
HTTP/1.1 405 METHOD NOT ALLOWED
```

Isso confirmou que Flask e Gunicorn estavam funcionando.

O servico foi ajustado para:

```text
--workers 2
```

Com dois workers:

- o ParmaCloudSync conseguiu enviar os lotes;
- o Portal permaneceu responsivo;
- requisicoes POST retornaram HTTP 200;
- consulta GET de teste retornou rapidamente HTTP 405, como esperado.

## Reinicializacao da DigitalOcean

O Ubuntu foi reiniciado com:

```bash
reboot
```

Apos a reinicializacao, foram confirmados como ativos:

```bash
systemctl is-active firebird3.0
systemctl is-active nginx
systemctl is-active parmasoft-portal.service
```

Os tres retornaram:

```text
active
```

Durante os primeiros segundos do reboot, o Portal ficou temporariamente indisponivel, comportamento esperado durante subida dos servicos.

Ficaram aprovados:

- inicio automatico do Firebird;
- inicio automatico do Nginx;
- inicio automatico do Gunicorn/API;
- recuperacao do Portal apos reboot.

## Limpeza Controlada dos Produtos na Nuvem

O endpoint usa:

```sql
UPDATE OR INSERT INTO TB_PORTAL_PRODUTO
MATCHING (PPR_CLIENTE, PPR_PRODUTO)
```

Portanto:

- inclui produtos novos;
- atualiza produtos existentes;
- nao remove produtos que deixaram de existir no ERP.

Antes da carga definitiva, a nuvem possuia:

- cliente: Fabri Tecidos;
- identificador: `fabritecidos`;
- `PCL_ID`: 2;
- produtos: 3.236.

Foi criado backup fisico com o Firebird parado:

```text
/var/lib/firebird/backups/cotacao_antes_limpeza_20260801_140350.fdb
```

Depois foi removido somente:

```sql
TB_PORTAL_PRODUTO
WHERE PPR_CLIENTE = 2
```

Resultado:

```text
PRODUTOS ANTES: 3236
PRODUTOS DEPOIS: 0
LIMPEZA CONFIRMADA COM SUCESSO.
```

Foram preservados:

- `TB_PORTAL_CLIENTE`;
- identificador;
- token;
- usuarios;
- senhas/hash;
- estrutura das tabelas;
- dados de outros clientes.

Durante a limpeza:

- ParmaCloudSync do Windows estava parado;
- `parmasoft-portal.service` estava parado;
- foi feito backup antes do `DELETE`.

## Sincronizacao Limpa Final

Apos religar a API e o Servico do Windows, foi executada a carga limpa usando o backup local da Fabri Tecidos.

Resultado no log do ParmaCloudSync:

- produtos lidos: 2.958;
- lotes: 30;
- 29 lotes de 100 registros;
- ultimo lote com 58 registros;
- HTTP 200 em todos os lotes;
- produtos enviados: 2.958 de 2.958;
- progresso: 100%;
- duracao aproximada: 15,59 segundos;
- sincronizacao concluida com sucesso.

Contagem final na nuvem:

```text
PRODUTOS NA NUVEM: 2958
```

Comparacao:

- enviados pelo ParmaCloudSync: 2.958;
- existentes na nuvem: 2.958;
- diferenca: 0.

## Endpoints e Enderecos Importantes

IP atual da DigitalOcean:

- `165.227.77.226`

Endpoint de sincronizacao de produtos:

- `http://165.227.77.226:5000/portal/fabritecidos/sincronizar-produtos`
- metodo: POST
- cabecalho: `X-Portal-Token`

Endpoint de login:

- `http://165.227.77.226:5000/portal/fabritecidos/login`
- metodo: POST

Endpoint de consulta de produtos:

- `http://165.227.77.226:5000/portal/fabritecidos/produtos`
- metodo: GET
- exige sessao autenticada.

Rota de teste:

- `http://165.227.77.226:5000/ping`

Tela atual do Portal:

- `http://165.227.77.226:5000/static/portal/index.html?cliente=fabritecidos`

O parametro abaixo e obrigatorio na URL atual:

```text
?cliente=fabritecidos
```

Sem esse parametro, a tela mostra:

```text
Cliente nao informado
```

Arquivos visuais do Portal:

- `/var/www/cotacao/static/portal/index.html`;
- `/var/www/cotacao/static/portal/portal.js`;
- `/var/www/cotacao/static/portal/portal.css`.

O JavaScript obtem o cliente por:

```javascript
new URLSearchParams(window.location.search)
```

Parametro esperado:

- `cliente`.

## Teste do Portal no Navegador

Foi validado:

- identificacao do cliente Fabri Tecidos;
- tela de login;
- autenticacao por sessao;
- usuario Fabricio autenticado;
- pesquisa por descricao;
- retorno de produtos;
- exibicao de codigo, descricao, unidade, estoque e preco;
- status de consulta concluida.

Foi feita pesquisa por "lencol" e os produtos foram retornados normalmente.

Nao registrar senhas em nenhum arquivo de documentacao.

## Seguranca e Melhorias Futuras

Situacao atual:

- o Portal esta sendo acessado diretamente pela porta 5000;
- o navegador mostra "Nao seguro";
- o Nginx esta ativo, mas ainda nao atua como proxy da API/Portal;
- a URL atual e tecnica e pouco amigavel.

Melhorias futuras, nao implementar nesta etapa:

1. Criar URL amigavel, por exemplo `/portal/fabritecidos`.
2. Configurar Nginx como reverse proxy.
3. Implantar HTTPS.
4. Retirar a exposicao publica direta da porta 5000 depois de validar o proxy.
5. Criar usuario Linux especifico para o servico, evitando execucao como root.
6. Melhorar a tela visual do Portal.
7. Avaliar paginacao e limite da pesquisa.
8. Avaliar tratamento visual para estoque negativo.
9. Remover, em etapa separada, o `SERVICE_START_PENDING` manual de `SvcDoRun()`, pois o `ServiceFramework` ja controla o estado inicial.
10. Nao misturar essas melhorias com a versao 1.0 aprovada.

## Proximo Passo

A proxima etapa e trabalhar exclusivamente na experiencia visual do Portal:

- revisar a tela atual;
- melhorar responsividade;
- melhorar apresentacao dos produtos;
- criar endereco amigavel;
- manter login e sessao;
- preservar completamente o backend e a sincronizacao aprovados.

Antes da implantacao real na Fabri Tecidos:

1. Instalar Python 3.11.9 de 32 bits para todos os usuarios.
2. Usar caminho global dedicado `C:\Python311-32`.
3. Instalar requirements no Python global.
4. Executar `pywin32_postinstall` fora do `venv`.
5. Testar conexao Firebird.
6. Instalar o servico pelo Python global.
7. Confirmar `ImagePath`.
8. Testar start, stop, restart e reboot.
9. Conferir logs.
10. Confirmar sincronizacao real.

## Conclusao

A versao 1.0 ficou tecnicamente aprovada em homologacao.

Partes aprovadas:

- sincronizador;
- Servico do Windows;
- recuperacao apos falhas;
- inicio automatico;
- API permanente na nuvem;
- Gunicorn com dois workers;
- Firebird;
- banco da nuvem;
- carga limpa;
- login;
- pesquisa pelo navegador;
- reboot das duas pontas.

Pendencias:

- instalacao controlada no servidor real da Fabri;
- correcao do manual;
- melhoria visual;
- URL amigavel;
- Nginx/HTTPS em etapa futura.

## Encerramento Oficial do Dia - 01/08/2026

Projeto: ParmaCloudSync / Portal Fabri Tecidos

No encerramento do dia, ficou definido que nao seriam executados mais comandos
remotos, SQL, testes, publicacoes, paradas ou inicializacoes de servico. Esta
secao registra somente o ponto documental de parada.

### Resultado Geral do Dia

O ParmaCloudSync v1.0 ja havia sido validado anteriormente em homologacao com:

- Python 3.11.9 de 32 bits;
- Servico Windows `ParmaCloudSync`;
- banco correto da Fabri Tecidos;
- envio de 2.958 produtos;
- 30 lotes;
- API e Portal na DigitalOcean;
- inicializacao automatica apos reinicializacao;
- repeticao automatica apos indisponibilidade da API.

No dia 01/08/2026 foram trabalhados:

1. publicacao e validacao do novo layout compacto do Portal;
2. preparacao do login sem diferenciar maiusculas e minusculas;
3. inclusao do custo do produto em todo o fluxo;
4. validacao do campo oficial de custo;
5. preparacao controlada para alteracao da nuvem e nova sincronizacao.

### Layout Compacto do Portal

Foi publicado na DigitalOcean o novo layout compacto dos arquivos:

- `index.html`;
- `portal.css`;
- `portal.js`.

Caminho remoto:

- `/var/www/cotacao/static/portal`

Backup criado antes da publicacao:

- `/var/www/cotacao/backups/portal_antes_publicacao_20260801_1539`

O layout foi aprovado visualmente:

- painel superior separado removido;
- `PARMASOFT` e `Fabri Tecidos` integrados ao painel de pesquisa;
- status da consulta no mesmo painel;
- usuario conectado no mesmo painel;
- campo de pesquisa logo abaixo;
- ganho de espaco vertical;
- tabela de produtos mais alta;
- pesquisa funcionando normalmente.

Depois de novo login em janela anonima, foi confirmado:

- usuario conectado: `Fabricio`.

No navegador normal, a sessao antiga ainda podia exibir traco no nome do
usuario porque havia sido criada antes da atualizacao do JavaScript. Depois de
novo login, o comportamento ficou correto.

### Login Case-Insensitive

Problema confirmado:

- `FABRICIO` autenticava;
- `fabricio` nao autenticava.

Necessidade definida:

- o nome do usuario nao deve diferenciar maiusculas e minusculas;
- a senha deve continuar sensivel a maiusculas e minusculas;
- o usuario retornado ao Portal deve continuar sendo o valor cadastrado no
  banco, por exemplo `Fabricio`.

A alteracao local foi preparada em `api_nuvem.py`, usando comparacao
equivalente a:

```sql
UPPER(U.PUS_USUARIO) = UPPER(?)
```

Essa alteracao ainda nao foi publicada na DigitalOcean.

### Campo Oficial do Custo

O campo oficial confirmado para a Fabri Tecidos e:

- `TB_PRODUTO.PRD_PRECO_CUSTO`

Nao utilizar outros campos de custo, custo medio, custo liquido, custo de
prateleira, campos auxiliares ou preco de venda. O custo deve preservar quatro
casas decimais.

### Alteracoes Locais Preparadas

Projeto local:

- `E:\Jorginho\Parma_Cloud`

Arquivos alterados localmente:

- `modelos.py`;
- `config.ini`;
- `api_nuvem.py`;
- `static/portal/index.html`;
- `static/portal/portal.css`;
- `static/portal/portal.js`.

Arquivos confirmados sem alteracao:

- `banco.py`;
- `api.py`;
- `sincronizador.py`.

Backup local criado:

- `E:\Jorginho\Parma_Cloud\backups\custo_login_20260801_155135`

Backup remoto anterior criado:

- `/var/www/cotacao/backups/custo_login_20260801_155213`

Resumo das implementacoes locais:

- `modelos.py` passou a possuir o atributo `custo`, preservando a diferenca
  entre `None` e custo igual a zero;
- `config.ini` passou a incluir `P.PRD_PRECO_CUSTO AS CUSTO` no `SELECT`;
- `api_nuvem.py` foi preparado com login case-insensitive, recebimento do
  campo `custo`, suporte a `PPR_CUSTO`, custo na sincronizacao, custo na
  consulta do Portal e preservacao de custo existente se um payload antigo nao
  trouxer o campo;
- Portal foi preparado com coluna `Custo` antes de `Preco`, quatro casas
  decimais, `NULL` exibido como traco, zero exibido como `R$ 0,0000`,
  alinhamento monetario a direita e layout compacto preservado.

As alteracoes de custo e login ainda nao foram publicadas.

### Banco Correto da Fabri e Validacao

Banco correto utilizado:

- `E:\Dados Clientes\Fabri Tecidos\DADOS.FDB`

Ambiente:

- host: `127.0.0.1`;
- porta: `3050`;
- Firebird: `2.5.9`;
- tamanho do arquivo: `2.133.901.312 bytes`;
- ultima modificacao registrada na validacao: `01/08/2026 15:50:48`.

A porta `3090` com Firebird 5 foi testada e rejeitou o banco por ODS
incompativel. A instancia correta para esse banco e o Firebird 2.5 na porta
3050.

Resultado do `SELECT`:

- com `PRD_PRECO_CUSTO AS CUSTO`: 2.958 produtos;
- sem a coluna custo: 2.958 produtos;
- mesmo conjunto: `True`;
- mesma ordem: `True`;
- primeiro produto: `1`;
- ultimo produto: `4627`.

Distribuicao dos custos:

- custo `NULL`: 0;
- custo zero: 11;
- custo positivo: 2.947;
- menor custo positivo: 0,01;
- maior custo: 109.782,41;
- media dos custos positivos: `104.2466653885307091957923312`.

A inclusao da coluna custo nao alterou quantidade, filtros ou ordenacao dos
produtos.

Amostra validada:

- codigo: `13`;
- descricao: `TAFETA LISO 50% POLIESTER 50% POLIAMIDA`;
- unidade: `MT`;
- estoque: `-22.12`;
- custo: `5.2956`;
- preco: `10.98`.

Confirmado:

- custo vem exclusivamente de `PRD_PRECO_CUSTO`;
- zero permanece zero;
- quatro casas sao preservadas;
- preco de venda nao foi usado como custo;
- nenhum `POST` foi realizado durante essa validacao.

### Servico Windows ParmaCloudSync

Runtime Windows em outra maquina:

- `C:\Parmasoft_Cloud`

Python global:

- `C:\Python311-32\python.exe`

O Servico Windows foi parado manualmente com sucesso.

Conferencia:

```text
sc query ParmaCloudSync
ESTADO : 1  STOPPED
```

Backup do runtime criado:

- `C:\Parmasoft_Cloud\backups\custo_login_20260801_1720`

Arquivos preservados:

- `modelos.py`;
- `config.ini`.

O Servico Windows `ParmaCloudSync` permanece parado. A atualizacao do runtime
ainda nao foi feita e o `config.ini` nao foi substituido. Quando chegar essa
etapa, alterar somente o `SELECT`, preservando host, porta, caminho do banco,
usuario e senha Firebird, endpoint, identificador, token, intervalo, lotes,
timeouts e demais configuracoes.

### Backups Remotos da Implantacao

Backup remoto dos quatro arquivos atuais:

- `/var/www/cotacao/backups/custo_login_implantacao_20260801_172543`

Arquivos preservados:

- `api_nuvem.py`;
- `index.html`;
- `portal.css`;
- `portal.js`.

Backup fisico do banco da nuvem:

- `/var/lib/firebird/backups/cotacao_antes_custo_20260801_172600.fdb`

Tamanho:

- `2.899.968 bytes`

O Firebird foi parado para a copia fisica e iniciado novamente com sucesso.

### Tentativas de Criacao de PPR_CUSTO

Campo planejado:

- `TB_PORTAL_PRODUTO.PPR_CUSTO NUMERIC(15,4)`

Nenhum `ALTER TABLE` foi executado ate o encerramento do dia.

Primeira tentativa:

- o comando remoto enviado ao Python falhou por montagem incorreta de aspas;
- erro: `SyntaxError: unterminated string literal`;
- ocorreu antes da conexao e antes de qualquer SQL.

Segunda tentativa:

- foi criado `/tmp/criar_ppr_custo.py` com heredoc protegido `<<'PY'`;
- ao executar, ocorreu `ModuleNotFoundError: No module named 'api_nuvem'`;
- causa: o script estava em `/tmp` e `/var/www/cotacao` nao estava no caminho
  de importacao do Python;
- ocorreu antes da conexao e antes de qualquer SQL;
- o script temporario foi removido.

Terceira tentativa:

- foi confirmado que `api_nuvem.py` possui `get_connection`;
- foi solicitado `systemctl stop parmasoft-portal.service`;
- a conferencia retornou `failed` em vez de `inactive`;
- como a autorizacao exigia explicitamente `inactive`, a etapa foi
  interrompida antes da criacao do script temporario e antes de qualquer
  `ALTER TABLE`;
- a API foi iniciada novamente e voltou para `active`.

### Ultimo Erro do Dia

Ultimo bloqueio:

- apos executar a parada de `parmasoft-portal.service`, o systemd apresentou
  estado `failed` em vez de `inactive`.

Possiveis explicacoes a investigar na retomada:

- Gunicorn ja estava com algum processo em falha antes da parada;
- o encerramento do Gunicorn retornou codigo que levou o systemd a registrar
  `failed`;
- algum worker nao encerrou conforme esperado;
- configuracao `Restart=always` pode ter interferido;
- o processo pode ter parado apesar do estado `failed`;
- a porta 5000 pode ou nao ter permanecido ocupada.

Nao assumir causa sem auditoria.

### Estado Final dos Ambientes

DigitalOcean:

- Firebird: `active`;
- `parmasoft-portal.service`: `active`;
- API e Portal voltaram a funcionar normalmente.

Banco da nuvem:

- backup fisico criado;
- `PPR_CUSTO` ainda nao foi criado;
- nenhum `ALTER TABLE` executado;
- nenhum `UPDATE` executado;
- nenhum `DELETE` executado.

Arquivos remotos:

- alteracoes de custo e login ainda nao publicadas;
- versao anterior da API continua ativa;
- novo layout compacto publicado anteriormente continua ativo.

Windows:

- `ParmaCloudSync`: `STOPPED`;
- o servico deve permanecer parado ate a retomada controlada.

Sincronizacao:

- nenhum `POST` executado;
- nenhuma nova sincronizacao realizada;
- produtos da nuvem permanecem com a estrutura anterior;
- custo ainda nao esta armazenado na nuvem.

Arquivos temporarios:

- `/tmp/criar_ppr_custo.py` removido;
- script novo dentro de `/var/www/cotacao` nao chegou a ser criado.

Seguranca:

- nenhuma senha registrada;
- nenhum token registrado;
- nenhuma chave privada exposta;
- nenhum hash de senha registrado;
- nenhum conteudo de `.portal_secret_key` registrado.

### Ponto de Parada Oficial

Ultima etapa concluida:

- layout compacto publicado e aprovado;
- banco correto da Fabri validado com 2.958 produtos;
- `PRD_PRECO_CUSTO` confirmado como campo oficial;
- custo implementado localmente;
- login case-insensitive implementado localmente;
- backups locais, Windows, remotos e do banco da nuvem criados;
- Servico Windows `ParmaCloudSync` parado;
- API e Firebird remotos ativos e funcionais.

Bloqueio atual:

- `systemctl stop parmasoft-portal.service` deixou o servico em `failed`, em
  vez de `inactive`.

Nenhuma alteracao no banco ocorreu.

### Primeira Acao na Retomada

Na retomada, nao comecar publicando ou alterando o banco. Primeiro auditar o
comportamento da parada do servico:

1. consultar o estado atual:

```bash
systemctl status parmasoft-portal.service --no-pager -l
```

2. consultar os logs do encerramento anterior:

```bash
journalctl -u parmasoft-portal.service --since "2026-08-01 17:00:00" --no-pager
```

3. conferir a definicao do servico:

```bash
systemctl cat parmasoft-portal.service
```

4. conferir processos do Gunicorn:

```bash
ps aux | grep -E '[g]unicorn|[a]pi_nuvem'
```

5. conferir quem esta ouvindo na porta 5000:

```bash
ss -ltnp | grep ':5000'
```

6. somente depois executar a parada novamente.

Se `systemctl` apresentar `failed` apos o stop, considerar o servico realmente
parado apenas se todas as condicoes abaixo forem confirmadas:

- nenhum processo Gunicorn relacionado esta ativo;
- nenhum processo `api_nuvem` esta ativo;
- ninguem esta ouvindo na porta 5000;
- `curl` para `127.0.0.1:5000` falha por conexao recusada;
- nao existe processo reiniciando automaticamente.

Nao tratar `failed` automaticamente como sucesso. Registrar a causa real antes
de avancar.

### Etapas Posteriores, Somente Apos Resolver o Stop

Depois de confirmar a API realmente parada:

1. criar o script temporario em `/var/www/cotacao/.tmp_criar_ppr_custo.py`;
2. importar `from api_nuvem import get_connection`;
3. consultar `RDB$RELATION_FIELDS`;
4. criar, se ainda nao existir, `PPR_CUSTO NUMERIC(15,4)`;
5. validar escala interna `-4`, cliente 2 com 2.958 produtos e 2.958 custos
   `NULL` antes da sincronizacao;
6. remover o script temporario;
7. publicar `api_nuvem.py`, `index.html`, `portal.css` e `portal.js`;
8. validar `py_compile`, importacao e Gunicorn;
9. iniciar a API;
10. testar `/ping` e HTTP 405 no GET do endpoint de sincronizacao;
11. preparar a entrega para o runtime Windows;
12. atualizar `modelos.py` na maquina Windows;
13. alterar somente o `SELECT` do `config.ini` real;
14. validar conexao e 2.958 produtos;
15. iniciar o Servico Windows;
16. sincronizar os custos;
17. validar na nuvem: total 2.958, custo `NULL` 0, custo zero 11, custo
    positivo 2.947, menor positivo 0,01 e maior 109.782,41;
18. testar login em todas as combinacoes de caixa;
19. validar o Portal no desktop e celular.

### Encerramento

Ponto de parada registrado. Nao executar mais comandos operacionais hoje. Nao
parar servicos novamente. Nao alterar banco. Nao tentar criar `PPR_CUSTO`. Nao
publicar a API. Nao iniciar o `ParmaCloudSync`.
