# Senhor das Trevas — MSX2+

Recriação de *Senhor das Trevas!* (Philips Odyssey, 1983 = *Attack of the Timelord!*, Magnavox 1982) para MSX2+, num cartucho ROM de 32 KB. A abertura é a mesma do OVNI (ON → SELECT GAME).

* **0 — original** (SCREEN 5): igual ao Odyssey. Tudo foi medido no cartucho original rodando no MAME (ver `ref/MEDIDAS.md`).
* **1 — moderno** (SCREEN 8): a mesma lógica e os mesmos sons, com fundo de estrelas, naves e canhão desenhados de novo, figuras em degradê e placar com brilho.

## Controles

| Tecla | Ação |
|---|---|
| ← → (ou joystick) | anda (acelera segurando) |
| espaço (ou gatilho) | atira |
| A–Z | escreve o nome do recorde (a qualquer momento, como no original) |
| ESC | volta ao menu |

## Montar e testar

```
npm install
npm run build      # gera src/o2dados.inc e out/TREVAS.ROM
npm test           # bateria nos dois modos (robô que mira) + teste de tempo
```

`node tools/compara.cjs 20,40,80` tira fotos do MSX nos mesmos quadros da abertura para comparar com as do MAME.

## Como foi medido

`ref/mame/`: roteiro Lua para o MAME 0.264 (`drive.lua`, `run.sh`) que joga o cartucho original e registra, quadro a quadro, cada escrita no i8244 (vídeo e som); decodificadores em Python (`dec.py`, `hud.py`, `track.py`, `i8244snd.py`); `extrai.py` gera `medidas.json`, de onde `tools/gen_o2.cjs` tira as sequências fixas, as figuras e os sons.

## Arquivos

| Arquivo | O que é |
|---|---|
| `src/trevas.asm` | base do OVNI 4.6: VDP, telas ON/SELECT, motor de som, teclado, RAM |
| `src/jogo.asm` | a lógica do jogo, escrevendo numa cópia do i8244 em RAM |
| `src/o2.asm` | modo 0: leva a cópia do i8244 para o SCREEN 5 |
| `src/o2m.asm` | modo 1: leva a mesma cópia para o SCREEN 8 |
| `src/o2dados.inc` | gerado: figuras, abertura, morte, estouro, sons |
| `ref/MEDIDAS.md` | tudo o que foi medido no original |
