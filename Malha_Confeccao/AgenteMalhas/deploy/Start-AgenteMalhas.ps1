[CmdletBinding()]
param(
    [string]$EnvironmentFile = 'C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env',
    [switch]$Once
)

$ErrorActionPreference = 'Stop'
$agentRoot = Split-Path -Parent $PSScriptRoot
$python = Join-Path $agentRoot 'venv\Scripts\python.exe'
$main = Join-Path $agentRoot 'main.py'
$bootstrapLog = 'C:\ProgramData\ParmaSoft\AgenteMalhas\logs\agente-malhas-bootstrap.log'

function Write-BootstrapLog {
    param([string]$Message)
    try {
        $directory = Split-Path -Parent $bootstrapLog
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        Add-Content -LiteralPath $bootstrapLog -Encoding UTF8 -Value ("{0:u} {1}" -f (Get-Date), $Message)
    } catch {
        # The agent log will contain runtime errors once its configuration is loaded.
    }
}

try {
    Set-Location -LiteralPath $agentRoot
    Write-BootstrapLog 'Inicializacao solicitada.'
    if (-not (Test-Path -LiteralPath $python -PathType Leaf)) { throw "Python do Agente nao encontrado: $python" }
    if (-not (Test-Path -LiteralPath $main -PathType Leaf)) { throw "main.py do Agente nao encontrado: $main" }
    if (-not (Test-Path -LiteralPath $EnvironmentFile -PathType Leaf)) { throw 'Arquivo protegido de ambiente nao encontrado.' }
$allowed = @(
    'MALHAS_AGENT_API_URL','MALHAS_AGENT_TOKEN','MALHAS_AGENT_EMPRESA_ID',
    'MALHAS_AGENT_EMPRESA_NOME','FB_HOST','FB_PORT','FB_DATABASE','FB_USER',
    'FB_PASSWORD','FB_CHARSET','MALHAS_AGENT_STATE_PATH','MALHAS_AGENT_LOG_PATH',
    'MALHAS_AGENT_LOG_MAX_BYTES','MALHAS_AGENT_LOG_BACKUP_COUNT',
    'MALHAS_AGENT_STOP_FILE','MALHAS_AGENT_RETRY_SECONDS',
    'MALHAS_AGENT_ALLOW_INSECURE_LOCAL_TESTS'
)

    foreach ($line in Get-Content -LiteralPath $EnvironmentFile -Encoding UTF8) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $pair = $trimmed -split '=', 2
        if ($pair.Count -ne 2 -or $pair[0] -notin $allowed) { throw 'Arquivo de ambiente contem chave invalida.' }
        [Environment]::SetEnvironmentVariable($pair[0], $pair[1], 'Process')
    }

    if ($Once) { & $python $main --once }
    else { & $python $main }
    $exitCode = $LASTEXITCODE
    Write-BootstrapLog "Processo do Agente finalizado com codigo $exitCode."
    exit $exitCode
} catch {
    Write-BootstrapLog ("Falha antes da inicializacao do Agente: " + $_.Exception.Message)
    Write-Error $_
    exit 1
}
