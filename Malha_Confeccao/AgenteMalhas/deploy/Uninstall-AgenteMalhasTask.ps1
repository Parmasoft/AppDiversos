[CmdletBinding(SupportsShouldProcess)]
param([string]$TaskName = 'ParmaSoft - Agente Malhas')
$ErrorActionPreference = 'Stop'
if (-not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) { Write-Host "Tarefa '$TaskName' nao esta instalada. Nenhum dado foi alterado."; exit 0 }
if ($PSCmdlet.ShouldProcess("tarefa agendada '$TaskName'", 'Remover configuracao de inicializacao automatica')) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host 'Tarefa removida. Credenciais, logs, state.db e demais dados foram preservados.'
}
