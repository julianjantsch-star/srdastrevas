#!/usr/bin/env python3
# Gera a fala do Senhor das Trevas para o MSX (src/voz.inc + src/voz.bin).
#
# O cartucho original (o2_45.bin) fala pelo The Voice: manda ALOFONES ao
# SP0256B-019 (as 14 frases estao no cartucho em 0x105-0x21F; a abertura sorteia
# uma das 11 primeiras). Aqui cada frase e sintetizada pelo nucleo do SP0256 do
# MAME (sp0256.cpp, BSD-3) num programa avulso (sim.cpp), recortada em alofones
# (cada um toca do aceite do seguinte ao aceite do outro), reamostrada de
# 9286 Hz para a taxa do MSX e quantizada nos 16 volumes do PSG (4 bits, 2 por
# byte). O MSX encadeia os alofones como o chip faz.
#
# Uso: python3 tools/voz/gen_voz.py <sp0256.cpp do MAME> <voice.zip do The Voice>
import sys, os, subprocess, zipfile, array, tempfile

AQUI = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(AQUI, "..", "..", "src")
F_CHIP = 3120000 / (7 * 6 * 8)          # 9286 Hz (cristal de 3,12 MHz do The Voice)
# o MSX toca uma amostra a cada 2 linhas, linhas 0..244 (123 por quadro de 60 Hz)
F_MSX = 123 * 59.94
BANCO0 = 3                               # bancos de 8 KB do ASCII8: 0-2 codigo, 3.. fala
AL = ('PA1 PA2 PA3 PA4 PA5 OY AY EH KK3 PP JH NN1 IH TT2 RR1 AX MM TT1 DH1 IY EY DD1 UW1 AO AA YY2 AE HH1 '
      'BB1 TH UH UW2 AW DD2 GG3 VV GG1 SH ZH RR2 FF KK2 KK1 ZZ NG LL WW XR WH YY1 CH ER1 ER2 OW DH2 SS NN2 HH2 '
      'OR AR YR GG2 EL BB2').split()

# as 14 frases do cartucho (alofones do SP0256-AL2), na ordem da tabela dele
FRASES = [
  ("DESTROY THE EARTHLING", "15 13 37 11 27 05 02 36 13 02 34 1d 02 2d 0c 2c"),
  ("THE EARTH WILL BE MINE", "36 13 02 34 1d 02 2e 0c 2d 02 3f 13 04 10 10 06 0b 0b"),
  ("PREPARE FOR DEFEAT", "09 09 0e 13 09 2f 02 28 3a 02 21 13 28 13 0d"),
  ("CONQUER THE WORLD", "08 18 18 0b 2a 33 03 36 13 02 2e 34 2d 21"),
  ("THIS PLANET IS MINE", "36 0c 37 02 09 2d 1a 0b 0c 11 03 0c 37 03 10 06 0b"),
  ("YOUR PLANET IS DOOMED", "19 3a 02 09 2d 1a 0b 0c 11 02 0c 37 03 21 1f 10 21"),
  ("DEFEND YOUR WORLD", "21 13 28 07 0b 15 03 19 3a 03 2e 34 2d 21"),
  ("ATTACK AND DESTROY", "0f 0d 1a 2a 04 1a 0b 15 04 21 13 37 11 27 05"),
  ("DEFEAT IS AT HAND", "21 13 28 13 0d 02 0c 37 02 1a 0d 03 1b 1a 0b 21"),
  ("SEIZE THE PLANET", "37 13 2b 03 36 13 03 09 2d 1a 0b 0c 11"),
  ("GOOD BYE EARTHLING", "22 1e 15 02 3f 06 03 34 1d 02 2d 0c 2c"),
  ("NOT BAD HUMAN", "0b 18 11 02 3f 1a 21 03 39 16 10 0f 0b"),
  ("A COMMENDABLE DEFENSE", "07 13 02 2a 0f 10 10 07 0b 15 0f 1c 1e 2d 04 21 13 28 07 0b 37"),
  ("YOU ARE A WORTHY OPPONENT", "19 3a 02 07 13 02 2e 34 36 13 03 0f 11 11 35 0b 0c 0b 11"),
]
# volumes do PSG (AY-3-8910), normalizados
NIVEIS = [0.0, 0.0106, 0.0150, 0.0222, 0.0320, 0.0466, 0.0665, 0.1039, 0.1237, 0.1986,
          0.2803, 0.3548, 0.4702, 0.6030, 0.7530, 1.0]
U0 = 0.36                                # o silencio (meio da excursao)
CENTRO = min(range(16), key=lambda i: abs(NIVEIS[i] - U0))

def main(sp_cpp, voice_zip):
  tmp = tempfile.mkdtemp()
  # programa avulso: o nucleo do MAME (lpc12, tabelas, microsequenciador) + sim.cpp
  linhas = open(sp_cpp).read().split("\n")
  ini = next(i for i, l in enumerate(linhas) if "inline int16_t sp0256_device::lpc12_t::limit" in l)
  fim = next(i for i, l in enumerate(linhas) if l.startswith("uint16_t sp0256_device::spb640_r"))
  open(os.path.join(tmp, "core.inc"), "w").write("\n".join(linhas[ini:fim]))
  subprocess.check_call(["g++", "-O2", "-w", "-o", os.path.join(tmp, "sim"), os.path.join(AQUI, "sim.cpp"), "-I", tmp])
  rom = bytearray(0x10000)
  z = zipfile.ZipFile(voice_zip)
  rom[0x1000:0x1800] = z.read("sp0256b-019.bin")
  rom[0x4000:0x8000] = z.read("spr128-003.bin")
  open(os.path.join(tmp, "rom.bin"), "wb").write(rom)

  cortes = {}
  for nome, s in FRASES:
    seq = [0x64] + [int(x, 16) for x in s.split()] + [0x64, 0x00]
    r = subprocess.run([os.path.join(tmp, "sim"), os.path.join(tmp, "rom.bin"), " ".join("%02x" % x for x in seq),
                        os.path.join(tmp, "f.raw")], stderr=subprocess.PIPE, text=True).stderr.split("\n")
    ac = [int(l.split()[0]) for l in r if l.strip() and not l.endswith("fim")]
    a = array.array("h", open(os.path.join(tmp, "f.raw"), "rb").read())
    for n in range(len(seq) - 2):
      cortes.setdefault(seq[n], a[ac[n + 1]:ac[n + 2]])

  # ganho: o percentil 99,5 da amplitude chega a +-0,6 em volta de 0,36 (os
  # picos cortam); escolhido pela melhor correlacao com o som do chip (11 dB)
  # (os picos raros cortam); os volumes do PSG sao logaritmicos
  todos = sorted(abs(x) for k, c in cortes.items() if k > 4 for x in c)
  ref = todos[int(len(todos) * 0.995)] or 1
  def quant(x):
    u = U0 + x / ref * 0.6
    return min(range(16), key=lambda i: abs(NIVEIS[i] - u))
  def ream(c):
    n = int(len(c) * F_MSX / F_CHIP)
    out = []
    for i in range(n):
      p = i * F_CHIP / F_MSX; j = int(p); f = p - j
      a0 = c[j] if j < len(c) else 0; a1 = c[j + 1] if j + 1 < len(c) else a0
      out.append(a0 + (a1 - a0) * f)
    return out

  codigos = sorted(cortes)
  tab, dados, banco, pos = [], [bytearray()], BANCO0, 0
  for k in codigos:
    c = ream(cortes[k])
    n = len(c) & ~1
    if k <= 4:                                       # pausa: so a duracao
      tab.append((k, 0xFF, 0, n)); continue
    nb = n // 2
    if pos + nb > 0x2000:
      dados.append(bytearray()); banco += 1; pos = 0
    q = [quant(x) for x in c[:n]]
    dados[-1] += bytes((q[i] << 4) | q[i + 1] for i in range(0, n, 2))
    tab.append((k, banco, 0xA000 + pos, n))
    pos += nb
  bin_ = b"".join(bytes(d) + bytes(0x2000 - len(d)) for d in dados)
  open(os.path.join(SRC, "voz.bin"), "wb").write(bin_)

  idx = {k: i for i, (k, *_) in enumerate(tab)}
  o = ["; gerado por tools/voz/gen_voz.py: a fala do original (The Voice / SP0256) em alofones",
       "VOZ_BANCOS equ %d          ; bancos de 8 KB a partir do %d" % (len(dados), BANCO0),
       "VOZ_CENTRO equ %d          ; volume do PSG do silencio" % CENTRO,
       "VOZ_NFR equ %d" % len(FRASES),
       "; alofone: banco (0xFF = pausa), endereco em 0xA000-0xBFFF, amostras (2 por byte)",
       "VOZ_TAB:"]
  for k, b, ad, n in tab:
    o.append("  db 0x%02x\n  dw 0x%04x, %d     ; %s" % (b, ad, n, AL[k] if k < 64 else "0x%02x" % k))
  o.append("VOZ_FR:")
  for i in range(len(FRASES)): o.append("  dw VOZ_F%d" % i)
  for i, (nome, s) in enumerate(FRASES):
    seq = [0x64] + [int(x, 16) for x in s.split()]
    o.append("VOZ_F%d:  ; %s\n  db %s, 0xFF" % (i, nome, ",".join(str(idx[x]) for x in seq)))
  open(os.path.join(SRC, "voz.inc"), "w").write("\n".join(o) + "\n")
  print("alofones", len(tab), "bancos", len(dados), "bytes", len(bin_), "taxa", round(F_MSX))

if __name__ == "__main__":
  main(sys.argv[1], sys.argv[2])
