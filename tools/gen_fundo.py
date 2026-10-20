#!/usr/bin/env python3
# Gera os fundos do Videopac+ (modos 3 e 4) a partir de ref/fundo/terrahawks_g7400.png,
# o fundo do Terrahawks / Attack of the Timelord! plus (Videopac+ 51) no G7400,
# tirado do MAME (moda dos quadros, sem os objetos do jogo).
#   modo 3 (SCREEN 5): o fundo igual, 256 x 184, cores da paleta 2..5 e 15
#   modo 4 (SCREEN 8): a Terra redesenhada com luz e atmosfera (faixa 256 x 64,
#   linhas 120..183) + a Lua, os asteriscos e nuvens como sprites (que se movem)
# Saida: src/fundo.bin (bancos de 8 KB depois da fala) e src/fundo.inc
import sys, os
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.join(AQUI, "..")
SRC = os.path.join(RAIZ, "src")
img = np.array(Image.open(os.path.join(RAIZ, "ref/fundo/terrahawks_g7400.png")).convert("RGB")).astype(int)
K = (img[..., 0] << 16) | (img[..., 1] << 8) | img[..., 2]
H, W = K.shape
PRETO, BRANCO, VERM, VERDE, OLIVA, AZUL = 0, 0xffffff, 0x790000, 0x006d07, 0x77670b, 0x1a37be

# MSX (X, Y) -> pixel do MAME: chip x = (X - 6) / 1.5, chip y = Y + 8; MAME = (2x + 10, y)
def amostra(X, Y):
    xm = int(round(2 * ((X - 6) / 1.5) + 10)); ym = Y + 8
    if 0 <= xm < W and 0 <= ym < H: return K[ym, xm]
    return PRETO

# ---------------- modo 3: o fundo igual, SCREEN 5 ----------------
IDX = {PRETO: 0, BRANCO: 15, VERM: 2, VERDE: 3, OLIVA: 4, AZUL: 5}
F5_H = 184
f5 = np.zeros((F5_H, 256), int)
for Y in range(F5_H):
    for X in range(256):
        f5[Y, X] = IDX.get(amostra(X, Y), 0)
b5 = bytes((f5[Y, X] << 4) | f5[Y, X + 1] for Y in range(F5_H) for X in range(0, 256, 2))

# ---------------- modo 4: a Terra moderna, SCREEN 8 (GGGRRRBB) ----------------
B8_Y0, B8_H = 120, 64
cls = np.zeros((B8_H, 256), int)
for y in range(B8_H):
    for X in range(256):
        c = amostra(X, B8_Y0 + y)
        cls[y, X] = {OLIVA: 1, VERDE: 2, AZUL: 3}.get(c, 0)
# a Lua fica fora da faixa (vira sprite): tira a parte dela que entrava (oliva a direita, acima da Terra)
# contorno de cima da Terra -> circulo (minimos quadrados)
pts = []
for X in range(0, 190):                     # so a esquerda da Lua
    col = np.where(cls[:, X] > 0)[0]
    if len(col): pts.append((X, B8_Y0 + col[0]))
P = np.array(pts, float)
A = np.c_[2 * P[:, 0], 2 * P[:, 1], np.ones(len(P))]
bb = (P ** 2).sum(1)
cx, cy, c0 = np.linalg.lstsq(A, bb, rcond=None)[0]
R = np.sqrt(c0 + cx * cx + cy * cy)
L = np.array([-0.55, -0.65, 0.52]); L /= np.linalg.norm(L)
BASE = {1: (0.62, 0.50, 0.25), 2: (0.15, 0.55, 0.20), 3: (0.10, 0.30, 0.85)}
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
def q332(r, g, b, X, y):
    d = BAYER[y & 3, X & 3]
    R3 = int(np.clip(round(r * 7 + d), 0, 7)); G3 = int(np.clip(round(g * 7 + d), 0, 7)); B2 = int(np.clip(round(b * 3 + d * 0.8), 0, 3))
    return (G3 << 5) | (R3 << 2) | B2
b8 = bytearray()
for y in range(B8_H):
    Y = B8_Y0 + y
    for X in range(256):
        dx, dy = X - cx, Y - cy
        dist = np.hypot(dx, dy)
        c = cls[y, X]
        if c == 0 and dist <= R:          # buraco (onde estava a Lua ou fora da amostra): oceano
            c = 3
        if dist <= R:
            nz = np.sqrt(max(R * R - dist * dist, 0)); n = np.array([dx, dy, nz]) / R
            luz = 0.22 + 0.9 * max(0.0, float(n @ L))
            r, g, b = (v * luz for v in BASE[c])
            borda = (R - dist) / 6.0          # brilho azul da atmosfera na borda
            if borda < 1:
                t = 1 - borda; r, g, b = r + 0.10 * t, g + 0.25 * t, b + 0.45 * t
            b8.append(q332(min(r, 1), min(g, 1), min(b, 1), X, y))
        elif dist <= R + 4:                    # halo da atmosfera
            t = 1 - (dist - R) / 4.0
            b8.append(q332(0.15 * t, 0.35 * t, 0.85 * t, X, y))
        else:
            b8.append(0)

# ---------------- sprites do modo 4 ----------------
# Lua: 48 x 32 (3 x 2 sprites 16x16) a partir da Lua do original (oliva com o rosto em preto)
# a Lua no MAME: topo = menor y de oliva em x 240..300; a linha mais larga da o centro
ys, xs = np.where(K == OLIVA)
topo = ys[(xs >= 240) & (xs <= 300)].min()
melhor = None
for yy in range(topo, topo + 40):
    xx = xs[(ys == yy) & (xs > 228)]
    if len(xx) and (melhor is None or xx.max() - xx.min() > melhor[1] - melhor[0]): melhor = (xx.min(), xx.max(), yy)
mx0, mx1, myw = melhor
mcx, mcy = (mx0 + mx1) / 2.0, float(myw)
rx, ry = (mx1 - mx0) / 2.0, float(myw - topo)
lua = np.zeros((32, 48), int)
for y in range(32):
    for x in range(48):
        u, v = (x - 23.5) / 24.0, (y - 15.5) / 16.0
        if u * u + v * v > 1.0: continue
        xm = int(round(mx0 + (x + 0.5) / 48.0 * (mx1 - mx0)))
        ym = int(round(topo + (y + 0.5) / 32.0 * 42))
        px = K[ym, xm] if 0 <= ym < H and 0 <= xm < W else OLIVA
        lua[y, x] = 0 if px == PRETO else 1     # o rosto (preto) fica transparente
def spr16(m, ox, oy):
    out = []
    for half in (0, 8):
        for y in range(16):
            bits = 0
            for x in range(8):
                if m[oy + y, ox + half + x]: bits |= 0x80 >> x
            out.append(bits)
    return out
LUA_SPR = [spr16(lua, sx * 16, sy * 16) for sy in range(2) for sx in range(3)]
# cores por linha (paleta fixa dos sprites do G7): 15 branco, 14 amarelo, 8 laranja, 6 oliva
LUA_COR = [15] * 2 + [14] * 16 + [8] * 5 + [6] * 9
# asteriscos: 2 formas (gira) 16x16
def forma(pts):
    m = np.zeros((16, 16), int)
    for x, y in pts: m[y, x] = 1
    return spr16(m, 0, 0)
c = 7
ast_a = [(c, c + d) for d in range(-5, 6)] + [(c + d, c) for d in range(-5, 6)] + [(c + d, c + d) for d in range(-4, 5)] + [(c + d, c - d) for d in range(-4, 5)]
ast_b = [(c + d, c + d // 2) for d in range(-5, 6)] + [(c - d // 2, c + d) for d in range(-5, 6)] + [(c + d, c - d // 2) for d in range(-5, 6)] + [(c + d // 2, c + d) for d in range(-5, 6)]
AST_SPR = [forma(ast_a), forma(ast_b)]
# posicoes dos asteriscos (centro) no MSX
ys, xs = np.where(K == VERM)
grupos = [(xs < 85), (xs >= 85)]
AST_POS = []
for gsel in grupos:
    xm, ym = xs[gsel].mean(), ys[gsel].mean()
    AST_POS.append((int(round(((xm - 10) / 2) * 1.5 + 6)) - 7, int(round(ym - 8)) - 7))
# nuvens: 16 x 8
nuv = np.zeros((16, 16), int)
for y, row in enumerate(["................", "....######......", "..##########....", ".#############..",
                         "################", ".##############.", "...#########....", "................"]):
    for x, ch in enumerate(row):
        if ch == "#": nuv[y, x] = 1
NUV_SPR = [spr16(nuv, 0, 0)]
LUA_X, LUA_Y = int(round(((mcx - 10) / 2) * 1.5 + 6)) - 24, 24   # alto no ceu: longe da Terra e da cruz ampliada (8 sprites por linha)

# ---------------- RLE e bancos ----------------
def rle(data):
    out = bytearray(); i = 0
    while i < len(data):
        v = data[i]; n = 1
        while i + n < len(data) and data[i + n] == v and n < 255: n += 1
        out += bytes((n, v)); i += n
    return bytes(out)
r5, r8 = rle(b5), bytes(b8)          # o modo 4 tem pontilhado: vai cru
BANCO0 = int(sys.argv[1]) if len(sys.argv) > 1 else 9
blob = r5 + r8
nb = (len(blob) + 0x1FFF) // 0x2000
open(os.path.join(SRC, "fundo.bin"), "wb").write(blob + bytes(nb * 0x2000 - len(blob)))
def onde(off): return BANCO0 + off // 0x2000, 0xA000 + off % 0x2000
b5b, b5a = onde(0); b8b, b8a = onde(len(r5))
o = ["; gerado por tools/gen_fundo.py: os fundos do Videopac+ (Terrahawks / Timelord plus, G7400)",
     "FD_BANCOS equ %d" % nb,
     "FD5_BANCO equ %d" % b5b, "FD5_END equ 0x%04x" % b5a, "FD5_BYTES equ %d   ; 256 x %d em SCREEN 5" % (len(b5), F5_H),
     "FD5_H equ %d" % F5_H,
     "FD8_BANCO equ %d" % b8b, "FD8_END equ 0x%04x" % b8a, "FD8_BYTES equ %d   ; 256 x %d em SCREEN 8, sem compressao" % (len(b8), B8_H),
     "FD8_Y0 equ %d" % B8_Y0, "FD8_H equ %d" % B8_H,
     "FD_LUA_X equ %d" % LUA_X, "FD_LUA_Y equ %d" % LUA_Y,
     "FD_AST1_X equ %d" % AST_POS[0][0], "FD_AST1_Y equ %d" % AST_POS[0][1],
     "FD_AST2_X equ %d" % AST_POS[1][0], "FD_AST2_Y equ %d" % AST_POS[1][1],
     "; padroes dos sprites (16x16): 6 da Lua, 2 do asterisco, 1 da nuvem",
     "FD_SPR:"]
for s in LUA_SPR + AST_SPR + NUV_SPR:
    o.append("  db " + ",".join("0x%02x" % v for v in s))
o.append("FD_NSPR equ %d" % len(LUA_SPR + AST_SPR + NUV_SPR))
o.append("FD_LUA_COR: db " + ",".join(str(v) for v in LUA_COR))
open(os.path.join(SRC, "fundo.inc"), "w").write("\n".join(o) + "\n")
print("modo 3: %d -> %d bytes; modo 4: %d -> %d bytes; %d bancos; Terra: centro (%.0f, %.0f) raio %.0f; Lua em (%d, %d); asteriscos %s"
      % (len(b5), len(r5), len(b8), len(r8), nb, cx, cy, R, LUA_X, LUA_Y, AST_POS))
# previa
prev = Image.new("RGB", (256, 212))
pal = {0: (0, 0, 0), 15: (255, 255, 255), 2: (110, 0, 0), 3: (0, 110, 0), 4: (110, 110, 0), 5: (36, 73, 182)}
for Y in range(F5_H):
    for X in range(256): prev.putpixel((X, Y), pal[f5[Y, X]])
prev.resize((768, 636), Image.NEAREST).save(os.path.join(AQUI, "..", "out", "fundo3.png"))
p8 = Image.new("RGB", (256, 212))
for y in range(B8_H):
    for X in range(256):
        v = b8[y * 256 + X]; p8.putpixel((X, B8_Y0 + y), (((v >> 2) & 7) * 36, (v >> 5) * 36, (v & 3) * 85))
for i, s in enumerate(LUA_SPR):
    sx, sy = i % 3, i // 3
    for half in (0, 1):
        for y in range(16):
            for x in range(8):
                if s[half * 16 + y] & (0x80 >> x):
                    p8.putpixel((LUA_X + sx * 16 + half * 8 + x, LUA_Y + sy * 16 + y), {14: (255, 255, 0), 15: (255, 255, 255), 8: (255, 146, 73), 6: (110, 110, 0)}[LUA_COR[sy * 16 + y]])
for (ax, ay) in AST_POS:
    s = AST_SPR[0]
    for half in (0, 1):
        for y in range(16):
            for x in range(8):
                if s[half * 16 + y] & (0x80 >> x): p8.putpixel((ax + half * 8 + x, ay + y), (255, 0, 0))
p8.resize((768, 636), Image.NEAREST).save(os.path.join(AQUI, "..", "out", "fundo4.png"))
