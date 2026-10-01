// Robo que mira (vai para baixo da nave mais baixa e atira) e nao perde
// vidas (o teste repoe), para ver os niveis passando e cada arma nova.
const fs = require("fs"), path = require("path");
const { MSX } = require("./msx.cjs");
const OUT = path.resolve(__dirname, "..", "out");
const sym = {};
for (const l of fs.readFileSync(path.join(OUT, "trevas.sym"), "utf8").split(/\r?\n/)) {
  const mm = l.match(/^([0-9a-f]{4}) (.+)$/); if (mm) sym[mm[2]] = parseInt(mm[1], 16);
}
const m = new MSX(fs.readFileSync(path.join(OUT, "TREVAS.ROM")));
const rd = n => m.mem[sym[n]];
m.runFrames(150); m.tap("SPACE", 3, 30); m.runFrames(120); m.tap("0", 3, 10);
const INI = parseInt(process.argv[3] || "1", 10);
m.runFrames(30); m.mem[sym.nivel] = INI; m.tap("0", 3, 10);      // desliga o rosto (e comeca no nivel INI)
const alvo = () => { let best = null; for (let i = 0; i < 16; i++) { const b = sym.shTab + i * 8; if (m.mem[b]) { const s = { x: m.mem[b + 1], y: m.mem[b + 2] }; if (!best || s.y > best.y) best = s; } } return best; };
let nivel = INI, quadro = 0, mortes = 0, vidas = rd("vidas"); const vistos = {};
const NIV = parseInt(process.argv[2] || "6", 10);
while (nivel !== NIV && quadro < 60 * 60 * 15) {
  const s = alvo(); const px = rd("plX");
  const want = s ? s.x - 2 : 120;
  m.key("LEFT", px > want + 1); m.key("RIGHT", px < want - 1);
  m.key("SPACE", quadro % 2 === 0);
  m.runFrames(1); quadro++;
  for (let i = 0; i < 8; i++) { const t = m.mem[sym.wpTab + i * 8]; if (t) (vistos[nivel] = vistos[nivel] || new Set()).add(t); }
  if (rd("vidas") < vidas) { mortes++; m.mem[sym.vidas] = 3; }
  vidas = rd("vidas");
  if (rd("nivel") !== nivel) { console.log("nivel", nivel, "limpo em", (quadro / 60).toFixed(0), "s; armas", [...(vistos[nivel] || [])].sort().join(","), "mortes", mortes); nivel = rd("nivel"); if (nivel === INI + 1) m.screenshot(path.join(OUT, "n5.png"), 2, 2); }
}
m.runFrames(400); m.screenshot(path.join(OUT, "n-ult.png"), 2, 2);
console.log("chegou ao nivel", nivel, "pontos", m.mem[sym.score] | m.mem[sym.score + 1] << 8, "armas no ultimo", [...(vistos[nivel] || [])].sort().join(","));
