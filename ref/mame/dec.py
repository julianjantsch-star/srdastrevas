import sys
CS=open('charset_i8244.bin','rb').read()
def frames(fn):
    d=open(fn,'rb').read()
    for i in range(len(d)//512): yield d[i*512:i*512+256], d[i*512+256:i*512+512]
def chars(v):
    out=[]
    for i in range(12):
        y,x,p,a=v[16+4*i:20+4*i]
        if y>=0xf0 or x>=0xf0: continue
        cid=(((a&1)<<8|p)+(y>>1))&0x1ff
        out.append((y,x,cid>>3,cid&7,(a>>1)&7))
    return out
def quads(v):
    out=[]
    for q in range(4):
        b=0x40+16*q
        s=''
        for k in range(4):
            y,x,p,a=v[b+4*k:b+4*k+4]
            cid=(((a&1)<<8|p)+(y>>1))&0x1ff
            s+='%02x/%d '%(cid>>3,(a>>1)&7)
        out.append((v[b],v[b+1],s))
    return out
def sprites(v):
    out=[]
    for i in range(4):
        y,x,a,_=v[4*i:4*i+4]
        shp=v[0x80+8*i:0x88+8*i]
        out.append((y,x,(a>>3)&7,a&7,shp.hex()))
    return out
if __name__=='__main__':
    fn=sys.argv[1]; fs=[int(a) for a in sys.argv[2:]]
    for n,(v,x) in enumerate(frames(fn)):
        if n in fs:
            print('Q',n,'ctrl %02x bg %02x'%(v[0xa0],v[0xa3]))
            print('  chars',chars(v)); print('  spr',sprites(v)); print('  quads',quads(v))
