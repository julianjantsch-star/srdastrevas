; =====================================================================
;  O "I8244 VIRTUAL" DO MODO 0
;  O jogo escreve, como o original escrevia no chip de video do Odyssey,
;  numa tabela em RAM: 12 caracteres (vCh) e 4 figuras (vSp). A cada quadro
;  O2Draw leva a tabela para a tela do MSX:
;   - caractere -> copia (HMMM) de uma celula ja colorida da pagina 1,
;     apagando (HMMV) onde estava so quando algo mudou;
;   - figura normal -> sprite 16x16 do V9938 (cor por linha = a cor dela);
;   - figura ampliada (a cruz da fenda, o estouro da morte) -> celula de
;     24x32 das paginas 2-3, copiada como um caractere.
;  Coordenadas do chip -> MSX: X = x * 1,5 + 6 (par), Y = y - 8 (ver
;  ref/MEDIDAS.md). Cores do chip 0..7 -> paleta: 0 -> 1, c -> c + 8.
; =====================================================================
O2_YOFF   equ 8
SAT_ADDR  equ 0x7600           ; atributos dos sprites (cores em 0x7400)
SPC_ADDR  equ 0x7400
SPP_ADDR  equ 0x7800           ; padroes 16x16
CEL_Y     equ 256              ; celulas dos caracteres (pagina 1)
ZCEL_Y    equ 512              ; celulas ampliadas (paginas 2-3)
VSLOTS    equ 13               ; 12 caracteres + 1 ampliada
NO        equ 0xFF

; ---------------------------------------------------------------------
; x do chip (A) -> X do MSX (A), par
O2X:    ld c,a
        srl a
        add a,c
        add a,6
        and 0xFE
        ret

; cor do chip (A, 0..7) -> indice da paleta (A)
O2Cor:  and 7
        jr z,OC_0
        add a,8
        ret
OC_0:   inc a
        ret

; ---------------------------------------------------------------------
; liga o modo 0: SCREEN 5 com sprites 16x16, monta as celulas e os padroes
; monta as celulas e os padroes (uma vez: na tela ON, enquanto espera a tecla)
O2Prepara:
        call O2Passo
        ld a,(o2Etapa)
        cp O2_ETAPAS
        jr c,O2Prepara
        ret

; uma etapa por chamada (a tela ON chama uma por quadro): 0 = padroes dos
; sprites; depois cada figura de caractere, cada ampliada e cada glifo do
; placar, em todas as cores
; O2_ETAPAS (1+CF_N+ZF_N+HUD_NG) fica depois do o2dados.inc (equ adiantado vira 0)
O2Passo:
        ld a,(o2Etapa)
        cp O2_ETAPAS
        ret nc
        inc a
        ld (o2Etapa),a
        dec a
        jp z,O2Padroes
        dec a
        cp CF_N
        jp c,O2CelCar
        sub CF_N
        cp ZF_N
        jp c,O2CelZoom
        sub ZF_N
        jp O2CelHud

O2Init:
        call O2Prepara
        call ClearScreen
        di
        ld a,0x42              ; R1: tela ligada, sprites 16x16
        out (VDPCTRL),a
        ld a,1|0x80
        out (VDPCTRL),a
        ld a,0xEF              ; R5: atributos em 0x7600 (modo 2 de sprites)
        out (VDPCTRL),a
        ld a,5|0x80
        out (VDPCTRL),a
        xor a                  ; R11
        out (VDPCTRL),a
        ld a,11|0x80
        out (VDPCTRL),a
        ld a,0x0F              ; R6: padroes em 0x7800
        out (VDPCTRL),a
        ld a,6|0x80
        out (VDPCTRL),a
        ld a,0x08              ; R8: sprites ligados
        out (VDPCTRL),a
        ld a,8|0x80
        out (VDPCTRL),a
        ei
        ; tabela virtual vazia, nada desenhado
        call O2Clear
        ld hl,vDrawn
        ld de,vDrawn+1
        ld bc,VSLOTS*6-1
        ld (hl),NO
        ldir
        ld a,0xFF
        ld (vSpCor),a
        ld (vSpCor+1),a
        ld (vSpCor+2),a
        ld (vSpCor+3),a
        ld hl,hudDr
        ld b,16
OI_HZ:  ld (hl),0xFF
        inc hl
        djnz OI_HZ
        jp O2Sprites

O2Padroes:
        ld hl,SPP_ADDR
        call SetWr
        ld hl,SPR_PAT
        ld bc,SF_N*32
OI_P:   ld a,(hl)
        call VOut
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,OI_P
        ret

; A = figura de caractere: as 8 cores dela
O2CelCar:
        ld (o2f),a
        xor a
        ld (o2c),a
OI_CC:  ld a,(o2f)
        call CelXY             ; BC = x (byte), DE = y
        push bc
        push de
        ld a,(o2f)
        ld l,a
        ld h,0
        add hl,hl              ; 14 bytes por figura
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de              ; *14
        ld de,CHFIG_DAT
        add hl,de
        pop de
        pop bc
        ld a,(o2c)
        call O2Cor
        ld (mkCor),a
        ld a,7
        ld (mkRows),a
        ld a,2
        ld (mkRep),a
        call PutMask12
        ld a,(o2c)
        inc a
        ld (o2c),a
        cp 8
        jr c,OI_CC
        ret

; A = figura ampliada: as 8 cores dela
O2CelZoom:
        ld (o2f),a
        xor a
        ld (o2c),a
OI_ZC:  call ZCelXY            ; de o2f/o2c
        push bc
        push de
        ld a,(o2f)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl              ; *32
        ld e,l
        ld d,h
        add hl,hl
        add hl,de              ; *96
        ld de,ZFIG_DAT
        add hl,de
        pop de
        pop bc
        ld a,(o2c)
        call O2Cor
        ld (mkCor),a
        call PutMask24
        ld a,(o2c)
        inc a
        ld (o2c),a
        cp 8
        jr c,OI_ZC
        ret

; A = figura de caractere -> BC = x da celula em bytes (cor 0), DE = y
CelXY:  ld c,a
        and 1
        ld b,a                 ; 0 ou 1
        ld a,c
        srl a                  ; linha da folha
        add a,a
        add a,a
        add a,a
        add a,a                ; *16
        ld e,a
        ld d,0
        ld hl,CEL_Y
        add hl,de
        ex de,hl
        ld a,b
        rrca                   ; 0 ou 0x80
        rrca                   ; 0 ou 0x40 (= 128 px em bytes /2)
        ld c,a
        ld a,(o2c)
        add a,a
        add a,a
        add a,a                ; 16 px por cor = 8 bytes
        add a,c
        ld c,a
        ld b,0
        ret

; o2f/o2c -> BC = x em bytes, DE = y da celula ampliada (n = f*8+c; 10 por linha)
ZCelXY: ld a,(o2f)
        add a,a
        add a,a
        add a,a
        ld hl,o2c
        add a,(hl)             ; n
        ld e,0
ZX_1:   cp 10
        jr c,ZX_2
        sub 10
        inc e
        jr ZX_1
ZX_2:   ld c,a                 ; coluna
        add a,a
        add a,c                ; *3
        add a,a
        add a,a                ; *12 bytes (24 px)
        ld c,a
        ld b,0
        ld a,e                 ; linha da folha * 32
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,ZCEL_Y
        add hl,de
        ex de,hl
        ret

; mascara 12 px (2 bytes por linha, bit 15 = esquerda) -> VRAM em SCREEN 5
; HL = mascara, BC = x em bytes, DE = y; (mkRows) linhas, cada uma (mkRep) vezes
PutMask12:
        ld (mkX),bc
        ld (mkYv),de
        ld a,(mkRows)
        ld (mkN),a
PM_L:   ld a,(hl)
        inc hl
        ld (mkBits),a
        ld a,(hl)
        inc hl
        ld (mkBits+1),a
        ld a,(mkRep)
        ld (mkK),a
PM_R:   push hl
        call MkSetWr           ; escrita em (mkX, mkYv) e mkYv + 1
        ld a,(mkBits)
        ld h,a
        ld a,(mkBits+1)
        ld l,a                 ; HL = 16 bits, bit 15 = pixel 0
        ld b,6
PM_B:   ld c,0
        add hl,hl
        jr nc,PM_B1
        ld a,(mkCor)
        rlca
        rlca
        rlca
        rlca
        ld c,a
PM_B1:  add hl,hl
        jr nc,PM_B2
        ld a,(mkCor)
        or c
        ld c,a
PM_B2:  ld a,c
        call VOut
        djnz PM_B
        pop hl
        ld a,(mkK)
        dec a
        ld (mkK),a
        jr nz,PM_R
        ld a,(mkN)
        dec a
        ld (mkN),a
        jr nz,PM_L
        ret

; mascara 24 px (3 bytes por linha, 32 linhas) -> VRAM; HL, BC, DE como acima
PutMask24:
        ld (mkX),bc
        ld (mkYv),de
        ld a,32
        ld (mkN),a
PZ_L:   push hl
        call MkSetWr
        pop hl
        ld b,3
PZ_3:   push bc
        ld c,(hl)
        inc hl
        ld b,4
PZ_4:   ld e,0
        rlc c
        jr nc,PZ_5
        ld a,(mkCor)
        rlca
        rlca
        rlca
        rlca
        ld e,a
PZ_5:   rlc c
        jr nc,PZ_6
        ld a,(mkCor)
        or e
        ld e,a
PZ_6:   ld a,e
        call VOut
        djnz PZ_4
        pop bc
        djnz PZ_3
        ld a,(mkN)
        dec a
        ld (mkN),a
        jr nz,PZ_L
        ret

; prepara escrita na VRAM em (mkX bytes, mkYv linha 0..1023) e avanca mkYv
; endereco = y * 128 + x (17 bits)
MkSetWr:
        ld de,(mkYv)
        ld a,(mkX)
        ld c,a
        ld a,d
        srl a
        and 1
        ld (mkHi),a            ; bit 16 = bit 9 de y
        ld a,d
        and 1
        rrca                   ; bit 8 de y -> bit 7
        ld h,a
        ld a,e
        and 1
        rrca                   ; bit 0 de y -> bit 7
        or c
        ld l,a
        ld a,e
        srl a
        or h
        ld h,a                 ; H = bits 8..1 de y
        inc de
        ld (mkYv),de
; HL = endereco baixo, (mkHi) = bit 16 -> prepara escrita
SetWr17:
        ld a,h
        rlca
        rlca
        and 3
        ld c,a
        ld a,(mkHi)
        add a,a
        add a,a
        or c
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

; ---------------------------------------------------------------------
; esvazia a tabela virtual (o que ja esta na tela e apagado no proximo O2Draw)
O2Clear:
        ld hl,vCh
        ld b,VSLOTS*4+16
OCL:    ld (hl),NO
        inc hl
        djnz OCL
        ret

; ---------------------------------------------------------------------
; leva a tabela virtual para a tela
O2Draw:
        ld ix,vCh
        ld iy,vDrawn
        ld b,VSLOTS
OD_L:   push bc
        ld a,b
        cp 1                   ; o ultimo e a figura ampliada
        jr z,OD_Z
        ; caractere: y, x, figura, cor
        ld a,(ix+2)
        cp NO
        jp z,OD_HIDE
        ld a,(ix+1)
        call O2X
        ld (odX),a
        ld a,(ix+0)
        sub O2_YOFF
        jp c,OD_HIDE
        ld (odY),a
        ld a,(ix+2)
        ld l,a
        ld h,0
        ld de,CHFIG_ALT
        add hl,de
        ld a,(hl)
        ld (odH),a
        ld a,12
        ld (odW),a
        ; chave = figura + cor*16
        ld a,(ix+3)
        and 7
        ld (o2c),a
        add a,a
        add a,a
        add a,a
        add a,a
        or (ix+2)
        ld (odK),a
        ld a,(ix+2)
        call CelXY             ; BC = x em bytes, DE = y
        ld l,c
        ld h,0
        add hl,hl              ; em pixels
        ld (odSX),hl
        ld (odSY),de
        jr OD_CMP
OD_Z:   ; figura ampliada: y, x, figura, cor
        ld a,(ix+2)
        cp NO
        jp z,OD_HIDE
        ld (o2f),a
        ld a,(ix+1)
        call O2X
        ld (odX),a
        ld a,(ix+0)
        sub O2_YOFF
        jp c,OD_HIDE
        ld (odY),a
        ld c,a
        ld a,184               ; recorta acima da caixa do placar (nao pisca o placar)
        sub c
        jp c,OD_HIDE
        jp z,OD_HIDE
        cp 32
        jr c,OD_ZH
        ld a,32
OD_ZH:  ld (odH),a
        ld a,24
        ld (odW),a
        ld a,(ix+3)
        and 7
        ld (o2c),a
        add a,a
        add a,a
        add a,a
        add a,a
        or (ix+2)
        or 0x80
        ld (odK),a
        call ZCelXY
        ld l,c
        ld h,0
        add hl,hl
        ld (odSX),hl
        ld (odSY),de
OD_CMP: ; igual ao desenhado? (x, y, chave)
        ld a,(odX)
        cp (iy+0)
        jr nz,OD_CHG
        ld a,(odY)
        cp (iy+1)
        jr nz,OD_CHG
        ld a,(odK)
        cp (iy+2)
        jr z,OD_NEXT
OD_CHG: call OD_Erase
        ; copia a celula
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
        ld a,(odW)
        cp 24                  ; ampliada: o fundo preto da celula nao cobre o placar
        call nz,CmdBlit
        ld a,(odW)
        cp 24
        call z,CmdBlitT
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
        jr OD_NEXT
OD_HIDE:
        call OD_Erase
OD_NEXT:
        ld de,4
        add ix,de
        ld de,6
        add iy,de
        pop bc
        dec b
        jp nz,OD_L
        jp O2Sprites

; apaga o que este slot desenhou (IY), se desenhou
OD_Erase:
        ld a,(iy+2)
        cp NO
        ret z
        ld (iy+2),NO
        ld a,(iy+1)
        add a,(iy+4)
        cp 185                 ; passou da linha 184 (a caixa do placar)
        jr c,OE_1
        ld a,1
        ld (hudRedo),a
OE_1:
        ld a,(iy+0)
        ld l,a
        ld h,0
        ld (c_dx),hl
        ld a,(iy+1)
        ld l,a
        ld (c_dy),hl
        ld a,(iy+3)
        ld l,a
        ld (c_nx),hl
        ld a,(iy+4)
        ld l,a
        ld (c_ny),hl
        xor a
        jp CmdFillB

; os 4 sprites: atributos (y, x, padrao, 0) e, se a cor mudou, as 16 linhas de cor
O2Sprites:
        ld hl,SAT_ADDR
        call SetWr
        ld ix,vSp
        ld b,4
OS_L:   ld a,(ix+2)
        cp NO
        jr z,OS_OFF
        ld a,(ix+0)
        sub O2_YOFF+1          ; o V9938 desenha o sprite uma linha abaixo de Y
        cp 211
        jr nc,OS_OFF
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
        jr OS_N
OS_OFF: ld a,217
        call VOut
        xor a
        call VOut
        call VOut
        call VOut
OS_N:   ld de,4
        add ix,de
        djnz OS_L
        ld a,216               ; fim da lista de sprites
        call VOut
        ; cores (so as que mudaram)
        ld ix,vSp
        ld iy,vSpCor
        ld c,0
OS_C:   ld a,(ix+3)
        and 7
        cp (iy+0)
        jr z,OS_CN
        ld (iy+0),a
        call O2Cor
        ld d,a
        push bc
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,SPC_ADDR
        add hl,de
        call SetWr
        pop bc
        ld a,(iy+0)
        call O2Cor
        ld b,16
OS_CL:  call VOut
        djnz OS_CL
OS_CN:  ld de,4
        add ix,de
        inc iy
        inc c
        ld a,c
        cp 4
        jr c,OS_C
        ret

; ---------------------------------------------------------------------
; caixa do placar (a grade do chip): magenta escuro
O2Caixa:
        ld hl,CX_TAB
        ld b,4
OCX:    push bc
        push hl
        call FillTab
        pop hl
        ld de,9
        add hl,de
        pop bc
        djnz OCX
        ret
CX_TAB: dw 18,184,220,3
        db 0x66
        dw 18,208,220,3
        db 0x66
        dw 18,187,4,21
        db 0x66
        dw 234,187,4,21
        db 0x66

; texto do placar: HL = 16 indices de glifo (HUD_GLIFOS) + 16 cores do chip
; (3 amarelo, 1 vermelho, 7 branco); x = 17 + 8i do chip, y = 199. Cada letra
; e uma copia (HMMM) de uma celula pronta; so as que mudaram
HUD_CY  equ 320               ; celulas do placar: glifo g, cor k em (16*(n&15), 320+16*(n>>4)), n = 3g+k
O2Hud:
        ld b,0
OH_L:   push bc
        push hl
        ld e,b
        ld d,0
        add hl,de
        ld a,(hl)              ; glifo
        ld de,16
        add hl,de
        ld c,(hl)              ; cor do chip
        ld e,a
        ld a,c
        cp 3
        ld c,0
        jr z,OH_K
        inc c
        cp 1
        jr z,OH_K
        inc c
OH_K:   ld a,e
        add a,a
        add a,e                ; 3g
        add a,c                ; n
        ld c,a
        ; ja esta assim?
        ld hl,hudDr
        pop de
        push de
        ld a,b
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        cp c
        jr z,OH_N
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
        ld de,HUD_CY
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
OH_N:   pop hl
        pop bc
        inc b
        ld a,b
        cp 16
        jr c,OH_L
        ret

; A = glifo do placar: as 3 cores dele
O2CelHud:
        ld (o2f),a
        xor a
        ld (o2c),a             ; cor (0 amarelo, 1 vermelho, 2 branco)
OHC_K:  ld a,(o2f)
        ld c,a
        add a,a
        add a,c
        ld hl,o2c
        add a,(hl)
        ld (odK),a             ; n = 3g + k
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
        ld de,HUD_CY
        add hl,de
        push hl
        ld a,(o2c)
        ld e,a
        ld d,0
        ld hl,HUDK_COR
        add hl,de
        ld a,(hl)
        ld (mkCor),a
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
        ld a,(odK)
        and 15
        add a,a
        add a,a
        add a,a
        ld c,a
        ld b,0
        pop de
        ld a,7
        ld (mkRows),a
        ld a,2
        ld (mkRep),a
        call PutMask12
        ld a,(o2c)
        inc a
        ld (o2c),a
        cp 3
        jr c,OHC_K
        ret
HUDK_COR: db 11, 9, 15         ; amarelo, vermelho e branco da paleta

; escrita na VRAM com folga: o V9938 com a tela e os sprites ligados (e o
; motor de comandos copiando) perde bytes escritos em menos de ~29 ciclos
VOut:   out (VDPDATA),a
        ret
