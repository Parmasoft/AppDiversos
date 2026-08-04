@echo off
title API Padaria ParmaSoft (VENV + RUN)

REM ===== Vai para a pasta da API =====
cd /d C:\Projetos Flutter\Padaria\api

IF ERRORLEVEL 1 (
  echo Erro: diretorio nao encontrado: C:\Projetos Flutter\Padaria\api
  pause
  exit /b 1
)

REM ===== UTF-8 para acentos =====
chcp 65001 >nul

REM ===== Cria o venv se nao existir =====
IF NOT EXIST "venv\Scripts\python.exe" (
  echo =========================================
  echo Criando ambiente virtual Python 3.11 32 bits...
  echo =========================================
  py -3.11-32 -m venv venv

  IF ERRORLEVEL 1 (
    echo Erro ao criar o ambiente virtual.
    pause
    exit /b 1
  )

  echo =========================================
  echo Instalando dependencias...
  echo =========================================
  call venv\Scripts\activate
  python -m pip install --upgrade pip
  python -m pip install flask fdb

  IF ERRORLEVEL 1 (
    echo Erro ao instalar dependencias.
    pause
    exit /b 1
  )
) ELSE (
  echo =========================================
  echo VENV ja existe. Ativando...
  echo =========================================
  call venv\Scripts\activate
)

REM ===== Sobe a API =====
echo =========================================
echo Iniciando API (app.py)...
echo =========================================
python app.py

REM ===== Mantem a janela aberta (pra ver erros) =====
pause
