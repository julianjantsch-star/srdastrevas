// Bateria do jogo (modo 0 ou 1: MODO=1): liga, escolhe o modo, ve a abertura,
// joga com um robo que mira (le a tabela virtual do i8244 na RAM), confere
// pontos, niveis, armas, morte/recorde e o nome digitado. Fotos em out/j*.png.
// Sai com codigo 1 se alguma verificacao falha.
const fs = require("fs"), path = require("path");
const { MSX } = require("./msx.cjs");
const OUT = path.resolve(__dirname, "..", "out");
const MODO = process.env.MODO || "0";
const sym = {};
for (const l of fs.readFileSync(path.join(OUT, "trevas.sym"), "utf8").split(/\r?\n/)) {
  const m = l.match(/^([0-9a-f]{4}) (.+)$/); if (m) sym[m[2]] = parseInt(m[1], 16);
}
const m = new MSX(fs.readFileSync(path.join(OUT, "TREVAS.ROM")));
const rd = n => m.mem[sym[n]], rd16 = n => m.mem[sym[n]] | (m.mem[sym[n] + 1] << 8);
const foto = n => { m.screenshot(path.join(OUT, "j" + MODO + "-" + n + ".png"), 2, 2); };
let falhas = 0;
const ok = (c, msg) => { console.log((c ? "ok   " : "FALHA") + " " + msg); if (!c) falhas++; };
const naves = () => { const v = []; for (let i = 0; i < 8; i++) { const b = sym.vCh + i * 4; if (m.mem[b + 2] === 0) v.push({ y: m.mem[b], x: m.mem[b + 1] }); } return v; };
const armas = () => { const v = []; for (let i = 0; i < 3; i++) { const b = sym.wpTab + i * 8; if (m.mem[b]) v.push({ t: m.mem[b], y: m.mem[b + 1], x: m.mem[b + 2] }); } return v; };

m.runFrames(150); m.tap("SPACE", 3, 30); m.runFrames(120);
m.tap(MODO, 3, 2);
m.runFrames(200); foto("1-raios");
ok(rd("estado") === 0 && rd16("abF") > 20, "abertura tocando (quadro " + rd16("abF") + ")");
ok(rd("vozOn") === 1, "o Senhor das Trevas fala com o rosto na tela");
{ // a fala: o volume B do PSG muda a cada 2 linhas (123 por quadro, menos as pausas)
  const n0 = m.psgLog.length; m.runFrames(30);
  const v = m.psgLog.slice(n0).filter(e => e[1] === 9).map(e => e[2]);
  ok(v.length > 600 && new Set(v).size > 5, "amostras da fala no canal B: " + v.length + " em 30 quadros, " + new Set(v).size + " niveis");
}
m.runFrames(200); foto("2-fila");
ok(rd("filaSaiu") === 1 && naves().length >= 4, "a fila sai da cruz: " + naves().length + " naves");
m.runFrames(140); foto("3-canhao");
ok(rd("plVivo") === 1, "o canhao chegou");

// robo: fica sob a nave mais baixa e atira; desvia do que cai perto
let quadros = 0, nivelMax = 1, mortes = 0, tipos = new Set(), pontosMax = 0, recorde0 = rd16("recorde");
let estAnt = rd("estado"), fotoNivel = false;
while (quadros < 60 * 60 * 6 && (nivelMax < 4 || mortes < 1)) {
  const px = rd("plX") + 8, ns = naves(), ws = armas();
  for (const w of ws) tipos.add(w.t);
  let alvo = ns.length ? ns.reduce((a, b) => (b.y > a.y ? b : a)).x + 4 : 77;
  let foge = 0;
  for (const w of ws) if (w.y > 120 && Math.abs(w.x + 4 - px) < 14) foge = w.x + 4 > px ? -1 : 1;
  const l = foge ? foge < 0 : alvo < px - 2, r = foge ? foge > 0 : alvo > px + 2;
  m.key("LEFT", l); m.key("RIGHT", r); m.key("SPACE", quadros % 4 < 2);
  m.runFrames(1); quadros++;
  const est = rd("estado");
  if (est === 2 && estAnt !== 2) { mortes++; if (mortes === 1) foto("5-morte"); }
  if (rd("nivel") > nivelMax) { nivelMax = rd("nivel"); console.log("  nivel", nivelMax, "aos", (quadros / 60).toFixed(0), "s, pontos", rd16("score")); if (!fotoNivel) { foto("4-nivel2"); fotoNivel = true; } }
  pontosMax = Math.max(pontosMax, rd16("score"));
  estAnt = est;
}
m.key("LEFT", false); m.key("RIGHT", false); m.key("SPACE", false);
console.log("  armas vistas", [...tipos].sort().join(","), "mortes", mortes, "nivel max", nivelMax);
ok(pontosMax >= 5, "fez pontos: " + pontosMax);
ok(nivelMax >= 2, "passou de nivel: " + nivelMax);
ok(tipos.has(1), "misseis no nivel 1");
if (nivelMax >= 2) ok(tipos.has(2), "minas a partir do nivel 2");
if (mortes) ok(rd16("recorde") >= Math.min(pontosMax, 9999) || rd16("recorde") > recorde0, "o recorde ficou com os pontos: " + rd16("recorde"));
// nome do recorde pelo teclado, a qualquer momento
for (const k of ["J", "U", "L", "I", "A", "N"]) m.tap(k, 2, 4);
m.runFrames(4); foto("6-nome");
const nome = String.fromCharCode(...m.mem.slice(sym.nomeRec, sym.nomeRec + 6));
ok(nome === "JULIAN", "nome do recorde: " + nome);
m.tap("ESC", 3, 30); foto("7-menu");
ok(m.romWrites.length === 0, "nenhuma escrita na ROM");
console.log(falhas ? falhas + " falha(s)" : "tudo certo");
process.exit(falhas ? 1 : 0);
