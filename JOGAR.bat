@echo off
setlocal
cd /d "%~dp0"

rem Uso:  JOGAR.bat        -> jogo completo
rem       JOGAR.bat 3      -> etapa 3 (de 1 a 5)

set "PROG=PONG"
if not "%~1"=="" set "PROG=ETAPA%~1"

if not exist "executaveis\%PROG%.COM" goto semprograma

set "DOSBOX="
set "PF86=%ProgramFiles(x86)%"
where dosbox >nul 2>nul && set "DOSBOX=dosbox"
if not defined DOSBOX if exist "%PF86%\DOSBox-0.74-3\DOSBox.exe" set "DOSBOX=%PF86%\DOSBox-0.74-3\DOSBox.exe"
if not defined DOSBOX if exist "%ProgramFiles%\DOSBox-0.74-3\DOSBox.exe" set "DOSBOX=%ProgramFiles%\DOSBox-0.74-3\DOSBox.exe"
if not defined DOSBOX if exist "%PF86%\DOSBox\DOSBox.exe" set "DOSBOX=%PF86%\DOSBox\DOSBox.exe"
if not defined DOSBOX if exist "%ProgramFiles%\DOSBox Staging\dosbox.exe" set "DOSBOX=%ProgramFiles%\DOSBox Staging\dosbox.exe"
if not defined DOSBOX if exist "%ProgramFiles%\DOSBox-X\dosbox-x.exe" set "DOSBOX=%ProgramFiles%\DOSBox-X\dosbox-x.exe"
if not defined DOSBOX goto semdosbox

"%DOSBOX%" -conf dosbox.conf -c "mount c executaveis" -c "c:" -c "%PROG%" -c "exit"
exit /b 0

:semprograma
echo O arquivo executaveis\%PROG%.COM nao foi encontrado.
echo Use JOGAR.bat sem numero (jogo completo) ou com um numero de 1 a 5.
pause
exit /b 1

:semdosbox
echo DOSBox nao encontrado neste computador.
echo Instale o DOSBox (https://www.dosbox.com) e execute este arquivo de novo.
start https://www.dosbox.com/download.php?main=1
pause
exit /b 1
