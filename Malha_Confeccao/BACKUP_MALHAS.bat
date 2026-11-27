@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem Backup restauravel do codigo-fonte Malhas/Confeccao.
rem Nao inclui segredos, bancos operacionais, ambientes virtuais ou artefatos.

set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"
set "WINRAR_EXE=%ProgramFiles%\WinRAR\WinRAR.exe"
set "RAR_EXE=%ProgramFiles%\WinRAR\Rar.exe"

if not exist "%WINRAR_EXE%" set "WINRAR_EXE=%ProgramFiles(x86)%\WinRAR\WinRAR.exe"
if not exist "%RAR_EXE%" set "RAR_EXE=%ProgramFiles(x86)%\WinRAR\Rar.exe"

if not exist "%WINRAR_EXE%" (
  echo ERRO: WinRAR.exe nao foi encontrado.
  exit /b 2
)
if not exist "%RAR_EXE%" (
  echo ERRO: Rar.exe nao foi encontrado junto ao WinRAR.
  exit /b 2
)

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "STAMP=%%I"
if not defined STAMP (
  echo ERRO: nao foi possivel gerar a data do backup.
  exit /b 2
)

set "ARCHIVE=%PROJECT_DIR%\Malha_Confeccao_%STAMP%.rar"
set "LOG=%PROJECT_DIR%\BACKUP_MALHAS_%STAMP%.log"
set "HASH_FILE=%ARCHIVE%.sha256"
set "STAGE=%TEMP%\Malha_Confeccao_backup_%STAMP%_%RANDOM%"

call :log "Inicio do backup. Origem: %PROJECT_DIR%"
call :log "Arquivo de destino: %ARCHIVE%"

if exist "%ARCHIVE%" (
  call :fail "O arquivo de destino ja existe; nenhuma substituicao foi feita."
  exit /b 3
)

mkdir "%STAGE%" >>"%LOG%" 2>&1
if errorlevel 1 (
  call :fail "Nao foi possivel criar a area temporaria."
  exit /b 3
)

rem /XJ impede seguir juncoes. /SL copia links como links; os remanescentes
rem sao removidos somente da area temporaria antes da compactacao.
robocopy "%PROJECT_DIR%" "%STAGE%" /E /XJ /SL /R:1 /W:1 /COPY:DAT /DCOPY:DAT /NFL /NDL /NJH /NJS /NP ^
  /XD build .dart_tool .venv .venv-wsl-tests venv __pycache__ .pytest_cache .idea .tools logs .gradle ^
  /XF *.rar *.rar.sha256 *.zip *.7z *.log *.tmp *.temp *.pyc *.env *.pfx *.p12 *.pem *.key *.keystore state.db state.db-lock state.db.lock .flutter-plugins-dependencies local.properties BACKUP_MALHAS_*.sha256 >>"%LOG%" 2>&1
set "ROBOCOPY_EXIT=%ERRORLEVEL%"
if %ROBOCOPY_EXIT% GEQ 8 (
  call :fail "Robocopy falhou com codigo %ROBOCOPY_EXIT%."
  call :cleanup
  exit /b %ROBOCOPY_EXIT%
)
call :log "Copia preparada com Robocopy (codigo %ROBOCOPY_EXIT%)."

powershell -NoProfile -Command "$stage=$env:STAGE; Get-ChildItem -LiteralPath $stage -Force -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint } | Remove-Item -Force -ErrorAction Stop" >>"%LOG%" 2>&1
if errorlevel 1 (
  call :fail "Nao foi possivel remover pontos de reanalise da area temporaria."
  call :cleanup
  exit /b 4
)

for %%F in ("pubspec.yaml" "pubspec.lock" "ApiMalhasNuvem\requirements.txt" "ApiMalhasNuvem\alembic.ini" "AgenteMalhas\requirements.txt" "BACKUP_MALHAS.bat") do (
  if not exist "%STAGE%\%%~F" (
    call :fail "Arquivo essencial ausente na copia preparada: %%~F"
    call :cleanup
    exit /b 5
  )
)

"%WINRAR_EXE%" a -r -ep1 -idq -y "%ARCHIVE%" "%STAGE%\*" >>"%LOG%" 2>&1
if errorlevel 1 (
  call :fail "WinRAR nao conseguiu criar o arquivo."
  call :cleanup
  exit /b 6
)

"%RAR_EXE%" t -idq "%ARCHIVE%" >>"%LOG%" 2>&1
if errorlevel 1 (
  call :fail "O teste de integridade do RAR falhou."
  call :cleanup
  exit /b 7
)

certutil -hashfile "%ARCHIVE%" SHA256 > "%HASH_FILE%"
if errorlevel 1 (
  call :fail "O RAR esta valido, mas a geracao do SHA-256 falhou."
  call :cleanup
  exit /b 8
)

for /f %%H in ('powershell -NoProfile -Command "(Get-FileHash -LiteralPath '%ARCHIVE%' -Algorithm SHA256).Hash"') do set "ARCHIVE_HASH=%%H"
if not defined ARCHIVE_HASH (
  call :fail "O RAR esta valido, mas nao foi possivel ler o SHA-256."
  call :cleanup
  exit /b 8
)
call :log "Integridade RAR aprovada. SHA-256: %ARCHIVE_HASH%"
call :cleanup
call :log "SUCESSO: backup criado e validado."
echo.
echo SUCESSO: %ARCHIVE%
echo SHA-256: %ARCHIVE_HASH%
echo Log: %LOG%
exit /b 0

:cleanup
if defined STAGE if exist "%STAGE%" rmdir /S /Q "%STAGE%" >>"%LOG%" 2>&1
exit /b 0

:log
echo [%date% %time%] %~1
>>"%LOG%" echo [%date% %time%] %~1
exit /b 0

:fail
call :log "ERRO: %~1"
echo.
echo ERRO: %~1
exit /b 0
