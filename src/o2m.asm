; =====================================================================
;  MODO 1 (moderno, SCREEN 8): desenha a mesma tabela virtual do i8244
;  com outro visual. (provisorio: usa o desenho do modo 0)
; =====================================================================
O2Init8: jp O2Init
O2Draw8: jp O2Draw
O2Hud8:  jp O2Hud
O2Caixa8: jp O2Caixa

; desliga o modo de jogo: esconde os sprites e volta ao R8/R1 dos menus
O2Off:  ld hl,SAT_ADDR
        call SetWr
        ld a,216
        out (VDPDATA),a
        di
        ld a,0x0A
        out (VDPCTRL),a
        ld a,8|0x80
        out (VDPCTRL),a
        ld a,0x40
        out (VDPCTRL),a
        ld a,1|0x80
        out (VDPCTRL),a
        ei
        ret
