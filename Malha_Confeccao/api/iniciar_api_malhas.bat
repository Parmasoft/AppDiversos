@echo off
setlocal EnableExtensions
chcp 65001 >nul
title PEDIDOS DE MALHAS - API LOCAL - PORTA 5056

cd /d "%~dp0"
if errorlevel 1 (
  echo.
  echo ERRO: nao foi possivel acessar a pasta da API.
  goto :erro
)

echo ========================================================
echo PEDIDOS DE MALHAS - API LOCAL
echo Pasta: %CD%
echo Endereco esperado: http://127.0.0.1:5056
echo ========================================================

if not exist ".env" (
  echo.
  echo ERRO: api\.env nao foi encontrado.
  echo Copie .env.example para .env e informe a configuracao local autorizada.
  goto :erro
)

set "PYTHON_EXE="
if exist "venv\Scripts\python.exe" set "PYTHON_EXE=venv\Scripts\python.exe"
if not defined PYTHON_EXE (
  py -3 -c "import sys" >nul 2>&1
  if not errorlevel 1 set "PYTHON_EXE=py -3"
)
if not defined PYTHON_EXE (
  python -c "import sys" >nul 2>&1
  if not errorlevel 1 set "PYTHON_EXE=python"
)
if not defined PYTHON_EXE (
  echo.
  echo ERRO: Python 3 nao foi localizado.
  goto :erro
)

%PYTHON_EXE% -c "import flask, fdb" >nul 2>&1
if errorlevel 1 (
  echo.
  echo ERRO: dependencias Flask e/ou fdb nao estao disponiveis no Python selecionado.
  echo Nenhuma dependencia foi instalada automaticamente.
  echo Crie api\venv e instale requirements.txt com autorizacao antes de iniciar.
  goto :erro
)

echo.
echo Iniciando API local. Pressione CTRL+C para encerrar normalmente.
echo O endpoint /health nao testa o Firebird.
echo.
%PYTHON_EXE% run.py
set "API_EXIT=%ERRORLEVEL%"
if not "%API_EXIT%"=="0" (
  echo.
  echo ERRO: a API foi encerrada com codigo %API_EXIT%.
  goto :erro
)

echo.
echo API encerrada.
pause
exit /b 0

:erro
echo.
pause
exit /b 1
