; =====================================================================
;  O JOGO, como o original faz (medidas em ref/MEDIDAS.md; as sequencias
;  fixas e os sons vem de ref/mame/medidas.json via tools/gen_o2.cjs)
;
;  A logica escreve na tabela virtual do i8244 (o2.asm): coordenadas e
;  cores do chip. Quem desenha e O2Draw (modo 0, SCREEN 5) ou O2Draw8
;  (modo 1, SCREEN 8).
;
;  Rodada: ABERTURA (tabela: raios, rosto, cruz; a fila nasce no quadro
;  AB_FILA e o canhao chega no AB_CANHAO) -> COMBATE -> ou a ultima nave
;  cai (o canhao fica livre 116 quadros e vem a abertura do proximo
;  nivel) ou o canhao e atingido (MORTE: 62 quadros; os pontos viram
;  recorde se passaram dele e a partida recomeca do nivel 1).
; =====================================================================

; ---- campo, em unidades do chip ----
PL_Y      equ 178              ; canhao (os dois caracteres) e o laser em repouso
PL_XMIN   equ 9
PL_XMAX   equ 137
LZ_TOPO   equ 34               ; o laser sobe de 178 a 34, 8 linhas por quadro
LZ_VEL    equ 8
FILA_X0   equ 78               ; a primeira nave sai da cruz aqui
FILA_Y0   equ 98
SH_XMIN   equ 6                ; a fila nunca sai deste retangulo (medido)
SH_XMAX   equ 148
SH_YMIN   equ 18
SH_YMAX   equ 150
SH_PASSO  equ 14               ; o lider decide a direcao a cada 14 unidades
SH_GAP    equ 10               ; cada nave anda 10 unidades atras da anterior
NSHIP     equ 8
NWPN      equ 3                ; armas no ar: as figuras 1, 2 e 3
ANIQ_CHAO equ 179
FIM_LIVRE equ 116              ; quadros entre a ultima nave e a nova abertura
RAPIDO_Q  equ 250              ; quadros a 2/quadro antes da velocidade de cruzeiro

; estados
E_ABERT   equ 0
E_COMB    equ 1
E_MORTE   equ 2
E_FIM     equ 3

; tipos de arma
W_MISSIL  equ 1
W_MINA    equ 2
W_ANIQ    equ 3
W_NUCL    equ 4

; slots da tabela virtual: caracteres 0..7 = naves, 8/9 = canhao, 0..7 = raios
SLOT_PL   equ 8

PlayGame:
        ld a,1
        ld (scanLetras),a      ; as letras do nome do recorde
        xor a
        ld (sairJogo),a
        call SndAllOff
        ld a,(modo)
        or a
        call z,O2Init
        ld a,(modo)
        or a
        call nz,O2Init8
        call NovaPartida
PG_Q:   call WaitFrame
        call ScanKeys
        ld a,7
        ld b,0x04              ; ESC volta ao menu
        call ChkEdge
        jr nz,PG_SAI
        call Quadro
        call Desenha
        jr PG_Q
PG_SAI: call SndAllOff
        call O2Off
        ret

Desenha:
        ld a,(modo)
        or a
        jr nz,DS_8
        call O2Draw
        jr DS_H
DS_8:   call O2Draw8
DS_H:   ld a,(hudRedo)
        or a
        ret z
        xor a
        ld (hudRedo),a
        ld hl,hudDr
        ld b,16
DS_Z:   ld (hl),0xFF
        inc hl
        djnz DS_Z
        call Caixa
        jp DesenhaPlacar

Caixa:  ld a,(modo)
        or a
        jp z,O2Caixa
        jp O2Caixa8

NovaPartida:
        ld hl,0
        ld (score),hl
        ld a,1
        ld (nivel),a
        call Caixa
        call DesenhaPlacar
NovaRodada:
        xor a
        ld (estado),a
        ld (abF),a
        ld (abF+1),a
        call O2Clear
        call ZeraJogo
        ld hl,SND_ABERTURA
        ld a,4
        jp SndPlay

ZeraJogo:
        ld hl,jgIni
        ld de,jgIni+1
        ld bc,jgFim-jgIni-1
        ld (hl),0
        ldir
        ld a,PL_XMIN/2+PL_XMAX/2
        ld (plX),a
        ld a,200               ; a primeira arma demora (medido: ~8 s depois da fila)
        ld (wpT),a
        ret

; ---------------------------------------------------------------------
Quadro:
        ; o nome do recorde e digitado a qualquer momento (como no original:
        ; cada letra ocupa a proxima das 6 posicoes)
        ld hl,keyEdge+2        ; so procura a letra se alguma linha de letras mudou
        ld a,(hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        jr z,QD_0
        call GetLetter
        or a
        jr z,QD_0
        ld c,a
        ld a,(nomeI)
        ld e,a
        ld d,0
        ld hl,nomeRec
        add hl,de
        ld (hl),c
        inc a
        cp 6
        jr c,QD_1
        xor a
QD_1:   ld (nomeI),a
        call DesenhaPlacar
QD_0:   ld a,(estado)
        cp E_ABERT
        jp z,QAbertura
        cp E_MORTE
        jp z,QMorte
        cp E_FIM
        jp z,QFim
        jp QCombate

; ---------------------------------------------------------------------
;  ABERTURA: a tabela manda nos raios, no rosto e na cruz
; ---------------------------------------------------------------------
QAbertura:
        ld hl,(abF)
        ld de,AB_N
        or a
        sbc hl,de
        jr c,QA_TAB
        ; a tabela acabou: o combate segue sozinho, com a marcha de fundo
        ld a,E_COMB
        ld (estado),a
        ld hl,SND_MARCHA
        call SndBg
        jp QCombate
QA_TAB: ld hl,(abF)
        add hl,hl
        add hl,hl
        ld de,AB_DAT
        add hl,de
        ld (abPtr),hl
        ; raios (so antes da fila)
        ld a,(hl)
        call Raios
        ; figura 0: rosto / ponto do centro (antes do canhao)
        ld hl,(abPtr)
        inc hl
        ld a,(hl)
        cp NO
        jr z,QA_S0
        ld (vSp+2),a
        ld a,90
        ld (vSp+0),a
        ld a,77
        ld (vSp+1),a
        ld a,1
        ld (vSp+3),a
        jr QA_S1
QA_S0:  ld a,(plVivo)
        or a
        jr nz,QA_S1            ; o canhao ja usa a figura 0
        ld a,NO
        ld (vSp+2),a
QA_S1:  ; figura 1: a cruz (normal no centro ou ampliada na fenda)
        ld hl,(abPtr)
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld c,(hl)
        ld (vZ+2),a            ; por padrao, nada ampliado
        cp NO
        jr z,QA_C0
        bit 7,c
        jr nz,QA_CZ
        ld (vSp+6),a
        ld a,90
        ld (vSp+4),a
        ld a,77
        ld (vSp+5),a
        ld a,c
        ld (vSp+7),a
        ld a,NO
        ld (vZ+2),a
        jr QA_C1
QA_CZ:  ld a,84
        ld (vZ+0),a
        ld a,72
        ld (vZ+1),a
        ld a,c
        and 7
        ld (vZ+3),a
        ld a,NO
        ld (vSp+6),a
        jr QA_C1
QA_C0:  ld a,NO
        ld (vSp+6),a
QA_C1:  ; a fila e o canhao entram nos quadros medidos
        ld hl,(abF)
        ld de,AB_FILA
        or a
        sbc hl,de
        jr c,QA_N
        jr nz,QA_F1
        call FilaNasce
QA_F1:  ld hl,(abF)
        ld de,AB_CANHAO
        or a
        sbc hl,de
        jr nz,QA_F2
        ld a,1
        ld (plVivo),a
        xor a
        ld (lzCor),a           ; o laser comeca cinza (cor 0), parado no canhao
QA_F2:  call Combate1          ; a fila anda (e, com o canhao, o resto)
QA_N:   ld hl,(abF)
        inc hl
        ld (abF),hl
        ret

; A = raio (k | base << 4) ou NO: os 8 raios em volta do centro
Raios:  cp NO
        jr nz,RA_ON
        ld a,(raioOn)
        or a
        ret z
        xor a
        ld (raioOn),a
        ld hl,vCh
        ld b,8
RA_OFF: ld (hl),NO
        inc hl
        inc hl
        ld (hl),NO
        inc hl
        inc hl
        djnz RA_OFF
        ret
RA_ON:  ld c,a
        and 7
        ld (raK),a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and 7
        ld (raBase),a
        ld a,1
        ld (raioOn),a
        ld ix,vCh
        ld hl,RAIO_TAB
        ld b,8
RA_L:   push bc
        ; y = y0 + dy*k ; x = x0 + dx*k ; figura ; cor = base + i
        ld a,(raK)
        ld e,a
        ld a,(hl)              ; y0
        inc hl
        ld d,(hl)              ; dy
        inc hl
        call MulAdd
        ld (ix+0),a
        ld a,(hl)              ; x0
        inc hl
        ld d,(hl)              ; dx
        inc hl
        call MulAdd
        ld (ix+1),a
        ld a,(hl)
        inc hl
        ld (ix+2),a
        pop bc
        ld a,8
        sub b
        ld c,a
        ld a,(raBase)
        add a,c
        and 7
        ld (ix+3),a
        ld de,4
        add ix,de
        djnz RA_L
        ret
; A = base, D = passo (com sinal), E = k -> A = base + passo * k
MulAdd: push bc
        ld b,e
        inc b
        jr MA_2
MA_1:   add a,d
MA_2:   djnz MA_1
        pop bc
        ret
; y0, dy, x0, dx, figura (os 8 raios: medidos, ver ref/MEDIDAS.md)
RAIO_TAB:
        db 114,8,   68,-4,  CF_ESQ
        db 114,8,   86,4,   CF_DIR
        db 70,-8,   68,-4,  CF_DIR
        db 70,-8,   86,4,   CF_ESQ
        db 92,0,    66,-6,  CF_HOR
        db 92,0,    88,6,   CF_HOR
        db 117,11,  77,0,   CF_VERT
        db 67,-11,  77,0,   CF_VERT

; ---------------------------------------------------------------------
;  COMBATE
; ---------------------------------------------------------------------
QCombate:
        call Combate1
        ; acabou a fila?
        ld a,(filaN)
        or a
        ret nz
        ld a,(filaSaiu)
        or a
        ret z
        ld a,E_FIM
        ld (estado),a
        xor a
        ld (fimT),a
        ret

; um quadro do combate (tambem roda durante a abertura, depois da fila nascer)
Combate1:
        call MoveFila
        ld a,(plVivo)
        or a
        ret z
        call MoveCanhao
        call MoveLaser
        call SoltaArma
        call MoveArmas
        call Acertos
        jp AtualizaPlacar

; ---------------------------------------------------------------------
;  A FILA
;  O lider anda numa das 8 direcoes; a cada SH_PASSO unidades decide virar
;  45 graus para um lado, para o outro, ou seguir. No primeiro quadro de
;  uma curva anda na direcao intermediaria. Cada ponto por onde passa vai
;  para o rastro; a nave i fica SH_GAP*i unidades atras. A cor de todas e a
;  direcao do lider (leste = 1, sentido horario).
; ---------------------------------------------------------------------
FilaNasce:
        ld a,NSHIP
        ld (filaN),a
        ld (filaNasc),a
        ld a,1
        ld (filaSaiu),a
        xor a
        ld (shDir),a           ; leste
        ld (shAnda),a
        ld (shRapT),a
        ld (shRapT+1),a
        ld (shFase),a
        ld (rastroN),a
        ld (rastroN+1),a
        ld a,FILA_X0
        ld (shX),a
        ld a,FILA_Y0
        ld (shY),a
        ; todas vivas, nenhuma ainda fora da cruz
        ld hl,shVivo
        ld b,NSHIP
FN_L:   ld (hl),1
        inc hl
        djnz FN_L
        ret

MoveFila:
        ld a,(filaSaiu)
        or a
        ret z
        ld a,(congela)
        or a
        jp nz,PoeNaves
        ; quantas unidades neste quadro: 1 enquanto a fila sai, depois 2 por
        ; RAPIDO_Q quadros, depois o cruzeiro do nivel (2,2,...,1)
        ld hl,(rastroN)
        ld de,SH_GAP*(NSHIP-1)+SH_PASSO
        or a
        sbc hl,de
        ld b,1
        jr c,MF_V
        ld hl,(shRapT)
        inc hl
        ld (shRapT),hl
        ld de,RAPIDO_Q
        or a
        sbc hl,de
        ld b,2
        jr c,MF_V
        ; cruzeiro: n passos de 2 e um de 1, n = nivel + 1 (ate 7)
        ld a,(nivel)
        cp 7
        jr c,MF_C1
        ld a,6
MF_C1:  inc a
        ld c,a
        ld a,(shFase)
        inc a
        cp c
        jr c,MF_C2
        jr z,MF_C2
        xor a
MF_C2:  ld (shFase),a
        cp c
        ld b,2
        jr nz,MF_V
        ld b,1
MF_V:   ; B unidades
MF_U:   push bc
        call PassoLider
        pop bc
        djnz MF_U
        jp PoeNaves

; o lider anda uma unidade (na diagonal, uma unidade em x e em y)
PassoLider:
        ld a,(shAnda)
        or a
        jr nz,PL_1
        call Decide
PL_1:   ld a,(shAnda)
        inc a
        ld (shAnda),a
        cp SH_PASSO
        jr c,PL_2
        xor a
        ld (shAnda),a
PL_2:   ; numa curva a primeira unidade ainda vai na direcao velha: o
        ; quadro da curva anda (2,1), como no original
        ld a,(shCurva)
        or a
        jr z,PL_3
        dec a
        ld (shCurva),a
        jr z,PL_3
        ld a,(shDirVelha)
        jr PL_3B
PL_3:   ld a,(shDir)
PL_3B:  add a,a                ; indice par da tabela de 16
PL_4:   add a,a
        ld l,a
        ld h,0
        ld de,DIR16
        add hl,de
        ld a,(shX)
        add a,(hl)
        ld (shX),a
        inc hl
        ld a,(shY)
        add a,(hl)
        ld (shY),a
        ; rastro: anel de 128 posicoes
        ld hl,(rastroN)
        inc hl
        ld (rastroN),hl
        ld a,l
        and 127
        add a,a
        ld l,a
        ld h,0
        ld de,rastro
        add hl,de
        ld a,(shX)
        ld (hl),a
        inc hl
        ld a,(shY)
        ld (hl),a
        ret

; escolhe a direcao do proximo trecho: esquerda, direita ou reto, sem sair
; do retangulo da fila
Decide: ld a,(shDir)
        ld (shDirVelha),a
        call Rnd
        and 3                  ; 0 reto, 1 esquerda, 2 direita, 3 reto
        ld c,0
        cp 1
        jr nz,DE_1
        ld c,-1
DE_1:   cp 2
        jr nz,DE_2
        ld c,1
DE_2:   ld a,(filaNasc)
        or a
        jr z,DE_3
        ; enquanto sai da cruz: o primeiro trecho e reto para o leste
        ld hl,(rastroN)
        ld a,h
        or a
        jr nz,DE_3
        ld a,l
        cp SH_PASSO
        jr nc,DE_3
        ld c,0
DE_3:   ld b,3                 ; tenta ate 3 vezes ficar dentro
DE_T:   ld a,(shDir)
        add a,c
        and 7
        ld (shTenta),a
        call Cabe
        jr nc,DE_OK
        ; nao cabe: vira para o outro lado
        ld a,c
        or a
        jr nz,DE_4
        ld c,1
        jr DE_5
DE_4:   neg
        ld c,a
        ld a,b
        cp 2
        jr nz,DE_5
        sla c                  ; meia volta
DE_5:   djnz DE_T
DE_OK:  ld a,(shTenta)
        ld (shDir),a
        ld e,a
        ld a,(shDirVelha)
        cp e
        ret z
        ld a,2
        ld (shCurva),a
        ret

; NC se um trecho de SH_PASSO na direcao (shTenta) fica no retangulo
Cabe:   push bc
        call Cabe1
        pop bc
        ret
Cabe1:  ld a,(shTenta)
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,DIR16
        add hl,de
        ld a,(hl)              ; dx (-1, 0, 1)
        ld d,a
        inc hl
        ld e,(hl)              ; dy
        ld a,(shX)
        ld b,SH_PASSO
CB_X:   add a,d
        djnz CB_X
        cp SH_XMIN
        jr c,CB_NAO
        cp SH_XMAX+1
        jr nc,CB_NAO
        ld a,(shY)
        ld b,SH_PASSO
CB_Y:   add a,e
        djnz CB_Y
        cp SH_YMIN
        jr c,CB_NAO
        cp SH_YMAX+1
        jr nc,CB_NAO
        or a
        ret
CB_NAO: scf
        ret

; 16 direcoes (leste = 0, sentido horario): dx, dy por unidade de rastro
; nas pares; as impares sao as intermediarias das curvas (meio passo)
DIR16:  db 1,0,   1,0,   1,1,   0,1,   0,1,   0,1,   -1,1,  -1,0
        db -1,0,  -1,0,  -1,-1, 0,-1,  0,-1,  0,-1,  1,-1,  1,0
; (indice = direcao * 2 nas pares; as entradas impares fazem a meia curva:
;  leste->sudeste anda (1,0) e (1,1) alternados, como o (2,1) do original)

; poe as naves vivas na tabela virtual (caracteres 0..7)
PoeNaves:
        ld ix,vCh
        ld iy,shVivo
        ld b,0                 ; i
PN_L:   ld a,(iy+0)
        or a
        jr z,PN_OFF
        ; posicao: rastro[n - GAP*i] (so se a nave ja saiu da cruz)
        ld a,b
        ld e,a
        ld d,0
        ld hl,GAP_TAB
        add hl,de
        ld e,(hl)              ; GAP * i
        ld d,0
        ld hl,(rastroN)
        or a
        sbc hl,de
        jr c,PN_OFF            ; ainda dentro da cruz
        jr z,PN_OFF
        ld a,l
        and 127
        add a,a
        ld l,a
        ld h,0
        ld de,rastro
        add hl,de
        ld a,(hl)
        ld (ix+1),a
        inc hl
        ld a,(hl)
        ld (ix+0),a
        ld (ix+2),CF_NAVE
        ld a,(shDir)
        inc a
        and 7
        ld (ix+3),a
        jr PN_N
PN_OFF: ld (ix+2),NO
PN_N:   ld de,4
        add ix,de
        inc iy
        inc b
        ld a,b
        cp NSHIP
        jr c,PN_L
        ret

GAP_TAB: db 0, SH_GAP, SH_GAP*2, SH_GAP*3, SH_GAP*4, SH_GAP*5, SH_GAP*6, SH_GAP*7

; ---------------------------------------------------------------------
;  O CANHAO: so anda na horizontal; acelera segurando (1/quadro nos 8
;  primeiros, depois +1 a cada 4, ate 7); parado ao soltar
; ---------------------------------------------------------------------
MoveCanhao:
        ld a,8
        ld b,0x10              ; esquerda (teclado ou joystick)
        call ChkDown
        ld c,-1
        jr nz,MC_1
        ld a,8
        ld b,0x80              ; direita
        call ChkDown
        ld c,1
        jr nz,MC_1
        xor a
        ld (plT),a
        ld (plDir),a
        jr MC_DES
MC_1:   ld a,(plDir)
        cp c
        jr z,MC_2
        ld a,c
        ld (plDir),a
        xor a
        ld (plT),a
MC_2:   ld a,(plT)
        inc a
        jr z,MC_3
        ld (plT),a
MC_3:   ; velocidade: 1 ate o quadro 8, depois 1 + (t - 8)/4 + 1, ate 7
        ld a,(plT)
        sub 9
        ld b,1
        jr c,MC_4
        srl a
        srl a
        add a,2
        cp 8
        jr c,MC_5
        ld a,7
MC_5:   ld b,a
MC_4:   ld a,(plX)
        bit 7,c
        jr nz,MC_ESQ
        add a,b
        cp PL_XMAX+1
        jr c,MC_X
        ld a,PL_XMAX
        jr MC_X
MC_ESQ: sub b
        jr c,MC_MIN
        cp PL_XMIN
        jr nc,MC_X
MC_MIN: ld a,PL_XMIN
MC_X:   ld (plX),a
        ld a,1
        ld (plAnda),a
        jr MC_D2
MC_DES: xor a
        ld (plAnda),a
MC_D2:  ; os dois caracteres verdes: "/" e "\"
        ld ix,vCh+SLOT_PL*4
        ld (ix+0),PL_Y
        ld a,(plX)
        ld (ix+1),a
        ld (ix+2),CF_ESQ
        ld (ix+3),2
        ld (ix+4),PL_Y
        add a,9
        ld (ix+5),a
        ld (ix+6),CF_DIR
        ld (ix+7),2
        ret

; ---------------------------------------------------------------------
;  O LASER (figura 0): parado no centro do canhao, sobe 8 linhas por
;  quadro ate a linha 34 e volta; um tiro por vez. Parado e andando, a
;  figura alterna com o jato (o "chafariz") a cada quadro.
; ---------------------------------------------------------------------
MoveLaser:
        ld a,(esT)
        or a
        jp nz,LaserEstouro
        ld a,(lzVoa)
        or a
        jr nz,ML_VOA
        ; parado: segue o canhao
        ld a,(plX)
        add a,4
        ld (lzX),a
        ld a,PL_Y
        ld (lzY),a
        ld a,8
        ld b,0x01              ; espaco / gatilho
        call ChkDown
        jr z,ML_PARADO
        ld a,1
        ld (lzVoa),a
        ld a,7
        ld (lzCor),a
        ld hl,SND_TIRO
        ld a,2
        call SndPlay
ML_VOA: ld a,(lzY)
        sub LZ_VEL
        ld (lzY),a
        cp LZ_TOPO
        jr nc,ML_DES
        ; chegou ao alto: volta ao canhao
        xor a
        ld (lzVoa),a
        ld a,(plX)
        add a,4
        ld (lzX),a
        ld a,PL_Y
        ld (lzY),a
ML_PARADO:
        ld a,(plAnda)
        or a
        ld a,SF_LASER
        jr z,ML_FIG
        ld a,(frameCnt)
        and 1
        ld a,SF_LASER
        jr z,ML_FIG
        ld a,SF_JATO
ML_FIG: ld (vSp+2),a
        jr ML_POS
ML_DES: ld a,SF_LASER
        ld (vSp+2),a
ML_POS: ld a,(lzY)
        ld (vSp+0),a
        ld a,(lzX)
        ld (vSp+1),a
        ld a,(lzCor)
        ld (vSp+3),a
        ret

; o estouro de uma nave: a figura 0 fica no lugar do acerto e passa pela
; tabela medida (31 quadros); so entao o laser volta ao canhao
LaserEstouro:
        ld a,(esT)
        dec a
        ld (esT),a
        jr z,LE_FIM
        ld a,(esT)
        ld c,a
        ld a,ES_N-1
        sub c                  ; indice 0..ES_N-2
        add a,a
        ld l,a
        ld h,0
        ld de,ES_DAT
        add hl,de
        ld a,(hl)
        ld (vSp+2),a
        inc hl
        ld a,(hl)
        ld (vSp+3),a
        ld a,(esY)
        ld (vSp+0),a
        ld a,(esX)
        ld (vSp+1),a
        ret
LE_FIM: xor a
        ld (lzVoa),a
        ld a,7
        ld (lzCor),a
        ret

; ---------------------------------------------------------------------
;  AS ARMAS DAS NAVES (figuras 1..3)
;  Nivel 1: misseis. Nivel 2: minas. Nivel 3: aniquiladores. Do 4o em
;  diante, matadores nucleonicos. Cada nivel solta sobretudo a arma nova
;  (3 de 4) e as antigas de vez em quando (medido nos niveis 1 a 3).
; ---------------------------------------------------------------------
SoltaArma:
        ld a,(congela)
        or a
        ret nz
        ld a,(wpT)
        or a
        jr z,SA_1
        dec a
        ld (wpT),a
        ret
SA_1:   ; proxima: entre 40 e 167 quadros, menos a cada nivel
        call Rnd
        and 127
        add a,40
        ld c,a
        ld a,(nivel)
        cp 6
        jr c,SA_2
        ld a,6
SA_2:   add a,a
        add a,a
        add a,a                ; 8 * nivel
        ld b,a
        ld a,c
        sub b
        jr nc,SA_3
        ld a,12
SA_3:   ld (wpT),a
        ; vaga
        ld ix,wpTab
        ld b,NWPN
SA_V:   ld a,(ix+0)
        or a
        jr z,SA_TEM
        ld de,8
        add ix,de
        djnz SA_V
        ret
SA_TEM: ; nave viva ao acaso
        call Rnd
        and 7
        ld c,a
        ld b,NSHIP
SA_N:   ld a,c
        ld e,a
        ld d,0
        ld hl,shVivo
        add hl,de
        ld a,(hl)
        or a
        jr z,SA_N2
        ld hl,vCh
        add hl,de
        add hl,de
        add hl,de
        add hl,de
        inc hl
        inc hl
        ld a,(hl)
        cp NO
        jr nz,SA_ACHOU
SA_N2:  ld a,c
        inc a
        and 7
        ld c,a
        djnz SA_N
        ret
SA_ACHOU:
        dec hl
        ld a,(hl)
        ld (ix+2),a            ; x da nave
        dec hl
        ld a,(hl)
        add a,4
        ld (ix+1),a            ; y logo abaixo dela
        ; tipo
        ld a,(nivel)
        cp 5
        jr c,SA_T1
        ld a,4
SA_T1:  ld c,a                 ; a mais nova
        call Rnd
        and 3
        jr nz,SA_T2            ; 3 de 4: a nova
        call Rnd
        and 3
        inc a
        cp c
        jr c,SA_T2B
        jr z,SA_T2B
SA_T2:  ld a,c
SA_T2B: ld (ix+0),a
        xor a
        ld (ix+3),a            ; estado (aniquilador: 1 = rola)
        ld (ix+4),a            ; quadro
        ld hl,SND_ARMA
        ld a,1
        jp SndPlay

; tabela de armas: +0 tipo, +1 y, +2 x, +3 estado, +4 quadro, +5 direcao
MoveArmas:
        ld a,(congela)
        or a
        ret nz
        ld ix,wpTab
        ld iy,vSp+4
        ld b,NWPN
MA_L:   push bc
        ld a,(ix+0)
        or a
        jp z,MA_OFF
        inc (ix+4)
        cp W_MISSIL
        jr nz,MA_MINA
        ; missil: cai 2 por quadro; a forma troca a cada 3 quadros
        ld a,(ix+1)
        add a,2
        ld (ix+1),a
        ld a,(ix+4)
        ld c,3
        call Div
        and 1
        ld a,SF_MISSIL
        jr z,MA_F1
        ld a,SF_MISSIL2
MA_F1:  ld c,7
        jp MA_CHAO
MA_MINA:
        cp W_MINA
        jr nz,MA_ANIQ
        ; mina: cai 1 por quadro e anda 1 para o lado do canhao em 2 de 3
        inc (ix+1)
        call Segue23
        ld a,(ix+4)
        and 4
        ld a,SF_PONTO
        ld c,1
        jr z,MA_F2
        ld a,SF_PONTO2
        ld c,3
MA_F2:  jp MA_CHAO
MA_ANIQ:
        cp W_ANIQ
        jr nz,MA_NUCL
        ; aniquilador: cai 1 por quadro; no chao rola meio passo por quadro
        ; na direcao do canhao (some depois de ~4 s rolando); pulsa verde/amarelo
        ld a,(ix+3)
        or a
        jr nz,MA_ROLA
        inc (ix+1)
        ld a,(ix+1)
        cp ANIQ_CHAO
        jr c,MA_AF
        ld (ix+1),ANIQ_CHAO
        ld (ix+3),1
        jr MA_AF
MA_ROLA:
        inc (ix+3)
        jr nz,MA_R1
        ld (ix+0),0            ; rolou demais: some
        jp MA_OFF
MA_R1:  ld a,(ix+4)
        and 1
        jr nz,MA_AF
        ld a,(plX)
        add a,5
        ld (wpAlvo),a
        call Anda1
MA_AF:  ld a,(ix+4)
        rrca
        and 3
        add a,SF_ANIQ
        ld b,a
        ld a,(ix+4)
        rrca
        rrca
        rrca
        and 1
        add a,2                ; cor 2 / 3
        ld c,a
        ld a,b
        ld e,(ix+3)
        inc e
        dec e
        jp nz,MA_FIM           ; rolando nao some no chao
        jr MA_CHAO
MA_NUCL:
        ; matador nucleonico: cai 1 por quadro e mira onde o canhao vai estar
        ; (o x dele mais a velocidade vezes os quadros que faltam), 1 de lado
        ; em 2 de cada 3 quadros
        inc (ix+1)
        ld a,PL_Y
        sub (ix+1)
        jr c,MA_N2
        srl a
        srl a                  ; quadros que faltam / 4
        ld c,a
        ld a,(plAnda)
        or a
        ld a,(plX)
        jr z,MA_N1
        ld b,a
        ld a,(plDir)
        bit 7,a
        ld a,b
        jr nz,MA_NE
        add a,c
        jr c,MA_NX
        cp PL_XMAX
        jr c,MA_N1
MA_NX:  ld a,PL_XMAX
        jr MA_N1
MA_NE:  sub c
        jr c,MA_NM
        cp PL_XMIN
        jr nc,MA_N1
MA_NM:  ld a,PL_XMIN
MA_N1:  add a,5
        ld (wpAlvo),a
        call Segue23B
MA_N2:  ld a,(ix+4)
        and 4
        ld a,SF_NUCL
        jr z,MA_F4
        ld a,SF_NUCL2
MA_F4:  ld c,7
MA_CHAO:
        ; o que cai some ao chegar ao chao
        ld b,a
        ld a,(ix+1)
        cp PL_Y+1              ; medido: o que cai some na linha 178-179
        ld a,b
        jr c,MA_FIM
        ld (ix+0),0
        jr MA_OFF
MA_FIM: ld (iy+2),a
        ld (iy+3),c
        ld a,(ix+1)
        ld (iy+0),a
        ld a,(ix+2)
        ld (iy+1),a
        jr MA_N
MA_OFF: ld (iy+2),NO
MA_N:   ld de,8
        add ix,de
        ld de,4
        add iy,de
        pop bc
        dec b
        jp nz,MA_L
        ret

; anda 1 para o lado do canhao em 2 de cada 3 quadros
Segue23:
        ld a,(plX)
        add a,5
        ld (wpAlvo),a
Segue23B:
        ld a,(ix+4)
        ld c,3
        call Div
        or a
        ret z                  ; 1 de cada 3: parado
; um passo de (ix+2) para (wpAlvo)
Anda1:  ld a,(wpAlvo)
        cp (ix+2)
        ret z
        ld a,(ix+2)
        jr c,S23_E
        inc a
        jr S23_X
S23_E:  dec a
S23_X:  ld (ix+2),a
        ret

; A mod C -> A (A < 256)
Div:    sub c
        jr nc,Div
        add a,c
        ret

; ---------------------------------------------------------------------
;  ACERTOS: o laser contra as naves (5 pontos) e contra as armas no ar
;  (missil 2, mina 4, aniquilador 8, nucleonico 16); as armas contra o canhao
; ---------------------------------------------------------------------
Acertos:
        ld a,(lzVoa)
        or a
        jp z,AC_ARMAS
        ld a,(esT)
        or a
        jp nz,AC_ARMAS
        ; laser: coluna x+4 (linhas y..y+15)
        ld ix,vCh
        ld iy,shVivo
        ld b,NSHIP
AC_S:   ld a,(iy+0)
        or a
        jr z,AC_SN
        ld a,(ix+2)
        cp NO
        jr z,AC_SN
        ; |lzX + 4 - (navX + 4)| < 5 e as linhas se cruzam (nave: y..y+3)
        ld a,(lzX)
        add a,4                ; a coluna do laser
        sub (ix+1)
        cp 8
        jr nc,AC_SN
        ld a,(lzY)
        ld c,a
        ld a,(ix+0)
        add a,4
        sub c
        jr c,AC_SN
        cp 20
        jr nc,AC_SN
        ; acertou a nave
        ld (iy+0),0
        ld (ix+2),NO
        ld a,(filaN)
        dec a
        ld (filaN),a
        ld a,(lzY)
        ld (esY),a
        ld a,(lzX)
        ld (esX),a
        ld a,ES_N
        ld (esT),a
        ld a,2
        ld (ptsAdd),a          ; +2 agora e +3 em 4 quadros (como o original)
        ld a,4
        ld (ptsT),a
        ld hl,SND_ESTOURO
        ld a,3
        call SndPlay
        jp AC_ARMAS
AC_SN:  ld de,4
        add ix,de
        inc iy
        djnz AC_S
        ; armas no ar
        ld ix,wpTab
        ld b,NWPN
AC_W:   ld a,(ix+0)
        or a
        jr z,AC_WN
        cp W_ANIQ
        jr nz,AC_W1
        ld a,(ix+3)
        or a
        jr nz,AC_WN            ; rolando no chao: o laser nao pega
AC_W1:  ld a,(lzX)
        add a,4
        sub (ix+2)
        cp 8
        jr nc,AC_WN
        ld a,(lzY)
        ld c,a
        ld a,(ix+1)
        add a,14
        sub c
        jr c,AC_WN
        cp 30
        jr nc,AC_WN
        ; pontos: 2, 4, 8, 16
        ld a,(ix+0)
        ld c,1
AC_P:   sla c
        dec a
        jr nz,AC_P
        ld a,c
        call SomaPontos
        ld (ix+0),0
        xor a
        ld (lzVoa),a
        ld hl,SND_TIRO
        ld a,2
        call SndPlay
        jr AC_ARMAS
AC_WN:  ld de,8
        add ix,de
        djnz AC_W
AC_ARMAS:
        ; as armas contra o canhao (caixa do triangulo: x..x+17, linhas 178..191)
        ld ix,wpTab
        ld b,NWPN
AC_C:   ld a,(ix+0)
        or a
        jr z,AC_CN
        ld a,(ix+1)
        add a,12
        cp PL_Y
        jr c,AC_CN
        ld a,(ix+2)
        add a,6
        ld c,a
        ld a,(plX)
        ld d,a
        ld a,c
        sub d
        jr c,AC_CN
        cp 20
        jr nc,AC_CN
        jp Morre
AC_CN:  ld de,8
        add ix,de
        djnz AC_C
        ret

SomaPontos:
        ld e,a
        ld d,0
        ld hl,(score)
        add hl,de
        ld (score),hl
        ld a,1
        ld (hudSujo),a
        ret

; os 5 pontos da nave entram em dois passos (+2 e, 4 quadros depois, +3)
AtualizaPlacar:
        ld a,(ptsAdd)
        or a
        jr z,AP_1
        call SomaPontos
        xor a
        ld (ptsAdd),a
AP_1:   ld a,(ptsT)
        or a
        jr z,AP_2
        dec a
        ld (ptsT),a
        jr nz,AP_2
        ld a,3
        call SomaPontos
AP_2:   ld a,(hudSujo)
        or a
        ret z
        xor a
        ld (hudSujo),a
        jp DesenhaPlacar

; ---------------------------------------------------------------------
;  FIM DO NIVEL: o canhao ainda anda e atira; depois tudo some
; ---------------------------------------------------------------------
QFim:   call Combate1
        ld a,(fimT)
        inc a
        ld (fimT),a
        cp FIM_LIVRE
        ret c
        ld a,(nivel)
        inc a
        jr nz,QF_1
        inc a                  ; 256 niveis: depois do 255 volta ao 1
QF_1:   ld (nivel),a
        jp NovaRodada

; ---------------------------------------------------------------------
;  MORTE: a fila congela; o estouro medido (62 quadros) no lugar do canhao
; ---------------------------------------------------------------------
Morre:  ld a,E_MORTE
        ld (estado),a
        ld a,1
        ld (congela),a
        xor a
        ld (moT),a
        ld (esT),a
        ld (lzVoa),a
        ; o canhao e as armas somem
        ld a,NO
        ld (vCh+SLOT_PL*4+2),a
        ld (vCh+SLOT_PL*4+6),a
        ld (vSp+6),a
        ld (vSp+10),a
        ld (vSp+14),a
        ld hl,wpTab
        ld b,NWPN*8
MO_Z:   ld (hl),0
        inc hl
        djnz MO_Z
        call SndBgOff
        ld hl,SND_MORTE
        ld a,4
        jp SndPlay

QMorte: ld a,(moT)
        cp MO_N
        jr nc,QM_FIM
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,MO_DAT
        add hl,de
        ld a,(hl)
        ld (vSp+2),a
        inc hl
        ld a,(hl)
        ld (vSp+3),a
        ld a,PL_Y
        ld (vSp+0),a
        ld a,(plX)
        add a,4
        ld (vSp+1),a
        inc hl
        ld a,(hl)
        ld (vZ+2),a
        inc hl
        ld a,(hl)
        ld (vZ+3),a
        ld a,169
        ld (vZ+0),a
        ld a,(plX)
        ld (vZ+1),a
        ld a,(moT)
        inc a
        ld (moT),a
        ret
QM_FIM: ; recorde e partida nova
        ld hl,(recorde)
        ld de,(score)
        or a
        sbc hl,de
        jr nc,QM_1
        ld (recorde),de
QM_1:   jp NovaPartida

; ---------------------------------------------------------------------
;  PLACAR: RRRR>?????? PPPP (recorde amarelo, seta vermelha, nome amarelo,
;  pontos brancos), nos quatro quadros de texto do chip
; ---------------------------------------------------------------------
DesenhaPlacar:
        ld hl,(recorde)
        call Num4
        ld de,hudTxt
        ld hl,numBuf
        ld bc,4
        ldir
        ld a,11                ; ">"
        ld (de),a
        inc de
        ld hl,nomeRec
        ld b,6
DP_N:   ld a,(hl)
        call AscGlifo
        ld (de),a
        inc de
        inc hl
        djnz DP_N
        ld a,12                ; espaco
        ld (de),a
        inc de
        push de
        ld hl,(score)
        call Num4
        pop de
        ld hl,numBuf
        ld bc,4
        ldir
        ld hl,HUD_CORES
        ld de,hudTxt+16
        ld bc,16
        ldir
        ld hl,hudTxt
        ld a,(modo)
        or a
        jp z,O2Hud
        jp O2Hud8

; HL -> numBuf: 4 digitos (indices de glifo 0..9), mod 10000
Num4:   ld de,numBuf
        ld bc,-10000
N4_0:   add hl,bc
        jr c,N4_0
        sbc hl,bc
        ld bc,-1000
        call N4D
        ld bc,-100
        call N4D
        ld bc,-10
        call N4D
        ld a,l
        ld (de),a
        ret
N4D:    xor a
        dec a
N4D1:   inc a
        add hl,bc
        jr c,N4D1
        sbc hl,bc
        ld (de),a
        inc de
        ret

; ASCII (A) -> indice em HUD_GLIFOS ("0123456789?> ABC...")
AscGlifo:
        cp '?'
        jr nz,AG_1
        ld a,10
        ret
AG_1:   cp 'A'
        jr c,AG_2
        sub 'A'-13
        ret
AG_2:   cp '0'
        jr c,AG_3
        sub '0'
        ret
AG_3:   ld a,12
        ret

; o texto do placar: 16 glifos e as 16 cores
; (hudTxt+16..31 = cores, fixas)
HUD_CORES:
        db 3,3,3,3, 1, 3,3,3,3,3,3, 3, 7,7,7,7

TXT_RECORDE: db "RECORDE",0
