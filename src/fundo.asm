; =====================================================================
;  FUNDOS DO VIDEOPAC+ (opcoes 3 e 4): a Terra, a Lua com rosto, os
;  asteriscos e as estrelas que o EF9340 do G7400 desenha no Terrahawks /
;  Attack of the Timelord! plus (gerados por tools/gen_fundo.py)
; =====================================================================

; A = banco, HL = origem (0xA000-0xBFFF), DE = bytes de saida, C = 1 se RLE
; (pares quantidade, valor). Escreve em sequencia na VRAM (endereco ja
; preparado). Atravessa os bancos de 8 KB. A fala nao pode estar tocando
FdCopia:
        ld (fdBk),a
        ld (0x7800),a
        ld a,c
        or a
        jr z,FD_RAW
FD_R:   ld b,(hl)
        call FdInc
        ld c,(hl)
        call FdInc
FD_R1:  ld a,c
        call VOut
        dec de
        ld a,d
        or e
        ret z
        djnz FD_R1
        jr FD_R
FD_RAW: ld a,(hl)
        call VOut
        call FdInc
        dec de
        ld a,d
        or e
        jr nz,FD_RAW
        ret
FdInc:  inc hl
        ld a,h
        cp 0xC0
        ret nz
        ld h,0xA0
        ld a,(fdBk)
        inc a
        ld (fdBk),a
        ld (0x7800),a
        ret

; A = indice, D = R*16+B, E = G
PalSet: di
        out (VDPCTRL),a
        ld a,16|0x80
        out (VDPCTRL),a
        ei
        ld a,d
        out (VDPPAL),a
        ld a,e
        out (VDPPAL),a
        ret

; ---------------------------------------------------------------------
; modo 3 (SCREEN 5): o fundo guardado em y = FD5_VY (pagina 3, livre) e
; copiado para a tela. Apagar uma figura = copiar o fundo de volta
FD5_VY  equ 800
Fundo5Init:
        ; as cores do fundo nos indices 2..5 (o jogo usa 1 e 9..15)
        ld a,2
        ld de,0x3000           ; vermelho escuro (asteriscos)
        call PalSet
        ld a,3
        ld de,0x0003           ; verde escuro
        call PalSet
        ld a,4
        ld de,0x3003           ; oliva (a Terra e a Lua)
        call PalSet
        ld a,5
        ld de,0x1502           ; azul (o mar)
        call PalSet
        ; linhas abaixo do fundo guardado: pretas (o que apaga no placar)
        ld hl,0
        ld (c_dx),hl
        ld hl,FD5_VY+FD5_H
        ld (c_dy),hl
        ld hl,256
        ld (c_nx),hl
        ld hl,1024-FD5_VY-FD5_H
        ld (c_ny),hl
        xor a
        call CmdFillB
        call WaitCmd
        ; descompacta em y = 800: endereco 800 * 128 = 0x19000
        ld a,1
        ld (mkHi),a
        ld hl,0x9000
        call SetWr17
        ld a,FD5_BANCO
        ld hl,FD5_END
        ld de,FD5_BYTES
        ld c,1
        call FdCopia
        ; e para a tela
        ld hl,0
        ld (c_sx),hl
        ld (c_dx),hl
        ld (c_dy),hl
        ld hl,FD5_VY
        ld (c_sy),hl
        ld hl,256
        ld (c_nx),hl
        ld hl,FD5_H
        ld (c_ny),hl
        jp CmdBlit

; ---------------------------------------------------------------------
; modo 4 (SCREEN 8): a Terra (faixa FD8_Y0..FD8_Y0+63) guardada em
; FD8_VY (o placar ocupa so 384..447 da pagina 1) e copiada para a tela;
; a Lua, os asteriscos e 2 nuvens sao sprites (planos 8..17) que se movem
FD8_VY  equ 448
FD_P0   equ 32                 ; padroes 16x16 32.. (o jogo usa 0..24 e 56..59)
FD_PL0  equ 8                  ; primeiro plano de sprite do fundo
FD_PAT_A1 equ FD_P0*4+24       ; padroes (8x8) dos asteriscos e da nuvem
FD_PAT_A2 equ FD_P0*4+28
FD_PAT_N  equ FD_P0*4+32
Fundo8Init:
        ; a faixa: 448 * 256 = 0x1C000
        ld a,1
        ld (mkHi),a
        ld hl,0xC000
        call SetWr17
        ld a,FD8_BANCO
        ld hl,FD8_END
        ld de,FD8_BYTES
        ld c,0
        call FdCopia
        ld hl,0
        ld (c_sx),hl
        ld (c_dx),hl
        ld hl,FD8_VY
        ld (c_sy),hl
        ld hl,FD8_Y0
        ld (c_dy),hl
        ld hl,256
        ld (c_nx),hl
        ld hl,FD8_H
        ld (c_ny),hl
        call CmdBlit
        ; padroes dos sprites do fundo
        ld hl,SPP8_ADDR+FD_P0*32
        call SetWr
        ld hl,FD_SPR
        ld bc,FD_NSPR*32
FI_P:   ld a,(hl)
        call VOut
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,FI_P
        ; cores: Lua (planos 8..13: 3 em cima, 3 embaixo), asteriscos (14, 15), nuvens (16, 17)
        ld hl,SPC8_ADDR+FD_PL0*16
        call SetWr
        ld c,2
FI_L1:  ld b,3
FI_L2:  push bc
        ld hl,FD_LUA_COR
        ld a,c
        cp 2
        jr z,FI_L3
        ld de,16
        add hl,de
FI_L3:  ld b,16
FI_L4:  ld a,(hl)
        call VOut
        inc hl
        djnz FI_L4
        pop bc
        djnz FI_L2
        dec c
        jr nz,FI_L1
        ld b,32
FI_A:   ld a,10                ; asteriscos: vermelho
        call VOut
        djnz FI_A
        ld b,16
FI_N1:  ld a,15                ; nuvem branca
        call VOut
        djnz FI_N1
        ld b,16
FI_N2:  ld a,7                 ; e uma cinza, mais longe
        call VOut
        djnz FI_N2
        xor a
        ld (fdT),a
        ld a,200
        ld (fdNuv),a
        ld a,90
        ld (fdNuv+1),a
        ret

; um quadro da animacao do fundo do modo 4: o relogio, as nuvens andando e
; os asteriscos pulsando (as posicoes vao para a tabela de sprites em FundoSat8)
FundoAnima8:
        ld hl,fdT
        inc (hl)
        ld a,(hl)
        and 3
        jr nz,FA8_1
        ld hl,fdNuv            ; nuvens: 1 px a cada 4 quadros (a de tras, a cada 8)
        dec (hl)
        ld a,(fdT)
        and 7
        jr nz,FA8_1
        inc hl
        dec (hl)
FA8_1:  ld a,(fdT)
        and 7
        ret nz
        ; asteriscos: a cor pulsa a cada 8 quadros
        ld a,(fdT)
        rrca
        rrca
        rrca
        and 3
        ld e,a
        ld d,0
        ld hl,FA8_CORES
        add hl,de
        ld a,(hl)
        push af
        ld hl,SPC8_ADDR+(FD_PL0+6)*16
        call SetWr
        pop af
        ld b,32
FA8_C:  call VOut
        djnz FA8_C
        ret
FA8_CORES: db 10, 8, 10, 2

; as 10 entradas do fundo na tabela de sprites (continua a escrita em
; sequencia do Sprites8, depois dos planos 0..7)
FundoSat8:
        ; Lua: balanca devagar (x +-12, y +-5) num ciclo de ~17 s
        ld a,(fdT)
        rrca
        rrca
        and 63
        ld e,a
        ld d,0
        ld hl,FD_SEN
        add hl,de
        ld a,(hl)              ; -12..12
        add a,FD_LUA_X
        ld (fdLx),a
        ld a,e
        add a,16               ; fase de 90 graus para y
        and 63
        ld e,a
        ld hl,FD_SEN
        add hl,de
        ld a,(hl)
        sra a
        sra a                  ; -3..3
        add a,FD_LUA_Y-1
        ld d,a                 ; y
        ld a,(fdLx)
        ld e,a                 ; x
        ld c,FD_P0*4
        ld b,2
FS_LY:  push bc
        push de
        ld b,3
FS_LX:  ld a,d
        call VOut
        ld a,e
        call VOut
        ld a,c
        call VOut
        xor a
        call VOut
        ld a,e
        add a,16
        ld e,a
        ld a,c
        add a,4
        ld c,a
        djnz FS_LX
        pop de
        ld a,d
        add a,16
        ld d,a
        pop bc
        ld a,c
        add a,12
        ld c,a
        djnz FS_LY
        ; asteriscos: giram (troca a forma a cada 16 quadros)
        ld a,(fdT)
        and 16
        ld a,FD_PAT_A1
        jr z,FS_A
        ld a,FD_PAT_A2
FS_A:   ld c,a
        ld a,FD_AST1_Y-1
        call VOut
        ld a,FD_AST1_X
        call VOut
        ld a,c
        call VOut
        xor a
        call VOut
        ld a,FD_AST2_Y-1
        call VOut
        ld a,FD_AST2_X
        call VOut
        ld a,c
        xor 4                  ; o outro na forma oposta
        call VOut
        xor a
        call VOut
        ; nuvens sobre a Terra
        ld a,142
        call VOut
        ld a,(fdNuv)
        call VOut
        ld a,FD_PAT_N
        call VOut
        xor a
        call VOut
        ld a,152
        call VOut
        ld a,(fdNuv+1)
        call VOut
        ld a,FD_PAT_N
        call VOut
        xor a
        jp VOut

; seno de 64 passos, amplitude 12
FD_SEN: db 0,1,2,4,5,6,7,8,8,9,10,11,11,12,12,12,12,12,12,12,11,11,10,9,8,8,7,6,5,4,2,1
        db 0,-1,-2,-4,-5,-6,-7,-8,-8,-9,-10,-11,-11,-12,-12,-12,-12,-12,-12,-12,-11,-11,-10,-9,-8,-8,-7,-6,-5,-4,-2,-1

; ---------------------------------------------------------------------
; apagar uma figura com o fundo do Videopac+ (c_dx, c_dy, c_nx, c_ny prontos)
FdApaga:
        ld a,(modo)
        or a
        jr nz,FDA_8
        ; modo 3: o fundo guardado em y + FD5_VY
        ld hl,(c_dx)
        ld (c_sx),hl
        ld hl,(c_dy)
        ld de,FD5_VY
        add hl,de
        ld (c_sy),hl
        jp CmdBlit
FDA_8:  ; modo 4: abaixo da linha 184 (placar) preto; FD8_Y0..183 = a faixa; acima, preto
        ld hl,(c_dy)
        ld de,(c_ny)
        add hl,de              ; HL = fim (exclusivo)
        ld de,184
        or a
        sbc hl,de
        jr c,FDA_1
        jr z,FDA_1
        ; parte no placar: preta
        push hl                ; linhas abaixo de 184
        ld hl,(c_ny)
        pop de
        push de
        or a
        sbc hl,de              ; ny sem o placar
        ld (fdNy),hl
        ld hl,184
        pop hl
        ld (c_ny),hl
        ld hl,(c_dy)
        push hl
        ld hl,184
        ld (c_dy),hl
        xor a
        call CmdFillB
        pop hl
        ld (c_dy),hl
        ld hl,(fdNy)
        ld (c_ny),hl
        ld a,h
        or l
        ret z
FDA_1:  ; agora o retangulo termina ate 184
        ld hl,(c_dy)
        ld de,FD8_Y0
        or a
        sbc hl,de
        jr nc,FDA_F            ; comeca dentro da faixa
        ; comeca acima: a parte de cima preta
        ld hl,(c_dy)
        ld de,(c_ny)
        add hl,de
        ld de,FD8_Y0+1
        or a
        sbc hl,de
        jr nc,FDA_2
        xor a                  ; todo acima da faixa
        jp CmdFillB
FDA_2:  inc hl                 ; HL = linhas dentro da faixa
        push hl
        ld de,(c_ny)
        ex de,hl
        or a
        sbc hl,de              ; linhas acima
        ld (c_ny),hl
        xor a
        call CmdFillB
        pop hl
        ld (c_ny),hl
        ld hl,FD8_Y0
        ld (c_dy),hl
        ld hl,0
FDA_F:  ; HL = c_dy - FD8_Y0
        ld de,FD8_VY
        add hl,de
        ld (c_sy),hl
        ld hl,(c_dx)
        ld (c_sx),hl
        jp CmdBlit

; desenho de uma celula: com o fundo, o preto da celula e transparente
CmdBlitC:
        ld a,(fundoVP)
        or a
        jp z,CmdBlit
        ld a,(modo)            ; modo 4: no ceu (acima da Terra) o fundo e preto e
        or a                   ; a copia rapida basta; so sobre a Terra a transparente
        jp z,CmdBlitT
        ld a,(odY)
        ld hl,odH
        add a,(hl)
        cp FD8_Y0+1
        jp c,CmdBlit
        jp CmdBlitT

; modo 4: o canhao sobre a Terra sem piscar. Monta fora da tela (pagina 0,
; linhas 216..: livres) o pedaco da Terra + o canhao (transparente) e copia
; tudo de uma vez; as margens pretas da celula viram Terra e apagam onde
; ele estava. odX/odY/odW/odH/odSX/odSY ja prontos (com as margens)
FD_RASC equ 216
CanhaoFundo8:
        ; 1) a Terra embaixo: da faixa guardada
        ld a,(odX)
        ld l,a
        ld h,0
        ld (c_sx),hl
        ld a,(odY)
        ld l,a
        ld de,FD8_VY-FD8_Y0
        add hl,de
        ld (c_sy),hl
        ld hl,0
        ld (c_dx),hl
        ld hl,FD_RASC
        ld (c_dy),hl
        ld a,(odW)
        ld l,a
        ld h,0
        ld (c_nx),hl
        ld a,(odH)
        ld l,a
        ld (c_ny),hl
        call CmdBlit
        ; 2) o canhao por cima, com o preto transparente (so o miolo de 24 px:
        ; a copia logica e lenta no SCREEN 8)
        ld hl,(odSX)
        ld de,CANH8_M
        add hl,de
        ld (c_sx),hl
        ld hl,(odSY)
        ld (c_sy),hl
        ld hl,CANH8_M
        ld (c_dx),hl
        ld hl,24
        ld (c_nx),hl
        call CmdBlitT
        ld a,(odW)
        ld l,a
        ld h,0
        ld (c_nx),hl
        ; 3) para a tela de uma vez
        ld hl,0
        ld (c_sx),hl
        ld hl,FD_RASC
        ld (c_sy),hl
        ld a,(odX)
        ld l,a
        ld h,0
        ld (c_dx),hl
        ld a,(odY)
        ld l,a
        ld (c_dy),hl
        jp CmdBlit
