[CmdletBinding()]
param([string]$TaskName = 'ParmaSoft - Agente Malhas')
$ErrorActionPreference = 'Stop'
try { $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop }
catch {
    if ($_.Exception.Message -match 'Acesso negado|Access is denied') { throw "Nao foi possivel consultar '$TaskName': acesso negado. Execute em PowerShell elevado." }
    if ($_.FullyQualifiedErrorId -match 'NoMatchingMSFT_ScheduledTask|ObjectNotFound') { Write-Host "Tarefa '$TaskName' nao esta instalada."; exit 3 }
    throw "Nao foi possivel consultar '$TaskName': $($_.Exception.Message)"
}
if ($null -eq $task) { Write-Host "Tarefa '$TaskName' nao esta instalada."; exit 3 }
try { $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop }
catch { throw "A tarefa '$TaskName' existe, mas nao foi possivel obter seu status: $($_.Exception.Message)" }
[pscustomobject]@{
    TaskName = $task.TaskName; State = $task.State; Enabled = $task.Settings.Enabled
    LastRunTime = $info.LastRunTime; LastTaskResult = ('0x{0:X8}' -f ([uint32]$info.LastTaskResult))
    NextRunTime = $info.NextRunTime; Action = $task.Actions.Execute; Arguments = $task.Actions.Arguments
} | Format-List
