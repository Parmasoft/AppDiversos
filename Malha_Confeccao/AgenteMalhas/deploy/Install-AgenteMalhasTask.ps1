[CmdletBinding()]
param(
    [Parameter(ParameterSetName = 'User', Mandatory)] [string]$TaskUser,
    [Parameter(ParameterSetName = 'User')] [SecureString]$TaskPassword,
    [Parameter(ParameterSetName = 'System', Mandatory)] [switch]$RunAsSystem,
    [string]$TaskName = 'ParmaSoft - Agente Malhas',
    [string]$EnvironmentFile = 'C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env'
)
$ErrorActionPreference = 'Stop'
$agentRoot = Split-Path -Parent $PSScriptRoot
$starter = Join-Path $PSScriptRoot 'Start-AgenteMalhas.ps1'
$python = Join-Path $agentRoot 'venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $starter -PathType Leaf)) { throw 'Start-AgenteMalhas.ps1 nao encontrado.' }
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) { throw 'Virtualenv/Python do Agente nao encontrado.' }
if (-not (Test-Path -LiteralPath $EnvironmentFile -PathType Leaf)) { throw 'Arquivo protegido de ambiente nao encontrado.' }
if (-not $TaskPassword) { $TaskPassword = Read-Host 'Senha da conta de servico (nao sera salva no script)' -AsSecureString }
$powerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -EnvironmentFile "{1}"' -f $starter, $EnvironmentFile
$action = New-ScheduledTaskAction -Execute $powerShell -Argument $arguments -WorkingDirectory $agentRoot
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = 'PT1M'
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Seconds 0) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

if ($RunAsSystem) {
    $principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $registered = Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction Stop
} else {
    if (-not $TaskPassword) { $TaskPassword = Read-Host 'Senha da conta de servico (nao sera salva no script)' -AsSecureString }
    $credential = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($TaskPassword)
    try {
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($credential)
        $registered = Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -User $TaskUser -Password $plainPassword -RunLevel Limited -Force -ErrorAction Stop
    } finally {
        if ($credential -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($credential) }
        Remove-Variable plainPassword -ErrorAction SilentlyContinue
    }
}
if ($null -eq $registered) { throw "O Agendador nao confirmou o registro da tarefa '$TaskName'." }
$verified = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
if ($verified.TaskName -ne $TaskName -or -not $verified.Settings.Enabled) { throw "A tarefa '$TaskName' nao foi confirmada como habilitada." }
Write-Host "Tarefa '$TaskName' registrada e habilitada. Ela sera iniciada no proximo boot; este script nao a inicia agora."
