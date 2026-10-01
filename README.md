# Senhor das Trevas — MSX2+

Recriação de *Senhor das Trevas!* (Philips Odyssey, 1983) para MSX2+, num cartucho ROM de 32 KB. Usa o mesmo molde do OVNI: abertura ON → SELECT GAME, modo 0 original (SCREEN 5).

## Montar e testar

```
npm install
npm run build      # gera out/TREVAS.ROM
npm test           # monta e roda a bateria no emulador headless (fotos em out/j*.png)
```

Outras provas: `node tools/testa-niveis.cjs <nivel-alvo> [nivel-inicial]` (um robô que mira joga sozinho), `node tools/testa-tempo.cjs [nivel]` (confere se o laço cabe num quadro).

## Controles

| Tecla | Ação |
|---|---|
| ← → (ou joystick) | anda |
| espaço (ou gatilho) | atira |
| 0, no rosto | desliga a "transmissão" do rosto até o fim da partida |
| ESC | volta ao menu |

## Arquivos

| Arquivo | O que é |
|---|---|
| `src/trevas.asm` | base vinda do OVNI 4.6: VDP, texto, telas ON/SELECT, motor de som, teclado e RAM |
| `src/jogo.asm` | o jogo: rosto, fenda, fila, canhão, armas, placar, morte, recorde |
| `tools/gensprites.cjs` | desenhos em ASCII → `src/sprites.inc` |
| `tools/msx.cjs` | emulador MSX2+ headless de teste |
| `PLANO.md` | plano e andamento |

Os valores marcados `PROVISORIO` em `src/jogo.asm` vêm do manual e das resenhas. Eles serão trocados pelos medidos nas gravações do console (PLANO.md, etapas 1 a 3).
