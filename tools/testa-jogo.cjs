// Bateria do jogo: liga, escolhe o modo 0, ve o rosto, pula com 0, joga
// atirando e andando, e confere placar, naves, mortes e fim de jogo.
// Fotos em out/j*.png. Sai com codigo 1 se alguma verificacao falha.
const fs = require("fs"), path = require("path");
const { MSX } = require("./msx.cjs");
const OUT = path.resolve(__dirname, "..", "out");
const sym = {};
for (const l of fs.readFileSync(path.join(OUT, "trevas.sym"), "utf8").split(/\r?\n/)) {
  const m = l.match(/^([0-9a-f]{4}) (.+)$/); if (m) sym[m[2]] = parseInt(m[1], 16);
}
const m = new MSX(fs.readFileSync(path.join(OUT, "TREVAS.ROM")));
const rd = n => m.mem[sym[n]], rd16 = n => m.mem[sym[n]] | (m.mem[sym[n] + 1] << 8);
const foto = n => { m.screenshot(path.join(OUT, n + ".png"), 2, 2); console.log("foto", n); };
const naves = () => { let k = 0; for (let i = 0; i < 16; i++) if (m.mem[sym.shTab + i * 8]) k++; return k; };
const armas = () => { const t = []; for (let i = 0; i < 8; i++) if (m.mem[sym.wpTab + i * 8]) t.push(m.mem[sym.wpTab + i * 8]); return t; };
let falhas = 0;
const ok = (c, msg) => { console.log((c ? "ok   " : "FALHA") + " " + msg); if (!c) falhas++; };

m.runFrames(150); m.tap("SPACE", 3, 30); m.runFrames(120);
m.tap("0", 3, 10);                       // SELECT GAME: original
m.runFrames(40); foto("j1-rosto");
ok(rd("faceOff") === 0, "rosto aparece");
m.runFrames(200);                        // o rosto acaba sozinho
m.runFrames(60); foto("j2-fenda");
ok(rd("nivel") === 1, "nivel 1");
ok(rd("toSpawn") < 8 && naves() > 0, "a fenda solta naves (" + naves() + " na tela, faltam " + rd("toSpawn") + ")");
m.runFrames(240); foto("j3-fila");
ok(naves() >= 6, "a fila se formou: " + naves());

// joga: atira sem parar e anda de um lado para o outro
let mortes = 0, vidas0 = rd("vidas"), tiposVistos = new Set(), maxNivel = 1, pontosAntes = rd16("score");
m.key("SPACE", true);
for (let f = 0; f < 60 * 120; f++) {
  const lado = Math.floor(f / 90) % 2 ? "LEFT" : "RIGHT";
  m.key("LEFT", lado === "LEFT"); m.key("RIGHT", lado === "RIGHT");
  m.runFrames(1);
  for (const t of armas()) tiposVistos.add(t);
  if (rd("vidas") < vidas0) { mortes++; vidas0 = rd("vidas"); }
  if (rd("nivel") > maxNivel) { maxNivel = rd("nivel"); console.log("  nivel", maxNivel, "no quadro", f, "pontos", rd16("score")); if (maxNivel === 2) foto("j4-nivel2"); }
  if (f === 1500) foto("j5-combate");
  if (rd("vidas") === 0 || rd16("frameCnt") === 0) break;
}
m.key("SPACE", false); m.key("LEFT", false); m.key("RIGHT", false);
ok(rd16("score") > pontosAntes, "fez pontos: " + rd16("score"));
ok(tiposVistos.size >= 1, "armas vistas: " + [...tiposVistos].join(","));
console.log("  mortes", mortes, "nivel maximo", maxNivel, "vidas", rd("vidas"));
// deixa morrer ate o fim de jogo
for (let f = 0; f < 60 * 300 && rd("vidas") > 0; f++) m.runFrames(1);
m.runFrames(200); foto("j6-fim");
ok(rd("vidas") === 0, "fim de jogo alcancado");
// nome do recorde
for (const k of ["J", "U", "L", "I", "A", "N"]) m.tap(k, 3, 6);
m.tap("RET", 3, 20); foto("j7-recorde");
const nome = String.fromCharCode(...m.mem.slice(sym.nomeRec, sym.nomeRec + 6));
ok(nome === "JULIAN", "nome do recorde: " + nome);
m.tap("SPACE", 3, 60); m.runFrames(60); foto("j8-volta");
ok(m.romWrites.length === 0, "nenhuma escrita na ROM");
console.log(falhas ? falhas + " falha(s)" : "tudo certo");
process.exit(falhas ? 1 : 0);
