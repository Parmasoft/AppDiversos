[CmdletBinding()]
param(
    [string]$TaskName = 'ParmaSoft - Agente Malhas',
    [string]$EnvironmentFile = 'C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env',
    [switch]$ShowDefinition
)
$ErrorActionPreference = 'Stop'

# Usa diretamente a API Task Scheduler 2.0, presente desde Windows Server 2008.
# Evita serializar LogonType=ServiceAccount no XML: esse valor e valido na API,
# mas nao e um valor valido do elemento XML LogonType.
$TASK_TRIGGER_BOOT = 8
$TASK_ACTION_EXEC = 0
$TASK_CREATE_OR_UPDATE = 6
$TASK_LOGON_SERVICE_ACCOUNT = 5
$TASK_INSTANCES_IGNORE_NEW = 2

$agentRoot = Split-Path -Parent $PSScriptRoot
$starter = Join-Path $PSScriptRoot 'Start-AgenteMalhas.ps1'
$powerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (!(Test-Path -LiteralPath $starter -PathType Leaf)) { throw 'Start-AgenteMalhas.ps1 nao encontrado.' }
if (!(Test-Path -LiteralPath $EnvironmentFile -PathType Leaf)) { throw 'Arquivo protegido de ambiente nao encontrado.' }

try { $service = New-Object -ComObject 'Schedule.Service'; $service.Connect() }
catch { throw "A API Task Scheduler 2.0 nao esta disponivel: $($_.Exception.Message)" }
$definition = $service.NewTask(0)
$definition.RegistrationInfo.Description = 'Agente Malhas - inicializacao automatica controlada'
$definition.Principal.UserId = 'NT AUTHORITY\SYSTEM'
$definition.Principal.LogonType = $TASK_LOGON_SERVICE_ACCOUNT
$definition.Principal.RunLevel = 1 # TASK_RUNLEVEL_HIGHEST
$definition.Settings.Enabled = $false # definido antes de qualquer registro
$definition.Settings.MultipleInstances = $TASK_INSTANCES_IGNORE_NEW
$definition.Settings.DisallowStartIfOnBatteries = $false
$definition.Settings.StopIfGoingOnBatteries = $false
$definition.Settings.AllowHardTerminate = $false
$definition.Settings.StartWhenAvailable = $true
$definition.Settings.RunOnlyIfNetworkAvailable = $false
$definition.Settings.ExecutionTimeLimit = 'PT0S'
$definition.Settings.RestartCount = 3
$definition.Settings.RestartInterval = 'PT1M'
$trigger = $definition.Triggers.Create($TASK_TRIGGER_BOOT)
$trigger.Enabled = $true
$trigger.Delay = 'PT1M'
$action = $definition.Actions.Create($TASK_ACTION_EXEC)
$action.Path = $powerShell
$action.Arguments = ('-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -EnvironmentFile "{1}"' -f $starter,$EnvironmentFile)
$action.WorkingDirectory = $agentRoot

if ($ShowDefinition) {
    [pscustomobject]@{ PowerShellVersion = $PSVersionTable.PSVersion.ToString(); TaskSchedulerHighestVersion = ('0x{0:X8}' -f [uint32]$service.HighestVersion); TaskName = $TaskName; EnabledBeforeRegistration = $definition.Settings.Enabled; TriggerDelay = $trigger.Delay; MultipleInstances = $definition.Settings.MultipleInstances; Principal = $definition.Principal.UserId } | Format-List
    Write-Output $definition.XmlText
    return
}

# A definicao ja contem Enabled=false. A API registra/substitui sem criar uma tarefa habilitada.
$null = $service.GetFolder('\').RegisterTaskDefinition($TaskName, $definition, $TASK_CREATE_OR_UPDATE, 'NT AUTHORITY\SYSTEM', $null, $TASK_LOGON_SERVICE_ACCOUNT, $null)
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
if ($task.Settings.Enabled) { throw 'Falha de seguranca: a tarefa ficou habilitada.' }
Write-Host "Tarefa '$TaskName' registrada DESATIVADA; ela nao foi iniciada."
