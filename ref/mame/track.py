from dec import *
from hud import hudchars
import sys
def run(fn, lo=0, hi=10**9, verbose=False):
    F=list(frames(fn))
    # nivel: conta ondas (quando o numero de naves sobe de 0); zera quando o placar zera
    nivel=0; prevn=0; prevsc=None
    act={}  # slot -> dict
    out=[]
    for n,(v,x) in enumerate(F):
        if n<lo or n>hi: continue
        sh=[c for c in chars(v) if c[2]==62]
        sc=''.join(str(c) for _,c,_ in hudchars(v)[12:16])
        if prevsc is not None and sc=='0000' and prevsc!='0000': nivel=0
        if len(sh)>0 and prevn==0: nivel+=1
        prevn=len(sh); prevsc=sc
        sps=sprites(v)
        for i in (1,2,3):
            y,xx,c,a,s=sps[i]
            vis = y<240 and s!='0000000000000000' and not s.startswith('38383f') and s not in ('1c1cfcffff3f3838','7077771ff8eeee0e','e7e7e71818e7e7e7','0eeeeef81f777770','0018187e7e181800','0066661818666600','003c7e7e7e7e3c00','3c7effffffff7e3c') 
            if vis:
                if i not in act:
                    act[i]={'n0':n,'lvl':nivel,'shape':set(),'col':set(),'path':[],'ships':[(c2[0],c2[1]) for c2 in sh]}
                d=act[i]; d['shape'].add(s); d['col'].add(c); d['path'].append((n,y,xx))
            elif i in act:
                d=act.pop(i); d['n1']=n; out.append(d)
    return out
if __name__=='__main__':
    for d in run(sys.argv[1]):
        p=d['path']; dys=[p[k+1][1]-p[k][1] for k in range(len(p)-1)]; dxs=[p[k+1][2]-p[k][2] for k in range(len(p)-1)]
        print('nv',d['lvl'],'q',d['n0'],'-',d['n1'],'ini',p[0][1:],'fim',p[-1][1:],'cores',sorted(d['col']),'formas',sorted(s[:8] for s in d['shape']),'dy',''.join('%d'%a for a in dys[:40]),'dx',''.join('%+d'%a if a else '0' for a in dxs[:30]))
