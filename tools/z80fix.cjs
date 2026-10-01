// Correcao de dois bugs do nucleo z80js 0.9.4 (tools/z80test.cjs comprova):
//  - "ld (ix+d),r" / "ld (iy+d),r": escrevia o valor de IX/IY no endereco
//    r+d (argumentos trocados);
//  - "ld (ix+d),n" / "ld (iy+d),n": usava this.ix (indefinido) e escrevia
//    no endereco 0.
// As leituras (ld r,(ix+d)), inc/dec/bit (ix+d) e add/sub (ix+d) estao certas.
const Z80 = require("z80js");
const regs = ["a", "b", "c", "d", "e", "h", "l"];
for (const ir of ["ix", "iy"]) {
  for (const r of regs) {
    Z80.prototype["ld__" + ir + "_d__" + r] = function () {
      this.tStates += 5;
      let d = this.read8(this.pc++); if (d > 127) d -= 256;
      this.write8((this.r1[ir] + d) & 0xffff, this.r1[r]);
    };
  }
  Z80.prototype["ld__" + ir + "_d__n"] = function () {
    this.tStates += 2;
    let d = this.read8(this.pc++); if (d > 127) d -= 256;
    const n = this.read8(this.pc++);
    this.write8((this.r1[ir] + d) & 0xffff, n);
  };
}
module.exports = Z80;