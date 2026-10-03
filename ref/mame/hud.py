from dec import *
CH='0123456789:$ ?L' # parcial
def hudchars(v):
    s=[]
    for q in range(4):
        b=0x40+16*q; qy=v[b]; x0=v[b+1]
        for k in range(4):
            y,x,p,a=v[b+4*k:b+4*k+4]
            cid=((((a&1)<<8|p)+(qy>>1))&0x1ff)>>3
            s.append((x0+16*k,cid,(a>>1)&7))
    s.sort()
    return s
def hudtxt(v):
    return ''.join(str(c) if c<10 else ('>' if c==0x10 else '?' if c==0x0d else '.' if c==0x2e else '[%x]'%c) for _,c,_ in hudchars(v))
