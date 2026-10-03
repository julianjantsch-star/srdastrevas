// O laco do jogo cabe num quadro? Conta voltas do laco (frameCnt sobe uma vez
// por WaitFrame) contra quadros emulados, da abertura ao combate cheio.
const fs = require("fs"), path = require("path");
const { MSX } = require("./msx.cjs");
const OUT = path.resolve(__dirname, "..", "out");
const sym = {};
for (const l of fs.readFileSync(path.join(OUT, "trevas.sym"), "utf8").split(/\r?\n/)) { const mm = l.match(/^([0-9a-f]{4}) (.+)$/); if (mm) sym[mm[2]] = parseInt(mm[1], 16); }
const m = new MSX(fs.readFileSync(path.join(OUT, "TREVAS.ROM")));
const fc = () => m.mem[sym.frameCnt] | m.mem[sym.frameCnt + 1] << 8;
m.runFrames(150); m.tap("SPACE", 3, 30); m.runFrames(120);
const t0 = fc(); m.tap(process.env.MODO || "0", 3, 1);
let g = 0; while (m.mem[sym.estado] === 0 && (m.mem[sym.abF] | m.mem[sym.abF + 1] << 8) === 0 && g++ < 600) m.runFrames(1);
console.log("inicializacao:", g, "quadros");
const fases = { abertura: [0, 0], combate: [0, 0] };
let pior = 0;
m.key("SPACE", true);
for (let k = 0; k < 400; k++) {
  m.key("LEFT", (k >> 4) & 1); m.key("RIGHT", !((k >> 4) & 1));
  const fase = m.mem[sym.estado] === 0 ? "abertura" : "combate";
  const a = fc(); m.runFrames(5); const d = 5 - (fc() - a);
  fases[fase][0] += d; fases[fase][1] += 5; if (d > pior) pior = d;
}
for (const [f, [p, t]] of Object.entries(fases)) if (t) console.log(f + ": " + p + " quadros perdidos em " + t + " (" + (100 * p / t).toFixed(1) + "%)");
console.log("pior trecho: " + pior + " de 5");
