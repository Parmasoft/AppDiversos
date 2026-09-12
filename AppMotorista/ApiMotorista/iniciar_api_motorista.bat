@echo off
setlocal EnableExtensions
chcp 65001 >nul
title APP MOTORISTA - API - PORTA 5055

cd /d "E:\Jorginho\AppMotorista\ApiMotorista"
if errorlevel 1 (
  echo.
  echo ERRO: pasta da API nao encontrada.
  echo E:\Jorginho\AppMotorista\ApiMotorista
  goto :erro
)

echo ========================================================
echo APP MOTORISTA - API - PORTA 5055
echo Pasta: %CD%
echo ========================================================

if not exist "requirements.txt" (
  echo ERRO: requirements.txt nao foi encontrado.
  goto :erro
)

if not exist ".env" (
  echo ERRO: arquivo local .env nao foi encontrado.
  echo Crie a configuracao local antes de iniciar a API.
  goto :erro
)

for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
  if not "%%A"=="" set "%%A=%%B"
)

if not defined FB_DATABASE (
  echo ERRO: FB_DATABASE nao configurado no arquivo .env.
  goto :erro
)
if not defined FB_PASSWORD (
  echo ERRO: FB_PASSWORD nao configurado no arquivo .env.
  goto :erro
)

set "VENV_NOVO=0"
if not exist "venv\Scripts\python.exe" (
  echo.
  echo Criando o ambiente virtual local...
  call :criar_venv
  if errorlevel 1 (
    echo ERRO: nao foi possivel criar o ambiente virtual.
    goto :erro
  )
  set "VENV_NOVO=1"
)

call "venv\Scripts\activate.bat"
if errorlevel 1 (
  echo ERRO: nao foi possivel ativar o ambiente virtual.
  goto :erro
)

set "INSTALAR_REQUISITOS=%VENV_NOVO%"
if not exist "venv\.requirements_installed.txt" set "INSTALAR_REQUISITOS=1"
if exist "venv\.requirements_installed.txt" (
  fc /b "requirements.txt" "venv\.requirements_installed.txt" >nul 2>&1
  if errorlevel 1 set "INSTALAR_REQUISITOS=1"
)
python -m pip check >nul 2>&1
if errorlevel 1 set "INSTALAR_REQUISITOS=1"
python -c "import flask, werkzeug, fdb" >nul 2>&1
if errorlevel 1 set "INSTALAR_REQUISITOS=1"

if "%INSTALAR_REQUISITOS%"=="1" (
  echo.
  echo Instalando as dependencias necessarias...
  python -m pip install -r requirements.txt
  if errorlevel 1 (
    echo ERRO: falha ao instalar requirements.txt.
    goto :erro
  )
  copy /y "requirements.txt" "venv\.requirements_installed.txt" >nul
) else (
  echo Ambiente virtual e dependencias conferidos.
)

set "PYTHONUTF8=1"
if not defined APP_HOST set "APP_HOST=127.0.0.1"
if not defined APP_PORT set "APP_PORT=5055"

echo.
echo ========================================================
echo API iniciando em http://127.0.0.1:5055
echo Banco Firebird: %FB_DATABASE%
echo Porta 5055 pronta para uso com ADB reverse.
echo Para encerrar, pressione CTRL+C.
echo ========================================================
echo.

python run.py
set "API_EXIT=%ERRORLEVEL%"
if not "%API_EXIT%"=="0" (
  echo.
  echo ERRO: a API foi encerrada com codigo %API_EXIT%.
  pause
  exit /b %API_EXIT%
)

echo.
echo API encerrada.
pause
exit /b 0

:erro
echo.
echo A API nao foi iniciada. Corrija a mensagem acima e tente novamente.
pause
exit /b 1

:criar_venv
set "PY_LAUNCHER="
py -3.11-32 -c "import sys" >nul 2>&1
if not errorlevel 1 set "PY_LAUNCHER=py -3.11-32"
if not defined PY_LAUNCHER (
  py -3 -c "import sys" >nul 2>&1
  if not errorlevel 1 set "PY_LAUNCHER=py -3"
)
if not defined PY_LAUNCHER (
  python -c "import sys" >nul 2>&1
  if not errorlevel 1 set "PY_LAUNCHER=python"
)
if not defined PY_LAUNCHER (
  echo ERRO: Python 3 nao foi encontrado.
  exit /b 1
)
call %PY_LAUNCHER% -m venv venv
exit /b %ERRORLEVEL%
