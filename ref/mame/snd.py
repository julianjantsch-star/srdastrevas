# registro de som: por quadro, lista de escritas (reg, valor) em 0xA7..0xAA
def snd(fn):
    d=open(fn,'rb').read(); fr=[]; cur=[]; i=0
    while i<len(d):
        if d[i]==254: fr.append(cur); cur=[]; i+=1
        else: cur.append((d[i+1],d[i+2])); i+=3
    return fr
if __name__=='__main__':
    import sys
    fr=snd(sys.argv[1]); a,b=int(sys.argv[2]),int(sys.argv[3])
    st={0xa7:0,0xa8:0,0xa9:0,0xaa:0}
    for n in range(a,b):
        w=[(r,v) for r,v in fr[n] if r>=0xa7]
        for r,v in w: st[r]=v
        if w: print(n,' '.join('%02x=%02x'%(r,v) for r,v in w))
