// O laco do combate cabe num quadro? Compara quadros emulados com voltas
// do laco (frameCnt sobe uma vez por WaitFrame) com a fila cheia e armas.
const fs = require("fs"), path = require("path");
const { MSX } = require("./msx.cjs");
const OUT = path.resolve(__dirname, "..", "out");
const sym = {};
for (const l of fs.readFileSync(path.join(OUT, "trevas.sym"), "utf8").split(/\r?\n/)) { const mm = l.match(/^([0-9a-f]{4}) (.+)$/); if (mm) sym[mm[2]] = parseInt(mm[1], 16); }
const m = new MSX(fs.readFileSync(path.join(OUT, "TREVAS.ROM")));
const fc = () => m.mem[sym.frameCnt] | m.mem[sym.frameCnt + 1] << 8;
m.runFrames(150); m.tap("SPACE", 3, 30); m.runFrames(120); m.tap("0", 3, 10);
m.runFrames(30); m.mem[sym.nivel] = parseInt(process.argv[2] || "10", 10); m.tap("0", 3, 10);
m.runFrames(300);                                   // fila inteira na tela
let pior = 0, total = 0, n = 0;
m.key("SPACE", true);
for (let k = 0; k < 600; k++) {
  m.key("LEFT", (k >> 6) & 1); m.key("RIGHT", !((k >> 6) & 1));
  const a = fc(); m.runFrames(10); const d = 10 - (fc() - a);
  total += d; n++; if (d > pior) pior = d;
  m.mem[sym.vidas] = 3;
}
console.log("quadros perdidos a cada 10:", (total / n).toFixed(2), "medio,", pior, "no pior trecho; uso do VDP", (m.vdp.cmdUs / 1e6).toFixed(1), "s");
