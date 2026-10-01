// Telas do esqueleto: ON, SELECT GAME e a tela do jogo (vazia), com o som de ligar conferido.
const fs=require("fs"),path=require("path");const {MSX}=require("./msx.cjs");
const OUT=path.resolve(__dirname,"..","out");
const sym={};for(const l of fs.readFileSync(path.join(OUT,"trevas.sym"),"utf8").split(/\r?\n/)){const m=l.match(/^([0-9a-f]{4}) (.+)$/);if(m)sym[m[2]]=parseInt(m[1],16);}
const m=new MSX(fs.readFileSync(path.join(OUT,"TREVAS.ROM")));
const foto=n=>{let k=0;while(m.cpu.pc!==sym.WF1&&k++<400000)m.cpu.execute();m.screenshot(path.join(OUT,n+".png"),2,2);console.log(n);};
m.runFrames(150);foto("e1-on");m.tap("SPACE",3,30);m.runFrames(10);
console.log("sfxPtr apos SELECT:",(m.mem[sym.sfxPtr]|m.mem[sym.sfxPtr+1]<<8).toString(16),"SFX_POWER:",sym.SFX_POWER.toString(16));
m.runFrames(110);foto("e2-select");m.tap("0",3,30);m.runFrames(60);console.log("modo:",m.mem[sym.modo]);foto("e3-jogo");
