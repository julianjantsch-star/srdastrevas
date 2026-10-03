# Extrai do registro do MAME as sequencias fixas e os sons, em ref/mame/medidas.json
import json
from dec import frames, chars, sprites
from i8244snd import simulate
CART=open('cart/o2_45.bin','rb').read()
# formas das figuras (sprites), na ordem da tabela do cartucho 0xd52..0xdf9 e o rosto 0xf8f..
SHAPES={}
for a in list(range(0xd52,0xe02,8))+[0xf8f,0xf97]:
    SHAPES[CART[a:a+8].hex()]=a
for k in ('7ebddb7e7e7e3c00','00183c1818000000'):
    SHAPES.setdefault(k,None)
def spr_list(v):
    out=[]
    for i,(y,x,c,a,s) in enumerate(sprites(v)):
        if y<240 and s!='0000000000000000': out.append([i,y,x,c,a&4,s])
        else: out.append(None)
    return out
def chr_list(v):
    return [[c[0],c[1],c[2],c[3],c[4]] for c in chars(v)]
def seq(fn,a,b):
    F=list(frames(fn)); return [dict(f=n-a,ch=chr_list(F[n][0]),sp=spr_list(F[n][0])) for n in range(a,b)]
M={}
# abertura depois de uma morte (p1: a tela some no quadro 1091; a fila sai em ...)
F2=list(frames('p2.vdc'))
b0=[n for n in range(4237,4400) if not chars(F2[n][0]) and all(s is None for s in spr_list(F2[n][0]))][0]
fs=[n for n in range(b0,4700) if any(c[2]==62 for c in chars(F2[n][0]))][0]
M['abertura']=seq('p2.vdc',b0,fs+220)
M['abertura_fila']=fs-b0
M['morte']=seq('p2.vdc',4237,b0)
print('morte',4237,'vazio',b0,'fila',fs)
M['estouro_nave']=seq('p2.vdc',3289,3320)
M['fim_nivel']=seq('p2.vdc',3288,3410)
# sons: estados por quadro (aa, padrao) nas janelas de cada evento
S1=simulate('p1.snd'); S2=simulate('p2.snd')
def snd(S,a,b): return [[S[n]['aa'],S[n]['seed']] for n in range(a,b)]
M['som']=dict(
  inicio=snd(S1,300,309),            # tecla 1: 6 quadros de 656 Hz
  abertura=snd(S2,b0,fs+220),      # raios, cruz e a saida da fila
  pronto=snd(S1,613,625),            # o canhao chega
  marcha=snd(S1,625,661),            # fundo: 36 quadros em loop
  tiro=snd(S2,655,665),
  estouro=snd(S2,908+2,908+33),
  arma=snd(S1,898,906),
  morte=snd(S2,4237,b0),
)
M['formas']=SHAPES
json.dump(M,open('medidas.json','w'))
print('abertura',len(M['abertura']),'fila em',M['abertura_fila'])
