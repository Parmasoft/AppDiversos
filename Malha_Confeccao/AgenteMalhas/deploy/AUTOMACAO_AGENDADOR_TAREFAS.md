# Automação do Agente Malhas pelo Agendador de Tarefas

Esta entrega apenas prepara a automação. Nenhum script deste diretório foi executado para criar, iniciar, parar ou remover uma tarefa nesta máquina.

## Estratégia

A tarefa `ParmaSoft - Agente Malhas` usa o gatilho de inicialização do Windows com atraso de um minuto e uma conta local dedicada. Ela executa sem login interativo. O wrapper usa o Python do `venv` do próprio repositório, define `AgenteMalhas` como diretório de trabalho e lê somente `C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env`.

A tarefa ignora novo disparo enquanto já houver uma execução e reinicia até três vezes, em intervalos de um minuto, quando o processo terminar com erro. O lock exclusivo existente em `state.db.lock` é uma segunda barreira: execução manual e agendada que apontem ao mesmo `state.db` não podem processar juntas. A idempotência de snapshots e pedidos permanece no agente/API já existente; este trabalho não altera o protocolo.

Os logs continuam em `C:\ProgramData\ParmaSoft\AgenteMalhas\logs`. O wrapper acrescenta apenas `agente-malhas-bootstrap.log` nesse diretório, para falhas antes da configuração Python. Nenhum script grava credenciais.

## Instalação futura (após autorização)

Em PowerShell elevado, a instalação sem senha pode usar a conta interna SYSTEM:

```powershell
Set-Location E:\Jorginho\Malha_Confeccao\AgenteMalhas\deploy
.\Install-AgenteMalhasTask.ps1 -RunAsSystem
```

SYSTEM não requer senha nem o direito de logon em lote. O instalador também mantém o modo opcional de conta dedicada (`-TaskUser`), que solicita a senha de modo protegido. Em ambos os modos, valida `venv`, wrapper e `.env`, registra mas não inicia a tarefa, e só informa sucesso após o Agendador confirmar que a tarefa está habilitada. Confirme antes que o `.env` aponta estado, logs e marcador de parada para ProgramData e que a ACL permite a leitura necessária.

Na máquina de desenvolvimento, as ACLs verificadas concedem `FullControl` a
`NT AUTHORITY\SYSTEM` no diretório ProgramData do agente, no `.env`, em
`state.db`, em `logs`, na raiz do agente e no executável Python do `venv`.
O acesso ao Firebird local continua sendo autenticado com as credenciais já
existentes no `.env`; a conectividade deve ser validada somente na ativação
autorizada, pois esta preparação não inicia o agente.

## Verificação e reinício futuros

```powershell
.\Get-AgenteMalhasTaskStatus.ps1
.\Restart-AgenteMalhasTask.ps1
```

Verifique `State`, `LastTaskResult` e os logs `agente-malhas.log` e `agente-malhas-bootstrap.log`. O teste manual `Start-AgenteMalhas.ps1 -Once` deve ser feito sob a mesma conta da tarefa, somente quando autorizado e sem outra instância em execução.

O reinício cria o marcador cooperativo, espera até 90 segundos e não finaliza processo à força. Ele recusa agir se a tarefa não estiver `Running`, para não sinalizar uma possível instância manual que compartilhe o estado.

## Reversão futura

```powershell
.\Uninstall-AgenteMalhasTask.ps1
```

Remove somente a tarefa agendada; preserva `.env`, logs, `state.db`, virtualenv, código e dados comerciais.

## Riscos operacionais

- Validar no computador alvo: conta da tarefa, direito de logon em lote, ACL de ProgramData e acesso ao Firebird.
- Não instalar enquanto a execução manual atual usa o mesmo `state.db`: o lock bloqueará a segunda instância, porém gerará reinícios e logs.
- Falhas persistentes após três reinícios exigem investigação dos logs e conectividade/API.
- Mover o repositório ou recriar o `venv` exige registrar a tarefa novamente, pois a ação usa caminhos absolutos.
## Estado operacional registrado — 26/10/2026

Nesta máquina, a configuração documentada foi aplicada como tarefa
`ParmaSoft - Agente Malhas`, executada por `NT AUTHORITY\SYSTEM`, sem senha de
usuário e com inicialização no boot. O registro de validação informa que a
tarefa foi iniciada, permaneceu em estado `Running` e produziu logs de
sincronização bem-sucedida em
`C:\ProgramData\ParmaSoft\AgenteMalhas\logs`.

O `.env` externo e a proteção contra instância simultânea permanecem inalterados.
Este documento não autoriza iniciar, parar, reiniciar, reinstalar ou modificar a
tarefa; ele apenas registra o estado confirmado em 26/10/2026.

