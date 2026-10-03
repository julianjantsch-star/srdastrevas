; =====================================================================
;  S E N H O R   D A S   T R E V A S   -   MSX2+
;  Recriacao do Senhor das Trevas! (Philips Odyssey, 1983) / Attack of
;  the Timelord! (Magnavox Odyssey2, 1982, Ed Averett)
;  SCREEN 5 (G4 - 256x212, 16 cores), MegaROM ASCII8 de 64 KB: bancos 0-2
;  fixos em 0x4000-0x9FFF (codigo), bancos 3.. em 0xA000-0xBFFF (a fala)
;
;  Abertura, fonte, paleta, motor de som, teclado e calibragem vem do
;  OVNI 4.6 (mesmo console, mesmo chip). O jogo esta em jogo.asm.
; =====================================================================

VDPDATA equ 0x98
VDPCTRL equ 0x99
VDPPAL  equ 0x9A
VDPIND  equ 0x9B
PSGADDR equ 0xA0
PSGDATA equ 0xA1
PPIC    equ 0xAA
PPIB    equ 0xA9

STACK   equ 0xF000
IM2TAB  equ 0xD000        ; tabela de vetores do IM 2 (257 bytes iguais a IM2VEC>>8)
IM2VEC  equ 0xD1D1        ; para onde a tabela manda: jp BangIsr
SCRW    equ 256
SCRH    equ 212

; ---- cores (paleta do Odyssey) ----
C_BLACK  equ 0
C_DGRAY  equ 1
C_RED    equ 2
C_GREEN  equ 3
C_YELLOW equ 4
C_BLUE   equ 5
C_MAGENTA equ 6
C_CYAN   equ 7
C_GRAY   equ 8
C_LRED   equ 9
C_LGREEN equ 10
C_LYELLOW equ 11
C_LBLUE  equ 12
C_LMAG   equ 13
C_LCYAN  equ 14
C_WHITE  equ 15

; ---- texto: glifo 7x7 desenhado em dobro (14x14), avanco de 16 ----
CHR_W   equ 16
CHR_H   equ 14

; =====================================================================
        org 0x4000
        db "AB"
        dw INIT
        dw 0
        dw 0
        dw 0
        ds 6,0

INIT:
        di
        ; ASCII8: liga os bancos 1 e 2 do codigo antes de passar de 0x6000
        ; (ao ligar, o mapeador pode estar com o banco 0 em toda janela)
        xor a
        ld (0x6000),a
        inc a
        ld (0x6800),a
        inc a
        ld (0x7000),a
        inc a
        ld (0x7800),a
        ld sp,STACK
        ; ROM de 32 KB: liga a pagina 2 (0x8000-0xBFFF) no slot deste cartucho
        call 0x0138            ; RSLREG: A = registrador de slot primario
        rrca
        rrca
        and 3                  ; slot primario da pagina 1
        ld c,a
        ld b,0
        ld hl,0xFCC1           ; EXPTBL
        add hl,bc
        ld a,(hl)
        and 0x80               ; slot expandido?
        or c
        ld c,a
        inc hl
        inc hl
        inc hl
        inc hl                 ; SLTTBL
        ld a,(hl)
        and 0x0C               ; slot secundario da pagina 1
        or c
        ld h,0x80              ; pagina 2
        call 0x0024            ; ENASLT
        ; a RAM de trabalho nasce com lixo no MSX real: zera tudo antes de usar
        ld hl,0xC000
        ld de,0xC001
        ld bc,RAM_FIM-0xC000-1
        ld (hl),0
        ldir
        ; IM 2: tabela de 257 bytes iguais (o barramento do MSX flutua no
        ; reconhecimento) -> vetor IM2VEC = jp BangIsr (50_sons)
        ld hl,IM2TAB
        ld de,IM2TAB+1
        ld bc,256
        ld (hl),IM2VEC>>8
        ldir
        ld a,0xC3
        ld (IM2VEC),a
        ld hl,LinhaIsr
        ld (IM2VEC+1),hl
        ld a,0xC3              ; WaitCmd (trampolim na RAM) = jp WcRapido
        ld (WaitCmd),a
        ld hl,WcRapido
        ld (WaitCmd+1),hl
        ld a,IM2TAB>>8
        ld i,a
        db 0xED,0x5E           ; im 2 (o montador gera o alias nao documentado ED 7E)
        ld a,0x06
        ld (r0sh),a            ; copia do R#0 (SCREEN 5)
        call VdpInit
        call PalInit
        call PsgInit
        call Calibra           ; mede esta maquina (CPU e VDP) antes do menu
        ld hl,0xA53C
        ld (rng),hl
        ; o recorde e o nome sobrevivem de partida em partida, como no console
        ld hl,0
        ld (recorde),hl
        ld hl,TXT_NOME
        ld de,nomeRec
        ld bc,7
        ldir
        xor a
        ld (nomeOpen),a
MAINLOOP:
        call ScreenOn           ; a experiencia comeca no botao ON
        call ScreenSelect       ; SELECT GAME: 0 = original, 1 = moderno
        call PlayGame
        jr MAINLOOP

; ---------------------------------------------------------------------
VdpInit:
        ld hl,VdpRegs
        ld c,0
        ld b,10
VI1:    ld a,(hl)
        out (VDPCTRL),a
        ld a,c
        or 0x80
        out (VDPCTRL),a
        inc hl
        inc c
        djnz VI1
        ld c,14
        ld b,4
VI2:    xor a
        out (VDPCTRL),a
        ld a,c
        or 0x80
        out (VDPCTRL),a
        inc c
        djnz VI2
        ret
VdpRegs:
        db 0x06         ; R0  modo G4 (SCREEN 5)
        db 0x40         ; R1  display ligado, sem interrupcao
        db 0x1F         ; R2  bitmap na pagina 0
        db 0xFF         ; R3
        db 0x00         ; R4
        db 0xFF         ; R5
        db 0x00         ; R6
        db 0x00         ; R7  borda preta
        db 0x0A         ; R8  sprites desligados, VRAM 128K
        db 0x80         ; R9  212 linhas

PalInit:
        xor a
        out (VDPCTRL),a
        ld a,16|0x80
        out (VDPCTRL),a
        ld hl,PalData
        ld c,VDPPAL
        ld b,32
        otir
        ret
; R*16+B , G  -- valores medidos na tela do console
PalData:
        db 0x00,0x00    ;  0 preto
        db 0x22,0x02    ;  1 cinza escuro
        db 0x52,0x02    ;  2 vermelho
        db 0x23,0x05    ;  3 verde
        db 0x53,0x05    ;  4 amarelo
        db 0x37,0x04    ;  5 azul
        db 0x55,0x01    ;  6 magenta escuro (a grade do placar no Senhor das Trevas)
        db 0x36,0x06    ;  7 ciano
        db 0x44,0x04    ;  8 cinza
        db 0x73,0x03    ;  9 vermelho claro
        db 0x34,0x07    ; 10 verde claro
        db 0x74,0x07    ; 11 amarelo claro
        db 0x47,0x05    ; 12 azul claro
        db 0x77,0x05    ; 13 magenta claro
        db 0x47,0x07    ; 14 ciano claro
        db 0x77,0x07    ; 15 branco

PsgInit:
        ld hl,PsgData
        ld c,0
        ld b,14
PI1:    ld a,c
        out (PSGADDR),a
        ld a,(hl)
        out (PSGDATA),a
        inc hl
        inc c
        djnz PI1
        ret
PsgData:
        db 0,0, 0,0, 0,0, 0, 0xB8, 0,0,0, 0,0, 0

; A = registrador, E = valor
; PsgWr para os passos de som: enquanto a fala toca, o volume B (9) e dela
; e o mixer fica com o tom e o ruido B desligados
PsgWrS:
        cp 7
        jr z,PWS_M
        cp 9
        jr nz,PsgWr
        ld a,(vozOn)
        or a
        ret nz
        ld a,9
        jr PsgWr
PWS_M:  ld a,(vozOn)
        or a
        ld a,7
        jr z,PsgWr
        ld a,e
        or 0x12
        ld e,a
        ld a,7
PsgWr:
        di                     ; a interrupcao de linha tambem escreve no PSG
        out (PSGADDR),a
        ld a,e
        out (PSGDATA),a
        ei
        ret

; =====================================================================
;  VDP
; =====================================================================
; WaitCmd e um trampolim na RAM (70_ram): jp WcRapido, ou jp WcLento enquanto
; o ruido lento toca (a interrupcao de linha precisa do R#15 em 1)
WcRapido:
        ld a,2
        out (VDPCTRL),a
        ld a,15|0x80
        out (VDPCTRL),a
WC1:    in a,(VDPCTRL)
        rrca
        jr c,WC1
        ld a,1                 ; o R#15 descansa em 1 (S#1)
        out (VDPCTRL),a
        ld a,15|0x80
        out (VDPCTRL),a
        ret
; de porta fechada: 6 consultas ao S#2 e, se o comando ainda roda, o R#15
; volta para 1 e a porta abre um instante para a interrupcao de linha
WcLento:
WL_0:   di
        ld a,2
        out (VDPCTRL),a
        ld a,15|0x80
        out (VDPCTRL),a
        in a,(VDPCTRL)
        rrca
        jr nc,WL_F
        in a,(VDPCTRL)
        rrca
        jr nc,WL_F
        in a,(VDPCTRL)
        rrca
        jr nc,WL_F
        in a,(VDPCTRL)
        rrca
        jr nc,WL_F
        in a,(VDPCTRL)
        rrca
        jr nc,WL_F
        in a,(VDPCTRL)
        rrca
        jr nc,WL_F
        ld a,1
        out (VDPCTRL),a
        ld a,15|0x80
        out (VDPCTRL),a
        ei
        jr WL_0
WL_F:   ld a,1
        out (VDPCTRL),a
        ld a,15|0x80
        out (VDPCTRL),a
        ei
        ret

VdpCmd:
        call WaitCmd
        di
        ld a,32
        out (VDPCTRL),a
        ld a,17|0x80
        out (VDPCTRL),a
        ei
        ld hl,c_sx
        ld c,VDPIND
        ld b,15
        otir
        ret

; HL = DX, DE = DY, B = NX, C = NY
SetDst:
        ld (c_dx),hl
        ld (c_dy),de
        ld l,b
        ld h,0
        ld (c_nx),hl
        ld l,c
        ld h,0
        ld (c_ny),hl
        ret

; HL = SX, DE = SY
SetSrc:
        ld (c_sx),hl
        ld (c_sy),de
        ret

; A = byte (2 pixels) -> HMMV
CmdFillB:
        ld (c_clr),a
        xor a
        ld (c_arg),a
        ld a,0xC0
        ld (c_cmd),a
        jp VdpCmd

; A = cor -> LMMV
CmdFillP:
        ld (c_clr),a
        xor a
        ld (c_arg),a
        ld a,0x80
        ld (c_cmd),a
        jp VdpCmd

; LMMM com TIMP (o preto da celula e transparente)
CmdBlitT:
        xor a
        ld (c_arg),a
        ld a,0x98
        ld (c_cmd),a
        jp VdpCmd

; HMMM (copia bytes)
CmdBlit:
        xor a
        ld (c_arg),a
        ld a,0xD0
        ld (c_cmd),a
        jp VdpCmd

; HL -> dx,dy,nx,ny (words) + byte de cor
FillTab:
        ld de,c_dx
        ld bc,8
        ldir
        ld a,(hl)
        ld (c_clr),a
        ld hl,(c_dy)
        ld de,(pgY)
        add hl,de
        ld (c_dy),hl
        ld a,(c_clr)
        jp CmdFillB

; limpa so o campo de jogo da pagina atual
ClearField:
        ld hl,0
        ld (c_dx),hl
        ld hl,(pgY)
        ld (c_dy),hl
        ld hl,SCRW
        ld (c_nx),hl
        ld hl,SCRH
        ld (c_ny),hl
        xor a
        jp CmdFillB

; limpa a tela toda
ClearScreen:
        call PageReset
        ld hl,0
        ld de,0
        ld (c_dx),hl
        ld (c_dy),de
        ld hl,SCRW
        ld (c_nx),hl
        ld hl,SCRH
        ld (c_ny),hl
        xor a
        jp CmdFillB

; volta a exibir e desenhar na pagina 0
PageReset:
        xor a
        ld (pagina),a
        ld hl,0
        ld (pgY),hl
        ld (pgBase),hl
        di
        ld a,0x1F
        out (VDPCTRL),a
        ld a,2|0x80
        out (VDPCTRL),a
        ei
        ret

; mostra a pagina que acabou de ser desenhada e passa a desenhar na outra
FlipPage:
        ld a,(pagina)
        or a
        ld a,0x1F
        jr z,FP_S
        ld a,0x3F
FP_S:   di
        out (VDPCTRL),a
        ld a,2|0x80
        out (VDPCTRL),a
        ei
        ld a,(pagina)
        xor 1
        ld (pagina),a
        or a
        jr nz,FP_P1
        ld hl,0
        ld (pgY),hl
        ld (pgBase),hl
        ret
FP_P1:  ld hl,256
        ld (pgY),hl
        ld hl,0x8000
        ld (pgBase),hl
        ret

; HL = endereco VRAM -> prepara escrita
SetWr:
        ld a,h
        rlca
        rlca
        and 0x03
        di
        out (VDPCTRL),a
        ld a,14|0x80
        out (VDPCTRL),a
        ld a,l
        out (VDPCTRL),a
        ld a,h
        and 0x3F
        or 0x40
        out (VDPCTRL),a
        ei
        ret

; =====================================================================
;  TEXTO  -  glifo 7x7 do Odyssey desenhado em dobro
; =====================================================================
; A = cor de frente, B = cor de fundo
SetCols:
        ld c,a
        rlca
        rlca
        rlca
        rlca
        or c
        ld (fgByte),a
        ld a,b
        ld c,a
        rlca
        rlca
        rlca
        rlca
        or c
        ld (bgByte),a
        ret

; (txtX) = x em pixels (par), (txtY) = y -> HL = endereco na VRAM
TxtAddr:
        ld a,(txtY)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl          ; y*128
        ld a,(txtX)
        srl a
        ld e,a
        ld d,0
        add hl,de
        ld de,(pgBase)
        add hl,de
        ret

; A = caractere
DrawChar:
        sub 32
        jr nc,DC_1
        xor a
DC_1:   cp FONT_LAST-31
        jr c,DC_2
        xor a
DC_2:   ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl          ; *2
        add hl,hl          ; *4
        add hl,de          ; *5
        add hl,de          ; *6
        add hl,de          ; *7
        ld de,FONT
        add hl,de
        ld (dcGlyph),hl
        call TxtAddr
        ld (dcAddr),hl
        ld b,FONT_H
DC_ROW:
        push bc
        ; expande os 7 bits do glifo em 7 bytes
        ld hl,(dcGlyph)
        ld a,(hl)
        inc hl
        ld (dcGlyph),hl
        ld c,a
        ld hl,rowBuf
        ld b,7
DC_EXP:
        rlc c
        jr nc,DC_BG
        ld a,(fgByte)
        jr DC_PUT
DC_BG:  ld a,(bgByte)
DC_PUT: ld (hl),a
        inc hl
        djnz DC_EXP
        ; a mesma linha e escrita duas vezes (o console dobra na vertical)
        ld b,2
DC_LINE:
        push bc
        ld hl,(dcAddr)
        call SetWr
        ld hl,rowBuf
        ld c,VDPDATA
        ld b,7
DC_OUTI: outi                  ; 40 T por byte: folga para o VDP mesmo em turbo
        nop
        nop
        nop
        jr nz,DC_OUTI
        ld hl,(dcAddr)
        ld de,128
        add hl,de
        ld (dcAddr),hl
        pop bc
        djnz DC_LINE
        pop bc
        djnz DC_ROW
        ret

; HL = string terminada em 0
DrawStr:
        call WaitCmd
DS_L:   ld a,(hl)
        or a
        ret z
        push hl
        call DrawChar
        pop hl
        inc hl
        ld a,(txtX)
        add a,CHR_W
        ld (txtX),a
        jr DS_L

; B = x, C = y, HL = string
PrintAt:
        ld a,b
        ld (txtX),a
        ld a,c
        ld (txtY),a
        jp DrawStr

; HL = string, C = y  -> centraliza na tela
PrintCenter:
        push hl
        ld b,0
PC_L:   ld a,(hl)
        or a
        jr z,PC_E
        inc b
        inc hl
        jr PC_L
PC_E:   ; x = (256 - n*16)/2
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a            ; n*16
        neg
        srl a
        and 0xFE
        ld b,a
        pop hl
        jp PrintAt

; =====================================================================
;  TELA DO BOTAO ON
; =====================================================================
ScreenOn:
        ld a,1
        ld (scanLetras),a      ; nos menus, le o teclado inteiro
        call ClearScreen
        ; corpo da chave
        ld hl,ON_BODY
        call FillTab
        ld hl,ON_TOP
        call FillTab
        ld hl,ON_SLOT
        call FillTab
        ; seta apontando para a chave
        ld hl,ON_ARROW1
        call FillTab
        ld hl,ON_ARROW2
        call FillTab
        ld a,C_WHITE
        ld b,C_BLACK
        call SetCols
        ld hl,TXT_ON
        ld b,152
        ld c,40
        call PrintAt
        ld a,C_GRAY
        ld b,C_BLACK
        call SetCols
        ld hl,TXT_ON1
        ld c,150
        call PrintCenter
        ld hl,TXT_ON2
        ld c,170
        call PrintCenter
SO_W:
        call WaitFrame
        call O2Passo            ; monta as figuras do jogo enquanto espera a tecla
        call ScanKeys
        call AnyEdge
        jr z,SO_W
        ret

ON_BODY:   dw 96,86,64,26
           db 0x22             ; vermelho
ON_TOP:    dw 100,80,56,8
           db 0x99             ; vermelho claro
ON_SLOT:   dw 96,112,64,6
           db 0x11             ; sombra
ON_ARROW1: dw 122,44,12,32
           db 0x88             ; haste da seta
ON_ARROW2: dw 114,68,28,10
           db 0x88             ; ponta da seta

; =====================================================================
;  TELA SELECT GAME
; =====================================================================
ScreenSelect:
        ld a,1
        ld (scanLetras),a
        call ClearScreen
        ; "SELECT GAME" com cada letra numa cor, como no console
        ld a,40
        ld (txtX),a
        ld a,60
        ld (txtY),a
        ld hl,TXT_SELECT
        ld de,SelColors
        call DrawColorStr
        ; o som de ligar toca quando SELECT GAME aparece (medido: 2,05 s
        ; depois do quadro em que a tela surge)
        ld hl,SFX_POWER
        ld a,4
        call SndPlay
        ld a,C_LGREEN
        ld b,C_BLACK
        call SetCols
        ld hl,TXT_OPT0
        ld c,110
        call PrintCenter
        ld a,C_LCYAN
        ld b,C_BLACK
        call SetCols
        ld hl,TXT_OPT1
        ld c,134
        call PrintCenter
        ld a,C_DGRAY
        ld b,C_BLACK
        call SetCols
        ld hl,TXT_OPT2
        ld c,172
        call PrintCenter
        ld hl,TXT_OPT3
        ld c,190
        call PrintCenter
SS_W:
        call WaitFrame
        call ScanKeys
        ld a,0
        ld b,0x01              ; tecla 0
        call ChkEdge
        jr nz,SS_0
        ld a,0
        ld b,0x02              ; tecla 1
        call ChkEdge
        jr nz,SS_1
        jr SS_W
SS_0:   xor a
        jr SS_GO
SS_1:   ld a,1
SS_GO:  ld (modo),a
        ld hl,SFX_SELECT
        ld a,4
        call SndPlay
        ld b,8
        call Delay
        ret

; HL = string, DE = tabela de cores (uma por letra, 0xFF reinicia)
DrawColorStr:
        call WaitCmd           ; a limpeza da tela (HMMV) ainda pode estar rodando
        ld (csStr),hl
        ld (csCol),de
DCS_L:
        ld hl,(csStr)
        ld a,(hl)
        or a
        ret z
        inc hl
        ld (csStr),hl
        push af
        ld hl,(csCol)
        ld a,(hl)
        cp 0xFF
        jr nz,DCS_C
        ld hl,SelColors
        ld a,(hl)
DCS_C:  inc hl
        ld (csCol),hl
        ld b,C_BLACK
        call SetCols
        pop af
        push af
        call DrawChar
        pop af
        ld a,(txtX)
        add a,CHR_W
        ld (txtX),a
        jr DCS_L

SelColors:
        db C_LGREEN, C_LRED, C_LYELLOW, C_LCYAN, C_LMAG, C_LBLUE
        db C_WHITE, C_LGREEN, C_LRED, C_LYELLOW, C_LCYAN
        db 0xFF



; =====================================================================
;  JOGO (esqueleto): maquina de estados da rodada
;  ROSTO -> FENDA -> COMBATE -> LIMPO -> (nivel+1) ... MORTE
; =====================================================================
CELL_W     equ 14              ; celula de teste da calibragem do VDP (igual a do OVNI: mesma escala)
CELL_H     equ 12

#include "jogo.asm"

; =====================================================================
;  SONS  -  todos medidos na gravacao do original (FFT + autocorrelacao)
;  O chip do Odyssey e UM registrador de deslocamento a 3932 Hz: toda
;  frequencia e submultipla dele (3932/2 = 1966, /6 = 656, /12 = 328,
;  /16 = 246, /24 = 164, /48 = 82), e como so ha uma voz, um som novo
;  interrompe o anterior. Aqui cada passo tem 12 bytes:
;    duracao, tomA(2), tomB(2), tomC(2), volA, volB, volC, ruido, mixer
;  e o PSG usa os tres canais para reproduzir o fundamental e os dois
;  parciais mais fortes de cada padrao (o 3o e o 5o harmonicos vem MAIS
;  fortes que o fundamental na gravacao).
;  0xFF encerra; 0xFE recomeca (sons de fundo, em loop).
; =====================================================================
P_82    equ 1364
P_117   equ 956
P_123   equ 909
P_164   equ 682
P_188   equ 595
P_234   equ 478
P_328   equ 341
P_352   equ 318
P_375   equ 298
P_393   equ 285
P_398   equ 281
P_422   equ 265
P_445   equ 251
P_492   equ 227
P_656   equ 171         ; 3933,6/6 = 655,6 Hz (171 -> 654,2; 170 dava 658,0)
P_961   equ 116
P_980   equ 114
P_1875  equ 60
P_1966  equ 57
P_2286  equ 49
P_2578  equ 43
P_2695  equ 42
P_2742  equ 41
P_2766  equ 40
P_2836  equ 39
P_2953  equ 38
P_3000  equ 37
P_3117  equ 36
P_3188  equ 35
P_3281  equ 34
P_3445  equ 32
P_3609  equ 31
P_3773  equ 30
P_3844  equ 29
P_4313  equ 26
P_4364  equ 26
P_4547  equ 25
P_4594  equ 24
P_5887  equ 19
P_469   equ 239
P_4617  equ 24
P_4664  equ 24
P_5906  equ 19
P_6141  equ 18
P_6234  equ 18
P_4143  equ 27          ; zumbido alto da morte: parcial de 4,1 kHz
; periodos travados em multiplos exatos (h = harmonico do fundamental)
P_249   equ 450         ; barra: fundamental
P_2728  equ 41          ; barra: h11 (450/41 = 10,98)
P_246   equ 455         ; zumbido: h3 de 82 Hz (1364/3)
P_410   equ 273         ; zumbido: h5 de 82 Hz (1364/5)
P_3390  equ 33          ; laser: h8 de 422 Hz
P_1177  equ 95          ; escada: h3 de 393 Hz
MIXABC  equ 0xB8        ; tres tons, sem ruido
MIXAB   equ 0xBC        ; tons A e B
MIXA    equ 0xBE        ; so o tom A
MIXAN   equ 0x9E        ; tom A + ruido no canal C
MIXABN  equ 0x9C        ; tons A e B + ruido no canal C
P_131   equ 854

; ligar (aparece SELECT GAME): a escada do registrador, uma quadrada por
; degrau: 82 (5 q) -> 164 (5) -> 328 (6) -> 655 (5) -> 1966 (5), sem decaimento
SFX_POWER:
        ; tune_select do BIOS (0x34A): tons 82, 164, 328, 655 e 1966 Hz, 5 quadros cada, volume 15
        db 5, P_82&255,P_82>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 5, P_164&255,P_164>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 5, P_328&255,P_328>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 5, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 5, P_1966&255,P_1966>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 0xFF

; escolher o jogo (tecla 0/1): o clique de teclado do BIOS do console, ~6 ms
; de relogio rapido (1 quadro de ruido rapido, mais baixo)
SFX_SELECT:
        ; tune_keyclick do BIOS (0x356): 655 Hz por 2 quadros
        db 2, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 0xFF

; escada antes da carga, ao renascer: 164 -> 328 -> 655 -> 1966, 5 quadros
; cada (medido nas duas gravacoes)
SFX_ESCADA:
        db 5, P_164&255,P_164>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 5, P_328&255,P_328>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 5, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 5, P_1966&255,P_1966>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 0xFF

; um pulso da carga do campo: o tom de 655 Hz do chip (quadrada), 1 quadro,
; um pouco abaixo do estouro (energia por borda: ~12/15). O primeiro da
; partida dura 4 quadros (medido em 11/09)
SFX_PULSO:
        db 1, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 0xFF
SFX_PULSO4:
        db 4, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 0xFF

; motor: enquanto a nave anda, a cada 5 quadros: 1 quadro de 1966 Hz e 1 de
; 328 Hz (a "cauda" das levas antigas era a reverberacao da sala)
SFX_MOTOR:
        db 1, P_1966&255,P_1966>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 1, P_328&255,P_328>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 0xFF

; o ponto do laser chega ao fim do alcance: 422 Hz + formante de 3 kHz,
; depois 2953, depois o padrao de 656, e um rabo em 4,6 kHz (~80 ms)
SFX_LASER:
        db 1, P_422&255,P_422>>8, P_2953&255,P_2953>>8, P_3390&255,P_3390>>8, 12,12,11, 0, MIXABC
        db 1, P_2953&255,P_2953>>8, P_961&255,P_961>>8, P_2836&255,P_2836>>8, 13,6,11, 0, MIXABC
        db 1, P_656&255,P_656>>8, P_3281&255,P_3281>>8, P_1966&255,P_1966>>8, 8,12,12, 0, MIXABC
        db 2, P_4617&255,P_4617>>8, P_3188&255,P_3188>>8, P_2742&255,P_2742>>8, 11,10,9, 0, MIXABC
        db 0xFF

; o estouro (estrela morta pelo laser ou absorvida pelo campo: o mesmo som).
; E o programa do chip do console, lido na gravacao de 14/09 pelas bordas na
; grade de 983,4 Hz (ref/decodifica.cjs, ref/grade.cjs, ref/nivel.cjs):
;   1 quadro  de ruido no relogio rapido (3933 Hz), mais baixo
;   2 quadros do tom de 655 Hz (111000 no relogio rapido: quadrada)
;   2 quadros de ruido no relogio rapido
;   2 quadros do tom de 123 Hz (00001111 no relogio lento: quadrada)
;  32 quadros de ruido no relogio lento (983 Hz), os 10 ultimos a 13/15
; 39 quadros, e so entao os pulsos da recarga. O ruido rapido e o do PSG
; (NP 28 = 3995 Hz); o lento sai bit a bit pela interrupcao de linha, com a
; semente do console (0xE1E1). Quadradas simples: os "harmonicos mais fortes
; que o fundamental" das levas antigas eram a cor do microfone da gravacao.
SFX_RASP:
SFX_ESTOURO:
        db 1, 0,0, 0,0, 0,0, 0,0,14, 28, 0x9F
        db 2, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 0xFD, 0xE1,0xE1, 0,0
        db 2, 0,0, 142,3, 0,0, 0,15,0, 0, 0xBD
        db 0xFD, 0xE1,0xE1, 15,0
        db 22, 0,0, 0,0, 0,0, 0,0,0, 0, 0xBF
        db 0xFD, 0,0, 15,9
        db 10, 0,0, 0,0, 0,0, 9,0,0, 0, 0xBF
        db 0xFF

; a barra viva: a quadrada de 246 Hz do relogio lento (983/4), em loop, no
; volume cheio (energia por borda igual a do estouro)
SFX_BARRA:
        db 8, P_246&255,P_246>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 0xFE
; a barra atira: 2 quadros de ruido no relogio rapido e 1 de 655 Hz
SFX_BARRATIRO:
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 1, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 0xFF

; a morte da nave: no console e o MESMO som do estouro, reiniciado a cada 16
; quadros junto com os ciclos da explosao da nave (gravacao de 11/09 lida na
; grade de 983,4 Hz: ref/grade.cjs, ref/decodifica.cjs). 147 quadros:
;   1 ciclo de 26  = 1 ruido rapido, 2 de 655 Hz, 2 ruido rapido, 2 de 123 Hz, 19 ruido lento
;   7 ciclos de 16 = 2 ruido rapido, 2 de 655 Hz, 2 ruido rapido, 2 de 123 Hz,  8 ruido lento
;   final de 9     = 1, 2, 2, 2 e 2 de ruido lento; dai o zumbido da pausa
; O ruido lento recomeca da mesma semente em todo ciclo, como la.
SFX_MORTE:
        db 1, 0,0, 0,0, 0,0, 0,0,14, 28, 0x9F
        db 2, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 0xFD, 0xE1,0xE1, 0,0
        db 2, 0,0, 142,3, 0,0, 0,15,0, 0, 0xBD
        db 0xFD, 0xE1,0xE1, 15,0
        db 19, 0,0, 0,0, 0,0, 0,0,0, 0, 0xBF
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 2, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 0xFD, 0xE1,0xE1, 0,0
        db 2, 0,0, 142,3, 0,0, 0,15,0, 0, 0xBD
        db 0xFD, 0xE1,0xE1, 15,0
        db 8, 0,0, 0,0, 0,0, 0,0,0, 0, 0xBF
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 2, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 0xFD, 0xE1,0xE1, 0,0
        db 2, 0,0, 142,3, 0,0, 0,15,0, 0, 0xBD
        db 0xFD, 0xE1,0xE1, 15,0
        db 8, 0,0, 0,0, 0,0, 0,0,0, 0, 0xBF
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 2, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 0xFD, 0xE1,0xE1, 0,0
        db 2, 0,0, 142,3, 0,0, 0,15,0, 0, 0xBD
        db 0xFD, 0xE1,0xE1, 15,0
        db 8, 0,0, 0,0, 0,0, 0,0,0, 0, 0xBF
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 2, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 0xFD, 0xE1,0xE1, 0,0
        db 2, 0,0, 142,3, 0,0, 0,15,0, 0, 0xBD
        db 0xFD, 0xE1,0xE1, 15,0
        db 8, 0,0, 0,0, 0,0, 0,0,0, 0, 0xBF
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 2, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 0xFD, 0xE1,0xE1, 0,0
        db 2, 0,0, 142,3, 0,0, 0,15,0, 0, 0xBD
        db 0xFD, 0xE1,0xE1, 15,0
        db 8, 0,0, 0,0, 0,0, 0,0,0, 0, 0xBF
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 2, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 0xFD, 0xE1,0xE1, 0,0
        db 2, 0,0, 142,3, 0,0, 0,15,0, 0, 0xBD
        db 0xFD, 0xE1,0xE1, 15,0
        db 8, 0,0, 0,0, 0,0, 0,0,0, 0, 0xBF
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 2, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 0xFD, 0xE1,0xE1, 0,0
        db 2, 0,0, 142,3, 0,0, 0,15,0, 0, 0xBD
        db 0xFD, 0xE1,0xE1, 15,0
        db 8, 0,0, 0,0, 0,0, 0,0,0, 0, 0xBF
        db 1, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 2, P_656&255,P_656>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 2, 0,0, 0,0, 0,0, 0,0,15, 28, 0x9F
        db 0xFD, 0xE1,0xE1, 0,0
        db 2, 0,0, 142,3, 0,0, 0,15,0, 0, 0xBD
        db 0xFD, 0xE1,0xE1, 15,0
        db 2, 0,0, 0,0, 0,0, 0,0,0, 0, 0xBF
        db 0xFF

; morta, ate renascer: a quadrada de 82 Hz do relogio lento (983/12), em
; loop, um passo do PSG abaixo do estouro (energia por borda ~11/15)
SFX_ZUMBIDO:
        db 8, P_82&255,P_82>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 0xFE
; o toque de cada volta da lacuna nos ??????: 164 Hz (983/6), 3 quadros
SFX_TIQUE:
        db 3, P_164&255,P_164>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 0xFF

; =====================================================================
;  SINCRONISMO E MOTOR DE SOM
;  Uma voz so, como o console: um som novo com prioridade igual ou maior
;  substitui o atual; menor e descartado. Quando o som de uma vez acaba,
;  o som de fundo (se houver) volta a tocar em loop.
; =====================================================================
WaitFrame:
        ld hl,(frameCnt)
        inc hl
        ld (frameCnt),hl
WF0:    di                     ; S#0 de porta fechada; o R#15 volta para 1 (ver BangIsr)
        xor a
        out (VDPCTRL),a
        ld a,15|0x80
        out (VDPCTRL),a
WF1:    in a,(VDPCTRL)         ; (as ferramentas param aqui: e a leitura do vblank)
        ld c,a
        ld a,1
        out (VDPCTRL),a
        ld a,15|0x80
        out (VDPCTRL),a
        ei
        bit 7,c
        jr z,WF0
        jp SfxTick

; le o S#0 com as interrupcoes fechadas e devolve o R#15 em 1 (S#1), onde
; a interrupcao de linha do ruido lento espera encontra-lo. Sai NZ se o
; vblank ja veio (a leitura limpa o flag)
LeS0:   di
        xor a
        out (VDPCTRL),a
        ld a,15|0x80
        out (VDPCTRL),a
        in a,(VDPCTRL)
        ld c,a
        ld a,1
        out (VDPCTRL),a
        ld a,15|0x80
        out (VDPCTRL),a
        ei
        ld a,c
        and 0x80
        ret

; =====================================================================
;  CALIBRAGEM (uma vez, no INIT): mede a CPU e o VDP desta maquina.
;  calCpu = iteracoes de um laco de 36 T entre dois vblanks (1391 no MSX2+
;  do Julian, 1493 no WebMSX); calVdp = esperas somadas de 16 copias de
;  14x12 (as celulas dos inimigos), ~600 no MSX real. Acima de 400 o modo
;  moderno desenha 4 estrelas do fundo por quadro em vez de 7 (econ).
; =====================================================================
Calibra:
        in a,(VDPCTRL)
CB_V0:  in a,(VDPCTRL)
        and 0x80
        jr z,CB_V0
        ld hl,0
CB_V1:  inc hl
        in a,(VDPCTRL)
        and 0x80
        jr z,CB_V1
        ld (calCpu),hl
        ld hl,0
        ld (calVdp),hl
        ld b,16
CB_L:   push bc
        ld hl,16
        ld (c_sx),hl
        ld hl,256+20
        ld (c_sy),hl
        ld hl,40
        ld (c_dx),hl
        ld (c_dy),hl
        ld hl,CELL_W
        ld (c_nx),hl
        ld hl,CELL_H
        ld (c_ny),hl
        xor a
        ld (c_arg),a
        ld a,0xD0
        ld (c_cmd),a
        call VdpCmd
        ld a,2
        di
        out (VDPCTRL),a
        ld a,15|0x80
        out (VDPCTRL),a
        ei
        ld hl,0
CB_W:   inc hl
        in a,(VDPCTRL)
        rrca
        jr c,CB_W
        xor a
        di
        out (VDPCTRL),a
        ld a,15|0x80
        out (VDPCTRL),a
        ei
        ld de,(calVdp)
        add hl,de
        ld (calVdp),hl
        pop bc
        djnz CB_L
        ld hl,(calVdp)
        ld de,400
        or a
        sbc hl,de
        ld a,0
        jr c,CB_E
        inc a
CB_E:   ld (econ),a
        ld a,1                 ; R#15 descansa em 1 (S#1): ver BangIsr
        out (VDPCTRL),a
        ld a,15|0x80
        out (VDPCTRL),a
        ret

; B = frames
Delay:
        push bc
        call WaitFrame
        pop bc
        djnz Delay
        ret

; HL = tabela, A = prioridade (1..4)
SndPlay:
        ld c,a
        ld a,(sndPrio)
        cp c
        jr z,SP_OK
        jr c,SP_OK
        ; prioridade menor: so entra se o som atual esta no ultimo quadro (o
        ; 1o pulso da recarga cola no fim do estouro, como no console)
        ld a,(sfxTimer)
        or a
        ret nz
        push hl
        ld hl,(sfxPtr)
        ld a,(hl)
        pop hl
        cp 0xFF
        ret nz
SP_OK:  ld a,c
        ld (sndPrio),a
        ld (sfxPtr),hl
        xor a
        ld (sfxTimer),a
        ret

; HL = tabela de fundo (termina em 0xFE)
SndBg:
        ld (bgPtr),hl
        ld a,(sndPrio)
        or a
        ret nz                 ; espera o som atual acabar
        ld (sfxPtr),hl
        xor a
        ld (sfxTimer),a
        ret

SndBgOff:
        ld hl,0
        ld (bgPtr),hl
        ld a,(sndPrio)
        or a
        ret nz                 ; um som de uma vez esta tocando: deixa
        ld hl,0
        ld (sfxPtr),hl
        jp SndSilence

SndAllOff:
        call VozPara
        ld hl,0
        ld (bgPtr),hl
        ld (sfxPtr),hl
        xor a
        ld (sndPrio),a
SndSilence:
        call BangOff
        ld e,0
        ld a,8
        call PsgWr
        ld e,0
        ld a,9
        call PsgWr
        ld e,0
        ld a,10
        jp PsgWr

SfxTick:
        ld hl,(sfxPtr)
        ld a,h
        or l
        ret z
        ld a,(sfxTimer)
        or a
        jr z,SfxNext
        dec a
        ld (sfxTimer),a
        ret
SfxNext:
        ld a,(hl)
        cp 0xFF
        jr z,SfxEnd
        cp 0xFE
        jr nz,SfxStep
        ; fim do loop de fundo: recomeca
        ld hl,(bgPtr)
        ld a,h
        or l
        jr nz,SfxStep
SfxEnd:
        call SndSilence
        xor a
        ld (sndPrio),a
        ld (sfxTimer),a
        ld hl,(bgPtr)
        ld (sfxPtr),hl         ; retoma o fundo, se houver...
        ld a,h
        or l
        ret z
        jp SfxStep             ; ...ja neste quadro, sem buraco (como no console)

; um passo de 12 bytes: duracao, tomA, tomB, tomC, volA, volB, volC, ruido, mixer
SfxStep:
        ld a,(hl)
        cp 0xFD
        jr nz,SS_COM
        call SfxBang           ; cabecalho do ruido lento; HL -> o passo comum que o segue
        jr SS_CAR
SS_COM: call BangOff           ; passo comum: o canal A volta a ser do PSG
SS_CAR: ld a,(hl)
        dec a
        ld (sfxTimer),a
        inc hl
        ld de,SFXREGS
        ld b,11
SS_L:   ld a,(de)
        push de
        push bc
        ld e,(hl)
        call PsgWrS
        pop bc
        pop de
        inc de
        inc hl
        djnz SS_L
        ld (sfxPtr),hl
        ret
SFXREGS: db 0,1,2,3,4,5,8,9,10,6,7

; =====================================================================
;  RUIDO LENTO (983 Hz), COMO O CHIP DO ODYSSEY FAZ
;  O relogio lento do i8244 e um deslocamento a cada 16 linhas de
;  varredura (15734/16 = 983 Hz) e o PSG nao tem ruido tao grave (o minimo
;  e 3,6 kHz): o chiado dele nao parece o ronco do console. Aqui a
;  interrupcao de LINHA do V9938, a cada 16 linhas, faz o que o i8244 faz
;  em modo ruido - fb = bit0 ^ bit5, desloca, fb entra no bit 15, a saida e
;  o bit 0 - e poe o bit no volume do canal A, que vira um DAC (tom e
;  ruido desligados no mixer). A semente e o estado do console quando o
;  ruido comeca (o tom de 123 Hz girando: 0xE1E1), lido bit a bit na
;  gravacao (ref/decodifica.cjs): a sequencia e a MESMA.
;  IM 2 com tabela de 257 bytes iguais (o barramento do MSX flutua no
;  reconhecimento), sem passar pelo BIOS. So existe fonte de interrupcao
;  enquanto um passo 0xFD toca (IE1). O programa principal fecha as
;  interrupcoes em toda sequencia de 2 bytes nas portas 0x99 e 0xA0 e deixa
;  sempre o R#15 em 1 (S#1), que e o que a rotina le para limpar o FH.
;  Linhas 4, 20, ... 244 (16 por quadro; so a virada tem 22 linhas): ate a
;  245 todo emulador conta como o V9938.
;  Passo de som: 0xFD, quadros, semente (2 bytes; 0 = continua), nivel do
;  bit 1, nivel do bit 0.
; =====================================================================
LinhaIsr:
        ex af,af'              ; o jogo alternativo de registradores e so desta rotina
        in a,(VDPCTRL)         ; S#1: bit 0 = FH (a leitura limpa)
        rrca
        jr nc,LI_FORA
        exx                    ; C' = proxima linha; fala: HL' = amostras, DE' = restantes, B' = fase/pausa
        ld a,(vozOn)
        or a
        jr nz,LI_VOZ
        ld a,c                 ; so o ruido lento: a cada 16 linhas
        add a,16
        cp 245
        jr c,LI_1
        ld a,4
LI_1:   ld c,a
        out (VDPCTRL),a
        ld a,19|0x80
        out (VDPCTRL),a
        call LiBang
        exx
LI_FORA:
        ex af,af'
        ei
        ret
; a fala: uma amostra a cada 2 linhas (0, 2, ... 244)
LI_VOZ: ld a,c
        add a,2
        cp 246
        jr c,LV_1
        xor a
LV_1:   ld c,a
        out (VDPCTRL),a
        ld a,19|0x80
        out (VDPCTRL),a
        ld a,(bgOn)            ; o ruido lento junto, a cada 8 amostras
        or a
        jr z,LV_2
        ld a,c
        and 15
        cp 4
        call z,LiBang
LV_2:   ld a,d
        or e
        jr z,LV_PROX
        dec de
        bit 7,b
        jr nz,LV_SAI           ; pausa: o volume fica
        ld a,9
        out (PSGADDR),a
        ld a,b
        xor 1                  ; 1 = nibble alto agora, 0 = o baixo (e avanca)
        ld b,a
        ld a,(hl)
        jr z,LV_LO
        rrca
        rrca
        rrca
        rrca
        jr LV_OUT
LV_LO:  inc hl
LV_OUT: and 15
        out (PSGDATA),a
LV_SAI: exx
        ex af,af'
        ei
        ret
; o proximo alofone da frase
LV_PROX:
        ld hl,(vozPtr)
        ld a,(hl)
        inc hl
        ld (vozPtr),hl
        cp 0xFF
        jr z,LV_FIM
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de              ; *5
        ld de,VOZ_TAB
        add hl,de
        ld a,(hl)              ; banco (0xFF = pausa)
        inc hl
        ld b,0
        cp 0xFF
        jr nz,LV_B
        ld b,0x80
        jr LV_C
LV_B:   ld (0x7800),a          ; ASCII8: o banco do alofone em 0xA000
LV_C:   ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push de
        ld e,(hl)
        inc hl
        ld d,(hl)              ; DE' = amostras
        pop hl                 ; HL' = endereco
        jr LV_SAI
LV_FIM: xor a
        ld (vozOn),a
        ld a,9
        out (PSGADDR),a
        xor a
        out (PSGDATA),a
        ld a,(bgOn)
        or a
        jr nz,LV_SAI           ; o ruido lento segue sozinho
        ld a,(r0sh)            ; ninguem mais: desliga a interrupcao de linha
        out (VDPCTRL),a
        ld a,0|0x80
        out (VDPCTRL),a
        ld hl,WcRapido
        ld (WaitCmd+1),hl
        jr LV_SAI

; um passo do ruido lento (i8244: fb = bit0 ^ bit5, desloca, sai o bit 0 no
; volume do canal A); estado na RAM. Preserva BC, DE, HL
LiBang: push hl
        ld hl,(bgReg)
        ld a,l
        and 0x21               ; bits 0 e 5 (o AND zera o carry)
        jp pe,LB_P             ; iguais: fb = 0
        scf
LB_P:   rr h
        rr l                   ; carry = o bit que saiu
        ld (bgReg),hl
        ld a,8
        out (PSGADDR),a
        ld a,(bgN1)
        jr c,LB_N
        ld a,(bgN0)
LB_N:   out (PSGDATA),a
        pop hl
        ret

; A = frase (VOZ_FR): comeca a falar. A interrupcao de linha toca
VozFala:
        ld l,a
        ld h,0
        add hl,hl
        ld de,VOZ_FR
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        di
        ld (vozPtr),de
        exx
        ld de,0                ; nada tocando: a 1a interrupcao pega o 1o alofone
        ld b,0
        exx
        ld a,7                 ; mixer: tom e ruido B desligados
        out (PSGADDR),a
        in a,(0xA2)
        or 0x12
        out (PSGDATA),a
        ld a,(vozOn)
        ld c,a
        ld a,1
        ld (vozOn),a
        ld a,c
        or a
        jr nz,VF_FIM           ; ja falava: so trocou a frase
        ld a,(bgOn)
        or a
        jr nz,VF_FIM           ; a interrupcao de linha ja corre (ruido lento)
        exx
        ld c,0
        exx
        ld hl,WcLento
        ld (WaitCmd+1),hl
        ld a,1                 ; R#15 = 1 e um FH velho limpo
        out (VDPCTRL),a
        ld a,15|0x80
        out (VDPCTRL),a
        in a,(VDPCTRL)
        xor a                  ; primeira linha: 0
        out (VDPCTRL),a
        ld a,19|0x80
        out (VDPCTRL),a
        ld a,(r0sh)
        or 0x10                ; IE1
        out (VDPCTRL),a
        ld a,0|0x80
        out (VDPCTRL),a
VF_FIM: ei
        ret

; cala a fala (o ruido lento, se tocando, continua)
VozPara:
        di
        ld a,(vozOn)
        or a
        jr z,VP_FIM
        xor a
        ld (vozOn),a
        ld a,9
        out (PSGADDR),a
        xor a
        out (PSGDATA),a
        ld a,(bgOn)
        or a
        jr nz,VP_FIM
        ld a,(r0sh)
        out (VDPCTRL),a
        ld a,0|0x80
        out (VDPCTRL),a
        in a,(VDPCTRL)         ; FH pendente (o R#15 esta em 1)
        ld hl,WcRapido
        ld (WaitCmd+1),hl
VP_FIM: ei
        ret

; HL -> cabecalho 0xFD, semente (2 bytes; 0 = o registrador continua), nivel
; do bit 1, nivel do bit 0. Sai com HL no passo comum que vem em seguida (o
; mixer dele deve deixar o canal A sem tom e sem ruido, e o volume A = nivel
; do bit 0)
SfxBang:
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)              ; DE = semente
        inc hl
        ld b,(hl)              ; B = nivel do bit 1
        inc hl
        ld c,(hl)              ; C = nivel do bit 0
        inc hl
        push hl
        di
        ld a,d
        or e
        jr z,SB_1              ; 0 = o registrador continua de onde esta
        ld (bgReg),de
SB_1:   ld a,b
        ld (bgN1),a
        ld a,c
        ld (bgN0),a
        ld a,(bgOn)
        or a
        jr nz,SB_FIM           ; ja tocando: so mudaram a semente e os niveis
        inc a
        ld (bgOn),a
        ld a,(vozOn)
        or a
        jr nz,SB_FIM           ; a fala ja liga a interrupcao de linha
        exx
        ld c,228               ; ligando agora: C' = primeira linha (228, 244, 4, 20, ...)
        exx
        ld hl,WcLento          ; o WaitCmd passa a ser o de porta fechada
        ld (WaitCmd+1),hl
        ld a,1                 ; R#15 = 1 e um FH velho limpo
        out (VDPCTRL),a
        ld a,15|0x80
        out (VDPCTRL),a
        in a,(VDPCTRL)
        ld a,228               ; primeira linha: o SfxTick roda logo depois do vblank (linha 212)
        out (VDPCTRL),a
        ld a,19|0x80
        out (VDPCTRL),a
        ld a,(r0sh)
        or 0x10                ; IE1
        out (VDPCTRL),a
        ld a,0|0x80
        out (VDPCTRL),a
SB_FIM: ei
        pop hl
        ret

; para o ruido lento e cala o canal A (preserva HL, DE, BC); a interrupcao
; de linha so desliga se a fala nao estiver tocando
BangOff:
        ld a,(bgOn)
        or a
        ret z
        di
        xor a
        ld (bgOn),a
        ld a,(vozOn)
        or a
        jr nz,BO_1
        push hl
        ld hl,WcRapido
        ld (WaitCmd+1),hl
        pop hl
        ld a,(r0sh)
        out (VDPCTRL),a
        ld a,0|0x80
        out (VDPCTRL),a
        in a,(VDPCTRL)         ; FH pendente (o R#15 esta em 1)
BO_1:   ld a,8
        out (PSGADDR),a
        xor a
        out (PSGDATA),a
        ei
        ret


; =====================================================================
;  TECLADO
; =====================================================================
; A = linha -> A = bits (0 = pressionada)
ReadRow:
        ld c,a
        in a,(PPIC)
        and 0xF0
        or c
        out (PPIC),a
        in a,(PPIB)
        ret

ScanKeys:
        ; no jogo so importam as linhas 0 (digitos), 7 (F5/ESC/RETURN) e 8
        ; (espaco e setas); as de letras (2-5) so com o nome aberto ou nos menus
        xor a
        call ScanRow
        ld a,7
        call ScanRow
        ld a,8
        call ScanRow
        ld a,(scanLetras)
        or a
        jr nz,SK_LE
        ld a,(modo)            ; modo moderno: so a linha do P (pausa)
        or a
        jr z,SK_NL
        ld a,4
        call ScanRow
        xor a
        ld (keyEdge+2),a
        ld (keyEdge+3),a
        ld (keyEdge+5),a
        ret
SK_LE:  ld a,2
        call ScanRow
        ld a,3
        call ScanRow
        ld a,4
        call ScanRow
        ld a,5
        jp ScanRow
SK_NL:  xor a
        ld (keyEdge+2),a
        ld (keyEdge+3),a
        ld (keyEdge+4),a
        ld (keyEdge+5),a
        ret

; A = linha: le a matriz, guarda em keyRow e a borda (apertou agora) em keyEdge.
; Na linha 8 (espaco e setas) o joystick entra junto, por um AND.
ScanRow:
        ld c,a
        ld b,0
        push bc
        call ReadRow           ; A = bits da linha (0 = apertada)
        pop bc
        push bc
        ld d,a
        ld a,c
        cp 8
        jr nz,SR_1
        push de
        call ReadJoy
        pop de
        and d
        ld d,a
SR_1:   pop bc
        ld a,d
        ld hl,keyRow
        add hl,bc
        ld e,(hl)
        ld (hl),a
        cpl
        and e
        ld hl,keyEdge
        add hl,bc
        ld (hl),a
        ret

PSGREAD equ 0xA2
; joystick da porta 1 pelo PSG: R#15 = 0x8F seleciona a porta 1 (saidas em
; nivel alto), R#14 le: bit 0 cima, 1 baixo, 2 esquerda, 3 direita, 4 e 5
; gatilhos (0 = apertado). Devolve em A os mesmos bits da linha 8 do teclado
; (bit 0 espaco, 4 esquerda, 5 cima, 6 baixo, 7 direita), em nivel baixo.
ReadJoy:
        di                     ; a interrupcao do ruido lento tambem escreve no PSG
        ld a,15
        out (PSGADDR),a
        ld a,0x8F
        out (PSGDATA),a
        ld a,14
        out (PSGADDR),a
        in a,(PSGREAD)
        ei
        ld c,a
        ld a,0xFF
        bit 0,c
        jr nz,RJ_1
        res 5,a
RJ_1:   bit 1,c
        jr nz,RJ_2
        res 6,a
RJ_2:   bit 2,c
        jr nz,RJ_3
        res 4,a
RJ_3:   bit 3,c
        jr nz,RJ_4
        res 7,a
RJ_4:   bit 4,c
        jr nz,RJ_5
        res 0,a
RJ_5:   bit 5,c
        ret nz
        res 0,a                ; o gatilho B tambem atira
        ret

; A = linha, B = mascara -> NZ se acabou de ser pressionada
ChkEdge:
        ld l,a
        ld h,0
        ld de,keyEdge
        add hl,de
        ld a,(hl)
        and b
        ret

; A = linha, B = mascara -> NZ se esta pressionada agora
ChkDown:
        ld l,a
        ld h,0
        ld de,keyRow
        add hl,de
        ld a,(hl)
        cpl
        and b
        ret

AnyEdge:
        ld hl,keyEdge
        ld b,9
        xor a
AE_L:   or (hl)
        inc hl
        djnz AE_L
        or a
        ret


; =====================================================================
;  TECLADO: letras A-Z
;  Linha 2 bits 6,7 = A,B ; linhas 3,4,5 = C..Z em sequencia
; =====================================================================
; -> A = letra recem pressionada, ou 0
GetLetter:
        ld a,2
        ld b,0x40
        call ChkEdge
        jr z,GLE_1
        ld a,'A'
        ret
GLE_1:  ld a,2
        ld b,0x80
        call ChkEdge
        jr z,GLE_2
        ld a,'B'
        ret
GLE_2:  ld a,'C'
        ld (glCh),a
        ld c,3
GLE_ROW:
        ld b,1
        ld e,0
GLE_BIT:
        push bc
        push de
        ld a,c
        call ChkEdge
        pop de
        pop bc
        jr nz,GLE_HIT
        ld a,(glCh)
        inc a
        ld (glCh),a
        sla b
        inc e
        ld a,e
        cp 8
        jr c,GLE_BIT
        inc c
        ld a,c
        cp 6
        jr c,GLE_ROW
        xor a
        ret
GLE_HIT:
        ld a,(glCh)
        ret


; =====================================================================
;  ALEATORIOS
; =====================================================================
Rnd:
        ld hl,(rng)
        ld d,h
        ld e,l
        ld b,7
RN1:    add hl,hl
        djnz RN1
        ld a,h
        xor d
        ld h,a
        ld a,l
        xor e
        ld l,a
        ld a,h
        srl a
        xor l
        ld l,a
        ld a,h
        xor l
        ld h,a
        ld a,h
        or l
        jr nz,RN2
        ld hl,0x1F35
RN2:    ld (rng),hl
        ld a,l
        ret


; =====================================================================
;  TEXTOS
; =====================================================================
TXT_ON:      db "ON",0
TXT_ON1:     db "APERTE ESPACO",0
TXT_CPU:     db "CPU",0
TXT_VDP:     db "VDP",0
TXT_ON2:     db "PARA LIGAR",0
TXT_SELECT:  db "SELECT GAME",0
TXT_OPT0:    db "0 ORIGINAL",0
TXT_OPT1:    db "1 MODERNO",0
TXT_OPT2:    db "SENHOR DAS",0
TXT_OPT3:    db "TREVAS",0
TXT_SETA:    db ">",0
TXT_NOME:    db "??????",0
TXT_PAUSA:   db "PAUSA",0
TXT_SAIR1:   db "VOLTAR AO MENU?",0
TXT_SAIR2:   db "S SIM  N NAO",0
TXT_VIDAS:   db "VIDAS",0
TXT_FIM:     db "FIM DE JOGO",0
TXT_TECLA:   db "APERTE ESPACO",0

#include "font.inc"
#include "o2.asm"
#include "o2dados.inc"
O2_ETAPAS equ 1+CF_N+ZF_N+HUD_NG
#include "o2m.asm"
#include "voz.inc"


; =====================================================================
;  RAM
; =====================================================================
        org 0xC000

c_sx:      ds 2
c_sy:      ds 2
c_dx:      ds 2
c_dy:      ds 2
c_nx:      ds 2
c_ny:      ds 2
c_clr:     ds 1
c_arg:     ds 1
c_cmd:     ds 1

fgByte:    ds 1
bgByte:    ds 1
txtX:      ds 1
txtY:      ds 1
rowBuf:    ds 8
numBuf:    ds 8
dcGlyph:   ds 2
dcAddr:    ds 2
csStr:     ds 2
csCol:     ds 2

rng:       ds 2
frameCnt:  ds 2
sfxPtr:    ds 2
sfxTimer:  ds 1
sndPrio:   ds 1
bgPtr:     ds 2

keyRow:    ds 12
keyEdge:   ds 12
skRow:     ds 1

modo:      ds 1

; ---------------- RAM do jogo ----------------
spI:       ds 1
spCol:     ds 1
spX:       ds 1
blSX:      ds 2
blSY:      ds 2
blW:       ds 1
blH:       ds 1
pgY:       ds 2
pgBase:    ds 2
pagina:    ds 1
shipP2X:   ds 1
shipP2Y:   ds 1

shipX:     ds 2
shipY:     ds 2
shipPX:    ds 1
shipPY:    ds 1
shipSpd:   ds 1
shipSpdY:  ds 1
aim:       ds 1
aimT:      ds 1
dirBits:   ds 1
charge:    ds 1
fieldSt:   ds 1
raspT:     ds 1
chgT:      ds 1
chgDelay:  ds 1
chgFirst:  ds 1
fireCd:    ds 1
engT:      ds 1
scanK:     ds 1

estado:    ds 1
vidas:     ds 1
fimTimer:  ds 2
morteT:    ds 1
morteQ:    ds 1               ; quadros desde a morte da nave (satura em 255)
nvK:       ds 1               ; fase da nuvem desenhada neste quadro (0xFF = nenhuma)
nvPK:      ds 1               ; ... no quadro anterior
nvP2K:     ds 1               ; ... ha 2 quadros (esta pagina): e a que se apaga
nvX:       ds 1
nvW:       ds 1
silCor:    ds 1               ; cor da silhueta/nuvem no formato do modo
flashCor:  ds 1
ptCor:     ds 1
spawnT:    ds 1
nEnem:     ds 1
score:     ds 2
recorde:   ds 2
nomeRec:   ds 8
nomeBuf:   ds 8
nomeI:     ds 1
nomeOpen:  ds 1
gapPos:    ds 1
gapT:      ds 1
hudDirty:  ds 1
hudPts:    ds 1
hudNome:   ds 1
hudGap:    ds 1
hudVidas:  ds 1               ; moderno: redesenhar as navezinhas (2 paginas)
gapPrev:   ds 1
hudRed:    ds 1
scanLetras: ds 1
barI:      ds 1
barFireT:  ds 1
barPar:    ds 1
barSpawnT: ds 2

enI:       ds 1
enJ:       ds 1
enTmp:     ds 1
; campos por inimigo, todos a menos de 128 bytes de enAct (IX = enAct + i):
; vx +12, vy +24, tipo +36, fx +48, posicao desenhada na pagina 0 (+60,+72)
; e na pagina 1 (+84,+96), apaga +108, cor +120; posicao em enX/enY
; (IY = enX + 2i, y em IY+24)
enAct:     ds 12
enVX:      ds 12
enVY:      ds 12
enTyp:     ds 12
enFX:      ds 12
enPX:      ds 12
enPY:      ds 12
enP2X:     ds 12
enP2Y:     ds 12
enErase:   ds 12
enCol:     ds 12
enX:       ds 24
enY:       ds 24
; lista compacta dos vivos, montada por MoveEnemies
enN:       ds 1
enLp:      ds 2
enLq:      ds 2
enLista:   ds 24
enLidx:    ds 12
enLtyp:    ds 12
evN:       ds 1
; anel: posicao inicial dos 3 pontos desenhados (0xFF = nenhum), por quadro
ringK:     ds 1
ringPK:    ds 1
ringP2K:   ds 1
spY:       ds 1
; modo moderno (G7)
pag8:      ds 1
stX:       ds 1
stY:       ds 1
stPal:     ds 2
stFase:    ds 1
stGrupo:   ds 1
stPasso:   ds 1               ; estrelas do fundo: passo entre as do mesmo quadro (5 ou 9)
enVis:     ds 72              ; por pagina e inimigo: x, y, chave do ultimo desenho
gradPtr:   ds 2
gradFlat:  ds 7
rowBuf8:   ds 14
dcY:       ds 1
sairJogo:  ds 1

msI:       ds 1
msTipo:    ds 1
; projeteis (IX = msAct + i): x +12, y +24, vx +36, vy +48, px +60, py +72,
; vida +84, apaga +96, p2x +108, p2y +120
msAct:     ds 12
msX:       ds 12
msY:       ds 12
msVX:      ds 12
msVY:      ds 12
msPX:      ds 12
msPY:      ds 12
msLife:    ds 12
msErase:   ds 12
msP2X:     ds 12
msP2Y:     ds 12

; particulas (IX = ptAct + i): x +14, y +28, vx +42, vy +56, px +70, py +84,
; apaga +98, p2x +112, p2y +126
ptI:       ds 1
ptAct:     ds 14
ptX:       ds 14
ptY:       ds 14
ptVX:      ds 14
ptVY:      ds 14
ptPX:      ds 14
ptPY:      ds 14
ptErase:   ds 14
ptP2X:     ds 14
ptP2Y:     ds 14

bmX:       ds 1
bmY:       ds 1
bmN:       ds 1
colX:      ds 1
colY:      ds 1
rhS:       ds 1
evA:       ds 1
evB:       ds 1
evX:       ds 1
evY:       ds 1
evTa:      ds 1               ; tipos do par que se encostou (estrela 0, circulo 1)
evTb:      ds 1
r0sh:      ds 1               ; copia do R#0 (modo de video) para ligar/desligar o IE1
bgOn:      ds 1               ; ruido lento tocando (interrupcao de linha ligada)
bgReg:     ds 2               ; registrador do ruido lento (16 bits)
bgN1:      ds 1               ; volume do canal A com o bit 1
bgN0:      ds 1               ; e com o bit 0
vozOn:     ds 1               ; a fala tocando (interrupcao de linha a cada 2 linhas)
vozPtr:    ds 2               ; proximo alofone da frase
WaitCmd:   ds 3               ; trampolim: jp WcRapido (normal) ou jp WcLento (ruido lento tocando)
frX:       ds 1
frY:       ds 1
frDir:     ds 1
frBase:    ds 1
flashX:    ds 1
flashY:    ds 1
flashT:    ds 1
flashE:    ds 1
flashPX:   ds 1
flashPY:   ds 1
fsX:       ds 1
fsY:       ds 1
drN:       ds 1
drS:       ds 1
drX:       ds 1
drY:       ds 1
glCh:      ds 1
invT:      ds 1
fsS:       ds 1               ; barra: modulo sorteado
fsM:       ds 1               ; barra: eixo maior
atrasado:  ds 1               ; a iteracao anterior passou de um quadro
econ:      ds 1               ; VDP lento: estrelas do fundo em quadros alternados
calCpu:    ds 2               ; calibragem: iteracoes da CPU por quadro
calVdp:    ds 2               ; calibragem: esperas de 16 HMMM de 14x12
msQuiet:   ds 1               ; quadros seguidos sem projetil vivo (ate 3)
ptQuiet:   ds 1               ; idem particulas
msN:       ds 1
ptN:       ds 1
; ---- Senhor das Trevas ----
nivel:     ds 1
abF:       ds 2
abVoz:     ds 1               ; a fala desta abertura ja saiu
abPtr:     ds 2
raioOn:    ds 1
raK:       ds 1
raBase:    ds 1
hudTxt:    ds 32              ; 16 glifos + 16 cores
hudSujo:   ds 1
hudRedo:   ds 1
hudDr:     ds 16
o2Etapa:   ds 1
estX:      ds 48*3            ; modo 1: estrelas (x, y, fase)
estI:      ds 1
zFig8:     ds 1
zCor8:     ds 1
zSrc8:     ds 2
hudX:      ds 1
; tabela virtual do i8244 (o2.asm): 12 caracteres, a figura ampliada, 4 figuras
vCh:       ds 48
vZ:        ds 4
vSp:       ds 16
vDrawn:    ds 13*6
vSpCor:    ds 4
o2f:       ds 1
o2c:       ds 1
odX:       ds 1
odY:       ds 1
odW:       ds 1
odH:       ds 1
odK:       ds 1
odSX:      ds 2
odSY:      ds 2
mkCor:     ds 1
mkRows:    ds 1
mkRep:     ds 1
mkN:       ds 1
mkK:       ds 1
mkBits:    ds 2
mkX:       ds 2
mkYv:      ds 2
mkHi:      ds 1
; estado do jogo (zerado a cada rodada, de jgIni a jgFim)
jgIni:
plX:       ds 1
plT:       ds 1
plDir:     ds 1
plAnda:    ds 1
plVivo:    ds 1
lzVoa:     ds 1
lzX:       ds 1
lzY:       ds 1
lzCor:     ds 1
esT:       ds 1
esX:       ds 1
esY:       ds 1
ptsAdd:    ds 1
ptsT:      ds 1
filaN:     ds 1
filaNasc:  ds 1
filaSaiu:  ds 1
congela:   ds 1
shX:       ds 1
shY:       ds 1
shDir:     ds 1
shDirVelha: ds 1
shTenta:   ds 1
shAnda:    ds 1
shCurva:   ds 1
shFase:    ds 1
shRapT:    ds 2
shVivo:    ds 8
rastroN:   ds 2
rastro:    ds 256
wpT:       ds 1
wpAlvo:    ds 1
wpTab:     ds 3*8
moT:       ds 1
fimT:      ds 1
jgFim:
RAM_FIM:
