#include <cstdint>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <memory>
#include <vector>
#define LOG(...) do{}while(0)
#define LOGFIFO(...) do{}while(0)
#define CLOCK_DIVIDER (7*6*8)
#define HIGH_QUALITY
#define SCBUF_SIZE   (4096)
#define SCBUF_MASK   (SCBUF_SIZE - 1)
#define PER_PAUSE    (64)
#define PER_NOISE    (64)
#define FIFO_ADDR    (0x1800 << 3)
typedef uint32_t offs_t;
struct nocb { void operator()(int){} };
struct nostream { void update(){} };
class sp0256_device {
public:
	void ald_w(uint8_t data); int lrq_r(); int sby_r();
	struct lpc12_t {
		int update(int num_samp, int16_t *out, uint32_t *optr); void regdec();
		int rpt, cnt; uint32_t per, rng; int amp; int16_t f_coef[6]; int16_t b_coef[6]; int16_t z_data[6][2]; uint8_t r[16]; int interp;
		static int16_t limit(int16_t s);
	};
	uint32_t getb(int len); void micro(); void bitrevbuff(uint8_t*, unsigned int, unsigned int);
	void SET_SBY(int s){ m_sby_line=s; }
	uint8_t *m_rom; nostream *m_stream = new nostream; nocb m_drq_cb, m_sby_cb;
	int m_sby_line, m_cur_len, m_silent; int16_t m_scratch[SCBUF_SIZE]; uint32_t m_sc_head, m_sc_tail;
	lpc12_t m_filt; int m_lrq, m_ald, m_pc, m_stack, m_fifo_sel, m_halted; uint32_t m_mode, m_page;
	uint32_t m_fifo_head, m_fifo_tail, m_fifo_bitp; uint16_t m_fifo[64];
	void reset(){ m_fifo_head=m_fifo_tail=m_fifo_bitp=0; memset(&m_filt,0,sizeof(m_filt)); m_halted=1; m_filt.rpt=-1; m_filt.rng=1; m_lrq=1; m_ald=0; m_pc=0; m_stack=0; m_fifo_sel=0; m_mode=0; m_page=0x1000<<3; m_silent=1; m_sby_line=1; m_sc_head=m_sc_tail=0; }
	// um passo de amostra (como o stream do MAME pedindo 1 amostra)
	int16_t sample(){
		if (m_sc_tail != m_sc_head) { int16_t v=m_scratch[m_sc_tail++ & SCBUF_MASK]; m_sc_tail&=SCBUF_MASK; return v; }
		int did=0;
		do {
			if (m_filt.rpt <= 0) micro();
			if (m_silent && m_filt.rpt <= 0) { m_scratch[m_sc_head++ & SCBUF_MASK]=0; did=1; }
			else did += m_filt.update(1, m_scratch, &m_sc_head);
			m_sc_head &= SCBUF_MASK;
		} while (m_filt.rpt >= 0 && did < 1);
		if (m_sc_tail != m_sc_head) { int16_t v=m_scratch[m_sc_tail++ & SCBUF_MASK]; m_sc_tail&=SCBUF_MASK; return v; }
		return 0;
	}
};
#define sp0256_datafmt sp0256_datafmt
#include "core.inc"
// uso: sim rom.bin "a b c ..." out.raw  -> 10 kHz s16; tambem imprime o indice de amostra em que cada codigo foi aceito
int main(int argc,char**argv){
	static uint8_t rom[0x10000]; FILE*f=fopen(argv[1],"rb"); fread(rom,1,0x10000,f); fclose(f);
	sp0256_device d; d.m_rom=rom; d.reset();
	std::vector<int> q; char*s=argv[2]; char*e; while(*s){ long v=strtol(s,&e,16); if(e==s)break; q.push_back((int)v); s=e; }
	FILE*o=fopen(argv[3],"wb"); size_t qi=0; long n=0; int quiet=0;
	while (n < 10000*30) {
		if (qi<q.size() && d.m_lrq) { fprintf(stderr,"%ld %02x\n",n,q[qi]); d.ald_w(q[qi++]); }
		int16_t v=d.sample(); fwrite(&v,2,1,o); n++;
		if (qi>=q.size() && d.m_lrq && d.m_halted && d.m_filt.rpt<=0) { if (++quiet>200) break; } else quiet=0;
	}
	fprintf(stderr,"%ld fim\n",n); fclose(o);
}
