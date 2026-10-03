# Simula o som do i8244 (como o MAME 0.264) a partir do registro de escritas e
# classifica cada quadro: silencio, tom (frequencia) ou ruido (rapido/lento).
from snd import snd
LINES = 262
def per(sig):
    for p in (2,3,4,6,8,12,24):
        if all(((sig >> i) & 1) == ((sig >> ((i + p) % 24)) & 1) for i in range(24)): return p
    return 24
def simulate(fn):
    fr = snd(fn)
    sig = 0; aa = 0; pres = 0; out = []
    for w in fr:
        wrote = False
        for r, v in w:
            if r == 0xaa: aa = v
            elif r in (0xa7, 0xa8, 0xa9):
                sh = {0xa7: 16, 0xa8: 8, 0xa9: 0}[r]
                sig = (sig & ~(0xff << sh)) | (v << sh); wrote = True
        seed = sig
        bits = []
        for l in range(LINES):
            pres += 1
            mask = 3 if aa & 0x20 else 0xf
            if (pres & mask) == 0:
                o = sig & 1; fb = o; s = sig >> 1
                if aa & 0x10:
                    fb ^= (s >> 4) & 1; s = (s & ~0x8000) | (fb << 15)
                s |= fb << 23; sig = s; bits.append(o)
        out.append(dict(aa=aa, seed=seed, wrote=wrote, bits=bits))
    return out
def classify(st):
    aa = st['aa']
    if not aa & 0x80 or (aa & 15) == 0: return ('-',)
    clk = 3933.6 if aa & 0x20 else 983.4
    if aa & 0x10: return ('N', 'R' if aa & 0x20 else 'L', aa & 15, st['seed'])
    p = per(st['seed'])
    ones = bin(st['seed'] & 0xffffff).count('1')
    if ones in (0, 24): return ('-',)
    return ('T', round(clk / p), aa & 15, st['seed'])
if __name__ == '__main__':
    import sys
    S = simulate(sys.argv[1]); a, b = int(sys.argv[2]), int(sys.argv[3])
    for n in range(a, b):
        c = classify(S[n]); print(n, c[:3], '%06x' % c[3] if len(c) > 3 else '')
