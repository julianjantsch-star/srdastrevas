#!/usr/bin/env python3
# Gera a fala do Senhor das Trevas para o MSX (src/voz.inc + src/voz.bin).
#
# O cartucho original (o2_45.bin) fala pelo The Voice: manda ALOFONES ao
# SP0256B-019 (as 14 frases estao no cartucho em 0x105-0x21F; a abertura sorteia
# uma das 11 primeiras). Aqui cada frase e sintetizada pelo nucleo do SP0256 do
# MAME (sp0256.cpp, BSD-3) num programa avulso (sim.cpp), recortada em alofones
# (cada um toca do aceite do seguinte ao aceite do outro), reamostrada de
# 9286 Hz para a taxa do MSX (com passa-baixa) e quantizada na soma dos volumes
# dos tres canais do PSG (1 byte por amostra, indice num trio de volumes). O MSX encadeia os alofones como o chip faz.
#
# Uso: python3 tools/voz/gen_voz.py <sp0256.cpp do MAME> <voice.zip do The Voice>
import sys, os, subprocess, zipfile, array, tempfile
import numpy as np

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
# volumes do PSG do MSX (YM2149 / S1985): 3 dB por passo, 0 = mudo
NIVEIS = [0.0] + [2 ** ((n - 15) / 2) for n in range(1, 16)]
U0, GANHO = 1.2, 1.4                     # o silencio e a excursao (soma de A, B e C)

def poda(vals, u, k):
  """tira valores da tabela ate sobrarem k, sempre o que menos aumenta o
  erro quadratico das amostras u (as amostras dele vao para um vizinho)"""
  v = np.array(vals, float)
  while len(v) > k:
    idx = np.abs(v[None, :] - u[:, None]).argmin(1)
    err0 = (v[idx] - u) ** 2
    cost = np.zeros(len(v))
    for i in np.unique(idx):
      m = idx == i; uu = u[m]
      alt = np.min([(v[j] - uu) ** 2 for j in (i - 1, i + 1) if 0 <= j < len(v)], axis=0)
      cost[i] = (alt - err0[m]).sum()
    vazios = np.where(cost == 0)[0]
    rm = vazios[:len(v) - k] if len(vazios) else [int(np.argmin(cost))]
    v = np.delete(v, rm)
  return v

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

  # tres canais (A, B e C) somados: o som do console espera a frase, entao
  # os tres sao da fala. Dos 608 niveis possiveis ficam os 256 que menos
  # pioram o erro na distribuicao real das amostras (cada amostra e um byte,
  # indice numa tabela de trios de volumes). Centro e ganho medidos contra a gravacao do MAME: ganho alto tira o chiado
  # dos trechos baixos; 1,4 ainda nao corta os picos das vogais.
  todos = np.concatenate([np.array(c, float) for k, c in cortes.items() if k > 4])
  ref = np.sort(np.abs(todos))[int(len(todos) * 0.995)] or 1
  Nv = np.array(NIVEIS)
  trios = {}
  for a_ in range(16):
    for b_ in range(16):
      for c_ in range(16):
        v = round(Nv[a_] + Nv[b_] + Nv[c_], 6)
        if v not in trios or max(a_, b_, c_) < max(trios[v]): trios[v] = (a_, b_, c_)
  vals = np.array(sorted(trios))
  u_all = U0 + todos[::7] / ref * GANHO
  vals = poda(vals, u_all, 256)
  tab_par = [(v,) + trios[round(float(v), 6)] for v in vals]
  def quant_arr(x):
    u = U0 + np.asarray(x) / ref * GANHO
    return np.abs(vals[None, :] - u[:, None]).argmin(1)
  # passa-baixa (sinc com janela, 3,4 kHz) e interpolacao para a taxa do MSX
  h = np.sinc(2 * 3400 / F_CHIP * (np.arange(63) - 31)) * np.hamming(63)
  h /= h.sum()
  # nas chiadas (S, SH, F, TH, T, K, P, CH, H...) o chiado mora acima da faixa
  # do MSX: sem filtro ele se dobra para dentro dela e o "s" continua se ouvindo
  CHIADAS = {"SS", "SH", "ZH", "ZZ", "FF", "TH", "HH1", "HH2", "CH", "JH",
             "TT1", "TT2", "KK1", "KK2", "KK3", "PP"}
  def ream(c, chiada=False):
    c = np.asarray(c, float)
    if not chiada: c = np.convolve(c, h, "same")
    n = int(len(c) * F_MSX / F_CHIP)
    return np.interp(np.arange(n) * F_CHIP / F_MSX, np.arange(len(c)), c)

  codigos = sorted(cortes)
  tab, dados, banco, pos = [], [bytearray()], BANCO0, 0
  for k in codigos:
    c = ream(cortes[k], k < 64 and AL[k] in CHIADAS)
    n = len(c)
    if k <= 4:                                       # pausa: so a duracao
      tab.append((k, 0xFF, 0, n)); continue
    if pos + n > 0x2000:
      dados.append(bytearray()); banco += 1; pos = 0
    dados[-1] += bytes(int(v) for v in quant_arr(c[:n]))
    tab.append((k, banco, 0xA000 + pos, n))
    pos += n
  bin_ = b"".join(bytes(d) + bytes(0x2000 - len(d)) for d in dados)
  open(os.path.join(SRC, "voz.bin"), "wb").write(bin_)

  idx = {k: i for i, (k, *_) in enumerate(tab)}
  o = ["; gerado por tools/voz/gen_voz.py: a fala do original (The Voice / SP0256) em alofones",
       "VOZ_BANCOS equ %d          ; bancos de 8 KB a partir do %d" % (len(dados), BANCO0),
       "VOZ_NPAR equ %d          ; trios de volume (A, B, C)" % len(tab_par),
       "VOZ_NFR equ %d" % len(FRASES),
       "; amostra = indice do trio: volumes A, B e C em VOZ_PA/PB/PC (copiados para a RAM)",
       "VOZ_PA: db " + ",".join(str(a) for v, a, b, c in tab_par),
       "VOZ_PB: db " + ",".join(str(b) for v, a, b, c in tab_par),
       "VOZ_PC: db " + ",".join(str(c) for v, a, b, c in tab_par),
       "; alofone: banco (0xFF = pausa), endereco em 0xA000-0xBFFF, amostras (1 por byte)",
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
