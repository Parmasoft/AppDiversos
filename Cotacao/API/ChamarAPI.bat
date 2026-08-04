@echo off
echo =========================================
echo  API COTACAO - FIREBIRD 2.5
echo =========================================
echo.

REM Ajuste este caminho para a pasta da API

REM aqui quando estou na roça:
REM cd /d C:\Projetos Flutter\Cotacao\API

REM aqui quando estou no escritório:
cd /d E:\Jorginho\Cotacao\API

REM Ativa o ambiente virtual
call venv\Scripts\activate

REM Sobe a API
python app.py

pause

