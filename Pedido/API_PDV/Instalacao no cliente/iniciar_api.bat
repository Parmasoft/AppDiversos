@echo off
title API Padaria ParmaSoft - Instalar e Rodar
chcp 65001 >nul
color 0A

REM ===== ABRE MINIMIZADO =====
if /I not "%1"=="min" (
    start /min cmd /c "%~f0" min
    exit /b
)

set "BASE_DIR=C:\ParmaSoft\Scanner"

echo =========================================
echo   API PADARIA PARMASOFT
echo   INSTALAR + CONFIGURAR + RODAR
echo =========================================
echo.

REM ===== VAI PARA A PASTA =====
cd /d "%BASE_DIR%"
if errorlevel 1 (
    echo ERRO: diretorio nao encontrado:
    echo %BASE_DIR%
    echo.
    echo Copie a pasta da API para esse caminho antes de executar.
    pause
    exit /b 1
)

REM ===== CONFERE ARQUIVOS =====
if not exist "app.py" (
    echo ERRO: arquivo app.py nao encontrado em:
    echo %BASE_DIR%
    pause
    exit /b 1
)

REM ===== CRIA requirements.txt SE NAO EXISTIR =====
if not exist "requirements.txt" (
    echo Criando requirements.txt...
    > requirements.txt echo flask
    >> requirements.txt echo fdb
    >> requirements.txt echo waitress
)

REM ===== VERIFICA PYTHON 3.11 32 BITS =====
echo Verificando Python 3.11 32 bits...
py -3.11-32 --version >nul 2>nul
if errorlevel 1 (
    echo.
    echo [ERRO] Python 3.11 32 bits nao encontrado.
    echo.
    echo Instale o Python 3.11 32 bits e marque:
    echo [x] Add Python to PATH
    echo.
    echo Depois execute este BAT novamente.
    echo.
    pause
    exit /b 1
)

REM ===== CRIA VENV SE NAO EXISTIR =====
if not exist "venv\Scripts\python.exe" (
    echo =========================================
    echo Criando ambiente virtual...
    echo =========================================
    py -3.11-32 -m venv venv

    if errorlevel 1 (
        echo ERRO ao criar o ambiente virtual.
        pause
        exit /b 1
    )
) else (
    echo =========================================
    echo VENV ja existe.
    echo =========================================
)

REM ===== ATIVA VENV =====
echo =========================================
echo Ativando ambiente virtual...
echo =========================================
call venv\Scripts\activate
if errorlevel 1 (
    echo ERRO ao ativar o ambiente virtual.
    pause
    exit /b 1
)

REM ===== INSTALA / ATUALIZA DEPENDENCIAS =====
echo =========================================
echo Atualizando pip...
echo =========================================
python -m pip install --upgrade pip

if errorlevel 1 (
    echo ERRO ao atualizar o pip.
    pause
    exit /b 1
)

echo =========================================
echo Instalando dependencias...
echo =========================================
python -m pip install -r requirements.txt

if errorlevel 1 (
    echo ERRO ao instalar dependencias.
    pause
    exit /b 1
)

REM ===== TESTA IMPORTS =====
echo =========================================
echo Testando bibliotecas...
echo =========================================
python -c "import flask; print('Flask OK')"
if errorlevel 1 (
    echo ERRO no Flask.
    pause
    exit /b 1
)

python -c "import fdb; print('FDB OK')"
if errorlevel 1 (
    echo ERRO no FDB.
    pause
    exit /b 1
)

python -c "import waitress; print('Waitress OK')"
if errorlevel 1 (
    echo ERRO no Waitress.
    pause
    exit /b 1
)

echo =========================================
echo Iniciando API...
echo =========================================
python app.py

pause