[CmdletBinding()]
param(
    [string]$PythonExe = 'python',
    [string]$EnvironmentFile = 'C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env',
    [string]$TaskName = 'ParmaSoft - Agente Malhas'
)
$ErrorActionPreference = 'Stop'
$agentRoot = Split-Path -Parent $PSScriptRoot
$dataRoot = Split-Path -Parent $EnvironmentFile
function Require-Admin { $id=[Security.Principal.WindowsIdentity]::GetCurrent(); $p=New-Object Security.Principal.WindowsPrincipal($id); if (!$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Execute este instalador em PowerShell elevado (Administrador).' } }
Require-Admin
$required = @('main.py','requirements.txt','agent\__init__.py','agent\config.py','agent\http_client.py','agent\instance_lock.py','agent\read_source.py','agent\receive_orders.py','agent\state.py','agent\sync.py','agent\diagnostics.py')
foreach ($relative in $required) { if (!(Test-Path -LiteralPath (Join-Path $agentRoot $relative) -PathType Leaf)) { throw "Pacote incompleto: arquivo obrigatorio ausente: $relative. Copie a pasta inteira PACOTE_INSTALACAO_SERVIDOR antes de instalar." } }
& $PythonExe -c "import sys; assert sys.version_info[:2] == (3,11), sys.version; assert sys.maxsize < 2**32, 'Python deve ser 32 bits'"
if ($LASTEXITCODE -ne 0) { throw 'Exige Python 3.11 de 32 bits. Informe -PythonExe com o executavel correto.' }
New-Item -ItemType Directory -Force -Path $dataRoot,(Join-Path $dataRoot 'logs') | Out-Null
$venv = Join-Path $agentRoot 'venv'
if (!(Test-Path -LiteralPath (Join-Path $venv 'Scripts\python.exe'))) { & $PythonExe -m venv $venv; if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar o ambiente virtual.' } }
$venvPython = Join-Path $venv 'Scripts\python.exe'
& $venvPython -m pip install --upgrade pip; if ($LASTEXITCODE -ne 0) { throw 'Falha ao atualizar pip.' }
& $venvPython -m pip install -r (Join-Path $agentRoot 'requirements.txt'); if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar as dependencias.' }
& $venvPython -c "import fdb, sys; print('Python',sys.version); print('fdb',fdb.__version__)"; if ($LASTEXITCODE -ne 0) { throw 'A dependencia fdb nao pode ser importada.' }
$example = Join-Path $PSScriptRoot 'agente-malhas.env.example'
if (!(Test-Path -LiteralPath $EnvironmentFile)) { Copy-Item -LiteralPath $example -Destination $EnvironmentFile; Write-Warning "Modelo criado em $EnvironmentFile. Preencha as credenciais antes do diagnostico." }
# Credenciais ficam fora do pacote. A ACL e aplicada ao arquivo/dados, nunca a senha e token em scripts.
$admin = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
$system = New-Object Security.Principal.SecurityIdentifier('S-1-5-18')
$acl = Get-Acl -LiteralPath $dataRoot; $acl.SetAccessRuleProtection($true,$false)
foreach ($identity in @($admin,$system)) { $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($identity,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))) }
Set-Acl -LiteralPath $dataRoot -AclObject $acl
$fileAcl = Get-Acl -LiteralPath $EnvironmentFile; $fileAcl.SetAccessRuleProtection($true,$false)
foreach ($identity in @($admin,$system)) { $fileAcl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($identity,'FullControl','Allow'))) }
Set-Acl -LiteralPath $EnvironmentFile -AclObject $fileAcl
$registrar = Join-Path $PSScriptRoot 'Register-AgenteMalhasTask.ps1'
if (!(Test-Path -LiteralPath $registrar -PathType Leaf)) { throw 'Register-AgenteMalhasTask.ps1 nao encontrado.' }
& $registrar -TaskName $TaskName -EnvironmentFile $EnvironmentFile
if ($LASTEXITCODE -ne 0) { throw 'Falha ao registrar a tarefa agendada.' }
Write-Host "Instalacao concluida. A tarefa '$TaskName' foi registrada DESATIVADA e nao foi iniciada."
