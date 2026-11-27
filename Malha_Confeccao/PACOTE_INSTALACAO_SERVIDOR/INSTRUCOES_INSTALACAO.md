# Instalação do Agente Malhas — AMPLIATOSERVER

Este pacote é independente do agente de origem. Copie a pasta inteira para `C:\Parmasoft\AgenteMalhas`. Não copie o `venv`, `state.db`, logs, caches ou um `.env` da origem.

### Reparo de estrutura incompleta

Se o diagnóstico informar `ModuleNotFoundError: No module named 'agent'`, a pasta `agent` não foi transferida. Com a tarefa ainda desativada, copie **recursivamente e por inteiro** `agent` deste pacote para `C:\Parmasoft\AgenteMalhas\agent`; copie também `main.py` para `C:\Parmasoft\AgenteMalhas\main.py` e substitua os arquivos `deploy\Test-AgenteMalhas.ps1` e `deploy\Start-AgenteMalhas.ps1`. Não copie `venv`, `state.db`, logs ou o arquivo de ambiente.

O diagnóstico passa a executar `python -m agent.diagnostics`, sem `PYTHONPATH` ou alteração dinâmica de caminhos. O instalador, inicializador e diagnóstico verificam os arquivos obrigatórios antes de prosseguir.

## Pré-requisitos confirmados

- Windows Server 2012 R2 Standard;
- Python **3.11.9 de 32 bits** e pip 24.0;
- acesso HTTPS a `https://malhas.parmatech.com.br`;
- cliente Firebird de **32 bits** disponível para o processo Python (incluindo `fbclient.dll`) e acesso de rede/local ao banco.

`fdb` 2.0.4 é puro Python e foi validado localmente com Python 3.11 de 32 bits. A biblioteca nativa Firebird não acompanha este pacote: ela precisa ser da mesma arquitetura do Python. O caminho do `.FDB` não é presumido nem criado pelo instalador.

## Instalação (PowerShell elevado)

Após copiar:

```powershell
Set-Location C:\Parmasoft\AgenteMalhas\deploy
.\Install-AgenteMalhas.ps1
```

Se `python` não apontar ao Python 3.11 x86, informe o executável explicitamente:

```powershell
.\Install-AgenteMalhas.ps1 -PythonExe 'C:\caminho\para\python.exe'
```

O instalador cria o virtualenv, instala `fdb==2.0.4`, cria a área protegida em `C:\ProgramData\ParmaSoft\AgenteMalhas`, prepara o arquivo externo de configuração e registra `ParmaSoft - Agente Malhas` para `NT AUTHORITY\SYSTEM`.

**A tarefa é registrada já desativada e o instalador nunca a inicia.** O atraso fixo de inicialização é de um minuto. O registro usa a API nativa Task Scheduler 2.0, em vez de montar XML manualmente; isso permite configurar o logon SYSTEM como conta de serviço e o atraso de boot de forma compatível. Não a habilite nem clique em Executar sem autorização posterior.

### Correção para instalação interrompida no PowerShell 4

Se a instalação anterior parou ao criar a tarefa, não é preciso recriar o virtualenv, reinstalar dependências nem substituir o arquivo de ambiente. Copie `deploy\Register-AgenteMalhasTask.ps1` deste pacote corrigido para `C:\Parmasoft\AgenteMalhas\deploy\Register-AgenteMalhasTask.ps1` e execute, em PowerShell elevado:

```powershell
Set-Location C:\Parmasoft\AgenteMalhas\deploy
.\Register-AgenteMalhasTask.ps1
```

O script acima somente registra/substitui a tarefa desativada; ele não inicia o agente.

Para inspecionar a definição e a versão do Agendador **sem registrar uma tarefa**, execute:

```powershell
.\Register-AgenteMalhasTask.ps1 -ShowDefinition
```

Esse diagnóstico imprime a definição XML efetivamente produzida pela API e não acessa banco, API ou credenciais além de verificar a existência do arquivo de ambiente.

## Configuração confidencial

Edite somente `C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env`; ele é criado a partir do exemplo sem segredos. Fornecer separadamente e por canal seguro:

- `MALHAS_AGENT_TOKEN` técnico exclusivo;
- ID e nome da empresa autorizada;
- host, porta, caminho/alias real, usuário, senha e charset Firebird;
- confirmação de que a conta SYSTEM tem acesso ao Firebird e ao `fbclient.dll` x86.

Não envie esse arquivo por e-mail, chat, Git, relatório, zip público ou junto com este pacote. O instalador restringe a pasta de dados e o arquivo a Administradores e SYSTEM. Guarde uma cópia segura das credenciais fora do servidor.

## Diagnóstico seguro

Depois de preencher a configuração, ainda com a tarefa desativada:

```powershell
.\Test-AgenteMalhas.ps1
```

O diagnóstico valida Python, `fdb`, TLS/`GET /api/v1/health` e uma consulta `SELECT 1 FROM RDB$DATABASE` em transação somente leitura. Ele não executa o agente, não publica snapshots, não faz claim, não envia ACK e não cria pedidos.

Não há endpoint autenticado de health do agente que seja comprovadamente livre de efeito colateral; portanto o token técnico não é validado pelo diagnóstico. A autenticação e o primeiro ciclo devem ser verificados somente no procedimento de ativação autorizado.

## Garantias preservadas

O código não foi alterado: mantém o lock exclusivo em `state.db.lock`, persiste snapshots antes do envio e, para pedidos, faz commit Firebird antes do ACK. A tarefa usa `IgnoreNew` como barreira adicional. O banco não é migrado por nenhum script deste pacote.

## Ativação futura (não executar agora)

Após autorização formal, um operador deverá revisar o diagnóstico, remover eventual `stop.request`, habilitar a tarefa pelo Agendador e executar o procedimento operacional aprovado. Esta entrega não contém nem executa comando de ativação.
