@echo off
setlocal
cd /d "%~dp0"

rem Gera os executaveis (ETAPA1 a ETAPA5 e PONG) a partir de src\pong.asm.
rem Precisa do NASM instalado (https://www.nasm.us).

where nasm >nul 2>nul
if errorlevel 1 goto semnasm

if not exist executaveis mkdir executaveis
for %%E in (1 2 3 4 5) do nasm -f bin -dETAPA=%%E src\pong.asm -o executaveis\ETAPA%%E.COM
nasm -f bin src\pong.asm -o executaveis\PONG.COM
echo Executaveis gerados na pasta executaveis.
pause
exit /b 0

:semnasm
echo NASM nao encontrado. Instale em https://www.nasm.us e adicione ao PATH.
pause
exit /b 1
