#!/bin/sh
# Gera os executaveis (ETAPA1 a ETAPA5 e PONG) a partir de src/pong.asm.
# Precisa do NASM:  sudo apt install nasm   (Linux)  |  brew install nasm  (macOS)
cd "$(dirname "$0")" || exit 1
command -v nasm >/dev/null 2>&1 || { echo "NASM nao encontrado."; exit 1; }
mkdir -p executaveis
for e in 1 2 3 4 5; do
  nasm -f bin -dETAPA=$e src/pong.asm -o executaveis/ETAPA$e.COM || exit 1
done
nasm -f bin src/pong.asm -o executaveis/PONG.COM || exit 1
echo "Executaveis gerados na pasta executaveis."
