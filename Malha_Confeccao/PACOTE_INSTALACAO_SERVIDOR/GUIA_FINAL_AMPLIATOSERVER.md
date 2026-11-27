# Guia final — AMPLIATOSERVER

## Transferência única

Transfira o arquivo `PACOTE_FINAL_AMPLIATOSERVER.zip` gerado ao lado deste pacote. Extraia-o em `C:\Temp\AgenteMalhasFinal` no servidor e, com a tarefa `ParmaSoft - Agente Malhas` ainda desativada, copie todo o conteúdo extraído para `C:\Parmasoft\AgenteMalhas`, mesclando e substituindo arquivos. O pacote não contém `venv`, `state.db`, logs ou credenciais e, portanto, não os substitui.

```powershell
Copy-Item -Path 'C:\Temp\AgenteMalhasFinal\*' -Destination 'C:\Parmasoft\AgenteMalhas' -Recurse -Force
```

Não execute novamente o instalador, não recrie a tarefa e não altere o arquivo externo `C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env`.

## Diagnóstico único e seguro

Em PowerShell elevado:

```powershell
Set-Location C:\Parmasoft\AgenteMalhas\deploy
.\Test-AgenteMalhas.ps1
```

O diagnóstico valida: estrutura/imports, `fbclient.dll` x86, Python/fdb, health HTTPS, token técnico e empresa, e Firebird somente leitura. A sonda do token envia um payload propositalmente incompleto para a rota de vendedores. Na API contratada, ela retorna `HTTP 400` antes de abrir transação; esse é o resultado de sucesso da autorização e não publica snapshot, não faz claim e não envia ACK.

Resultados relevantes:

- `API tecnica: token e empresa validados`: token, empresa e rota interna estão corretos.
- `HTTP 401`: token técnico inválido, inativo ou diferente do configurado.
- `HTTP 403`: token válido, mas vinculado a outra empresa.
- `falha DNS`, `falha TLS`, `timeout` ou `falha de transporte`: investigar conectividade do servidor.

O diagnóstico nunca exibe token, senha ou cabeçalho Authorization.

## Ativação controlada posterior

Somente após o diagnóstico terminar sem erro e com autorização operacional, habilite e inicie a tarefa manualmente pelo Agendador de Tarefas. A ativação não faz parte do instalador nem deste diagnóstico.

Após a primeira inicialização, consulte o log em `C:\ProgramData\ParmaSoft\AgenteMalhas\logs\agente-malhas.log`. Erros HTTP e transporte passam a registrar categoria e status sem incluir segredos.
