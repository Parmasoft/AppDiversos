@echo off
setlocal EnableExtensions

title Copiar BarCode e AppMotorista - Parmasoft

echo ============================================================
echo   COPIA COMPACTA - BARCODE + APP MOTORISTA
echo ============================================================
echo.
echo Origem:
echo   E:\Jorginho\BarCode
echo   E:\Jorginho\AppMotorista
echo.
echo Este BAT copia os fontes e arquivos importantes,
echo ignorando pastas geradas/cache que deixam os projetos enormes.
echo.

set "SRC_BARCODE=E:\Jorginho\BarCode"
set "SRC_MOTORISTA=E:\Jorginho\AppMotorista"

if not exist "%SRC_BARCODE%\" (
    echo ERRO: Pasta nao encontrada:
    echo %SRC_BARCODE%
    pause
    exit /b 1
)

if not exist "%SRC_MOTORISTA%\" (
    echo ERRO: Pasta nao encontrada:
    echo %SRC_MOTORISTA%
    pause
    exit /b 1
)

set /p "DEST=Digite a pasta de destino ^(ex.: D:\Atualizacao_Notebook ou G:\Atualizacao_Notebook^): "

if "%DEST%"=="" (
    echo.
    echo Destino nao informado. Operacao cancelada.
    pause
    exit /b 1
)

if not exist "%DEST%\" mkdir "%DEST%" >nul 2>&1

echo.
echo ============================================================
echo Copiando BARCODE...
echo ============================================================

robocopy "%SRC_BARCODE%" "%DEST%\BarCode" /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ ^
 /XD ^
 "build" ^
 ".dart_tool" ^
 ".gradle" ^
 "Pods" ^
 "node_modules" ^
 "__pycache__" ^
 ".pytest_cache" ^
 ".mypy_cache" ^
 ".venv" ^
 "venv" ^
 "env" ^
 ".git" ^
 ".idea" ^
 ".vscode" ^
 /XF ^
 "*.pyc" ^
 "*.pyo" ^
 "*.class" ^
 "*.apk" ^
 "*.aab" ^
 "*.ipa" ^
 "*.log" ^
 "*.tmp"

set "RC_BARCODE=%ERRORLEVEL%"

echo.
echo ============================================================
echo Copiando APP MOTORISTA...
echo ============================================================

robocopy "%SRC_MOTORISTA%" "%DEST%\AppMotorista" /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ ^
 /XD ^
 "build" ^
 ".dart_tool" ^
 ".gradle" ^
 "Pods" ^
 "node_modules" ^
 "__pycache__" ^
 ".pytest_cache" ^
 ".mypy_cache" ^
 ".venv" ^
 "venv" ^
 "env" ^
 ".git" ^
 ".idea" ^
 ".vscode" ^
 /XF ^
 "*.pyc" ^
 "*.pyo" ^
 "*.class" ^
 "*.apk" ^
 "*.aab" ^
 "*.ipa" ^
 "*.log" ^
 "*.tmp"

set "RC_MOTORISTA=%ERRORLEVEL%"

echo.
echo ============================================================
echo RESULTADO
echo ============================================================
echo.

if %RC_BARCODE% LEQ 7 (
    echo BarCode.....: OK
) else (
    echo BarCode.....: ERRO Robocopy %RC_BARCODE%
)

if %RC_MOTORISTA% LEQ 7 (
    echo AppMotorista: OK
) else (
    echo AppMotorista: ERRO Robocopy %RC_MOTORISTA%
)

echo.
echo Destino:
echo   %DEST%
echo.
echo IMPORTANTE:
echo No notebook, as pastas ignoradas serao recriadas pelas ferramentas.
echo Para projetos Flutter, execute "flutter pub get" antes de compilar.
echo.
echo Pastas como .codex-work e Documentacao NAO sao excluidas.
echo Assim, checkpoints e STATUS seguem junto com a copia.
echo.
pause

endlocal
