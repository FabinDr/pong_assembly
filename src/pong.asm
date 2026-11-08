; =====================================================================
;  PONG em Assembly x86 (16 bits, modo real)  -  Arquitetura de
;  Computadores (UFMA / BICT)
;
;  O mesmo arquivo gera todas as etapas do projeto. Escolha a etapa
;  na hora de montar:
;
;     nasm -f bin -dETAPA=1 pong.asm -o pong.com     (tela e raquetes)
;     nasm -f bin -dETAPA=2 pong.asm -o pong.com     (+ teclado)
;     nasm -f bin -dETAPA=3 pong.asm -o pong.com     (+ bola e paredes)
;     nasm -f bin -dETAPA=4 pong.asm -o pong.com     (+ rebatida nas raquetes)
;     nasm -f bin -dETAPA=5 pong.asm -o pong.com     (+ placar e vitoria)
;     nasm -f bin pong.asm -o pong.com               (etapa 6: jogo completo)
;
;  Cada bloco  %if ETAPA >= N ... %endif  so entra a partir da etapa N.
;
;  Rodar:  DOSBox -> mount c <pasta> -> c: -> pong
;  Controles: W/S (jogador 1)   setas CIMA/BAIXO (jogador 2)
;             R = reiniciar     ESC = sair
;
;  Mapa de memoria:
;    CS:0100h         codigo e dados (.COM)
;    CS+1000h:0000h   back buffer (64000 bytes, "rascunho" da tela)
;    A000h:0000h      memoria de video VGA, modo 13h (320x200)
;    0000h:0024h      vetor do INT 9 (teclado)
; =====================================================================

%ifndef ETAPA
  %define ETAPA 6
%endif

bits 16
org 100h

; ---------------------------- constantes -----------------------------
SCREEN_W     equ 320
SCREEN_H     equ 200
PADDLE_W     equ 4
PADDLE_H     equ 32
PADDLE_SPEED equ 3
BALL_SIZE    equ 4
P1_X         equ 8
P2_X         equ SCREEN_W - 8 - PADDLE_W
WIN_SCORE    equ 5

SC_ESC  equ 01h
SC_R    equ 13h
SC_W    equ 11h
SC_S    equ 1Fh
SC_UP   equ 48h
SC_DOWN equ 50h

; =====================================================================
;  PROGRAMA PRINCIPAL
; =====================================================================
start:
    ; segmento do back buffer: o proximo bloco de 64 KB (CS + 1000h)
    mov ax, cs
    add ax, 1000h
    mov [buf_seg], ax

    ; BIOS INT 10h, AH=00h: modo de video 13h (320x200, 256 cores)
    mov ax, 0013h
    int 10h

%if ETAPA >= 2
    ; instala a rotina do teclado (IRQ1 = INT 9)
    mov ax, 3509h               ; DOS: le o vetor antigo -> ES:BX
    int 21h
    mov [old9_off], bx
    mov [old9_seg], es
    mov dx, int9_handler        ; DS:DX = nova rotina
    mov ax, 2509h               ; DOS: grava o novo vetor
    int 21h
%endif

    call reset_game

%if ETAPA == 1
    ; ---- ETAPA 1: desenha um quadro e espera qualquer tecla (BIOS)
    call render
    xor ah, ah
    int 16h
    jmp exit
%else
main_loop:
    call wait_vsync             ; sincroniza com a taxa da tela (~70 Hz)

    cmp byte [key_esc], 0
    jne exit

  %if ETAPA >= 5
    cmp byte [game_over], 0
    jne .game_over
  %endif

    call update                 ; logica do jogo
    call render                 ; desenho + copia para a VGA

  %if ETAPA >= 5
    cmp byte [game_over], 0
    je main_loop
    call show_winner            ; acabou de terminar: mostra a mensagem
    jmp main_loop

.game_over:
    cmp byte [key_r], 0
    je main_loop
    call reset_game
  %endif
    jmp main_loop
%endif

exit:
%if ETAPA >= 2
    ; restaura o vetor do INT 9 original
    push ds
    mov dx, [old9_off]
    mov bx, [old9_seg]
    mov ds, bx
    mov ax, 2509h
    int 21h
    pop ds
%endif
    mov ax, 0003h               ; volta ao modo texto
    int 10h
    mov ax, 4C00h               ; devolve o controle ao DOS
    int 21h

%if ETAPA >= 2
; =====================================================================
;  ROTINA DE INTERRUPCAO DO TECLADO (INT 9)
;  O hardware chama esta rotina a cada tecla pressionada ou solta.
;  Ela so atualiza a tabela de estado das teclas.
; =====================================================================
int9_handler:
    push ax
    push bx
    push ds
    push cs
    pop ds                      ; DS = CS para acessar as variaveis

    in al, 60h                  ; le o codigo da tecla (scancode)
    mov ah, al
    and al, 7Fh                 ; bit 7 = 1 significa "tecla solta"
    mov bl, 1                   ; BL = 1 pressionada
    test ah, 80h
    jz .tem_estado
    xor bl, bl                  ; BL = 0 solta
.tem_estado:
    cmp al, SC_W
    jne .n1
    mov [key_w], bl
.n1:
    cmp al, SC_S
    jne .n2
    mov [key_s], bl
.n2:
    cmp al, SC_UP
    jne .n3
    mov [key_up], bl
.n3:
    cmp al, SC_DOWN
    jne .n4
    mov [key_down], bl
.n4:
    cmp al, SC_ESC
    jne .n5
    mov [key_esc], bl
.n5:
    cmp al, SC_R
    jne .fim
    mov [key_r], bl
.fim:
    mov al, 20h                 ; EOI: avisa o PIC que a interrupcao acabou
    out 20h, al
    pop ds
    pop bx
    pop ax
    iret

; =====================================================================
;  wait_vsync: espera o retraco vertical (porta 3DAh, bit 3)
; =====================================================================
wait_vsync:
    mov dx, 3DAh
.w1:
    in al, dx
    test al, 8
    jnz .w1
.w2:
    in al, dx
    test al, 8
    jz .w2
    ret
%endif

; =====================================================================
;  reset_game: posicoes iniciais (e zera o placar, a partir da etapa 5)
; =====================================================================
reset_game:
%if ETAPA >= 5
    mov byte [score1], 0
    mov byte [score2], 0
    mov byte [game_over], 0
%endif
    mov word [p1_y], (SCREEN_H - PADDLE_H) / 2
    mov word [p2_y], (SCREEN_H - PADDLE_H) / 2
%if ETAPA >= 3
    mov ax, 2                   ; primeiro saque para a direita
    call serve
%endif
    ret

%if ETAPA >= 3
; =====================================================================
;  serve: AX = velocidade horizontal inicial (+2 direita / -2 esquerda)
;  Direcao vertical sorteada pelo bit 0 do contador do PIT (porta 40h).
; =====================================================================
serve:
    mov [ball_dx], ax
    mov word [ball_x], SCREEN_W / 2 - BALL_SIZE / 2
    mov word [ball_y], SCREEN_H / 2 - BALL_SIZE / 2
    in al, 40h
    test al, 1
    mov word [ball_dy], 1       ; MOV nao altera FLAGS
    jnz .ok
    mov word [ball_dy], -1
.ok:
    ret
%endif

%if ETAPA >= 2
; =====================================================================
;  clamp_paddle: limita AX a 0 .. SCREEN_H-PADDLE_H (comparacao com sinal)
; =====================================================================
clamp_paddle:
    cmp ax, 0
    jge .a
    xor ax, ax
.a:
    cmp ax, SCREEN_H - PADDLE_H
    jle .b
    mov ax, SCREEN_H - PADDLE_H
.b:
    ret

; =====================================================================
;  update: um passo da simulacao (1 vez por quadro)
; =====================================================================
update:
    ; ---------- raquete do jogador 1 (W / S) ----------
    mov ax, [p1_y]
    cmp byte [key_w], 0
    je .p1_nao_sobe
    sub ax, PADDLE_SPEED
.p1_nao_sobe:
    cmp byte [key_s], 0
    je .p1_nao_desce
    add ax, PADDLE_SPEED
.p1_nao_desce:
    call clamp_paddle
    mov [p1_y], ax

    ; ---------- raquete do jogador 2 (setas) ----------
    mov ax, [p2_y]
    cmp byte [key_up], 0
    je .p2_nao_sobe
    sub ax, PADDLE_SPEED
.p2_nao_sobe:
    cmp byte [key_down], 0
    je .p2_nao_desce
    add ax, PADDLE_SPEED
.p2_nao_desce:
    call clamp_paddle
    mov [p2_y], ax

%if ETAPA >= 3
    ; ---------- movimento da bola: posicao += velocidade ----------
    mov ax, [ball_dx]
    add [ball_x], ax
    mov ax, [ball_dy]
    add [ball_y], ax

    ; ---------- colisao com teto e piso (inverte dy) ----------
    cmp word [ball_y], 0
    jge .teto_ok
    mov word [ball_y], 0
    neg word [ball_dy]          ; complemento de dois: dy = -dy
.teto_ok:
    cmp word [ball_y], SCREEN_H - BALL_SIZE
    jle .piso_ok
    mov word [ball_y], SCREEN_H - BALL_SIZE
    neg word [ball_dy]
.piso_ok:
%endif

%if ETAPA == 3
    ; ---------- etapa 3: ainda sem raquetes, as laterais tambem rebatem
    cmp word [ball_x], 0
    jge .esq_ok
    mov word [ball_x], 0
    neg word [ball_dx]
.esq_ok:
    cmp word [ball_x], SCREEN_W - BALL_SIZE
    jle .dir_ok
    mov word [ball_x], SCREEN_W - BALL_SIZE
    neg word [ball_dx]
.dir_ok:
%endif

%if ETAPA >= 4
    ; ---------- colisao com a raquete 1 (so se a bola vai para a esquerda)
    cmp word [ball_dx], 0
    jge .checa_p2
    cmp word [ball_x], P1_X + PADDLE_W
    jg .checa_p2
    cmp word [ball_x], P1_X - BALL_SIZE
    jle .checa_p2
    mov ax, [p1_y]
    mov bx, [ball_y]
    add bx, BALL_SIZE           ; borda de baixo da bola
    cmp bx, ax                  ; bola acima da raquete?
    jle .checa_p2
    add ax, PADDLE_H            ; borda de baixo da raquete
    cmp [ball_y], ax            ; bola abaixo da raquete?
    jge .checa_p2
    neg word [ball_dx]          ; rebate
    mov word [ball_x], P1_X + PADDLE_W
    mov ax, [ball_y]            ; efeito: dy = (centro bola - centro raquete) / 8
    add ax, BALL_SIZE / 2
    sub ax, [p1_y]
    sub ax, PADDLE_H / 2
    sar ax, 3                   ; divisao com sinal por 8
    mov [ball_dy], ax
    jmp .pontuacao

    ; ---------- colisao com a raquete 2 (so se a bola vai para a direita)
.checa_p2:
    cmp word [ball_dx], 0
    jle .pontuacao
    cmp word [ball_x], P2_X - BALL_SIZE
    jl .pontuacao
    cmp word [ball_x], P2_X + PADDLE_W
    jge .pontuacao
    mov ax, [p2_y]
    mov bx, [ball_y]
    add bx, BALL_SIZE
    cmp bx, ax
    jle .pontuacao
    add ax, PADDLE_H
    cmp [ball_y], ax
    jge .pontuacao
    neg word [ball_dx]
    mov word [ball_x], P2_X - BALL_SIZE
    mov ax, [ball_y]
    add ax, BALL_SIZE / 2
    sub ax, [p2_y]
    sub ax, PADDLE_H / 2
    sar ax, 3
    mov [ball_dy], ax

    ; ---------- a bola saiu pela esquerda ou pela direita? ----------
.pontuacao:
    cmp word [ball_x], 0
    jge .confere_direita
  %if ETAPA >= 5
    inc byte [score2]           ; saiu pela esquerda: ponto do jogador 2
  %endif
    mov ax, -2                  ; quem tomou o ponto recebe o saque
    call serve
    jmp .confere_vitoria
.confere_direita:
    cmp word [ball_x], SCREEN_W - BALL_SIZE
    jl .fim_update
  %if ETAPA >= 5
    inc byte [score1]           ; saiu pela direita: ponto do jogador 1
  %endif
    mov ax, 2
    call serve
.confere_vitoria:
  %if ETAPA >= 5
    cmp byte [score1], WIN_SCORE
    je .acabou
    cmp byte [score2], WIN_SCORE
    jne .fim_update
.acabou:
    mov byte [game_over], 1
  %endif
%endif
.fim_update:
    ret
%endif

; =====================================================================
;  draw_rect: desenha retangulo no back buffer (ES = buf_seg)
;    AX = x   BX = y   CX = largura   DX = altura   [color] = cor
;  Endereco do pixel:  y*320 + x = (y<<8) + (y<<6) + x
; =====================================================================
draw_rect:
    pusha
    mov di, bx
    shl di, 8                   ; y * 256
    shl bx, 6                   ; y * 64
    add di, bx                  ; y * 320
    add di, ax                  ; + x
    mov al, [color]
    mov bx, 320
    sub bx, cx                  ; salto para a linha seguinte
.linha:
    push cx
    rep stosb                   ; escreve CX bytes de AL em ES:DI
    pop cx
    add di, bx
    dec dx
    jnz .linha
    popa
    ret

%if ETAPA >= 5
; =====================================================================
;  draw_score: AX = x inicial, SI = pontos, BP = passo (+10 ou -10)
;  Cada ponto vira um quadradinho 6x6.
; =====================================================================
draw_score:
    or si, si
    jz .fim
.loop:
    mov bx, 4
    mov cx, 6
    mov dx, 6
    call draw_rect
    add ax, bp
    dec si
    jnz .loop
.fim:
    ret
%endif

; =====================================================================
;  render: monta o quadro no back buffer e copia tudo para a VGA
; =====================================================================
render:
    mov ax, [buf_seg]
    mov es, ax
    cld

    ; limpa o back buffer (32000 palavras = 64000 bytes)
    xor di, di
    xor ax, ax
    mov cx, 32000
    rep stosw

    ; linha central tracejada (cor 8 = cinza)
    mov byte [color], 8
    xor bx, bx
.tracejado:
    mov ax, SCREEN_W / 2 - 1
    mov cx, 2
    mov dx, 4
    call draw_rect
    add bx, 8
    cmp bx, SCREEN_H
    jb .tracejado

    ; raquetes (cor 15 = branco)
    mov byte [color], 15
    mov ax, P1_X
    mov bx, [p1_y]
    mov cx, PADDLE_W
    mov dx, PADDLE_H
    call draw_rect
    mov ax, P2_X
    mov bx, [p2_y]
    mov cx, PADDLE_W
    mov dx, PADDLE_H
    call draw_rect

%if ETAPA >= 3
    ; bola
    mov ax, [ball_x]
    mov bx, [ball_y]
    mov cx, BALL_SIZE
    mov dx, BALL_SIZE
    call draw_rect
%endif

%if ETAPA >= 5
    ; placar: um quadradinho por ponto
    mov al, [score1]
    xor ah, ah
    mov si, ax
    mov ax, 8
    mov bp, 10
    call draw_score
    mov al, [score2]
    xor ah, ah
    mov si, ax
    mov ax, SCREEN_W - 14
    mov bp, -10
    call draw_score
%endif

    ; apresenta: copia o back buffer (RAM) para a memoria de video (A000h)
    push ds
    mov ax, [buf_seg]
    mov ds, ax
    xor si, si
    mov ax, 0A000h
    mov es, ax
    xor di, di
    mov cx, 32000
    rep movsw                   ; copia bloco DS:SI -> ES:DI
    pop ds
    ret

%if ETAPA >= 5
; =====================================================================
;  show_winner: mensagem final pela BIOS (INT 10h, AH=0Eh)
; =====================================================================
show_winner:
    mov ah, 02h                 ; posiciona o cursor
    mov bh, 0
    mov dh, 11
    mov dl, 10
    int 10h
    mov si, msg_p1
    cmp byte [score1], WIN_SCORE
    je .imprime1
    mov si, msg_p2
.imprime1:
    call print_str
    mov ah, 02h
    mov bh, 0
    mov dh, 13
    mov dl, 7
    int 10h
    mov si, msg_fim
    call print_str
    ret

print_str:                      ; imprime a string (terminada em 0) em DS:SI
    lodsb
    or al, al
    jz .fim
    mov ah, 0Eh
    mov bx, 000Eh               ; pagina 0, cor 14 (amarelo)
    int 10h
    jmp print_str
.fim:
    ret
%endif

; =====================================================================
;  DADOS (variaveis do jogo na memoria)
; =====================================================================
ball_x     dw 0                 ; posicao da bola (com sinal)
ball_y     dw 0
ball_dx    dw 0                 ; velocidade da bola (com sinal)
ball_dy    dw 0
p1_y       dw 0                 ; topo da raquete 1
p2_y       dw 0                 ; topo da raquete 2
score1     db 0
score2     db 0
game_over  db 0
color      db 15
key_w      db 0                 ; estado das teclas (escritas pela rotina do INT 9)
key_s      db 0
key_up     db 0
key_down   db 0
key_esc    db 0
key_r      db 0
buf_seg    dw 0                 ; segmento do back buffer
old9_off   dw 0                 ; vetor antigo do INT 9
old9_seg   dw 0

msg_p1  db 'JOGADOR 1 VENCEU!', 0
msg_p2  db 'JOGADOR 2 VENCEU!', 0
msg_fim db 'R = reiniciar   ESC = sair', 0
