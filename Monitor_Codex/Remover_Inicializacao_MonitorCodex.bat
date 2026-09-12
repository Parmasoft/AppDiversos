@echo off
setlocal
title Remover inicializacao do Monitor Codex

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"$startup=[Environment]::GetFolderPath('Startup'); ^
$shortcutPath=Join-Path $startup 'Monitor Codex Parmasoft.lnk'; ^
if (Test-Path $shortcutPath) { ^
    Remove-Item $shortcutPath -Force; ^
    Write-Host ''; ^
    Write-Host 'OK - Inicializacao automatica removida.'; ^
} else { ^
    Write-Host ''; ^
    Write-Host 'O atalho de inicializacao nao estava presente.'; ^
}"

echo.
pause
endlocal
