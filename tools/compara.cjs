// Fotos do MSX nos quadros da abertura em que ha foto do MAME (ref: s1, uma a cada 30
// quadros a partir de 300; a abertura comeca no 300 la e no quadro 0 da tabela aqui)
const fs = require("fs"), path = require("path");
const { MSX } = require("./msx.cjs");
const OUT = path.resolve(__dirname, "..", "out");
const sym = {};
for (const l of fs.readFileSync(path.join(OUT, "trevas.sym"), "utf8").split(/\r?\n/)) { const mm = l.match(/^([0-9a-f]{4}) (.+)$/); if (mm) sym[mm[2]] = parseInt(mm[1], 16); }
const m = new MSX(fs.readFileSync(path.join(OUT, "TREVAS.ROM")));
m.runFrames(150); m.tap("SPACE", 3, 30); m.runFrames(120); m.tap("0", 3, 1);
const abF = () => m.mem[sym.abF] | m.mem[sym.abF + 1] << 8;
let k = 0; const alvos = (process.argv[2] || "30,60,90,120,150,180,210,240,270").split(",").map(Number);
for (const a of alvos) { let g = 0; while (abF() < a && g++ < 2000) m.runFrames(1); m.screenshot(path.join(OUT, "cmp-" + String(a).padStart(3, "0") + ".png"), 1, 1); }
console.log("ok");
