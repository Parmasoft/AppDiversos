@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title APP MOTORISTA - CELULAR ANDROID USB

cd /d "E:\Jorginho\AppMotorista\AppMotorista"
if errorlevel 1 (
  echo.
  echo ERRO: pasta do App Flutter nao encontrada.
  echo E:\Jorginho\AppMotorista\AppMotorista
  goto :erro
)

where adb >nul 2>&1
if errorlevel 1 (
  if defined ANDROID_SDK_ROOT (
    if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" (
      set "PATH=%ANDROID_SDK_ROOT%\platform-tools;%PATH%"
    )
  )
)
where adb >nul 2>&1
if errorlevel 1 (
  if defined ANDROID_HOME (
    if exist "%ANDROID_HOME%\platform-tools\adb.exe" (
      set "PATH=%ANDROID_HOME%\platform-tools;%PATH%"
    )
  )
)
where adb >nul 2>&1
if errorlevel 1 (
  echo.
  echo ERRO: ADB nao foi encontrado.
  echo Instale/configure o Android SDK Platform-Tools e tente novamente.
  goto :erro
)

where flutter >nul 2>&1
if errorlevel 1 (
  echo.
  echo ERRO: Flutter nao foi encontrado no PATH.
  goto :erro
)

echo ========================================================
echo APP MOTORISTA - CELULAR ANDROID FISICO VIA USB
echo ========================================================
echo.
echo Dispositivos vistos pelo ADB:
adb devices -l
echo.

set /a "PHYSICAL_COUNT=0"
set "DEVICE_SERIAL="
for /f "skip=1 tokens=1,2" %%A in ('adb devices') do (
  set "CANDIDATE_SERIAL=%%A"
  set "CANDIDATE_STATE=%%B"
  if /i "!CANDIDATE_STATE!"=="device" (
    if /i not "!CANDIDATE_SERIAL:~0,9!"=="emulator-" (
      set /a "PHYSICAL_COUNT+=1"
      set "DEVICE_SERIAL=!CANDIDATE_SERIAL!"
    )
  )
)

if "%PHYSICAL_COUNT%"=="0" (
  echo Nenhum aparelho Android fisico e autorizado foi encontrado.
  echo.
  echo Verifique:
  echo - cabo USB conectado;
  echo - Depuracao USB ativada no aparelho;
  echo - autorizacao deste computador confirmada na tela do celular.
  goto :erro
)

if not "%PHYSICAL_COUNT%"=="1" (
  echo Foram encontrados %PHYSICAL_COUNT% aparelhos Android fisicos.
  echo Mantenha somente o aparelho de teste conectado e execute novamente.
  goto :erro
)

echo Aparelho selecionado automaticamente: %DEVICE_SERIAL%
echo.
echo Configurando ADB reverse da porta 5055...
adb -s "%DEVICE_SERIAL%" reverse tcp:5055 tcp:5055
if errorlevel 1 (
  echo ERRO: nao foi possivel configurar adb reverse na porta 5055.
  goto :erro
)

echo.
echo A API do aparelho sera acessada por http://127.0.0.1:5055
echo Iniciando o Flutter somente no aparelho fisico selecionado...
echo.

flutter run -d "%DEVICE_SERIAL%" --dart-define=API_BASE_URL=http://127.0.0.1:5055
set "FLUTTER_EXIT=%ERRORLEVEL%"
if not "%FLUTTER_EXIT%"=="0" (
  echo.
  echo ERRO: Flutter foi encerrado com codigo %FLUTTER_EXIT%.
  pause
  exit /b %FLUTTER_EXIT%
)

echo.
echo App encerrado.
pause
exit /b 0

:erro
echo.
echo O App nao foi iniciado.
pause
exit /b 1
