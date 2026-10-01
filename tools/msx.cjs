// Harness MSX2+ headless: Z80 (z80js) + VDP V9938 (G6/SCREEN 7 + command engine)
// + PPI (teclado) + PSG (captura). Usado para testar a ROM sem emulador externo.
const Z80 = require("./z80fix.cjs");
const zlib = require("zlib");
const fs = require("fs");

const CPU_HZ = 3579545;
const CYCLES_PER_FRAME = parseInt(process.env.MSX_CYCLES || "0", 10) || Math.round(CPU_HZ / 60);

// Matriz de teclado MSX: linha -> nomes dos bits 0..7
const MATRIX = [
  ["0", "1", "2", "3", "4", "5", "6", "7"],
  ["8", "9", "MINUS", "EQ", "BSLASH", "LBRACK", "RBRACK", "SEMI"],
  ["QUOTE", "BQUOTE", "COMMA", "PERIOD", "SLASH", "UNDER", "A", "B"],
  ["C", "D", "E", "F", "G", "H", "I", "J"],
  ["K", "L", "M", "N", "O", "P", "Q", "R"],
  ["S", "T", "U", "V", "W", "X", "Y", "Z"],
  ["SHIFT", "CTRL", "GRAPH", "CAPS", "CODE", "F1", "F2", "F3"],
  ["F4", "F5", "ESC", "TAB", "STOP", "BS", "SELECT", "RET"],
  ["SPACE", "HOME", "INS", "DEL", "LEFT", "UP", "DOWN", "RIGHT"],
];
const KEYPOS = {};
MATRIX.forEach((row, r) => row.forEach((name, b) => { if (name) KEYPOS[name] = [r, b]; }));

class VDP {
  constructor() {
    this.vram = new Uint8Array(0x20000);
    this.regs = new Uint8Array(64);
    this.status = new Uint8Array(16);
    this.now = 0; this.busyUntil = 0; this.timing = true; this.cmdUs = 0;
    this.pal = new Uint8Array(32);       // 16 cores x (RB, G)
    this.addr = 0;
    this.latch = 0;
    this.second = false;
    this.palLatch = -1;
    this.readAhead = 0;
    this.cmdCount = 0;
    this.regs[8] = 0x08;
  }
  writeCtrl(v) {
    if (!this.second) { this.latch = v & 0xff; this.second = true; return; }
    this.second = false;
    if (v & 0x80) this.setReg(v & 0x3f, this.latch);
    else {
      this.addr = (((this.regs[14] & 7) << 14) | ((v & 0x3f) << 8) | this.latch) & 0x1ffff;
      if (!(v & 0x40)) { this.readAhead = this.vram[this.addr]; this.addr = (this.addr + 1) & 0x1ffff; }
    }
  }
  readStatus() {
    const n = this.regs[15] & 0x0f;
    if (n === 2) { if (this.now < this.busyUntil) this.status[2] |= 0x01; else this.status[2] &= ~0x01; }
    let v = this.status[n];
    if (n === 0) this.status[0] &= ~0x80;   // limpa flag de vblank na leitura
    if (n === 1) { v = (v & 1) | 0x04; this.status[1] &= ~0x01; }   // S#1: FH (interrupcao de linha) + ID do V9958; ler limpa o FH
    return v;
  }
  // o feixe entrou na linha r (0-255, relativa ao inicio da area ativa, como o R#19 conta)
  linha(r) { if (r === this.regs[19]) this.status[1] |= 0x01; }
  // pino INT: vblank com IE0 (R#1 bit 5) ou linha com IE1 (R#0 bit 4)
  intPend() { return ((this.status[1] & 0x01) && (this.regs[0] & 0x10)) || ((this.status[0] & 0x80) && (this.regs[1] & 0x20)); }
  setReg(r, v) {
    this.regs[r] = v & 0xff;
    if (r === 14) this.addr = (this.addr & 0x3fff) | ((v & 7) << 14);
    if (r === 16) this.palLatch = -1;
    if (r === 46) this.execCommand(v & 0xff);
  }
  writeData(v) { this.vram[this.addr] = v & 0xff; this.addr = (this.addr + 1) & 0x1ffff; }
  readData() { const v = this.readAhead; this.readAhead = this.vram[this.addr]; this.addr = (this.addr + 1) & 0x1ffff; return v; }
  writePal(v) {
    const i = (this.regs[16] & 0x0f);
    if (this.palLatch < 0) { this.palLatch = v & 0xff; }
    else {
      this.pal[i * 2] = this.palLatch; this.pal[i * 2 + 1] = v & 0x07;
      this.palLatch = -1;
      this.regs[16] = (i + 1) & 0x0f;
    }
  }
  writeIndirect(v) {
    const r = this.regs[17] & 0x3f;
    const noInc = this.regs[17] & 0x80;
    this.setReg(r, v);
    if (!noInc) this.regs[17] = (this.regs[17] & 0x80) | ((r + 1) & 0x3f);
  }
  // --- geometria da tela conforme o modo de video ---
  // G4 (SCREEN 5): 256 pixels/linha = 128 bytes.  G6 (SCREEN 7): 512 = 256 bytes.
  isG4() { return (this.regs[0] & 0x0e) === 0x06; }
  isG7() { return (this.regs[0] & 0x0e) === 0x0e; }   // SCREEN 8: 1 byte por pixel
  bpl() { return this.isG4() ? 128 : 256; }
  scrW() { return (this.isG4() || this.isG7()) ? 256 : 512; }
  xmask() { return this.bpl() - 1; }

  // --- command engine (2 pixels por byte em G4/G6, 1 em G7) ---
  rd(x, y) { return this.vram[(((y & 0x3ff) * this.bpl()) | ((this.isG7() ? x : (x >> 1)) & this.xmask())) & 0x1ffff]; }
  wr(x, y, v) { this.vram[(((y & 0x3ff) * this.bpl()) | ((this.isG7() ? x : (x >> 1)) & this.xmask())) & 0x1ffff] = v & 0xff; }
  getPix(x, y) { const b = this.rd(x, y); if (this.isG7()) return b; return (x & 1) ? (b & 0x0f) : (b >> 4); }
  setPix(x, y, c, lop) {
    if (this.isG7()) { const nv = this.logop(this.rd(x, y), c & 0xff, lop, 0xff); if (nv !== null) this.wr(x, y, nv); return; }
    const b = this.rd(x, y);
    const old = (x & 1) ? (b & 0x0f) : (b >> 4);
    const nv = this.logop(old, c & 0x0f, lop, 0x0f);
    if (nv === null) return;
    this.wr(x, y, (x & 1) ? ((b & 0xf0) | nv) : ((b & 0x0f) | (nv << 4)));
  }
  logop(dst, src, lop, mask) {
    if ((lop & 0x08) && src === 0) return null;   // variantes transparentes
    switch (lop & 0x07) {
      case 0: return src;
      case 1: return dst & src;
      case 2: return dst | src;
      case 3: return dst ^ src;
      case 4: return (~src) & mask;
      default: return dst;
    }
  }
  // leitor de pixel para as ferramentas: indice (G4) ou byte GGGRRRBB (G7)
  pixel(x, y, base) { const a = (base + y * this.bpl() + (this.isG7() ? x : (x >> 1))) & 0x1ffff; const b = this.vram[a]; if (this.isG7()) return b; return (x & 1) ? (b & 0x0f) : (b >> 4); }
  pixelRGB(x, y, base) { const p = this.pixel(x, y, base); if (this.isG7()) return [Math.round(((p >> 2) & 7) * 255 / 7), Math.round((p >> 5) * 255 / 7), Math.round((p & 3) * 255 / 3)]; return this.rgb(p); }
  displayOn() { return (this.regs[1] & 0x40) !== 0; }
  execCommand(cmd) {
    const R = this.regs;
    const op = cmd >> 4, lop = cmd & 0x0f;
    const SX = (R[32] | (R[33] << 8)) & 0x1ff;
    const SY = (R[34] | (R[35] << 8)) & 0x3ff;
    const DX = (R[36] | (R[37] << 8)) & 0x1ff;
    const DY = (R[38] | (R[39] << 8)) & 0x3ff;
    let NX = (R[40] | (R[41] << 8)) & 0x3ff; if (NX === 0) NX = this.scrW();
    let NY = (R[42] | (R[43] << 8)) & 0x3ff; if (NY === 0) NY = 1024;
    const CLR = R[44];
    const dix = (R[45] & 0x04) ? -1 : 1;
    const diy = (R[45] & 0x08) ? -1 : 1;
    const BPL = this.bpl(), XM = this.xmask(), G7 = this.isG7();
    this.cmdCount++;
    if (this.timing) {
      const bytes = (G7 ? NX : Math.max(1, NX >> 1)) * NY, pix = NX * NY;
      // MSX real (11/09): 50 HMMM de 14x12 em S5 = 1876 esperas de ~11 us -> 412 us
      // cada (84 bytes); em S8 (168 bytes) 787 us: 37 us + 4,46 us/byte. HMMV de
      // 256x212 em S5 = 76 ms -> 2,8 us/byte. LMMV/LMMM escalados na mesma razao.
      const us = 37 + (op === 0xc ? bytes * 2.8 : op === 0xd ? bytes * 4.46 : op === 0x8 ? pix * 6.2 : op === 0x9 ? pix * 8.4 : 0);
      this.busyUntil = Math.max(this.now, this.busyUntil || 0) + Math.round(us * 3.579545);
      this.cmdUs = (this.cmdUs || 0) + us;
    }
    switch (op) {
      case 0xc: { // HMMV - preenche bytes
        const nxb = G7 ? NX : Math.max(1, NX >> 1), dxb = G7 ? DX : (DX >> 1);
        for (let y = 0; y < NY; y++) {
          for (let xb = 0; xb < nxb; xb++) {
            this.vram[((((DY + y * diy) & 0x3ff) * BPL) | ((dxb + xb * dix) & XM)) & 0x1ffff] = CLR;
          }
        }
        break;
      }
      case 0xd: { // HMMM - copia bytes
        const nxb = G7 ? NX : Math.max(1, NX >> 1), sxb = G7 ? SX : (SX >> 1), dxb = G7 ? DX : (DX >> 1);
        const buf = [];
        for (let y = 0; y < NY; y++) {
          for (let xb = 0; xb < nxb; xb++) {
            buf.push(this.vram[((((SY + y * diy) & 0x3ff) * BPL) | ((sxb + xb * dix) & XM)) & 0x1ffff]);
          }
        }
        let k = 0;
        for (let y = 0; y < NY; y++) {
          for (let xb = 0; xb < nxb; xb++) {
            this.vram[((((DY + y * diy) & 0x3ff) * BPL) | ((dxb + xb * dix) & XM)) & 0x1ffff] = buf[k++];
          }
        }
        break;
      }
      case 0x8: // LMMV - preenche pixels
        for (let y = 0; y < NY; y++) {
          for (let x = 0; x < NX; x++) this.setPix(DX + x * dix, DY + y * diy, G7 ? CLR : (CLR & 0x0f), lop);
        }
        break;
      case 0x9: { // LMMM - copia pixels
        const buf = [];
        for (let y = 0; y < NY; y++) {
          for (let x = 0; x < NX; x++) buf.push(this.getPix(SX + x * dix, SY + y * diy));
        }
        let k = 0;
        for (let y = 0; y < NY; y++) {
          for (let x = 0; x < NX; x++) this.setPix(DX + x * dix, DY + y * diy, buf[k++], lop);
        }
        break;
      }
      case 0x0: break; // STOP
      default: this.unknownCmd = cmd; break;
    }
    if (!this.timing) this.status[2] &= ~0x01; // sem modelo de tempo: concluido na hora
  }
  displayBase() {
    // G4: paginas de 32KB selecionadas pelos bits 5-6 de R#2. G6: 2 paginas de 64KB.
    if (this.isG4()) return (((this.regs[2] >> 5) & 3) * 0x8000) & 0x1ffff;
    return (this.regs[2] & 0x20) ? 0x10000 : 0;
  }
  rgb(i) {
    const rb = this.pal[i * 2], g = this.pal[i * 2 + 1];
    const r = (rb >> 4) & 7, b = rb & 7;
    const s = v => Math.round(v * 255 / 7);
    return [s(r), s(g), s(b)];
  }
}

// O MSX real gasta mais que os T nominais: 1 T de espera por ciclo M1 (MSX)
// e ~3 T por acesso de I/O (medido com TESTE.ROM: laco de 36 T rodou 1391
// vezes por quadro, 42,9 T cada; WebMSX 1493). Prefixos CB/DD/ED/FD sao um
// M1 a mais; DD CB / FD CB dois.
function extraT(op, op2) {
  let e = 1;
  if (op === 0xcb || op === 0xdd || op === 0xed || op === 0xfd) {
    e = 2;
    if ((op === 0xdd || op === 0xfd) && op2 === 0xcb) e = 3;
    if (op === 0xed) {
      const io = (op2 & 0xc7) === 0x40 || (op2 & 0xc7) === 0x41 || (op2 & 0xe4) === 0xa2;   // in r,(c) / out (c),r / ini,ind,outi,outd e repetidos
      if (io) e += 3;
    }
  } else if (op === 0xdb || op === 0xd3) e += 3;   // in a,(n) / out (n),a
  return e;
}
class MSX {
  constructor(rom) {
    this.mem = new Uint8Array(65536);
    this.romStart = 0x4000; this.romEnd = 0x4000 + rom.length;
    this.mem.set(rom, 0x4000);
    // BIOS minimo: ENASLT (0x0024, so retorna) e RSLREG (0x0138: in a,(0xA8); ret).
    // A pagina 2 (0x8000-0xBFFF) do cartucho so aparece depois de ENASLT,
    // como na maquina real: o BIOS chama o INIT com a pagina 1 apenas
    this.mem[0x0024] = 0xc9;
    this.mem[0x0138] = 0xdb; this.mem[0x0139] = 0xa8; this.mem[0x013a] = 0xc9;
    // 0x0038 (IM 1), como o BIOS: le o S#0 (limpa o vblank) e volta
    [0xf5, 0xdb, 0x99, 0xf1, 0xfb, 0xc9].forEach((b, i) => { this.mem[0x0038 + i] = b; });
    this.frameStart = 0; this.linhaK = 0; this.proxLinha = CYCLES_PER_FRAME / 262; this.eiDelay = false; this.nInts = 0;
    this.pag2 = false;
    this.romWrites = [];
    this.vdp = new VDP();
    this.keys = new Uint8Array(16).fill(0xff);
    this.ppiC = 0;
    this.psg = new Uint8Array(16);
    this.psgAddr = 0;
    this.joy1 = 0xff;   // joystick 1: bit 0 cima, 1 baixo, 2 esq, 3 dir, 4 A, 5 B (0 = apertado)
    this.psgLog = [];
    this.cycles = 0;
    const self = this;
    const memI = {
      read8: a => { a &= 0xffff; return (a & 0xc000) === 0x8000 && !self.pag2 ? 0xff : self.mem[a]; },
      write8: (a, v) => {
        a &= 0xffff;
        if (a >= self.romStart && a < self.romEnd) {
          if (self.romWrites.length < 50) self.romWrites.push([a, v, self.cpu ? self.cpu.pc : 0]);
          return;
        }
        self.mem[a] = v & 0xff;
      },
    };
    const portI = {
      read: p => self.inPort(p & 0xff),
      write: (p, v) => self.outPort(p & 0xff, v & 0xff),
    };
    this.cpu = new Z80(memI, portI, false);
    this.cpu.pc = this.mem[0x4002] | (this.mem[0x4003] << 8);
    this.cpu.r1.sp = 0xf380;
    // toda execucao de instrucao (inclusive pelas ferramentas, que chamam
    // cpu.execute() direto) avanca o relogio: senao um WaitCmd fora de
    // runFrames ficaria esperando um VDP parado no tempo
    const raw = this.cpu.execute.bind(this.cpu);
    this.cpu.execute = () => this.step(raw);
  }
  // uma instrucao, com as esperas de M1/IO do MSX real; devolve os T gastos
  step(raw) {
    const cpu = this.cpu;
    // interrupcao mascaravel (o nucleo z80js nao atende: faz-se aqui). Depois
    // de um EI a CPU ainda executa uma instrucao antes de aceitar.
    let di = 0;
    if (!this.eiDelay && cpu.iff1 && this.vdp.intPend()) di = this.aceitaInt();
    this.eiDelay = false;
    const t0 = cpu.tStates, pc = cpu.pc, op = this.mem[pc], op2 = this.mem[(pc + 1) & 0xffff];
    if (pc === 0x0024) this.pag2 = true;   // ENASLT: o cartucho passa a ocupar a pagina 2
    raw();
    if (op === 0xfb) this.eiDelay = true;
    let d = cpu.tStates - t0;
    if (d <= 0) d = 4;
    d += extraT(op, op2);
    this.cycles += d;
    this.vdp.now = this.cycles;
    if (this.cycles >= this.proxLinha) this.avancaLinhas();
    return d + di;
  }
  // IM 1: rst 0x38; IM 2: vetor em (I*256 + 0xFF), o barramento do MSX flutua em 0xFF
  aceitaInt() {
    const cpu = this.cpu; cpu.iff1 = false; cpu.iff2 = false;
    if (cpu.halted) { cpu.halted = false; cpu.pc = (cpu.pc + 1) & 0xffff; }
    const sp = (cpu.r1.sp - 2) & 0xffff; cpu.r1.sp = sp; this.mem[sp] = cpu.pc & 0xff; this.mem[(sp + 1) & 0xffff] = cpu.pc >> 8;
    let custo;
    if (cpu.im === 2) { const v = ((cpu.i & 0xff) << 8) | 0xff; cpu.pc = this.mem[v] | (this.mem[(v + 1) & 0xffff] << 8); custo = 19; } else { cpu.pc = 0x0038; custo = 13; }
    custo += 2;   // esperas do MSX no ciclo de reconhecimento
    this.cycles += custo; this.vdp.now = this.cycles; this.nInts++;
    return custo;
  }
  // linhas de varredura: o quadro do emulador comeca no vblank (linha 212 do
  // R#19); 262 linhas: 212..229, depois -32..211 (como o openMSX conta)
  avancaLinhas() {
    while (this.cycles >= this.proxLinha) {
      if (this.linhaK >= 261) { this.proxLinha = Infinity; break; }   // a virada do quadro e do runFrames
      this.linhaK++; const kk = this.linhaK; this.vdp.linha((kk < 18 ? 212 + kk : kk - 50) & 0xff);
      this.proxLinha = this.frameStart + (kk + 1) * CYCLES_PER_FRAME / 262;
    }
  }
  inPort(p) {
    this.vdp.now = this.cycles;
    switch (p) {
      case 0x98: return this.vdp.readData();
      case 0x99: return this.vdp.readStatus();
      case 0xa2: if ((this.psgAddr & 0x0f) === 14) return (this.psg[15] & 0x40) ? 0xff : this.joy1; return this.psg[this.psgAddr & 0x0f];
      case 0xa8: return 0x00;
      case 0xa9: return this.keys[this.ppiC & 0x0f];
      case 0xaa: return this.ppiC;
      default: return 0xff;
    }
  }
  outPort(p, v) {
    this.vdp.now = this.cycles;
    switch (p) {
      case 0x98: this.vdp.writeData(v); break;
      case 0x99: this.vdp.writeCtrl(v); break;
      case 0x9a: this.vdp.writePal(v); break;
      case 0x9b: this.vdp.writeIndirect(v); break;
      case 0xa0: this.psgAddr = v & 0x0f; break;
      case 0xa1: this.psg[this.psgAddr] = v; this.psgLog.push([this.cycles, this.psgAddr, v]); break;
      case 0xaa: this.ppiC = v; break;
      default: break;
    }
  }
  key(name, down) {
    const pos = KEYPOS[name];
    if (!pos) throw new Error("tecla desconhecida: " + name);
    if (down) this.keys[pos[0]] &= ~(1 << pos[1]);
    else this.keys[pos[0]] |= (1 << pos[1]);
  }
  // roda n frames (60Hz), gerando o flag de vblank
  runFrames(n) {
    for (let f = 0; f < n; f++) {
      // o vblank vem a cada CYCLES_PER_FRAME exatos, contados do vblank anterior (e nao de
      // onde a ferramenta parou de executar): o quadro nao estica com o alinhamento das ferramentas
      const target = Math.max(this.cycles + 1, this.frameStart + CYCLES_PER_FRAME);
      while (this.cycles < target) {
        this.cpu.execute();
        if (this.cpu.halted) { this.cycles = target; break; }
      }
      this.vdp.status[0] |= 0x80;
      this.vdp.status[2] |= 0x20;
      this.frameStart = target; this.linhaK = 0; this.proxLinha = target + CYCLES_PER_FRAME / 262; this.vdp.linha(212);
    }
  }
  // joystick 1: nome UP/DOWN/LEFT/RIGHT/A/B, apertado ou nao
  joy(name, down) {
    const bit = { UP: 0, DOWN: 1, LEFT: 2, RIGHT: 3, A: 4, B: 5 }[name];
    if (bit === undefined) throw new Error("joystick: " + name);
    if (down) this.joy1 &= ~(1 << bit); else this.joy1 |= (1 << bit);
  }
  // pressiona e solta uma tecla
  tap(name, holdFrames, gapFrames) {
    holdFrames = holdFrames === undefined ? 3 : holdFrames;
    gapFrames = gapFrames === undefined ? 8 : gapFrames;
    this.key(name, true); this.runFrames(holdFrames);
    this.key(name, false); this.runFrames(gapFrames);
  }
  screenshot(path, scaleY, scaleX) {
    scaleY = scaleY === undefined ? 2 : scaleY;
    scaleX = scaleX === undefined ? ((this.vdp.isG4() || this.vdp.isG7()) ? 2 : 1) : scaleX;
    const v = this.vdp, base = v.displayBase();
    const W = v.scrW(), H = 212;
    const rows = [];
    for (let y = 0; y < H; y++) {
      const line = Buffer.alloc(W * scaleX * 3);
      for (let x = 0; x < W; x++) {
        const rgb = v.pixelRGB(x, y, base);
        for (let k = 0; k < scaleX; k++) {
          const o = (x * scaleX + k) * 3;
          line[o] = rgb[0]; line[o + 1] = rgb[1]; line[o + 2] = rgb[2];
        }
      }
      for (let k = 0; k < scaleY; k++) rows.push(line);
    }
    writePNG(path, W * scaleX, H * scaleY, rows);
  }
}

function writePNG(path, w, h, rows) {
  const raw = Buffer.alloc(rows.length * (w * 3 + 1));
  let o = 0;
  for (const r of rows) { raw[o++] = 0; r.copy(raw, o); o += w * 3; }
  const idat = zlib.deflateSync(raw, { level: 9 });
  const chunks = [];
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type, "ascii"), data]);
    const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td) >>> 0);
    chunks.push(len, td, crc);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  chunk("IHDR", ihdr); chunk("IDAT", idat); chunk("IEND", Buffer.alloc(0));
  fs.writeFileSync(path, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])].concat(chunks)));
}
let CRCT = null;
function crc32(buf) {
  if (!CRCT) {
    CRCT = new Int32Array(256);
    for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1); CRCT[n] = c; }
  }
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRCT[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff);
}

module.exports = { MSX, VDP, MATRIX, KEYPOS, CYCLES_PER_FRAME, writePNG, extraT };
