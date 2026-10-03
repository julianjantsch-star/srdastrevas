// Monta src/ovni.asm em out/OVNI.ROM (cartucho MSX de 32KB em 0x4000).
// (reconstruido em 11/09/2026 a partir do build.mjs do MSX-Domino, depois
//  que a copia no Drive perdeu o arquivo; use ALVO=teste para src/teste.asm)
import { Asm } from "z80-asm";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const ALVO = process.env.ALVO || "ovni";
const SRC = path.join(ROOT, "src", ALVO + ".asm");
const OUT = path.join(ROOT, "out", ALVO.toUpperCase() + ".ROM");
const LST = path.join(ROOT, "out", ALVO + ".lst");
const SYM = path.join(ROOT, "out", ALVO + ".sym");

const asm = new Asm(p => {
  const candidates = [p, path.join(ROOT, "src", path.basename(p))];
  for (const c of candidates) {
    try { return fs.readFileSync(c, "utf8").split(/\r?\n/); } catch (e) { /* proximo */ }
  }
  return undefined;
});
asm.assembleFile(SRC);

let errors = 0;
const lines = [];
for (const l of asm.assembledLines) {
  if (l.error) {
    errors++;
    if (errors <= 30) console.error("ERRO linha " + l.lineNumber + ": " + l.line.trim() + "\n   -> " + l.error);
  }
  lines.push(
    (l.address >>> 0).toString(16).padStart(4, "0") + "  " +
    l.binary.map(b => b.toString(16).padStart(2, "0")).join(" ").padEnd(14) + "  " + l.line
  );
}
fs.writeFileSync(LST, lines.join("\n") + "\n");

// MegaROM ASCII8: bancos 0-2 (0x4000-0x9FFF) = codigo; 3.. = a fala (src/voz.bin)
const ROM_BASE = 0x4000, ROM_SIZE = 0x6000, ROM_TOTAL = 0x10000;
const rom = Buffer.alloc(ROM_SIZE, 0);
let maxAddr = ROM_BASE, overflow = false;
for (const l of asm.assembledLines) {
  if (!l.binary.length) continue;
  let a = l.address;
  for (const b of l.binary) {
    if (a < ROM_BASE || a >= ROM_BASE + ROM_SIZE) { overflow = true; }
    else rom[a - ROM_BASE] = b;
    a++;
  }
  if (a > maxAddr) maxAddr = a;
}
// --- verificacao: o assembler trunca silenciosamente jr/djnz fora de alcance ---
const symMap = new Map();
for (const scope of asm.scopes) for (const [name, info] of scope.symbols) symMap.set(name, info.value);
for (const l of asm.assembledLines) {
  if (!l.binary.length) continue;
  const src = l.line.replace(/;.*$/, "").trim();
  const m = src.match(/^(?:[A-Za-z_.$][\w.$]*:\s*)?(jr|djnz)\s+(.*)$/i);
  if (!m) continue;
  const operand = m[2].split(",").pop().trim();
  if (!symMap.has(operand)) continue;
  const target = symMap.get(operand);
  const delta = target - (l.address + 2);
  if (delta < -128 || delta > 127) {
    errors++;
    console.error("ERRO linha " + l.lineNumber + ": " + src +
      "  -> deslocamento " + delta + " fora do alcance de " + m[1].toLowerCase() + " (use jp)");
  }
}

if (errors) { console.error("\n" + errors + " erro(s) de montagem. ROM nao gerada."); process.exit(1); }
if (overflow) { console.error("Codigo fora da faixa 0x4000-0x9FFF (bancos fixos do ASCII8)."); process.exit(1); }

// symbols
const syms = [];
for (const scope of asm.scopes) for (const [name, info] of scope.symbols) syms.push([name, info.value]);
syms.sort((a, b) => a[1] - b[1]);
fs.writeFileSync(SYM, syms.map(s => s[1].toString(16).padStart(4, "0") + " " + s[0]).join("\n") + "\n");

const VOZ = path.join(ROOT, "src", "voz.bin");
const voz = fs.existsSync(VOZ) ? fs.readFileSync(VOZ) : Buffer.alloc(0);
if (ROM_SIZE + voz.length > ROM_TOTAL) { console.error("A fala nao cabe na MegaROM."); process.exit(1); }
const total = Buffer.alloc(ROM_TOTAL, 0xff);
rom.copy(total, 0); voz.copy(total, ROM_SIZE);
fs.writeFileSync(OUT, total);
const used = maxAddr - ROM_BASE;
console.log("OK  ROM: " + OUT);
console.log("    codigo/dados ate 0x" + maxAddr.toString(16) + "  (" + used + " bytes usados, " + (ROM_SIZE - used) + " livres de " + ROM_SIZE + "); fala: " + voz.length + " bytes; MegaROM ASCII8 de " + (ROM_TOTAL >> 10) + " KB");
