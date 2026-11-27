@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INICIAR_AGENTE_MOTORISTA.ps1" -IntervalSeconds 30
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%EXIT_CODE%"=="0" echo A execucao terminou com erro. Veja a mensagem acima.
pause
exit /b %EXIT_CODE%
