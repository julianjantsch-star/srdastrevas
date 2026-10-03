// Fotos do modo 0 nos mesmos momentos das gravacoes do original (para comparar)
const fs = require("fs"), path = require("path");
const { MSX } = require("./msx.cjs");
const OUT = path.resolve(__dirname, "..", "out");
const sym = {};
for (const l of fs.readFileSync(path.join(OUT, "trevas.sym"), "utf8").split(/\r?\n/)) { const m = l.match(/^([0-9a-f]{4}) (.+)$/); if (m) sym[m[2]] = parseInt(m[1], 16); }
const m = new MSX(fs.readFileSync(path.join(OUT, "TREVAS.ROM")));
const foto = n => { m.screenshot(path.join(OUT, n + ".png"), 2, 2); };
m.runFrames(150); m.tap("SPACE", 3, 30); m.runFrames(120); m.tap("0", 3, 2);
const t0 = Date.now();
const marcas = [20, 40, 60, 100, 140, 170, 200, 260, 300, 340, 400, 500];
let f = 0;
for (const k of marcas) { m.runFrames(k - f); f = k; foto("o2-" + String(k).padStart(3, "0")); }
console.log("estado", m.mem[sym.estado], "abF", m.mem[sym.abF] | m.mem[sym.abF + 1] << 8, "naves", m.mem[sym.filaN], "pts", m.mem[sym.score]);
m.key("SPACE", true); m.key("RIGHT", true); m.runFrames(40); foto("o2-tiro"); m.key("RIGHT", false);
for (let i = 0; i < 1500; i++) { m.runFrames(1); }
foto("o2-depois"); console.log("estado", m.mem[sym.estado], "naves", m.mem[sym.filaN], "pts", m.mem[sym.score] | m.mem[sym.score + 1] << 8, "rom writes", m.romWrites.length, (Date.now() - t0) + " ms");
