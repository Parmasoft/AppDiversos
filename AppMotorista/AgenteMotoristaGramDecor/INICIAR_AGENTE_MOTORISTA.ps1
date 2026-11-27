param(
    [ValidateRange(5, 3600)][int]$IntervalSeconds = 30,
    [switch]$SelfTest,
    [ValidateRange(0, 30)][int]$HoldLockSeconds = 0,
    [switch]$ReturnOnly,
    [string]$OperationGuid
)

$ErrorActionPreference = 'Stop'
$agentDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$python = Join-Path $agentDirectory '.venv\Scripts\python.exe'
$main = Join-Path $agentDirectory 'main.py'
$configurationDirectory = 'C:\Users\Jorge Parma\AppData\Local\Parmasoft\AgenteMotoristaGramDecor'
$configurationFiles = @((Join-Path $configurationDirectory 'agent-token.env'), (Join-Path $configurationDirectory 'agent-firebird.env'))
$logDirectory = Join-Path $agentDirectory 'logs'
$mutexName = 'Local\Parmasoft.AgenteMotoristaGramDecor.Manifestos'
$maxLogBytes = 5MB

function Import-ProtectedEnvironmentFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Arquivo de configuracao protegido nao encontrado: $Path" }
    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine.TrimStart()
        if (-not $line.Trim() -or $line.StartsWith('#') -or $line.StartsWith(';')) { continue }
        $separator = $line.IndexOf('=')
        if ($separator -le 0) { throw "Linha de configuracao invalida em $Path" }
        $name = $line.Substring(0, $separator).Trim()
        if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { throw "Nome de variavel invalido em $Path" }
        [Environment]::SetEnvironmentVariable($name, $line.Substring($separator + 1), 'Process')
    }
}

function Write-AgentLog {
    param([Parameter(Mandatory = $true)][string]$Message)
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $path = Join-Path $logDirectory ("agente-manifestos-{0:yyyyMMdd}.log" -f (Get-Date))
    if ((Test-Path -LiteralPath $path) -and (Get-Item -LiteralPath $path).Length -ge $maxLogBytes) {
        Move-Item -LiteralPath $path -Destination ("$path.{0:HHmmss}" -f (Get-Date))
    }
    ("{0:yyyy-MM-dd HH:mm:ss.fff zzz} {1}" -f (Get-Date), $Message) | Tee-Object -FilePath $path -Append
}

function Set-SafeAgentEnvironment {
    # Forced after protected files: normal operation is restricted to company 10.
    [Environment]::SetEnvironmentVariable('MOTORISTA_DELIVERY_RETURN_ENABLED', 'true', 'Process')
    [Environment]::SetEnvironmentVariable('MOTORISTA_DELIVERY_RETURN_OPERATION_GUID', $null, 'Process')
    # Company scope: new released manifests for company 10 are discovered every round.
    [Environment]::SetEnvironmentVariable('MOTORISTA_ALLOWED_SCOPES', '10', 'Process')
}

function Set-ControlledReturnEnvironment {
    if (-not $ReturnOnly -or [string]::IsNullOrWhiteSpace($OperationGuid)) {
        throw 'Modo return-only exige OperationGuid.'
    }
    $parsedGuid = [Guid]::Empty
    if (-not [Guid]::TryParse($OperationGuid, [ref]$parsedGuid)) {
        throw 'OperationGuid invalida para modo return-only.'
    }
    [Environment]::SetEnvironmentVariable('MOTORISTA_DELIVERY_RETURN_ENABLED', 'true', 'Process')
    [Environment]::SetEnvironmentVariable('MOTORISTA_DELIVERY_RETURN_OPERATION_GUID', $parsedGuid.ToString(), 'Process')
}

$mutex = New-Object System.Threading.Mutex($false, $mutexName)
$hasMutex = $false
try {
    try { $hasMutex = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $hasMutex = $true }
    if (-not $hasMutex) { Write-Host 'O Agente Motorista ja esta em execucao. Nenhuma nova instancia foi iniciada.' -ForegroundColor Yellow; exit 2 }
    if ($SelfTest) {
        Set-SafeAgentEnvironment
        if ($ReturnOnly) { Set-ControlledReturnEnvironment }
        Write-AgentLog "SELFTEST OK lock=$mutexName return=$env:MOTORISTA_DELIVERY_RETURN_ENABLED scopes=$env:MOTORISTA_ALLOWED_SCOPES returnOnly=$ReturnOnly"
        if ($HoldLockSeconds -gt 0) { Start-Sleep -Seconds $HoldLockSeconds }
        exit 0
    }
    if (-not (Test-Path -LiteralPath $python -PathType Leaf)) { throw "Python do Agente nao encontrado: $python" }
    if (-not (Test-Path -LiteralPath $main -PathType Leaf)) { throw "main.py do Agente nao encontrado: $main" }
    foreach ($configurationFile in $configurationFiles) { Import-ProtectedEnvironmentFile -Path $configurationFile }
    Set-SafeAgentEnvironment
    if ($ReturnOnly) {
        Set-ControlledReturnEnvironment
        Write-AgentLog "RETURN-ONLY start operation=$env:MOTORISTA_DELIVERY_RETURN_OPERATION_GUID scopes=$env:MOTORISTA_ALLOWED_SCOPES"
        Push-Location -LiteralPath $agentDirectory
        try {
            & $python $main --return-only --operation-guid $env:MOTORISTA_DELIVERY_RETURN_OPERATION_GUID 2>&1 | ForEach-Object { Write-AgentLog "RETURN-ONLY $_" }
            exit $LASTEXITCODE
        }
        finally { Pop-Location }
    }
    Write-AgentLog "START interval=${IntervalSeconds}s scopes=$env:MOTORISTA_ALLOWED_SCOPES return=$env:MOTORISTA_DELIVERY_RETURN_ENABLED"
    Push-Location -LiteralPath $agentDirectory
    try {
        while ($true) {
            Write-AgentLog 'RUN start'
            & $python $main 2>&1 | ForEach-Object { Write-AgentLog "RUN $_" }
            $exitCode = $LASTEXITCODE
            if ($exitCode -eq 0) { Write-AgentLog 'RUN complete exit=0' } else { Write-AgentLog "RUN error exit=$exitCode" }
            Write-AgentLog "WAIT seconds=$IntervalSeconds (Ctrl+C para encerrar)"
            Start-Sleep -Seconds $IntervalSeconds
        }
    }
    finally { Pop-Location }
}
catch {
    try { Write-AgentLog "FATAL $($_.Exception.Message)" } catch { }
    Write-Error $_
    exit 1
}
finally {
    if ($hasMutex) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
