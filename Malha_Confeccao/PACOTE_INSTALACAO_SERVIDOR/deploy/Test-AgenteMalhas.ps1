[CmdletBinding()]
param([string]$EnvironmentFile = 'C:\ProgramData\ParmaSoft\AgenteMalhas\agente-malhas.env', [switch]$SkipApiAuthProbe)
$ErrorActionPreference = 'Stop'
$agentRoot = Split-Path -Parent $PSScriptRoot; $python = Join-Path $agentRoot 'venv\Scripts\python.exe'
$firebirdClientDirectory = 'C:\Program Files\Firebird\Firebird_2_5\WOW64'
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
    Write-Host "Cliente Firebird x86 validado e adicionado ao PATH do processo: $firebirdClientDirectory"
}
$required = @('main.py','requirements.txt','agent\__init__.py','agent\config.py','agent\http_client.py','agent\instance_lock.py','agent\read_source.py','agent\receive_orders.py','agent\state.py','agent\sync.py','agent\diagnostics.py')
foreach ($relative in $required) { if (!(Test-Path -LiteralPath (Join-Path $agentRoot $relative) -PathType Leaf)) { throw "Pacote incompleto: arquivo obrigatorio ausente: $relative. Copie a pasta agent completa do pacote de instalacao." } }
if (!(Test-Path -LiteralPath $python)) { throw 'Virtualenv ausente. Execute primeiro Install-AgenteMalhas.ps1.' }
if (!(Test-Path -LiteralPath $EnvironmentFile)) { throw "Arquivo de ambiente ausente: $EnvironmentFile" }
Add-FirebirdClientToProcessPath
$allowed = @('MALHAS_AGENT_API_URL','MALHAS_AGENT_TOKEN','MALHAS_AGENT_EMPRESA_ID','MALHAS_AGENT_EMPRESA_NOME','FB_HOST','FB_PORT','FB_DATABASE','FB_USER','FB_PASSWORD','FB_CHARSET','MALHAS_AGENT_STATE_PATH','MALHAS_AGENT_LOG_PATH','MALHAS_AGENT_LOG_MAX_BYTES','MALHAS_AGENT_LOG_BACKUP_COUNT','MALHAS_AGENT_STOP_FILE','MALHAS_AGENT_RETRY_SECONDS','MALHAS_AGENT_ALLOW_INSECURE_LOCAL_TESTS')
foreach ($line in Get-Content -LiteralPath $EnvironmentFile -Encoding UTF8) { $v=$line.Trim(); if (!$v -or $v.StartsWith('#')) { continue }; $pair=$v -split '=',2; if ($pair.Count -ne 2 -or $pair[0] -notin $allowed) { throw 'Arquivo de ambiente contem chave invalida.' }; [Environment]::SetEnvironmentVariable($pair[0],$pair[1],'Process') }
Push-Location -LiteralPath $agentRoot
try {
    & $python -c "import agent, agent.config, agent.diagnostics, fdb; print('Estrutura e imports do pacote: OK')"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if ($SkipApiAuthProbe) { & $python -m agent.diagnostics }
    else { & $python -m agent.diagnostics --api-auth-probe }
    exit $LASTEXITCODE
} finally { Pop-Location }
