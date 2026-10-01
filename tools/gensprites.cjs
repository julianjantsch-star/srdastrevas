// Gera src/sprites.inc: as figuras do jogo, desenhadas aqui em ASCII.
// Cada figura ocupa uma celula de 16x16 na pagina 1 da VRAM (y = 256), de
// onde o jogo copia com HMMM. A borda preta em volta do desenho apaga o
// rastro quando o objeto anda ate 2 pixels por quadro (o laser deixa 8
// linhas pretas embaixo). PROVISORIO: a forma de cada figura sai da
// gravacao do console (PLANO.md, etapa 2).
const fs = require("fs"), path = require("path");
const COR = { ".": 0, "R": 2, "G": 3, "y": 4, "B": 5, "M": 6, "C": 7, "A": 8,
  "r": 9, "g": 10, "Y": 11, "b": 12, "m": 13, "c": 14, "W": 15 };
const FIG = [
  ["NAVE", [
    "............",
    "............",
    "....WWWW....",
    "..CCCCCCCC..",
    "..CmCmCmCC..",
    "..CCCCCCCC..",
    "....C..C....",
    "...C....C...",
    "............",
    "............"]],
  ["NAVE2", [
    "............",
    "............",
    "....WWWW....",
    "..YYYYYYYY..",
    "..YrYrYrYY..",
    "..YYYYYYYY..",
    "....Y..Y....",
    "...Y....Y...",
    "............",
    "............"]],
  ["CANHAO", [
    "................",
    "................",
    ".......WW.......",
    ".......WW.......",
    "......WWWW......",
    "..bbbbbbbbbbbb..",
    "..bccccccccccb..",
    "..bbbbbbbbbbbb..",
    "..b.b.b..b.b.b..",
    "...b.b.bb.b.b...",
    "................",
    "................"]],
  ["MISSIL", [
    "............",
    "............",
    ".....WW.....",
    ".....WW.....",
    ".....WW.....",
    ".....WW.....",
    "...WWWWWW...",
    "....WWWW....",
    ".....WW.....",
    "............"]],
  ["MINA", [
    "............",
    "............",
    "....RRRR....",
    "...RrrrrR...",
    "...RrRRrR...",
    "...RrRRrR...",
    "...RrrrrR...",
    "....RRRR....",
    "............",
    "............"]],
  ["ANIQ", [
    "............",
    "............",
    "....GGGG....",
    "...GGGGGG...",
    "...GG..GG...",
    "...GG..GG...",
    "...GGGGGG...",
    "....GGGG....",
    "............",
    "............"]],
  ["NUCLEO", [
    "............",
    "............",
    ".....MM.....",
    "....MWWM....",
    "...MWWWWM...",
    "...MWWWWM...",
    "....MWWM....",
    ".....MM.....",
    "............",
    "............"]],
  ["ESTOURO", [
    "............",
    "..Y...Y...Y.",
    "...Y.Y.Y.Y..",
    "....YYYY....",
    "..YYYrrYYY..",
    "....YYYY....",
    "...Y.Y.Y.Y..",
    "..Y...Y...Y.",
    "............",
    "............"]],
  ["LASER", [
    ".WW.", ".WW.", ".WW.", ".WW.", ".WW.", ".WW.", ".WW.", ".WW.",
    "....", "....", "....", "....", "....", "....", "....", "...."]],
  ["ANIQ2", [
    "............",
    "............",
    "....gggg....",
    "...gggggg...",
    "...gg..gg...",
    "...gg..gg...",
    "...gggggg...",
    "....gggg....",
    "............",
    "............"]],
];
let out = "; ---- figuras do jogo: gerado por tools/gensprites.cjs (nao editar) ----\n";
out += "; celulas de 16x16 (8 bytes x 16 linhas), em ordem de SL_*\n";
FIG.forEach(([nome], i) => { out += "SL_" + nome + " equ " + i + "\n"; });
out += "SPR_N equ " + FIG.length + "\nSPRITES:\n";
for (const [nome, arte] of FIG) {
  out += "; " + nome + "\n";
  for (let y = 0; y < 16; y++) {
    const lin = (arte[y] || "").padEnd(16, ".");
    const b = [];
    for (let x = 0; x < 16; x += 2) {
      const a = COR[lin[x]], c = COR[lin[x + 1]];
      if (a === undefined || c === undefined) throw new Error(nome + ": cor desconhecida na linha " + y);
      b.push("0x" + ((a << 4) | c).toString(16).padStart(2, "0"));
    }
    out += "  db " + b.join(",") + "\n";
  }
}
fs.writeFileSync(path.join(__dirname, "..", "src", "sprites.inc"), out);
console.log("sprites.inc:", FIG.length, "figuras");
