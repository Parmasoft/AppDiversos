[CmdletBinding()]
param([string]$EnvironmentFile = 'C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env', [switch]$Once)
$ErrorActionPreference = 'Stop'
$agentRoot = Split-Path -Parent $PSScriptRoot
$python = Join-Path $agentRoot 'venv\Scripts\python.exe'
$main = Join-Path $agentRoot 'main.py'
$agentPackage = Join-Path $agentRoot 'agent'
$bootstrapLog = 'C:\ProgramData\ParmaSoft\AgenteMalhas\logs\agente-malhas-bootstrap.log'
 $firebirdClientDirectory = 'C:\Program Files\Firebird\Firebird_2_5\WOW64'
function Write-BootstrapLog([string]$Message) {
    try { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $bootstrapLog) | Out-Null; Add-Content -LiteralPath $bootstrapLog -Encoding UTF8 -Value ("{0:u} {1}" -f (Get-Date), $Message) } catch {}
}
function Add-FirebirdClientToProcessPath {
    $fbclient = Join-Path $firebirdClientDirectory 'fbclient.dll'
    if (!(Test-Path -LiteralPath $fbclient -PathType Leaf)) { throw "fbclient.dll nao encontrada em: $fbclient" }
    $stream = $null
    try {
        $stream = [System.IO.File]::Open($fbclient, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        $dos = New-Object byte[] 64
        if ($stream.Read($dos, 0, $dos.Length) -ne $dos.Length -or $dos[0] -ne 0x4D -or $dos[1] -ne 0x5A) { throw 'fbclient.dll nao possui cabecalho PE valido.' }
        $peOffset = [System.BitConverter]::ToInt32($dos, 0x3C)
        if ($peOffset -lt 64 -or $peOffset -gt 1048576) { throw 'fbclient.dll possui deslocamento PE invalido.' }
        $stream.Position = $peOffset
        $pe = New-Object byte[] 6
        if ($stream.Read($pe, 0, $pe.Length) -ne $pe.Length -or $pe[0] -ne 0x50 -or $pe[1] -ne 0x45 -or $pe[2] -ne 0 -or $pe[3] -ne 0) { throw 'fbclient.dll nao possui assinatura PE valida.' }
        if ([System.BitConverter]::ToUInt16($pe, 4) -ne 0x014C) { throw 'fbclient.dll nao e x86/32 bits; o Python do Agente exige cliente Firebird 32 bits.' }
    } finally { if ($stream) { $stream.Dispose() } }
    $parts = @($env:Path -split ';' | Where-Object { $_ })
    if ($parts -notcontains $firebirdClientDirectory) { $env:Path = $firebirdClientDirectory + ';' + $env:Path }
    Write-BootstrapLog "Cliente Firebird x86 validado e adicionado ao PATH do processo: $firebirdClientDirectory"
}
try {
    Set-Location -LiteralPath $agentRoot
    if (!(Test-Path -LiteralPath $python -PathType Leaf)) { throw "Python do Agente nao encontrado: $python" }
    if (!(Test-Path -LiteralPath $main -PathType Leaf)) { throw "main.py nao encontrado: $main" }
    foreach ($module in @('__init__.py','config.py','http_client.py','instance_lock.py','read_source.py','receive_orders.py','state.py','sync.py')) { if (!(Test-Path -LiteralPath (Join-Path $agentPackage $module) -PathType Leaf)) { throw "Pacote incompleto: agent\\$module ausente. A tarefa nao sera iniciada." } }
    if (!(Test-Path -LiteralPath $EnvironmentFile -PathType Leaf)) { throw 'Arquivo protegido de ambiente nao encontrado.' }
    Add-FirebirdClientToProcessPath
    $allowed = @('MALHAS_AGENT_API_URL','MALHAS_AGENT_TOKEN','MALHAS_AGENT_EMPRESA_ID','MALHAS_AGENT_EMPRESA_NOME','FB_HOST','FB_PORT','FB_DATABASE','FB_USER','FB_PASSWORD','FB_CHARSET','MALHAS_AGENT_STATE_PATH','MALHAS_AGENT_LOG_PATH','MALHAS_AGENT_LOG_MAX_BYTES','MALHAS_AGENT_LOG_BACKUP_COUNT','MALHAS_AGENT_STOP_FILE','MALHAS_AGENT_RETRY_SECONDS','MALHAS_AGENT_ALLOW_INSECURE_LOCAL_TESTS')
    foreach ($line in Get-Content -LiteralPath $EnvironmentFile -Encoding UTF8) {
        $value = $line.Trim(); if (!$value -or $value.StartsWith('#')) { continue }
        $pair = $value -split '=', 2
        if ($pair.Count -ne 2 -or $pair[0] -notin $allowed) { throw 'Arquivo de ambiente contem chave invalida.' }
        [Environment]::SetEnvironmentVariable($pair[0], $pair[1], 'Process')
    }
    Write-BootstrapLog 'Inicializacao solicitada.'
    if ($Once) { & $python $main --once } else { & $python $main }
    $exitCode = $LASTEXITCODE; Write-BootstrapLog "Processo finalizado com codigo $exitCode."; exit $exitCode
} catch { Write-BootstrapLog ("Falha antes da inicializacao: " + $_.Exception.Message); Write-Error $_; exit 1 }
