# Manual de instalação, migração e homologação — Agente Malhas

Data de consolidação: 17/11/2026. Este manual descreve o Agente Malhas distribuído no pacote `PACOTE_INSTALACAO_SERVIDOR`. Ele não contém credenciais e não autoriza ativação automática.

## 1. Finalidade e arquitetura

O Agente Malhas é um processo Python local que lê vendedores, clientes, produtos e formas de pagamento do Firebird, publica snapshots na API Nuvem e recebe pedidos destinados à empresa. O fluxo operacional é:

```text
Flutter -> API Nuvem -> Agente Malhas -> Firebird -> Painel Delphi -> Pedido de Venda
```

O agente usa SQLite exclusivamente para controlar revisões e snapshots pendentes. O Firebird é o destino dos pedidos recebidos; o agente não executa migrations e não converte diretamente o pedido recebido em Pedido de Venda.

## 2. Pré-requisitos

- Windows Server 2012 R2 Standard ou ambiente Windows compatível com o Agendador 2.0;
- PowerShell 4.0 ou superior;
- Python 3.11.9 de **32 bits** e `pip` funcional;
- pacote Python `fdb==2.0.4`;
- Firebird 2.5 com cliente `fbclient.dll` de **32 bits**;
- acesso HTTPS à URL autorizada da API;
- acesso de rede e permissões ao banco Firebird;
- conta `NT AUTHORITY\SYSTEM` com leitura do `.env`, acesso ao Firebird e permissão de escrita no diretório de estado/logs.

O cliente Firebird do cenário homologado encontra-se em:

```text
C:\Program Files\Firebird\Firebird_2_5\WOW64\fbclient.dll
```

Os wrappers do pacote validam o cabeçalho PE da DLL como x86 e acrescentam esse diretório somente ao `PATH` do processo que executa Python. Eles não alteram o PATH global do Windows.

## 3. Estrutura obrigatória

Instalar o conteúdo do pacote em `C:\Parmasoft\AgenteMalhas`:

```text
C:\Parmasoft\AgenteMalhas\main.py
C:\Parmasoft\AgenteMalhas\requirements.txt
C:\Parmasoft\AgenteMalhas\agent\
C:\Parmasoft\AgenteMalhas\deploy\
C:\Parmasoft\AgenteMalhas\venv\                 # criado localmente
C:\ProgramData\ParmaSoft\AgenteMalhas\           # dados e configuração protegidos
```

O diretório `agent` é obrigatório e contém `__init__.py`, `config.py`, `http_client.py`, `instance_lock.py`, `read_source.py`, `receive_orders.py`, `state.py`, `sync.py` e `diagnostics.py`. Não mover esses módulos para a raiz: `main.py` os importa como pacote Python `agent`.

O pacote não deve conter `venv`, `state.db`, logs, `__pycache__`, `.pyc`, token ou senha.

## 4. Configuração externa e segura

O wrapper lê por padrão:

```text
C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env
```

Criar esse arquivo a partir de `deploy\agente-malhas.env.example`, fora do Git. Restringir leitura a SYSTEM e administradores autorizados. Nunca enviar o arquivo por Git, e-mail, chat, relatório ou ZIP público.

Variáveis obrigatórias:

```text
MALHAS_AGENT_API_URL
MALHAS_AGENT_TOKEN
MALHAS_AGENT_EMPRESA_ID
MALHAS_AGENT_EMPRESA_NOME
FB_DATABASE
FB_USER
FB_PASSWORD
```

Variáveis suportadas adicionais:

```text
FB_HOST                 # padrão localhost
FB_PORT                 # padrão 3050
FB_CHARSET              # padrão WIN1252
MALHAS_AGENT_STATE_PATH # padrão state.db relativo
MALHAS_AGENT_LOG_PATH
MALHAS_AGENT_LOG_MAX_BYTES
MALHAS_AGENT_LOG_BACKUP_COUNT
MALHAS_AGENT_STOP_FILE
MALHAS_AGENT_RETRY_SECONDS
MALHAS_AGENT_ALLOW_INSECURE_LOCAL_TESTS
```

No cenário AMPLIATOSERVER homologado foi informado o banco `C:\Parmasoft\Dados\DADOS.FDB`, Firebird 2.5, empresa `1`/`TEKNO PRIME` e API HTTPS. Confirmar o host Firebird real antes de preencher `FB_HOST`; não presumir `localhost` quando o serviço estiver em outro computador.

Não há variável reconhecida para caminho de `fbclient.dll`; os wrappers do pacote tratam o diretório WOW64 indicado acima.

## 5. Instalação nova

Em PowerShell elevado, depois de copiar a pasta completa para o destino:

```powershell
Set-Location C:\Parmasoft\AgenteMalhas\deploy
.\Install-AgenteMalhas.ps1
```

O instalador valida Python 3.11 x86, cria `venv`, instala as dependências, cria a área de dados e registra a tarefa. A tarefa é registrada **desativada**. O instalador não inicia o agente.

Se necessário, informar explicitamente o executável Python x86:

```powershell
.\Install-AgenteMalhas.ps1 -PythonExe 'C:\caminho\python.exe'
```

O arquivo de ambiente deve ser preenchido por canal seguro antes do diagnóstico. A instalação não pressupõe caminho do `.FDB`, token ou senha.

## 6. Diagnóstico antes da ativação

Com tarefa desativada, execute:

```powershell
Set-Location C:\Parmasoft\AgenteMalhas\deploy
.\Test-AgenteMalhas.ps1
```

O diagnóstico valida estrutura/imports, Python x86, `fdb`, `fbclient.dll` x86, health HTTPS, autenticação técnica/empresa e uma consulta Firebird `SELECT 1 FROM RDB$DATABASE` em transação de leitura. Não publica snapshot, não faz claim, não envia ACK e não grava pedido comercial.

A prova de autenticação técnica usa payload propositalmente incompleto na rota de vendedores. Para o contrato da API auditado, `HTTP 400` é o resultado esperado após autenticação e antes de abrir transação. `401` indica token inválido/inativo; `403`, empresa não autorizada; DNS/TLS/timeout indicam transporte.

## 7. Tarefa agendada e inicialização automática

Nome padrão: `ParmaSoft - Agente Malhas`.

O registro utiliza a API COM Task Scheduler 2.0, executa como `NT AUTHORITY\SYSTEM`, usa Boot Trigger com atraso `PT1M`, política `IgnoreNew`, reinício em falha e `Enabled=false` no momento do registro. O uso da API COM evita incompatibilidades do PowerShell 4 com a propriedade `Delay` do trigger.

Diagnóstico de definição sem registrar tarefa:

```powershell
.\Register-AgenteMalhasTask.ps1 -ShowDefinition
```

Após autorização operacional, a habilitação e a execução devem ser feitas manualmente pelo Agendador. Confirmar o gatilho de boot e a conta SYSTEM. A confirmação de `MSFT_TaskBootTrigger` no AMPLIATOSERVER foi informada no histórico de homologação; o teste de reinicialização física do servidor ainda permanece pendente.

## 8. Execução única, idempotência e pedidos

O processo cria `state.db.lock` junto do estado. Um segundo processo que aponta ao mesmo `state.db` falha com erro de instância já existente. A tarefa também usa `IgnoreNew`.

Para snapshots, o agente grava o corpo e a revisão em SQLite antes do envio. Após confirmação da API, grava a revisão em `revisions` e remove o `pending`. Em falha, reenvia o mesmo payload/revisão.

Para pedidos, a API faz claim; o agente grava em Firebird; a transação Firebird faz commit; somente então o agente envia ACK. A chave de idempotência local é empresa, origem `FLUTTER` e ID local do pedido, além do hash de conteúdo. Não executar duas instâncias para a mesma empresa durante migração.

## 9. Migração existente e state.db

Antes de migrar, parar controladamente o agente antigo e manter o novo desativado. O estado autoritativo do agente antigo deve acompanhar a migração:

1. Fazer backup do estado novo antes de qualquer substituição.
2. Com ambos os agentes parados, copiar o `state.db` do agente antigo para o caminho definido em `MALHAS_AGENT_STATE_PATH` no novo ambiente.
3. Se existirem, preservar junto `state.db-wal` e `state.db-shm`; não copiar `state.db.lock`, logs, `stop.request`, `venv` ou `.env`.
4. Proteger a transferência: o SQLite pode conter snapshots e dados comerciais sensíveis.
5. Executar o diagnóstico antes da ativação.

O caminho efetivo é sempre `MALHAS_AGENT_STATE_PATH`. `C:\Parmasoft\AgenteMalhas\state.db` e `C:\ProgramData\ParmaSoft\AgenteMalhas\state.db` são arquivos distintos; usar o que estiver configurado no `.env`. Não deduzir o estado ativo somente pelo local do arquivo.

### Backup e restauração consistente

Não copiar SQLite enquanto o agente estiver em execução. Com a tarefa desativada e o processo encerrado, copiar o arquivo de estado e quaisquer arquivos `-wal`/`-shm` existentes para um diretório protegido com data/hora. Para restauração, manter primeiro o estado atual em backup, restaurar o conjunto do estado autorizado e conferir ACLs. Não apagar estado para “resolver” revisão sem comparar a origem e o estado da API.

## 10. Logs e diagnóstico de falhas

Logs principais:

```text
C:\ProgramData\ParmaSoft\AgenteMalhas\logs\agente-malhas.log
C:\ProgramData\ParmaSoft\AgenteMalhas\logs\agente-malhas-bootstrap.log
```

O bootstrap registra falhas antes da inicialização Python. O agente usa rotação de log configurável. Não deve registrar token, senha ou cabeçalho Authorization.

Erros de API passam a ser categorizados no pacote consolidado sem segredos: HTTP e rota, DNS, TLS, timeout ou transporte. Health HTTPS válido não comprova token técnico; usar `Test-AgenteMalhas.ps1` para o diagnóstico completo.

## 11. HTTP 409 de snapshots

Na rota de vendedores, o contrato auditado retorna `409` em duas situações:

- `REVISAO_ANTIGA`: revisão enviada menor que a última revisão aceita;
- `REVISAO_CONFLITANTE`: mesma revisão com hash de conteúdo diferente.

Uma instalação nova sem o estado histórico normalmente começa em revisão 1, enquanto a API pode já possuir revisão maior. O procedimento seguro é parar o novo agente, preservar seu estado em backup e comparar/transferir o estado autoritativo do agente antigo. Não apagar `state.db`, não reinicializar revisões e não reenviar snapshot manualmente.

O código específico do 409 não pode ser obtido por endpoint de leitura da API atual. Se a comparação dos estados não bastar, solicitar ao operador da API consulta somente leitura da tabela de sincronização, comparando recurso, revisão e hash. Não publicar snapshot como “teste”.

## 12. Checklist de instalação e homologação

- [ ] Python 3.11.9 x86 confirmado.
- [ ] `fdb==2.0.4` importado no virtualenv.
- [ ] `fbclient.dll` WOW64/x86 validada.
- [ ] Estrutura `agent\` completa no destino.
- [ ] `.env` externo criado, protegido e sem segredos em repositório.
- [ ] Host/porta/caminho Firebird confirmados.
- [ ] Tarefa registrada como SYSTEM e desativada.
- [ ] Diagnóstico estrutural, HTTPS, token/empresa e Firebird aprovado.
- [ ] Estado SQLite antigo avaliado ou transferido em migração.
- [ ] Nenhuma instância antiga em processamento para a mesma empresa.
- [ ] Ativação autorizada e logs iniciais revisados.
- [ ] Pedido de homologação conferido no Firebird/Painel, quando aplicável.
- [ ] Reinicialização física do servidor testada e registrada separadamente.

## 13. Recuperação e reversão

Em falha após ativação, desabilitar a tarefa, solicitar parada cooperativa por `MALHAS_AGENT_STOP_FILE` e aguardar o encerramento. Não finalizar processo à força salvo incidente controlado. Preservar logs e fazer backup do estado antes de qualquer alteração.

Para reversão de migração, manter o agente novo parado e restaurar somente um estado SQLite previamente confirmado, sob controle operacional. O agente antigo só pode ser retomado se o novo estiver definitivamente parado, para não haver duas instâncias da mesma empresa. Investigar autenticação, Firebird e revisão antes de qualquer nova ativação.

## 14. Evidência e limites

Os nomes de variáveis, rotas, lock, idempotência, persistência SQLite, commit antes do ACK e scripts descritos foram conferidos nos fontes locais. Os comandos de instalação e diagnóstico são fornecidos pelos scripts do pacote. Resultados específicos da migração/homologação do AMPLIATOSERVER estão registrados como informações relatadas no histórico correspondente, exceto quando há evidência local direta.
