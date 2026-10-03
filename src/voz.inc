; gerado por tools/voz/gen_voz.py: a fala do original (The Voice / SP0256) em alofones
VOZ_BANCOS equ 3          ; bancos de 8 KB a partir do 3
VOZ_CENTRO equ 11          ; volume do PSG do silencio
VOZ_NFR equ 14
; alofone: banco (0xFF = pausa), endereco em 0xA000-0xBFFF, amostras (2 por byte)
VOZ_TAB:
  db 0xff
  dw 0x0000, 360     ; PA3
  db 0xff
  dw 0x0000, 774     ; PA4
  db 0xff
  dw 0x0000, 1598     ; PA5
  db 0x03
  dw 0xa000, 2702     ; OY
  db 0x03
  dw 0xa547, 1606     ; AY
  db 0x03
  dw 0xa86a, 510     ; EH
  db 0x03
  dw 0xa969, 766     ; KK3
  db 0x03
  dw 0xaae8, 1332     ; PP
  db 0x03
  dw 0xad82, 876     ; NN1
  db 0x03
  dw 0xaf38, 438     ; IH
  db 0x03
  dw 0xb013, 918     ; TT2
  db 0x03
  dw 0xb1de, 1168     ; RR1
  db 0x03
  dw 0xb426, 510     ; AX
  db 0x03
  dw 0xb525, 1168     ; MM
  db 0x03
  dw 0xb76d, 614     ; TT1
  db 0x03
  dw 0xb8a0, 1606     ; IY
  db 0x03
  dw 0xbbc3, 438     ; DD1
  db 0x03
  dw 0xbc9e, 656     ; UW1
  db 0x03
  dw 0xbde6, 656     ; AA
  db 0x04
  dw 0xa000, 1168     ; YY2
  db 0x04
  dw 0xa248, 730     ; AE
  db 0x04
  dw 0xa3b5, 812     ; HH1
  db 0x04
  dw 0xa54b, 292     ; BB1
  db 0x04
  dw 0xa5dd, 1116     ; TH
  db 0x04
  dw 0xa80b, 656     ; UH
  db 0x04
  dw 0xa953, 1606     ; UW2
  db 0x04
  dw 0xac76, 1072     ; DD2
  db 0x04
  dw 0xae8e, 720     ; GG3
  db 0x04
  dw 0xaff6, 730     ; RR2
  db 0x04
  dw 0xb163, 964     ; FF
  db 0x04
  dw 0xb345, 1022     ; KK1
  db 0x04
  dw 0xb544, 1384     ; ZZ
  db 0x04
  dw 0xb7f8, 1386     ; NG
  db 0x04
  dw 0xbaad, 876     ; LL
  db 0x04
  dw 0xbc63, 1168     ; WW
  db 0x05
  dw 0xa000, 2264     ; XR
  db 0x05
  dw 0xa46c, 876     ; ER1
  db 0x05
  dw 0xa622, 1898     ; ER2
  db 0x05
  dw 0xa9d7, 1606     ; OW
  db 0x05
  dw 0xacfa, 1680     ; DH2
  db 0x05
  dw 0xb042, 558     ; SS
  db 0x05
  dw 0xb159, 1206     ; HH2
  db 0x05
  dw 0xb3b4, 2118     ; OR
  db 0x05
  dw 0xb7d7, 454     ; BB2
  db 0x05
  dw 0xb8ba, 50     ; 0x64
VOZ_FR:
  dw VOZ_F0
  dw VOZ_F1
  dw VOZ_F2
  dw VOZ_F3
  dw VOZ_F4
  dw VOZ_F5
  dw VOZ_F6
  dw VOZ_F7
  dw VOZ_F8
  dw VOZ_F9
  dw VOZ_F10
  dw VOZ_F11
  dw VOZ_F12
  dw VOZ_F13
VOZ_F0:  ; DESTROY THE EARTHLING
  db 44,16,15,40,14,28,3,0,39,15,0,37,23,0,33,9,32, 0xFF
VOZ_F1:  ; THE EARTH WILL BE MINE
  db 44,39,15,0,37,23,0,34,9,33,0,43,15,2,13,13,4,8,8, 0xFF
VOZ_F2:  ; PREPARE FOR DEFEAT
  db 44,7,7,11,15,7,35,0,29,42,0,26,15,29,15,10, 0xFF
VOZ_F3:  ; CONQUER THE WORLD
  db 44,6,18,18,8,30,36,1,39,15,0,34,37,33,26, 0xFF
VOZ_F4:  ; THIS PLANET IS MINE
  db 44,39,9,40,0,7,33,20,8,9,14,1,9,40,1,13,4,8, 0xFF
VOZ_F5:  ; YOUR PLANET IS DOOMED
  db 44,19,42,0,7,33,20,8,9,14,0,9,40,1,26,25,13,26, 0xFF
VOZ_F6:  ; DEFEND YOUR WORLD
  db 44,26,15,29,5,8,16,1,19,42,1,34,37,33,26, 0xFF
VOZ_F7:  ; ATTACK AND DESTROY
  db 44,12,10,20,30,2,20,8,16,2,26,15,40,14,28,3, 0xFF
VOZ_F8:  ; DEFEAT IS AT HAND
  db 44,26,15,29,15,10,0,9,40,0,20,10,1,21,20,8,26, 0xFF
VOZ_F9:  ; SEIZE THE PLANET
  db 44,40,15,31,1,39,15,1,7,33,20,8,9,14, 0xFF
VOZ_F10:  ; GOOD BYE EARTHLING
  db 44,27,24,16,0,43,4,1,37,23,0,33,9,32, 0xFF
VOZ_F11:  ; NOT BAD HUMAN
  db 44,8,18,14,0,43,20,26,1,41,17,13,12,8, 0xFF
VOZ_F12:  ; A COMMENDABLE DEFENSE
  db 44,5,15,0,30,12,13,13,5,8,16,12,22,24,33,2,26,15,29,5,8,40, 0xFF
VOZ_F13:  ; YOU ARE A WORTHY OPPONENT
  db 44,19,42,0,5,15,0,34,37,39,15,1,12,14,14,38,8,9,8,14, 0xFF
