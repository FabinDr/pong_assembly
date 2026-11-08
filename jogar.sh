#!/bin/sh
# Uso:  ./jogar.sh        -> jogo completo
#       ./jogar.sh 3      -> etapa 3 (de 1 a 5)
cd "$(dirname "$0")" || exit 1

PROG="PONG"
[ -n "$1" ] && PROG="ETAPA$1"

if [ ! -f "executaveis/$PROG.COM" ]; then
  echo "O arquivo executaveis/$PROG.COM nao foi encontrado."
  echo "Use ./jogar.sh sem numero (jogo completo) ou com um numero de 1 a 5."
  exit 1
fi

if command -v dosbox >/dev/null 2>&1; then
  DOSBOX=dosbox
elif [ -x "/Applications/DOSBox.app/Contents/MacOS/DOSBox" ]; then
  DOSBOX="/Applications/DOSBox.app/Contents/MacOS/DOSBox"
else
  echo "DOSBox nao encontrado. Instale com:"
  echo "  Ubuntu/Debian:  sudo apt install dosbox"
  echo "  macOS:          baixe em https://www.dosbox.com"
  exit 1
fi

"$DOSBOX" -conf dosbox.conf -c "mount c executaveis" -c "c:" -c "$PROG" -c "exit"
