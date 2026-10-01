; =====================================================================
;  JOGO: maquina de estados da rodada
;  ROSTO -> FENDA/COMBATE -> LIMPO -> (nivel+1) ... MORTE -> FIM
;
;  Tudo o que esta marcado PROVISORIO vem do manual e das resenhas
;  (PLANO.md, secao 1), nao da gravacao do console: e para trocar pelos
;  valores medidos na etapa 2.
;
;  Desenho: uma pagina so (a 0). Cada objeto e uma celula copiada da
;  pagina 1 (HMMM) com borda preta em volta do desenho, que apaga o
;  rastro de ate 2 pixels por quadro; o que salta mais (a nave que desce
;  uma fileira, o objeto que some) e apagado com HMMV. Todo x e par
;  (2 pixels por byte no SCREEN 5).
; =====================================================================

; ---- campo ----
HUD_Y      equ 2
FIELD_TOP  equ 20
GROUND_Y   equ 198             ; linha do chao (2 linhas)
PLY_Y      equ 184             ; topo da celula do canhao (16x12)
LZ_Y0      equ 168             ; topo da celula do laser quando sai
LZ_VEL     equ 6               ; PROVISORIO: "rapido"
ANIQ_Y     equ 186             ; aniquilador rolando no chao (topo da celula)
CHAO_LIM   equ 188             ; o que cai passa daqui: bateu no chao
FENDA_X    equ 122
FENDA_Y    equ 22
FENDA_BC   equ FENDA_X*256-4*256+FENDA_Y-6   ; B = x, C = y do retangulo da fenda
SHIP_Y0    equ 26              ; primeira fileira da fila
SHIP_YMAX  equ 122             ; ultima fileira
SHIP_DY    equ 12
SHIP_GAP   equ 16              ; distancia entre naves na fila (pixels)
X_MAX      equ 244             ; celula de 12: x de 0 a 242 (x par)

; ---- tamanhos das celulas ----
NAVE_W     equ 12
NAVE_H     equ 10
PLY_W      equ 16
PLY_H      equ 12
LZ_W       equ 4
LZ_H       equ 16

; ---- tabelas (8 bytes por objeto) ----
MAXSHIP    equ 16
MAXWPN     equ 8
MAXBOOM    equ 4
; nave: +0 ativa, +1 x, +2 y, +3 dx (+2/-2), +4 dy (+12/-12)
; arma: +0 tipo (0 = livre, 1..4), +1 x, +2 y, +3 estado (0 cai, 1 rola), +4 dir
; estouro: +0 quadros restantes, +1 x, +2 y
W_MISSIL   equ 1
W_MINA     equ 2
W_ANIQ     equ 3
W_NUCLEO   equ 4

; ---- regras (PROVISORIO: manual e resenhas) ----
VIDAS_INI  equ 3               ; as fontes divergem (uma vida x volta um nivel): medir
PT_NAVE    equ 5
BOOM_T     equ 10

PlayGame:
        xor a
        ld (scanLetras),a
        ld (sairJogo),a
        ld (faceOff),a
        call SndAllOff
        call UploadSprites
        ld hl,0
        ld (score),hl
        ld a,VIDAS_INI
        ld (vidas),a
        ld a,1
        ld (nivel),a
PG_RODADA:
        ld a,(faceOff)
        or a
        call z,Rosto
        ld a,(sairJogo)
        or a
        jr nz,PG_SAIR
PG_VIDA:
        call RodadaIni
        call Combate           ; A = 0 limpo, 1 morreu, 2 saiu
        cp 2
        jr z,PG_SAIR
        or a
        jr nz,PG_MORREU
        call Limpo
        ld a,(nivel)
        inc a                  ; 256 niveis: depois do 255 volta ao 1
        jr nz,PG_N
        inc a
PG_N:   ld (nivel),a
        jr PG_RODADA
PG_MORREU:
        call Morte
        ld a,(vidas)
        dec a
        ld (vidas),a
        jr nz,PG_VIDA          ; o mesmo nivel recomeca, sem o rosto
        call FimDeJogo
PG_SAIR:
        call SndAllOff
        ret

; ---------------------------------------------------------------------
;  figuras: ROM -> pagina 1 da VRAM (y = 256), celula i em x = 16i
; ---------------------------------------------------------------------
UploadSprites:
        call WaitCmd
        ld hl,SPRITES
        ld (upSrc),hl
        xor a
        ld (upI),a
US_FIG: ld b,16
        ld de,0                ; linha
US_LIN: push bc
        push de
        ; endereco = 0x8000 + linha*128 + i*8
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(upI)
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0x80
        add hl,de
        call SetWr
        ld hl,(upSrc)
        ld c,VDPDATA
        ld b,8
US_OUT: outi
        nop
        nop
        jr nz,US_OUT
        ld (upSrc),hl
        pop de
        inc de
        pop bc
        djnz US_LIN
        ld a,(upI)
        inc a
        ld (upI),a
        cp SPR_N
        jr c,US_FIG
        ret

; A = celula, B = x, C = y, D = largura, E = altura -> copia (HMMM)
DrawCell:
        push de
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (c_sx),hl
        ld hl,256
        ld (c_sy),hl
        ld l,b
        ld h,0
        ld (c_dx),hl
        ld l,c
        ld (c_dy),hl
        pop de
        ld l,d
        ld (c_nx),hl
        ld l,e
        ld (c_ny),hl
        jp CmdBlit

; B = x, C = y, D = largura, E = altura -> preto (HMMV)
EraseBox:
        xor a
; ... A = byte de cor (2 pixels)
FillBox:
        push af
        ld l,b
        ld h,0
        ld (c_dx),hl
        ld l,c
        ld (c_dy),hl
        ld l,d
        ld (c_nx),hl
        ld l,e
        ld (c_ny),hl
        pop af
        jp CmdFillB

; HL -> x, y, largura, altura (bytes) e a cor (byte de 2 pixels)
FillTabB:
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld a,(hl)
        jr FillBox

; ---------------------------------------------------------------------
;  ROSTO: o Senhor das Trevas aparece e "fala" (resmungo do chip).
;  0 desliga a transmissao (nao volta mais nesta partida). PROVISORIO:
;  o desenho, a duracao e o resmungo saem da gravacao 1.
; ---------------------------------------------------------------------
ROSTO_T    equ 180

Rosto:
        call ClearScreen
        ld hl,RO_CABECA
        call FillTabB
        ld hl,RO_CHIFRE1
        call FillTabB
        ld hl,RO_CHIFRE2
        call FillTabB
        ld hl,RO_OLHO1
        call FillTabB
        ld hl,RO_OLHO2
        call FillTabB
        ld hl,RO_PUPILA1
        call FillTabB
        ld hl,RO_PUPILA2
        call FillTabB
        ld hl,RO_NARIZ
        call FillTabB
        ld a,C_LRED
        ld b,C_BLACK
        call SetCols
        ld hl,TXT_OPT2
        ld c,150
        call PrintCenter
        ld hl,TXT_OPT3
        ld c,168
        call PrintCenter
        ld a,C_DGRAY
        ld b,C_BLACK
        call SetCols
        ld hl,TXT_DESLIGA
        ld c,194
        call PrintCenter
        ld hl,SFX_RESMUNGO
        call SndBg
        ld a,ROSTO_T
        ld (faceT),a
RO_L:   call WaitFrame
        call ScanKeys
        ld a,7
        ld b,0x04              ; ESC
        call ChkEdge
        jr nz,RO_ESC
        xor a
        ld b,0x01              ; tecla 0
        call ChkEdge
        jr nz,RO_ZERO
        ld a,(frameCnt)
        and 7
        call z,RoBoca
        ld a,(faceT)
        dec a
        ld (faceT),a
        jr nz,RO_L
        jp SndAllOff
RO_ZERO:
        ld a,1
        ld (faceOff),a
        jp SndAllOff
RO_ESC: ld a,1
        ld (sairJogo),a
        jp SndAllOff

; a boca abre e fecha ao acaso, como se falasse
RoBoca:
        ld hl,RO_BOCAFUNDO
        call FillTabB
        call Rnd
        and 14
        add a,2
        ld e,a                 ; altura
        ld b,104
        ld c,108
        ld d,48
        jp EraseBox

; x, y, largura, altura, cor
RO_CABECA:   db 80,36,96,100, 0x22
RO_CHIFRE1:  db 80,20,12,24, 0x99
RO_CHIFRE2:  db 164,20,12,24, 0x99
RO_OLHO1:    db 98,62,24,12, 0x00
RO_OLHO2:    db 134,62,24,12, 0x00
RO_PUPILA1:  db 106,64,8,8, 0xBB
RO_PUPILA2:  db 142,64,8,8, 0xBB
RO_NARIZ:    db 124,80,8,18, 0x99
RO_BOCAFUNDO: db 104,106,48,22, 0x22

; ---------------------------------------------------------------------
;  inicio de cada vida: campo limpo, chao, placar, fila vazia na fenda
; ---------------------------------------------------------------------
RodadaIni:
        call ClearScreen
        call SndAllOff
        ; chao
        ld bc,0*256+GROUND_Y
        ld de,128*256+2
        ld a,0x88
        call FillBox
        ld bc,128*256+GROUND_Y
        ld de,128*256+2
        ld a,0x88
        call FillBox
        ; tabelas zeradas
        ld hl,shTab
        ld de,shTab+1
        ld bc,MAXSHIP*8+MAXWPN*8+MAXBOOM*8-1
        ld (hl),0
        ldir
        xor a
        ld (lzAct),a
        ld (morreu),a
        ld (shipAcc),a
        ld (wAcc),a
        ld (plV),a
        ld a,120
        ld (plX),a
        ld a,SHIP_GAP
        ld (spDist),a          ; a primeira nave sai logo
        ; parametros do nivel (PROVISORIO: medir a tabela de niveis)
        ld a,(nivel)
        cp 10
        jr c,RI_N
        ld a,10                ; daqui para cima so muda a cor
RI_N:   ld c,a                 ; C = nivel limitado (1..10)
        add a,7
        cp MAXSHIP+1
        jr c,RI_1
        ld a,MAXSHIP
RI_1:   ld (toSpawn),a         ; naves: 8, 9, ... 16
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a                ; 16n
        ld b,a
        add a,112
        jr nc,RI_2
        ld a,255
RI_2:   ld (shipRate),a        ; passo de 2 px: 128/256 por quadro no nivel 1
        ld a,b                 ; 16n
        add a,96
        jr nc,RI_3
        ld a,255
RI_3:   ld (wRate),a           ; queda das armas
        ld a,c
        ld b,a
        add a,a
        add a,b
        add a,a                ; 6n
        ld b,a
        ld a,78
        sub b                  ; 72, 66, ... 18
        ld (dropReload),a
        ld (dropT),a
        ld a,c
        cp 5
        jr c,RI_4
        ld a,4                 ; depois do 4o nivel, todas as armas juntas
RI_4:   ld (maxType),a
        ld a,1
        ld (hudDirty),a
        call HudDraw
        jp DrawPlayer

; ---------------------------------------------------------------------
;  COMBATE: um quadro por volta. Sai com A = 0 (todas as naves mortas),
;  1 (o canhao foi atingido) ou 2 (ESC)
; ---------------------------------------------------------------------
Combate:
        call WaitFrame
        call ScanKeys
        ld a,7
        ld b,0x04              ; ESC volta ao menu
        call ChkEdge
        jr z,CO_1
        ld a,2
        ret
CO_1:   call MovePlayer
        call MoveLaser
        call Fenda
        call MoveShips
        call DropWeapon
        call MoveWeapons
        call LaserHits
        call MoveBooms
        ld a,(hudDirty)
        or a
        call nz,HudDraw
        ld a,(morreu)
        or a
        jr z,CO_2
        ld a,1
        ret
CO_2:   ld a,(toSpawn)
        or a
        jr nz,Combate
        call CountShips
        or a
        jr nz,Combate
        ret                    ; A = 0

; A = naves vivas
CountShips:
        ld hl,shTab
        ld de,8
        ld b,MAXSHIP
        xor a
CS_L:   bit 0,(hl)
        jr z,CS_N
        inc a
CS_N:   add hl,de
        djnz CS_L
        ret

; ---------------------------------------------------------------------
;  canhao (maquina do tempo): so anda na horizontal, 2 px por quadro
; ---------------------------------------------------------------------
MovePlayer:
        xor a
        ld (plV),a
        ld a,8
        ld b,0x10              ; esquerda
        call ChkDown
        jr z,MP_DIR
        ld a,(plX)
        cp 4
        jr c,DrawPlayer
        sub 2
        ld (plX),a
        ld a,-2
        ld (plV),a
        jr DrawPlayer
MP_DIR: ld a,8
        ld b,0x80              ; direita
        call ChkDown
        jr z,DrawPlayer
        ld a,(plX)
        cp 238
        jr nc,DrawPlayer
        add a,2
        ld (plX),a
        ld a,2
        ld (plV),a
DrawPlayer:
        ld a,(plX)
        ld b,a
        ld c,PLY_Y
        ld de,PLY_W*256+PLY_H
        ld a,SL_CANHAO
        jp DrawCell

; ---------------------------------------------------------------------
;  laser: um tiro na tela por vez
; ---------------------------------------------------------------------
MoveLaser:
        ld a,(lzAct)
        or a
        jr nz,ML_VOA
        ld a,8
        ld b,0x01              ; espaco / gatilho
        call ChkDown
        ret z
        ld a,1
        ld (lzAct),a
        ld a,(plX)
        add a,6
        ld (lzX),a
        ld a,LZ_Y0
        ld (lzY),a
        ld hl,SFX_TIRO
        ld a,2
        call SndPlay
        jr ML_DES
ML_VOA: ld a,(lzY)
        sub LZ_VEL
        ld (lzY),a
        cp FIELD_TOP
        jr nc,ML_DES
        ; chegou ao alto: apaga a celula de onde estava
        add a,LZ_VEL
        ld c,a
        ld a,(lzX)
        ld b,a
        ld de,LZ_W*256+LZ_H
        xor a
        ld (lzAct),a
        jp EraseBox
ML_DES: ld a,(lzX)
        ld b,a
        ld a,(lzY)
        ld c,a
        ld de,LZ_W*256+LZ_H
        ld a,SL_LASER
        jp DrawCell

; apaga o laser (acertou alguma coisa)
LaserOff:
        xor a
        ld (lzAct),a
        ld a,(lzX)
        ld b,a
        ld a,(lzY)
        ld c,a
        ld de,LZ_W*256+LZ_H
        jp EraseBox

; ---------------------------------------------------------------------
;  FENDA: enquanto ainda ha naves para sair, a fenda multicolorida
;  pisca no alto e solta uma nave a cada SHIP_GAP pixels de fila
; ---------------------------------------------------------------------
Fenda:
        ld a,(toSpawn)
        or a
        ret z
        ld a,(spDist)
        cp SHIP_GAP
        jr c,FE_COR
        ; procura uma vaga
        ld ix,shTab
        ld de,8
        ld b,MAXSHIP
FE_V:   ld a,(ix+0)
        or a
        jr z,FE_NOVA
        add ix,de
        djnz FE_V
        jr FE_COR
FE_NOVA:
        ld (ix+0),1
        ld (ix+1),FENDA_X
        ld (ix+2),SHIP_Y0
        ld (ix+3),2
        ld (ix+4),SHIP_DY
        xor a
        ld (spDist),a
        ld a,(toSpawn)
        dec a
        ld (toSpawn),a
        jr nz,FE_COR
        ; saiu a ultima: a fenda fecha
        ld bc,FENDA_BC
        ld de,20*256+6
        jp EraseBox
FE_COR: ; cor que gira a cada 2 quadros
        ld a,(frameCnt)
        rrca
        and 7
        ld l,a
        ld h,0
        ld de,FendaCores
        add hl,de
        ld a,(hl)
        ld bc,FENDA_BC
        ld de,20*256+4
        jp FillBox
FendaCores:
        db 0x99,0xBB,0xAA,0xEE,0xCC,0xDD,0xFF,0x44

; ---------------------------------------------------------------------
;  a fila: todas as naves seguem a mesma regra e saem da fenda uma
;  atras da outra, entao formam a cobra que serpenteia pelo alto. Anda
;  2 px de cada vez; na borda desce (ou sobe) uma fileira e volta.
; ---------------------------------------------------------------------
MoveShips:
        ld a,(shipRate)
        ld b,a
        ld a,(shipAcc)
        add a,b
        ld (shipAcc),a
        ret nc                 ; neste quadro a fila nao anda
        ld a,(spDist)
        add a,2
        jr nc,MS_D
        ld a,255
MS_D:   ld (spDist),a
        ld a,(nivel)
        and 1
        ld a,SL_NAVE
        jr nz,MS_F
        ld a,SL_NAVE2
MS_F:   ld (shipFig),a
        ld ix,shTab
        ld b,MAXSHIP
MS_L:   push bc
        ld a,(ix+0)
        or a
        jr z,MS_PROX
        ld a,(ix+1)
        add a,(ix+3)
        cp X_MAX
        jr c,MS_OK
        ; borda: apaga onde esta, troca de fileira e de sentido
        ld b,(ix+1)
        ld c,(ix+2)
        ld de,NAVE_W*256+NAVE_H
        call EraseBox
        ld a,(ix+3)
        neg
        ld (ix+3),a
        ld a,(ix+2)
        add a,(ix+4)
        cp SHIP_YMAX+1
        jr nc,MS_SOBE
        cp SHIP_Y0
        jr nc,MS_Y
        ; passou do alto: volta a descer
        ld (ix+4),SHIP_DY
        add a,SHIP_DY*2
        jr MS_Y
MS_SOBE:
        ld (ix+4),-SHIP_DY
        sub SHIP_DY*2
MS_Y:   ld (ix+2),a
        ld a,(ix+1)
MS_OK:  ld (ix+1),a
        ld b,a
        ld c,(ix+2)
        ld de,NAVE_W*256+NAVE_H
        ld a,(shipFig)
        call DrawCell
MS_PROX:
        ld de,8
        add ix,de
        pop bc
        djnz MS_L
        ret

; ---------------------------------------------------------------------
;  armas: uma nave sorteada solta uma arma a cada dropReload quadros.
;  Nivel 1 so misseis; cada nivel libera mais uma; do 4o em diante
;  todas (PROVISORIO: o manual)
; ---------------------------------------------------------------------
DropWeapon:
        ld a,(dropT)
        dec a
        ld (dropT),a
        ret nz
        ld a,(dropReload)
        ld (dropT),a
        ; vaga
        ld iy,wpTab
        ld de,8
        ld b,MAXWPN
DW_V:   ld a,(iy+0)
        or a
        jr z,DW_TEM
        add iy,de
        djnz DW_V
        ret
DW_TEM: ; nave sorteada: comeca num indice ao acaso e pega a primeira viva
        call Rnd
        and MAXSHIP-1
        ld c,a
        ld b,MAXSHIP
DW_N:   ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,shTab
        add hl,de
        ld a,(hl)
        or a
        jr nz,DW_ACHOU
        ld a,c
        inc a
        and MAXSHIP-1
        ld c,a
        djnz DW_N
        ret                    ; nenhuma nave viva
DW_ACHOU:
        inc hl
        ld a,(hl)
        ld (iy+1),a            ; x da nave
        inc hl
        ld a,(hl)
        add a,8
        ld (iy+2),a            ; logo abaixo dela
        ld (iy+3),0
        ld (iy+4),0
        ; tipo: 1..maxType ao acaso
        call Rnd
        and 3
        ld b,a
        ld a,(maxType)
        ld c,a
        ld a,b
DW_MOD: cp c
        jr c,DW_T
        sub c
        jr DW_MOD
DW_T:   inc a
        ld (iy+0),a
        ret

MoveWeapons:
        ; passo vertical deste quadro (2 px quando o acumulador estoura)
        ld a,(wRate)
        ld b,a
        ld a,(wAcc)
        add a,b
        ld (wAcc),a
        ld a,0
        rla
        ld (vPasso),a
        ld ix,wpTab
        ld b,MAXWPN
MW_L:   push bc
        ld a,(ix+0)
        or a
        jp z,MW_PROX
        cp W_ANIQ
        jr nz,MW_CAI
        ld a,(ix+3)
        or a
        jp nz,MW_ROLA
MW_CAI: ld a,(vPasso)
        or a
        jr z,MW_HOR
        ld a,(ix+2)
        add a,2
        ld (ix+2),a
MW_HOR: ld a,(ix+0)
        cp W_MINA
        jr z,MW_SEGUE
        cp W_NUCLEO
        jr nz,MW_CHAO
        ; matador nucleonico: mira onde o canhao VAI estar quando chegar
        ; ao chao (x + velocidade * quadros que faltam)
        ld a,(frameCnt)
        and 1
        jr nz,MW_CHAO
        ld a,CHAO_LIM
        sub (ix+2)             ; linhas que faltam (~ quadros, a 2 px por 2 quadros)
        srl a
        ld c,a
        ld a,(plV)
        or a
        ld a,(plX)
        jr z,MW_ALVO
        jp m,MW_ESQ
        add a,c
        jr nc,MW_ALVO
        ld a,236
        jr MW_ALVO
MW_ESQ: sub c
        jr nc,MW_ALVO
        xor a
MW_ALVO:
        add a,2                ; centro do canhao ~ centro da arma
        and 0xFE
        jr MW_VAI
MW_SEGUE:                      ; mina: segue o canhao
        ld a,(frameCnt)
        and 1
        jr nz,MW_CHAO
        ld a,(plX)
        add a,2
MW_VAI: cp (ix+1)
        jr z,MW_CHAO
        ld a,(ix+1)
        jr c,MW_V_E
        add a,2
        jr MW_V_X
MW_V_E: sub 2
MW_V_X: cp X_MAX
        jr nc,MW_CHAO
        ld (ix+1),a
MW_CHAO:
        ld a,(ix+2)
        cp CHAO_LIM
        jr c,MW_DES
        ld a,(ix+0)
        cp W_ANIQ
        jr nz,MW_SOME
        ; aniquilador: pousa e passa a rolar na direcao do canhao
        ld (ix+2),ANIQ_Y
        ld (ix+3),1
        ld a,(plX)
        add a,2
        cp (ix+1)
        ld a,2
        jr nc,MW_DIR
        ld a,-2
MW_DIR: ld (ix+4),a
        jr MW_DES
MW_ROLA:
        ld a,(ix+1)
        add a,(ix+4)
        cp X_MAX
        jr nc,MW_SOME          ; saiu pelo lado
        ld (ix+1),a
        jr MW_DES
MW_SOME:
        ; bateu no chao (ou saiu): apaga a celula
        ld b,(ix+1)
        ld c,(ix+2)
        ld de,NAVE_W*256+NAVE_H
        call EraseBox
        ld (ix+0),0
        ; o chao pode ter sido raspado pela borda da celula
        call RepaintGround
        jr MW_PROX
MW_DES: ld a,(ix+0)
        ld e,SL_MISSIL-1
        add a,e
        cp SL_ANIQ
        jr nz,MW_FIG
        ld a,(frameCnt)
        and 8
        ld a,SL_ANIQ
        jr z,MW_FIG
        ld a,SL_ANIQ2          ; os aniquiladores pulsam
MW_FIG: ld b,(ix+1)
        ld c,(ix+2)
        ld de,NAVE_W*256+NAVE_H
        call DrawCell
        ; encostou no canhao?
        ld a,(ix+2)
        cp PLY_Y-6
        jr c,MW_PROX
        ld a,(ix+1)
        ld hl,plX
        sub (hl)
        sub 2                  ; diferenca entre os centros
        jp p,MW_ABS
        neg
MW_ABS: cp 10
        jr nc,MW_PROX
        ld a,1
        ld (morreu),a
MW_PROX:
        ld de,8
        add ix,de
        pop bc
        dec b
        jp nz,MW_L
        ret

RepaintGround:
        ld a,(ix+1)
        and 0xF0
        ld b,a
        ld c,GROUND_Y
        ld de,32*256+2
        ld a,0x88
        jp FillBox

; ---------------------------------------------------------------------
;  laser contra naves e armas (o aniquilador so morre no ar)
; ---------------------------------------------------------------------
LaserHits:
        ld a,(lzAct)
        or a
        ret z
        ld ix,shTab
        ld b,MAXSHIP
LH_S:   ld a,(ix+0)
        or a
        jr z,LH_SP
        call LzToca
        jr nc,LH_SP
        ld (ix+0),0
        ld hl,PT_NAVE
        jp Acertou
LH_SP:  ld de,8
        add ix,de
        djnz LH_S
        ld ix,wpTab
        ld b,MAXWPN
LH_W:   ld a,(ix+0)
        or a
        jr z,LH_WP
        cp W_ANIQ
        jr nz,LH_W1
        ld a,(ix+3)
        or a
        jr nz,LH_WP            ; rolando no chao: o laser nao pega
LH_W1:  call LzToca
        jr nc,LH_WP
        ; pontos: 2, 4, 8, 16 conforme o tipo
        ld a,(ix+0)
        ld hl,1
LH_PT:  add hl,hl
        dec a
        jr nz,LH_PT
        ld (ix+0),0
        jp Acertou
LH_WP:  ld de,8
        add ix,de
        djnz LH_W
        ret

; IX = alvo (celula 12x10, desenho em x+2..x+9, y+2..y+7) -> C se o laser
; (x+1..x+2, y..y+7) encosta
LzToca:
        ld a,(lzX)
        sub (ix+1)
        cp 9
        ret nc
        ld a,(lzY)
        sub (ix+2)
        add a,5
        cp 13
        ret

; IX = alvo morto, HL = pontos
Acertou:
        ld de,(score)
        add hl,de
        ld (score),hl
        ld a,1
        ld (hudDirty),a
        call LaserOff
        ld b,(ix+1)
        ld c,(ix+2)
        ld de,NAVE_W*256+NAVE_H
        call EraseBox
        ; estouro no lugar
        ld iy,bmTab
        ld de,8
        ld b,MAXBOOM
AC_V:   ld a,(iy+0)
        or a
        jr z,AC_B
        add iy,de
        djnz AC_V
        jr AC_SOM
AC_B:   ld (iy+0),BOOM_T
        ld a,(ix+1)
        ld (iy+1),a
        ld a,(ix+2)
        ld (iy+2),a
AC_SOM: ld hl,SFX_ESTOURO
        ld a,3
        jp SndPlay

MoveBooms:
        ld ix,bmTab
        ld b,MAXBOOM
MB_L:   push bc
        ld a,(ix+0)
        or a
        jr z,MB_P
        dec a
        ld (ix+0),a
        ld b,(ix+1)
        ld c,(ix+2)
        ld de,NAVE_W*256+NAVE_H
        jr z,MB_APAGA
        ld a,SL_ESTOURO
        call DrawCell
        jr MB_P
MB_APAGA:
        call EraseBox
MB_P:   ld de,8
        add ix,de
        pop bc
        djnz MB_L
        ret

; ---------------------------------------------------------------------
;  placar: pontos a esquerda, vidas no meio, nivel a direita
; ---------------------------------------------------------------------
HudDraw:
        xor a
        ld (hudDirty),a
        ld a,C_WHITE
        ld b,C_BLACK
        call SetCols
        ld hl,(score)
        call Num5
        ld hl,numBuf
        ld bc,0*256+HUD_Y
        call PrintAt
        ld a,C_LCYAN
        ld b,C_BLACK
        call SetCols
        ld a,(vidas)
        add a,'0'
        ld (numBuf+1),a
        ld a,'V'
        ld (numBuf),a
        xor a
        ld (numBuf+2),a
        ld hl,numBuf
        ld bc,112*256+HUD_Y
        call PrintAt
        ld a,C_LYELLOW
        ld b,C_BLACK
        call SetCols
        ld a,(nivel)
        ld l,a
        ld h,0
        call Num5
        ld a,'N'
        ld (numBuf+1),a
        ld hl,numBuf+1
        ld bc,192*256+HUD_Y
        jp PrintAt

; HL -> numBuf: 5 digitos e 0
Num5:
        ld de,numBuf
        ld bc,-10000
        call N5D
        ld bc,-1000
        call N5D
        ld bc,-100
        call N5D
        ld bc,-10
        call N5D
        ld a,l
        add a,'0'
        ld (de),a
        inc de
        xor a
        ld (de),a
        ret
N5D:    ld a,'0'-1
N5D1:   inc a
        add hl,bc
        jr c,N5D1
        sbc hl,bc
        ld (de),a
        inc de
        ret

; ---------------------------------------------------------------------
;  LIMPO: a ultima nave caiu. Elogio/ameaca e o proximo nivel
; ---------------------------------------------------------------------
Limpo:
        call SndAllOff
        ld hl,SFX_ESCADA
        ld a,4
        call SndPlay
        ld a,C_LGREEN
        ld b,C_BLACK
        call SetCols
        ld hl,TXT_LIMPO1
        ld c,70
        call PrintCenter
        ld a,C_LRED
        ld b,C_BLACK
        call SetCols
        ld hl,TXT_LIMPO2
        ld c,96
        call PrintCenter
        ld b,120
        jp Delay

; ---------------------------------------------------------------------
;  MORTE: o canhao explode (o som de morte do console, 147 quadros)
; ---------------------------------------------------------------------
Morte:
        call SndAllOff
        ld hl,SFX_MORTE
        ld a,4
        call SndPlay
        ld a,150
        ld (faceT),a
MO_L:   call WaitFrame
        ; pisca: estouro / vazio, a cada 8 quadros
        ld a,(plX)
        ld b,a
        ld c,PLY_Y
        ld de,PLY_W*256+PLY_H
        call EraseBox
        ld a,(frameCnt)
        and 8
        jr z,MO_N
        ld a,(plX)
        add a,2
        ld b,a
        ld c,PLY_Y+1
        ld de,NAVE_W*256+NAVE_H
        ld a,SL_ESTOURO
        call DrawCell
MO_N:   ld a,(faceT)
        dec a
        ld (faceT),a
        jr nz,MO_L
        jp SndAllOff

; ---------------------------------------------------------------------
;  FIM DE JOGO: pontos, recorde e nome pelo teclado
; ---------------------------------------------------------------------
FimDeJogo:
        call ClearScreen
        ld a,C_LRED
        ld b,C_BLACK
        call SetCols
        ld hl,TXT_FIM
        ld c,30
        call PrintCenter
        ld a,C_WHITE
        ld b,C_BLACK
        call SetCols
        ld hl,(score)
        call Num5
        ld hl,numBuf
        ld c,60
        call PrintCenter
        ; bateu o recorde?
        ld hl,(recorde)
        ld de,(score)
        or a
        sbc hl,de
        jr nc,FJ_MOSTRA
        ld (recorde),de
        call PedeNome
FJ_MOSTRA:
        ld a,C_LYELLOW
        ld b,C_BLACK
        call SetCols
        ld hl,TXT_RECORDE
        ld c,140
        call PrintCenter
        ld hl,(recorde)
        call Num5
        ld hl,numBuf
        ld bc,48*256+162
        call PrintAt
        ld hl,nomeRec
        ld bc,144*256+162
        call PrintAt
        ld a,C_DGRAY
        ld b,C_BLACK
        call SetCols
        ld hl,TXT_TECLA
        ld c,194
        call PrintCenter
        xor a
        ld (scanLetras),a
        ld b,30
        call Delay
FJ_W:   call WaitFrame
        call ScanKeys
        ld a,8
        ld b,0x01
        call ChkEdge
        jr z,FJ_W
        ret

PedeNome:
        ld a,1
        ld (scanLetras),a
        ld a,C_LGREEN
        ld b,C_BLACK
        call SetCols
        ld hl,TXT_NOME1
        ld c,92
        call PrintCenter
        ld hl,nomeBuf
        ld b,7
PN_Z:   ld (hl),0
        inc hl
        djnz PN_Z
        xor a
        ld (nomeI),a
PN_L:   ; mostra o nome com tracos no que falta
        ld hl,nomeBuf
        ld de,rowBuf
        ld b,6
PN_C:   ld a,(hl)
        or a
        jr nz,PN_C1
        ld a,'-'
PN_C1:  ld (de),a
        inc hl
        inc de
        djnz PN_C
        xor a
        ld (de),a
        ld a,C_WHITE
        ld b,C_BLACK
        call SetCols
        ld hl,rowBuf
        ld bc,80*256+114
        call PrintAt
PN_W:   call WaitFrame
        call ScanKeys
        ld a,7
        ld b,0x80              ; RETURN
        call ChkEdge
        jr nz,PN_FIM
        ld a,7
        ld b,0x20              ; BS
        call ChkEdge
        jr nz,PN_BS
        call GetLetter
        or a
        jr z,PN_W
        ld c,a
        ld a,(nomeI)
        cp 6
        jr nc,PN_W
        ld e,a
        ld d,0
        ld hl,nomeBuf
        add hl,de
        ld (hl),c
        inc a
        ld (nomeI),a
        ld hl,SFX_SELECT
        ld a,1
        call SndPlay
        jr PN_L
PN_BS:  ld a,(nomeI)
        or a
        jr z,PN_W
        dec a
        ld (nomeI),a
        ld e,a
        ld d,0
        ld hl,nomeBuf
        add hl,de
        ld (hl),0
        jr PN_L
PN_FIM: ld a,(nomeI)
        or a
        jr z,PN_W              ; nome vazio nao vale
        ld hl,nomeBuf
        ld de,nomeRec
        ld bc,7
        ldir
        ret

; o resmungo do rosto sem o modulo The Voice: o chip recarregado quadro a
; quadro. PROVISORIO: o programa de verdade sai da gravacao 1 (etapa 3)
SFX_RESMUNGO:
        db 3, P_123&255,P_123>>8, 0,0, 0,0, 13,0,0, 0, MIXA
        db 2, P_164&255,P_164>>8, 0,0, 0,0, 14,0,0, 0, MIXA
        db 4, P_82&255,P_82>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 2, 0,0, 0,0, 0,0, 0,0,11, 28, 0x9F
        db 3, P_117&255,P_117>>8, 0,0, 0,0, 13,0,0, 0, MIXA
        db 5, 0,0, 0,0, 0,0, 0,0,0, 0, 0xBF
        db 0xFE
; tiro do canhao: PROVISORIO (medir na gravacao)
SFX_TIRO:
        db 1, P_1966&255,P_1966>>8, 0,0, 0,0, 15,0,0, 0, MIXA
        db 1, P_656&255,P_656>>8, 0,0, 0,0, 13,0,0, 0, MIXA
        db 1, P_328&255,P_328>>8, 0,0, 0,0, 11,0,0, 0, MIXA
        db 0xFF

TXT_DESLIGA: db "0 DESLIGA",0
TXT_LIMPO1:  db "MUITO BEM",0
TXT_LIMPO2:  db "MAS EU VOLTO",0
TXT_NOME1:   db "SEU NOME",0
TXT_RECORDE: db "RECORDE",0
