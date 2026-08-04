@echo off
title Instalador API Scanner ParmaSoft
color 0A

echo ============================================
echo Instalando API Scanner ParmaSoft
echo ============================================
echo.

REM Garante que esta rodando como Administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERRO: Execute este BAT como Administrador.
    echo.
    pause
    exit /b
)

REM Vai para a pasta onde o BAT esta
cd /d "%~dp0"

echo Pasta atual:
cd
echo.

REM Verifica app.py
if not exist "app.py" (
    echo ERRO: app.py nao encontrado nesta pasta.
    echo Coloque este BAT na mesma pasta do app.py.
    echo.
    pause
    exit /b
)

REM Instala Python 3.11.9 se existir instalador na pasta
echo Verificando Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    if exist "python-3.11.9.exe" (
        echo Python nao encontrado. Instalando Python 3.11.9...
        python-3.11.9.exe /quiet InstallAllUsers=1 PrependPath=1 Include_pip=1 Include_launcher=1
        echo Aguardando instalacao do Python...
        timeout /t 20 /nobreak >nul
    ) else (
        echo ERRO: Python nao encontrado e python-3.11.9.exe nao esta na pasta.
        echo Instale o Python manualmente ou coloque o instalador aqui.
        echo.
        pause
        exit /b
    )
) else (
    python --version
)

echo.
echo Removendo venv anterior, se existir...
if exist "venv" (
    rmdir /s /q "venv"
)

echo.
echo Criando ambiente virtual...
python -m venv venv
if %errorlevel% neq 0 (
    echo ERRO ao criar venv.
    echo.
    pause
    exit /b
)

echo.
echo Atualizando pip...
call venv\Scripts\python.exe -m pip install --upgrade pip

echo.
echo Instalando pacotes...
call venv\Scripts\pip.exe install flask fdb pywin32 reportlab
if %errorlevel% neq 0 (
    echo ERRO ao instalar pacotes.
    echo.
    pause
    exit /b
)

echo.
echo Liberando porta 5001 no Firewall...
netsh advfirewall firewall add rule name="API Scanner ParmaSoft 5001" dir=in action=allow protocol=TCP localport=5001 >nul 2>&1

echo.
echo Criando iniciar_api.bat...
(
echo @echo off
echo title API Scanner ParmaSoft
echo color 0A
echo.
echo cd /d "%%~dp0"
echo.
echo echo ============================================
echo echo Iniciando API Scanner ParmaSoft
echo echo ============================================
echo echo.
echo echo Pasta atual:
echo cd
echo echo.
echo echo Verificando porta 5001...
echo netstat -ano ^| findstr ":5001"
echo echo.
echo echo Verificando Python do venv...
echo venv\Scripts\python.exe --version
echo echo.
echo echo Iniciando app.py...
echo venv\Scripts\python.exe app.py
echo echo.
echo echo API encerrada ou ocorreu erro.
echo pause
) > iniciar_api.bat

echo.
echo Criando atalho na inicializacao do Windows...
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "BAT_ATALHO=%STARTUP%\iniciar_api_scanner.bat"

(
echo @echo off
echo cd /d "%~dp0"
echo start "" "%~dp0iniciar_api.bat"
) > "%BAT_ATALHO%"

echo.
echo ============================================
echo Instalacao concluida.
echo ============================================
echo.
echo Para iniciar agora, rode:
echo iniciar_api.bat
echo.
echo Depois teste no navegador:
echo http://127.0.0.1:5001/produto?cod=7891035210006
echo.
pause