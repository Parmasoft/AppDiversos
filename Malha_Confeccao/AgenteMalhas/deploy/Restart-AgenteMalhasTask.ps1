[CmdletBinding()]
param(
    [string]$TaskName = 'ParmaSoft - Agente Malhas',
    [string]$EnvironmentFile = 'C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env',
    [int]$TimeoutSeconds = 90
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $EnvironmentFile -PathType Leaf)) { throw 'Arquivo protegido de ambiente nao encontrado.' }
$stopFile = $null
foreach ($line in Get-Content -LiteralPath $EnvironmentFile -Encoding UTF8) {
    $trimmed = $line.Trim()
    if ($trimmed -match '^MALHAS_AGENT_STOP_FILE=(.*)$') { $stopFile = $Matches[1].Trim(); break }
}
if (-not $stopFile) { $stopFile = 'C:\ProgramData\ParmaSoft\AgenteMalhas\stop.request' }
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
if ($task.State -ne 'Running') { throw "A tarefa nao esta em execucao (estado: $($task.State)). Nenhum marcador de parada foi criado para evitar interromper uma instancia manual." }
New-Item -ItemType File -Path $stopFile -Force | Out-Null
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
try {
    do { Start-Sleep -Seconds 2; $task = Get-ScheduledTask -TaskName $TaskName } while ($task.State -eq 'Running' -and (Get-Date) -lt $deadline)
    if ($task.State -eq 'Running') { throw 'Tempo esgotado aguardando a parada controlada; a tarefa nao foi finalizada a forca.' }
} finally { Remove-Item -LiteralPath $stopFile -Force -ErrorAction SilentlyContinue }
Start-ScheduledTask -TaskName $TaskName
Write-Host "Reinicio solicitado para '$TaskName'. Consulte o status e os logs para confirmar."
