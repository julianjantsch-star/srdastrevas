// Gera src/o2dados.inc a partir de ref/mame/medidas.json (o registro do
// original no MAME): as figuras do i8244 expandidas para o MSX (x * 1,5), os
// glifos usados, as sequencias fixas (abertura, morte, estouro) e os sons
// convertidos para passos do PSG no formato do motor do OVNI.
const fs = require("fs"), path = require("path");
const ROOT = path.resolve(__dirname, "..");
const M = JSON.parse(fs.readFileSync(path.join(ROOT, "ref/mame/medidas.json"), "utf8"));
let out = "; ---- gerado por tools/gen_o2.cjs a partir de ref/mame/medidas.json (nao editar) ----\n";
const db = (arr) => arr.map(b => "0x" + (b & 255).toString(16).padStart(2, "0")).join(",");

// ------------------------------------------------------------------ glifos
// conjunto de caracteres do i8244 (so os usados): 7 linhas, bit 7 = esquerda
const GL = {
  0x00: [0x7c,0xc6,0xc6,0xc6,0xc6,0xc6,0x7c], 0x01: [0x18,0x38,0x18,0x18,0x18,0x18,0x3c],
  0x02: [0x3c,0x66,0x0c,0x18,0x30,0x60,0x7e], 0x03: [0x7c,0xc6,0x06,0x3c,0x06,0xc6,0x7c],
  0x04: [0xcc,0xcc,0xcc,0xfe,0x0c,0x0c,0x0c], 0x05: [0xfe,0xc0,0xc0,0x7c,0x06,0xc6,0x7c],
  0x06: [0x7c,0xc6,0xc0,0xfc,0xc6,0xc6,0x7c], 0x07: [0xfe,0x06,0x0c,0x18,0x30,0x60,0xc0],
  0x08: [0x7c,0xc6,0xc6,0x7c,0xc6,0xc6,0x7c], 0x09: [0x7c,0xc6,0xc6,0x7e,0x06,0xc6,0x7c],
  0x0c: [0,0,0,0,0,0,0], 0x0d: [0x3c,0x66,0x0c,0x18,0x18,0x00,0x18],
  0x36: [0x00,0x18,0x0c,0xfe,0x0c,0x18,0x00],
  0x0e: [0xc0,0xc0,0xc0,0xc0,0xc0,0xc0,0xfe], 0x0f: [0xfc,0xc6,0xc6,0xfc,0xc0,0xc0,0xc0],
  0x11: [0xc6,0xc6,0xc6,0xd6,0xfe,0xee,0xc6], 0x12: [0xfe,0xc0,0xc0,0xf8,0xc0,0xc0,0xfe],
  0x13: [0xfc,0xc6,0xc6,0xfc,0xd8,0xcc,0xc6], 0x14: [0x7e,0x18,0x18,0x18,0x18,0x18,0x18],
  0x15: [0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x7c], 0x16: [0x3c,0x18,0x18,0x18,0x18,0x18,0x3c],
  0x17: [0x7c,0xc6,0xc6,0xc6,0xc6,0xc6,0x7c], 0x18: [0x7c,0xc6,0xc6,0xc6,0xde,0xcc,0x76],
  0x19: [0x7c,0xc6,0xc0,0x7c,0x06,0xc6,0x7c], 0x1a: [0xfc,0xc6,0xc6,0xc6,0xc6,0xc6,0xfc],
  0x1b: [0xfe,0xc0,0xc0,0xf8,0xc0,0xc0,0xc0], 0x1c: [0x7c,0xc6,0xc0,0xc0,0xce,0xc6,0x7e],
  0x1d: [0xc6,0xc6,0xc6,0xfe,0xc6,0xc6,0xc6], 0x1e: [0x06,0x06,0x06,0x06,0x06,0xc6,0x7c],
  0x1f: [0xc6,0xcc,0xd8,0xf0,0xd8,0xcc,0xc6], 0x20: [0x38,0x6c,0xc6,0xc6,0xfe,0xc6,0xc6],
  0x21: [0x7e,0x06,0x0c,0x18,0x30,0x60,0x7e], 0x22: [0xc6,0xc6,0x6c,0x38,0x6c,0xc6,0xc6],
  0x23: [0x7c,0xc6,0xc0,0xc0,0xc0,0xc6,0x7c], 0x24: [0xc6,0xc6,0xc6,0xc6,0xc6,0x6c,0x38],
  0x25: [0xfc,0xc6,0xc6,0xfc,0xc6,0xc6,0xfc], 0x26: [0xc6,0xee,0xfe,0xd6,0xc6,0xc6,0xc6],
  0x2c: [0x66,0x66,0x66,0x3c,0x18,0x18,0x18], 0x2d: [0xc6,0xe6,0xf6,0xfe,0xde,0xce,0xc6],
  0x2e: [0x03,0x06,0x0c,0x18,0x30,0x60,0xc0], 0x3b: [0xc0,0x60,0x30,0x18,0x0c,0x06,0x03],
  0x28: [0x00,0x00,0x00,0x7e,0x00,0x00,0x00], 0x3e: [0x00,0x00,0x00,0x10,0x38,0xff,0x7e],
};
// texto do placar: ASCII -> codigo do i8244
const ASC = { " ": 0x0c, "?": 0x0d, ">": 0x36, L: 0x0e, P: 0x0f, W: 0x11, E: 0x12, R: 0x13, T: 0x14, U: 0x15,
  I: 0x16, O: 0x17, Q: 0x18, S: 0x19, D: 0x1a, F: 0x1b, G: 0x1c, H: 0x1d, J: 0x1e, K: 0x1f, A: 0x20, Z: 0x21,
  X: 0x22, C: 0x23, V: 0x24, B: 0x25, M: 0x26, Y: 0x2c, N: 0x2d };
for (let d = 0; d < 10; d++) ASC[String(d)] = d;

// 8 unidades do chip -> 12 pixels (unidade i cobre [3i/2, 3(i+1)/2))
function expand8(bitsMsbLeft) {
  let v = 0;
  for (let i = 0; i < 8; i++) if (bitsMsbLeft & (0x80 >> i)) for (let p = (3 * i) >> 1; p < (3 * (i + 1)) >> 1; p++) v |= 1 << (15 - p);
  return v; // 16 bits, bit 15 = pixel 0
}
const rev8 = b => { let r = 0; for (let i = 0; i < 8; i++) if (b & (1 << i)) r |= 0x80 >> i; return r; };

// caracteres do jogo: [nome, codigo, linha inicial, linhas]
const CHFIG = [["CF_NAVE", 0x3e, 5, 2], ["CF_ESQ", 0x2e, 0, 7], ["CF_DIR", 0x3b, 0, 7], ["CF_VERT", 0x14, 1, 6], ["CF_HOR", 0x28, 0, 7]];
out += "\n; caracteres do jogo: mascara 12 px (2 bytes) por linha do glifo, cada linha = 2 linhas na tela\n";
CHFIG.forEach(([n], i) => out += `${n} equ ${i}\n`);
out += `CF_N equ ${CHFIG.length}\nCHFIG_ALT:\n  db ${CHFIG.map(f => f[3] * 2).join(",")}\nCHFIG_DAT:\n`;
for (const [n, c, r0, nr] of CHFIG) {
  const rows = [];
  for (let r = 0; r < 7; r++) { const v = r < nr ? expand8(GL[c][r0 + r]) : 0; rows.push(v >> 8, v & 255); }
  out += `  db ${db(rows)}   ; ${n}\n`;
}
// glifos do placar, na ordem de HUD_GLIFOS
const HUDCH = "0123456789?> ABCDEFGHIJKLMNOPQRSTUVWXYZ";
out += `\n; glifos do placar (${HUDCH.length}): ordem "${HUDCH}"\nHUD_NG equ ${HUDCH.length}\nHUD_GLIFOS:\n`;
for (const ch of HUDCH) {
  const g = GL[ASC[ch]]; if (!g) throw new Error("glifo " + ch);
  const rows = []; for (let r = 0; r < 7; r++) { const v = expand8(g[r]); rows.push(v >> 8, v & 255); }
  out += `  db ${db(rows)}   ; ${ch}\n`;
}

// ------------------------------------------------------------------ figuras (sprites)
// formas do i8244: bit 0 = esquerda. Normais -> padrao 16x16 (12 px, linha = 2 linhas)
const SP = [
  ["SF_LASER", "1010101010101010"], ["SF_JATO", "101010387cfefe00"],
  ["SF_PONTO", "0000001818000000"], ["SF_PONTO2", "0000183c3c180000"],
  ["SF_ANEL", "003c7e7e7e7e3c00"], ["SF_ANEL2", "3c7effffffff7e3c"],
  ["SF_MISSIL", "4042424212381010"], ["SF_MISSIL2", "40e2474212101010"],
  ["SF_ANIQ", "0000241818240000"], ["SF_ANIQ2", "0000101c38080000"], ["SF_ANIQ3", "000008381c100000"], ["SF_ANIQ4", "0042240000244200"],
  ["SF_NUCL", "0010284428100000"], ["SF_NUCL2", "0000102810000000"],
  ["SF_ROSTO", "003c5a7e3c3c1800"], ["SF_ROSTO2", "7ebddb7e3c427e3c"], ["SF_ROSTO3", "7ebddb7e7e7e3c00"], ["SF_ROSTO4", "00183c1818000000"],
  ["SF_CRUZ", "0018187e7e181800"], ["SF_XIS", "0066661818666600"],
  ["SF_GIRA1", "7077771ff8eeee0e"], ["SF_GIRA2", "e7e7e71818e7e7e7"], ["SF_GIRA3", "0eeeeef81f777770"],
  ["SF_GIRA4", "1c1cfcffff3f3838"], ["SF_GIRA5", "38383ffffffc1c1c"],
];
const SPIDX = {}; SP.forEach(([n, h], i) => SPIDX[h] = i);
out += "\n; figuras do i8244 como sprites 16x16 do V9938 (padrao: coluna esquerda, depois a direita)\n";
SP.forEach(([n], i) => out += `${n} equ ${i}\n`);
out += `SF_N equ ${SP.length}\nSPR_PAT:\n`;
for (const [n, h] of SP) {
  const b = Buffer.from(h, "hex"); const L = [], R = [];
  for (let r = 0; r < 8; r++) { const v = expand8(rev8(b[r])); for (let k = 0; k < 2; k++) { L.push(v >> 8); R.push(v & 255); } }
  out += `  db ${db(L.concat(R))}   ; ${n}\n`;
}
// ampliadas (cata-vento, cruz, aneis): 24 x 32, 3 bytes por linha, 1 bpp
const ZF = ["SF_GIRA1", "SF_GIRA2", "SF_GIRA3", "SF_GIRA4", "SF_GIRA5", "SF_CRUZ", "SF_XIS", "SF_PONTO", "SF_PONTO2", "SF_ANEL", "SF_ANEL2"];
out += "\n; figuras ampliadas (a cruz da fenda e o estouro da morte): 24 x 32 px, 1 bpp\n";
ZF.forEach((n, i) => out += `Z${n.slice(1)} equ ${i}\n`);
out += `ZF_N equ ${ZF.length}\nZFIG_DAT:\n`;
for (const n of ZF) {
  const h = SP.find(s => s[0] === n)[1]; const b = Buffer.from(h, "hex"); const rows = [];
  for (let r = 0; r < 8; r++) { let v = 0; for (let i = 0; i < 8; i++) if (b[r] & (1 << i)) v |= 7 << (21 - 3 * i); for (let k = 0; k < 4; k++) rows.push(v >> 16, (v >> 8) & 255, v & 255); }
  out += `  db ${db(rows)}   ; ${n}\n`;
}
const zidx = h => { const n = SP[SPIDX[h]][0]; const i = ZF.indexOf(n); if (i < 0) throw new Error("ampliada " + n); return i; };
const sidx = h => { if (!(h in SPIDX)) throw new Error("figura desconhecida " + h); return SPIDX[h]; };

// ------------------------------------------------------------------ abertura
// por quadro: raio (k | base<<4, 0xFF = sem), figura 0 (rosto/ponto), figura 1 (cruz) e a cor da cruz
// (bit 7 da cor = ampliada, em 84,72)
const A = M.abertura, FS = M.abertura_fila;
let raios = [], ab = [];
for (const fr of A) {
  let r = 0xff;
  for (const c of fr.ch) if (c[2] === 46 && c[0] >= 114 && c[1] <= 68) r = ((c[0] - 114) >> 3) | (c[4] << 4);
  if (fr.f >= FS) r = 0xff;
  const s0 = fr.sp[0], s1 = fr.sp[1];
  let f0 = 0xff, f1 = 0xff, c1 = 0;
  if (s0 && s0[1] === 90 && fr.f < FS) f0 = sidx(s0[5]);
  if (s1) { if (s1[4]) { f1 = zidx(s1[5]); c1 = s1[3] | 0x80; } else { f1 = sidx(s1[5]); c1 = s1[3]; } }
  ab.push(r, f0, f1, c1);
}
const CRUZ_FIM = A.filter(fr => fr.sp[1] && fr.sp[1][4]).map(fr => fr.f).pop();
const CANHAO = A.filter(fr => fr.ch.some(c => c[2] === 46 && c[0] === 178)).map(fr => fr.f)[0];
out += `\n; abertura: ${A.length} quadros a partir da tela vazia; a fila sai no quadro ${FS}\n`;
out += `AB_N equ ${A.length}\nAB_FILA equ ${FS}\nAB_CRUZ_FIM equ ${CRUZ_FIM}\nAB_CANHAO equ ${CANHAO}\nAB_DAT:\n`;
for (let i = 0; i < ab.length; i += 32) out += `  db ${db(ab.slice(i, i + 32))}\n`;

// morte: figura 0 (em cima do canhao) e figura 1 ampliada (169,73 do chip)
const MO = M.morte; let mo = [];
for (const fr of MO) {
  const s0 = fr.sp[0], s1 = fr.sp[1];
  mo.push(s0 && s0[1] === 178 && !s0[5].startsWith("1010101010") && !s0[5].startsWith("101010387c") ? sidx(s0[5]) : 0xff, s0 ? s0[3] : 0,
    s1 && s1[4] ? zidx(s1[5]) : 0xff, s1 ? s1[3] : 0);
}
out += `\n; morte do canhao: ${MO.length} quadros (figura 0, cor, ampliada, cor)\nMO_N equ ${MO.length}\nMO_DAT:\n`;
for (let i = 0; i < mo.length; i += 32) out += `  db ${db(mo.slice(i, i + 32))}\n`;
// estouro de nave: a figura 0 (o laser) vira o anel no lugar do acerto
const ES = M.estouro_nave; let es = [];
for (const fr of ES) { const s0 = fr.sp[0]; es.push(s0 ? sidx(s0[5]) : 0xff, s0 ? s0[3] : 0); }
out += `\n; estouro de nave: ${ES.length} quadros (figura, cor)\nES_N equ ${ES.length}\nES_DAT:\n  db ${db(es)}\n`;

// ------------------------------------------------------------------ sons
// estado por quadro [aa, padrao de 24 bits] -> passos do motor do OVNI
// (duracao, tomA, tomB, tomC, volA, volB, volC, ruido, mixer; 0xFD = ruido lento)
function per(s) { for (const p of [2, 3, 4, 6, 8, 12, 24]) { let ok = true; for (let i = 0; i < 24 && ok; i++) ok = ((s >> i) & 1) === ((s >> ((i + p) % 24)) & 1); if (ok) return p; } return 24; }
const vol = v => v <= 0 ? 0 : Math.max(1, Math.min(15, Math.round(15 + 2 * Math.log2(v / 15))));
function passo(aa, seed) {
  if (!(aa & 0x80) || (aa & 15) === 0) return { k: "-", st: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xbf] };
  const fast = aa & 0x20, v = vol(aa & 15);
  if (aa & 0x10) {
    if (fast) return { k: "NR" + v, st: [0, 0, 0, 0, 0, 0, 0, 0, v, 28, 0x9f] };
    return { k: "NL" + v, lento: true, v, seed: seed & 0xffff };
  }
  const ones = (seed & 0xffffff).toString(2).split("").filter(c => c === "1").length;
  if (ones === 0 || ones === 24) return { k: "-", st: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xbf] };
  const f = (fast ? 3933.6 : 983.4) / per(seed), tp = Math.round(111861 / f);
  return { k: "T" + tp + "/" + v, st: [tp & 255, tp >> 8, 0, 0, 0, 0, v, 0, 0, 0, 0xbe] };
}
function som(nome, estados, loop) {
  const ps = estados.map(([aa, seed]) => passo(aa, seed));
  let s = `\n${nome}:\n`, i = 0, prevLento = false;
  while (i < ps.length) {
    let j = i + 1; while (j < ps.length && ps[j].k === ps[i].k && j - i < 250) j++;
    const p = ps[i], n = j - i;
    if (p.lento) {
      // ruido lento: cabecalho 0xFD (semente; 0 = continua) + passo com o canal A como DAC
      s += `  db 0xFD, ${db([prevLento ? 0 : p.seed & 255, prevLento ? 0 : p.seed >> 8, p.v, 0])}\n`;
      s += `  db ${n}, 0,0, 0,0, 0,0, 0,0,0, 0, 0xBF\n`;
      prevLento = true;
    } else { s += `  db ${n}, ${db(p.st)}\n`; prevLento = false; }
    i = j;
  }
  return s + (loop ? "  db 0xFE\n" : "  db 0xFF\n");
}
out += "\n; ---- sons, quadro a quadro como o i8244 tocou (ref/mame/medidas.json) ----";
const S = M.som;
out += som("SND_INICIO", S.inicio) + som("SND_ABERTURA", S.abertura) + som("SND_PRONTO", S.pronto) +
  som("SND_MARCHA", S.marcha, true) + som("SND_TIRO", S.tiro) + som("SND_ESTOURO", S.estouro) +
  som("SND_ARMA", S.arma) + som("SND_MORTE", S.morte);
fs.writeFileSync(path.join(ROOT, "src", "o2dados.inc"), out);
console.log("o2dados.inc:", out.length, "bytes de texto");
