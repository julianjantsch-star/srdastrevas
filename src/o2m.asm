; =====================================================================
;  MODO 1 (moderno): SCREEN 8 (G7, 256 cores GGGRRRBB)
;  A mesma tabela virtual do i8244 (o2.asm), a mesma logica e os mesmos
;  sons do modo 0; muda so o desenho:
;   - fundo de estrelas que piscam (6 por quadro);
;   - caracteres em degrade (claro em cima, escuro embaixo) na rampa de 5
;     tons da cor do chip (RAMP8);
;   - a nave e um disco com cupula (NAVE8) e o canhao uma piramide cheia
;     (CANHAO8): cada metade dela vai no slot de um dos caracteres;
;   - as figuras normais sao sprites com a cor clara em cima e a escura
;     embaixo; as ampliadas, 4 sprites com o padrao gerado quando mudam;
;   - placar em degrade e caixa com brilho.
; =====================================================================
SAT8      equ 0xFA00
SPC8_ADDR equ 0xF800
SPP8_ADDR equ 0xF000
C8_Y      equ 256              ; celulas: figura f, cor c em (16c, 256 + 16f)
NAVE8_Y   equ 256+16*CF_N      ; a nave nova, cor c em (16c, NAVE8_Y)
CANH8_Y   equ NAVE8_Y+16       ; a piramide (24 x 14) em (0, CANH8_Y)
HUD8_Y    equ 384              ; placar: n = 3g + k em (16*(n&15), 384 + 16*(n>>4))
ZPAT8     equ 56               ; padroes 56..59 (16x16): a figura ampliada
NESTR     equ 48

; ---------------------------------------------------------------------
O2Init8:
        xor a
        ld (o2Etapa),a         ; o SCREEN 8 usa a VRAM das celulas do modo 0
        di
        ld a,0x0E              ; R0: G7
        ld (r0sh),a
        out (VDPCTRL),a
        ld a,0|0x80
        out (VDPCTRL),a
        ld a,0x02              ; R1: tela desligada enquanto monta, sprites 16x16
        out (VDPCTRL),a
        ld a,1|0x80
        out (VDPCTRL),a
        ld a,0x1F              ; R2: pagina 0
        out (VDPCTRL),a
        ld a,2|0x80
        out (VDPCTRL),a
        ld a,0xF7              ; R5/R11: atributos em 0xFA00
        out (VDPCTRL),a
        ld a,5|0x80
        out (VDPCTRL),a
        ld a,0x01
        out (VDPCTRL),a
        ld a,11|0x80
        out (VDPCTRL),a
        ld a,0x1E              ; R6: padroes em 0xF000
        out (VDPCTRL),a
        ld a,6|0x80
        out (VDPCTRL),a
        ld a,0x08              ; R8: sprites ligados
        out (VDPCTRL),a
        ld a,8|0x80
        out (VDPCTRL),a
        ei
        ; limpa as paginas 0 e 1 (512 linhas)
        ld hl,0
        ld (c_dx),hl
        ld (c_dy),hl
        ld hl,256
        ld (c_nx),hl
        ld hl,512
        ld (c_ny),hl
        xor a
        call CmdFillB
        call WaitCmd
        call Celulas8
        ; estrelas
        ld b,NESTR
        ld hl,estX
IE_E:   push bc
        push hl
        call Rnd
        pop hl
        ld (hl),a              ; x
        push hl
        ld de,NESTR
        add hl,de
        push hl
        call Rnd
        and 127
        ld c,a
        call Rnd
        and 31
        add a,c
        add a,6
        pop hl
        ld (hl),a              ; y (6..164)
        ld de,NESTR
        add hl,de
        push hl
        call Rnd
        pop hl
        and 7
        ld (hl),a              ; fase
        pop hl
        inc hl
        pop bc
        djnz IE_E
        xor a
        ld (estI),a
        ld a,0xFF
        ld (zFig8),a
        ld (zCor8),a
        ld (vSpCor),a
        ld (vSpCor+1),a
        ld (vSpCor+2),a
        ld (vSpCor+3),a
        ; tabela virtual vazia
        call O2Clear
        ld hl,vDrawn
        ld de,vDrawn+1
        ld bc,VSLOTS*6-1
        ld (hl),NO
        ldir
        ld hl,hudDr
        ld b,16
I8_H:   ld (hl),0xFF
        inc hl
        djnz I8_H
        di
        ld a,0x42              ; tela ligada
        out (VDPCTRL),a
        ld a,1|0x80
        out (VDPCTRL),a
        ei
        jp Sprites8

; ---------------------------------------------------------------------
; celulas do modo 1 (feito a cada vez que o modo 1 comeca)
Celulas8:
        ; padroes dos sprites normais
        ld hl,SPP8_ADDR
        call SetWr
        ld hl,SPR_PAT
        ld bc,SF_N*32
C8_P:   ld a,(hl)
        call VOut
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,C8_P
        ; caracteres em degrade: f = 0..CF_N-1, c = 0..7
        xor a
        ld (o2f),a
C8_F:   xor a
        ld (o2c),a
C8_C:   ld a,(o2f)
        ld l,a
        ld h,0
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de              ; *14
        ld de,CHFIG_DAT
        add hl,de
        push hl
        ld a,(o2f)
        ld l,a
        ld h,0
        ld de,CHFIG_ALT
        add hl,de
        ld a,(hl)
        ld (mkRows),a          ; linhas na tela (2 por linha do glifo)
        ld a,(o2c)
        add a,a
        add a,a
        add a,a
        add a,a
        ld (mkX),a
        ld a,(o2f)
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,C8_Y
        add hl,de
        ld (mkYv),hl
        pop hl
        call Degrade8
        ld a,(o2c)
        inc a
        ld (o2c),a
        cp 8
        jr c,C8_C
        ld a,(o2f)
        inc a
        ld (o2f),a
        cp CF_N
        jr c,C8_F
        ; a nave nova nas 8 cores
        xor a
        ld (o2c),a
C8_N:   ld a,(o2c)
        add a,a
        add a,a
        add a,a
        add a,a
        ld (mkX),a
        ld hl,NAVE8_Y
        ld (mkYv),hl
        ld hl,NAVE8
        ld a,NAVE8_W
        ld (mkK),a
        ld a,NAVE8_H
        ld (mkN),a
        call Tons8
        ld a,(o2c)
        inc a
        ld (o2c),a
        cp 8
        jr c,C8_N
        ; a piramide, verde
        ld a,2
        ld (o2c),a
        xor a
        ld (mkX),a
        ld hl,CANH8_Y
        ld (mkYv),hl
        ld hl,CANHAO8
        ld a,CANHAO8_W
        ld (mkK),a
        ld a,CANHAO8_H
        ld (mkN),a
        call Tons8
        ; placar: glifos em amarelo (3), vermelho (1) e branco (7)
        xor a
        ld (o2f),a
C8_G:   xor a
        ld (odK),a             ; k
C8_K:   ld a,(o2f)
        ld c,a
        add a,a
        add a,c
        ld hl,odK
        add a,(hl)
        ld c,a                 ; n
        and 15
        add a,a
        add a,a
        add a,a
        add a,a
        ld (mkX),a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,HUD8_Y
        add hl,de
        ld (mkYv),hl
        ld a,(odK)
        ld e,a
        ld d,0
        ld hl,K8_COR
        add hl,de
        ld a,(hl)
        ld (o2c),a
        ld a,(o2f)
        ld l,a
        ld h,0
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        ld de,HUD_GLIFOS
        add hl,de
        ld a,14
        ld (mkRows),a
        call Degrade8
        ld a,(odK)
        inc a
        ld (odK),a
        cp 3
        jr c,C8_K
        ld a,(o2f)
        inc a
        ld (o2f),a
        cp HUD_NG
        jr c,C8_G
        ret
K8_COR: db 3, 1, 7

; mascara de 12 px (2 bytes por linha do glifo, cada uma vale 2 linhas) ->
; (mkRows) linhas na tela em (mkX, mkYv), tom pela altura: 4 em cima ate 1
; embaixo, na rampa da cor (o2c)
Degrade8:
        xor a
        ld (mkK),a             ; linha
D8_L:   push hl
        call MkSetWr8
        pop hl
        push hl
        ; tom = 4 - linha*4/altura (no minimo 1)
        ld a,(mkK)
        add a,a
        add a,a
        ld c,a
        ld a,(mkRows)
        ld b,a
        ld e,4
D8_T:   ld a,c
        sub b
        jr c,D8_T2
        ld c,a
        dec e
        jr D8_T
D8_T2:  ld a,e
        or a
        jr nz,D8_T3
        inc a
D8_T3:  ld e,a
        ld a,(o2c)
        ld d,a
        add a,a
        add a,a
        add a,d                ; c*5
        add a,e
        ld e,a
        ld d,0
        ld hl,RAMP8
        add hl,de
        ld c,(hl)              ; a cor deste tom
        pop hl
        push hl
        ; linha do glifo = linha / 2
        ld a,(mkK)
        srl a
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld d,(hl)
        inc hl
        ld e,(hl)              ; DE = 16 bits, bit 15 = pixel 0
        ex de,hl
        ld b,12
D8_P:   add hl,hl
        ld a,0
        jr nc,D8_P1
        ld a,c
D8_P1:  call VOut
        djnz D8_P
        pop hl
        ld a,(mkK)
        inc a
        ld (mkK),a
        ld b,a
        ld a,(mkRows)
        cp b
        jr nz,D8_L
        ret

; desenho em tons (1 byte por pixel, 0..4) -> (mkK) x (mkN) em (mkX, mkYv),
; na rampa da cor (o2c)
Tons8:  ld a,(mkN)
        ld (mkRep),a
T8_L:   push hl
        call MkSetWr8
        pop hl
        ld a,(mkK)
        ld b,a
T8_P:   ld a,(o2c)
        ld e,a
        add a,a
        add a,a
        add a,e                ; c*5
        add a,(hl)
        inc hl
        push hl
        ld e,a
        ld d,0
        ld hl,RAMP8
        add hl,de
        ld a,(hl)
        pop hl
        call VOut
        djnz T8_P
        ld a,(mkRep)
        dec a
        ld (mkRep),a
        jr nz,T8_L
        ret

; escrita na VRAM do SCREEN 8 em (mkX, mkYv 0..511) e mkYv + 1
MkSetWr8:
        ld de,(mkYv)
        ld a,d
        and 1
        ld (mkHi),a            ; y >= 256 -> bit 16
        ld h,e
        ld a,(mkX)
        ld l,a
        inc de
        ld (mkYv),de
        jp SetWr17

; ---------------------------------------------------------------------
; leva a tabela virtual para a tela do modo 1
O2Draw8:
        call Estrelas8
        ld ix,vCh
        ld iy,vDrawn
        ld b,12
D8_SL:  push bc
        ld a,(ix+2)
        cp NO
        jp z,D8_HIDE
        ld a,(ix+1)
        call O2X
        ld (odX),a
        ld a,(ix+0)
        sub O2_YOFF
        jp c,D8_HIDE
        ld (odY),a
        ld a,(ix+3)
        and 7
        ld c,a
        add a,a
        add a,a
        add a,a
        add a,a
        or (ix+2)
        ld (odK),a
        ld a,12
        ld (odW),a
        ; qual celula: slots 8 e 9 (b = 4 e 3) sao as metades da piramide
        ld a,b
        cp 12-SLOT_PL
        jr z,D8_PE
        cp 12-SLOT_PL-1
        jr z,D8_PD
        ld a,(ix+2)
        cp CF_NAVE
        jr nz,D8_CH
        ; a nave nova: 12 x 6, uma linha acima
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld (odSX),hl
        ld hl,NAVE8_Y
        ld (odSY),hl
        ld a,NAVE8_H
        ld (odH),a
        ld a,(odY)
        dec a
        ld (odY),a
        jr D8_CMP
D8_PE:  ld hl,0
        jr D8_PX
D8_PD:  ld hl,12
D8_PX:  ld (odSX),hl
        ld hl,CANH8_Y
        ld (odSY),hl
        ld a,CANHAO8_H
        ld (odH),a
        jr D8_CMP
D8_CH:  ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld (odSX),hl
        ld a,(ix+2)
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,C8_Y
        add hl,de
        ld (odSY),hl
        ld a,(ix+2)
        ld l,a
        ld h,0
        ld de,CHFIG_ALT
        add hl,de
        ld a,(hl)
        ld (odH),a
D8_CMP: ld a,(odX)
        cp (iy+0)
        jr nz,D8_CHG
        ld a,(odY)
        cp (iy+1)
        jr nz,D8_CHG
        ld a,(odK)
        cp (iy+2)
        jr z,D8_NEXT
D8_CHG: call OD_Erase
        ld hl,(odSX)
        ld (c_sx),hl
        ld hl,(odSY)
        ld (c_sy),hl
        ld a,(odX)
        ld l,a
        ld h,0
        ld (c_dx),hl
        ld a,(odY)
        ld l,a
        ld (c_dy),hl
        ld a,(odW)
        ld l,a
        ld (c_nx),hl
        ld a,(odH)
        ld l,a
        ld (c_ny),hl
        call CmdBlit
        ld a,(odX)
        ld (iy+0),a
        ld a,(odY)
        ld (iy+1),a
        ld a,(odK)
        ld (iy+2),a
        ld a,(odW)
        ld (iy+3),a
        ld a,(odH)
        ld (iy+4),a
        jr D8_NEXT
D8_HIDE:
        call OD_Erase
D8_NEXT:
        ld de,4
        add ix,de
        ld de,6
        add iy,de
        pop bc
        dec b
        jp nz,D8_SL
        jp Sprites8

; ---------------------------------------------------------------------
; sprites do modo 1: as 4 figuras (0..3) e a ampliada (planos 4..7)
Sprites8:
        ; a ampliada mudou de forma? gera os 4 padroes
        ld a,(vZ+2)
        cp NO
        jr z,SP8_A
        ld hl,zFig8
        cp (hl)
        jr z,SP8_A
        ld (hl),a
        call PadraoZ8
SP8_A:  ld hl,SAT8
        call SetWr
        ld ix,vSp
        ld b,4
SP8_L:  ld a,(ix+2)
        cp NO
        jr z,SP8_OFF
        ld a,(ix+0)
        sub O2_YOFF+1
        cp 211
        jr nc,SP8_OFF
        call VOut
        ld a,(ix+1)
        call O2X
        call VOut
        ld a,(ix+2)
        add a,a
        add a,a
        call VOut
        xor a
        call VOut
        jr SP8_N
SP8_OFF:
        ld a,217
        call VOut
        xor a
        call VOut
        call VOut
        call VOut
SP8_N:  ld de,4
        add ix,de
        djnz SP8_L
        ; a ampliada: 2 x 2 sprites (24 x 32)
        ld a,(vZ+2)
        cp NO
        jr z,SP8_ZOFF
        ld a,(vZ+0)
        sub O2_YOFF+1
        ld d,a
        ld a,(vZ+1)
        call O2X
        ld e,a
        ld c,ZPAT8*4
        ld b,4
SP8_Z:  ld a,d
        call VOut
        ld a,e
        call VOut
        ld a,c
        call VOut
        xor a
        call VOut
        ld a,c
        add a,4
        ld c,a
        ; ordem: (0,0) (16,0) (0,16) (16,16)
        ld a,b
        cp 3
        jr nz,SP8_Z1
        ld a,e
        sub 16
        ld e,a
        ld a,d
        add a,16
        ld d,a
        jr SP8_Z2
SP8_Z1: ld a,e
        add a,16
        ld e,a
SP8_Z2: djnz SP8_Z
        jr SP8_FIM
SP8_ZOFF:
        ld b,4
SP8_ZO: ld a,217
        call VOut
        xor a
        call VOut
        call VOut
        call VOut
        djnz SP8_ZO
SP8_FIM:
        ld a,216
        call VOut
        ; cores: as que mudaram (planos 0..3 e a ampliada nos 4..7)
        ld ix,vSp
        ld iy,vSpCor
        ld c,0
SP8_C:  ld a,(ix+3)
        and 7
        cp (iy+0)
        jr z,SP8_CN
        ld (iy+0),a
        call Cor8Plano
SP8_CN: ld de,4
        add ix,de
        inc iy
        inc c
        ld a,c
        cp 4
        jr c,SP8_C
        ld a,(vZ+3)
        and 7
        ld hl,zCor8
        cp (hl)
        ret z
        ld (hl),a
        ld c,4
SP8_ZC: push af
        call Cor8Plano
        pop af
        inc c
        ld b,a
        ld a,c
        cp 8
        ld a,b
        jr c,SP8_ZC
        ret

; A = cor do chip, C = plano: 10 linhas da cor clara e 6 da escura
Cor8Plano:
        push bc
        ld e,a
        ld d,0
        ld hl,SPC8
        add hl,de
        ld b,(hl)
        ld hl,SPC8E
        add hl,de
        ld e,(hl)
        push de
        push bc
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,SPC8_ADDR
        add hl,de
        call SetWr
        pop bc
        pop de
        ld a,b
        ld b,10
CP8_1:  call VOut
        djnz CP8_1
        ld a,e
        ld b,6
CP8_2:  call VOut
        djnz CP8_2
        pop bc
        ret

; padroes 56..59 a partir da figura ampliada (A): 24 x 32, 3 bytes por linha
PadraoZ8:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,de              ; *96
        ld de,ZFIG_DAT
        add hl,de
        ld (zSrc8),hl
        ld hl,SPP8_ADDR+ZPAT8*32
        call SetWr
        ; (0,0): bytes 0 e 1 das linhas 0..15 ; (16,0): byte 2 e zero
        ; (0,16) e (16,16): o mesmo nas linhas 16..31
        ld c,0                 ; quadrante
PZ8_Q:  ld a,c
        and 2
        ld e,0
        jr z,PZ8_1
        ld e,16*3
PZ8_1:  ld d,0
        ld hl,(zSrc8)
        add hl,de              ; linha inicial
        ld a,c
        and 1
        jr z,PZ8_E
        inc hl
        inc hl                 ; coluna 16..23 (byte 2)
        ld b,16
PZ8_D1: ld a,(hl)
        call VOut
        inc hl
        inc hl
        inc hl
        djnz PZ8_D1
        ld b,16
        xor a
PZ8_D2: call VOut
        djnz PZ8_D2
        jr PZ8_N
PZ8_E:  push hl
        ld b,16
PZ8_E1: ld a,(hl)
        call VOut
        inc hl
        inc hl
        inc hl
        djnz PZ8_E1
        pop hl
        inc hl
        ld b,16
PZ8_E2: ld a,(hl)
        call VOut
        inc hl
        inc hl
        inc hl
        djnz PZ8_E2
PZ8_N:  inc c
        ld a,c
        cp 4
        jr c,PZ8_Q
        ret

; ---------------------------------------------------------------------
; estrelas: 6 por quadro mudam de fase (apagadas por quem passou em cima,
; voltam sozinhas)
Estrelas8:
        ld b,6
ES8_L:  push bc
        ld a,(estI)
        inc a
        cp NESTR
        jr c,ES8_1
        xor a
ES8_1:  ld (estI),a
        ld e,a
        ld d,0
        ld hl,estX
        add hl,de
        ld a,(hl)
        ld (mkX),a
        ld bc,NESTR
        add hl,bc
        ld a,(hl)
        ld (mkYv),a
        xor a
        ld (mkYv+1),a
        add hl,bc
        ld a,(hl)
        inc a
        and 7
        ld (hl),a
        ld e,a
        ld d,0
        ld hl,ESTRELA8
        add hl,de
        ld a,(hl)
        push af
        call MkSetWr8
        pop af
        call VOut
        pop bc
        djnz ES8_L
        ret

; ---------------------------------------------------------------------
; caixa do placar: barras na cor do meio de GRADE8 e uma linha de brilho
O2Caixa8:
        ld hl,CX_TAB
        ld b,4
OC8:    push bc
        push hl
        ld de,c_dx
        ld bc,8
        ldir
        ld a,(GRADE8+1)
        call CmdFillB
        pop hl
        ld de,9
        add hl,de
        pop bc
        djnz OC8
        ld hl,CX8_BRILHO
        ld b,2
OC8_B:  push bc
        push hl
        ld de,c_dx
        ld bc,8
        ldir
        ld a,(GRADE8+2)
        call CmdFillB
        pop hl
        ld de,9
        add hl,de
        pop bc
        djnz OC8_B
        ret
CX8_BRILHO:
        dw 20,185,216,1
        db 0
        dw 20,209,216,1
        db 0

; placar do modo 1: as celulas em HUD8_Y
O2Hud8:
        ld b,0
H8_L:   push bc
        push hl
        ld e,b
        ld d,0
        add hl,de
        ld a,(hl)
        ld de,16
        add hl,de
        ld c,(hl)
        ld e,a
        ld a,c
        cp 3
        ld c,0
        jr z,H8_K
        inc c
        cp 1
        jr z,H8_K
        inc c
H8_K:   ld a,e
        add a,a
        add a,e
        add a,c
        ld c,a
        ld hl,hudDr
        ld e,b
        ld d,0
        add hl,de
        ld a,(hl)
        cp c
        jr z,H8_N
        ld (hl),c
        ld a,c
        and 15
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld (c_sx),hl
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,HUD8_Y
        add hl,de
        ld (c_sy),hl
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,17
        call O2X
        ld l,a
        ld h,0
        ld (c_dx),hl
        ld hl,199-O2_YOFF
        ld (c_dy),hl
        ld hl,12
        ld (c_nx),hl
        ld hl,14
        ld (c_ny),hl
        call CmdBlit
H8_N:   pop hl
        pop bc
        inc b
        ld a,b
        cp 16
        jr c,H8_L
        ret

; ---------------------------------------------------------------------
; desliga o modo de jogo: esconde os sprites e volta ao SCREEN 5 dos menus
O2Off:  ld a,(modo)
        or a
        ld hl,SAT_ADDR
        jr z,OF_1
        ld hl,SAT8
OF_1:   call SetWr
        ld a,216
        call VOut
        di
        ld a,0x0A              ; R8: sprites desligados
        out (VDPCTRL),a
        ld a,8|0x80
        out (VDPCTRL),a
        ld a,0x40              ; R1
        out (VDPCTRL),a
        ld a,1|0x80
        out (VDPCTRL),a
        ld a,0x06              ; R0: G4 (SCREEN 5)
        ld (r0sh),a
        out (VDPCTRL),a
        ld a,0|0x80
        out (VDPCTRL),a
        ld a,0x1F
        out (VDPCTRL),a
        ld a,2|0x80
        out (VDPCTRL),a
        ei
        ret
