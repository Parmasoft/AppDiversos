@echo off
setlocal
title Instalar inicializacao do Monitor Codex

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%MonitorCodex.ps1"

if not exist "%PS1%" (
    echo.
    echo ERRO: Nao encontrei:
    echo %PS1%
    echo.
    echo Coloque este arquivo na mesma pasta do MonitorCodex.ps1.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"$startup=[Environment]::GetFolderPath('Startup'); ^
$shortcutPath=Join-Path $startup 'Monitor Codex Parmasoft.lnk'; ^
$ws=New-Object -ComObject WScript.Shell; ^
$s=$ws.CreateShortcut($shortcutPath); ^
$s.TargetPath=$env:SystemRoot + '\System32\WindowsPowerShell\v1.0\powershell.exe'; ^
$s.Arguments='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%PS1%""'; ^
$s.WorkingDirectory='%SCRIPT_DIR%'; ^
$s.Description='Monitor local de limite do Codex - Parmasoft'; ^
$s.Save(); ^
Write-Host ''; ^
Write-Host 'OK - Inicializacao automatica configurada.'; ^
Write-Host ('Atalho criado em: ' + $shortcutPath)"

echo.
echo O Monitor Codex sera iniciado automaticamente quando voce entrar no Windows.
echo.
pause
endlocal
