# Senhor das Trevas — MSX2+

Recriação de *Senhor das Trevas!* (Philips Odyssey, 1983 = *Attack of the Timelord!*, Magnavox 1982) para MSX2+, numa MegaROM ASCII8 de 64 KB (código nos bancos 0–2, a fala nos bancos 3–5). A abertura é a mesma do OVNI (ON → SELECT GAME).

O **Senhor das Trevas fala**, como no Odyssey com o módulo *The Voice* (o mesmo que o Odyssey Vault liga): a cada abertura ele sorteia uma das 11 frases do cartucho ("Prepare for defeat", "Seize the planet", "The earth will be mine"…) e o rosto fica na tela até a frase acabar; ao limpar um nível, ele elogia ("A commendable defense", "Not bad, human", "You are a worthy opponent").

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

`python3 tools/voz/gen_voz.py <sp0256.cpp do MAME> <voice.zip>` refaz `src/voz.bin` e `src/voz.inc` (a fala).

`node tools/compara.cjs 20,40,80` tira fotos do MSX nos mesmos quadros da abertura para comparar com as do MAME.

## Como foi medido

`ref/mame/`: roteiro Lua para o MAME 0.264 (`drive.lua`, `run.sh`) que joga o cartucho original e registra, quadro a quadro, cada escrita no i8244 (vídeo e som); decodificadores em Python (`dec.py`, `hud.py`, `track.py`, `i8244snd.py`); `extrai.py` gera `medidas.json`, de onde `tools/gen_o2.cjs` tira as sequências fixas, as figuras e os sons.

## A fala

O cartucho original manda **alofones** ao SP0256B-019 do The Voice (as 14 frases estão em `o2_45.bin`, 0x105–0x21F, terminadas por 0x01). `tools/voz/gen_voz.py` compila o núcleo do SP0256 do MAME (`sp0256.cpp`) num programa avulso, sintetiza cada frase a 9286 Hz (cristal de 3,12 MHz ÷ 336), recorta os alofones pelo instante em que o chip aceita o seguinte, reamostra para 7373 Hz e quantiza nos 16 volumes do PSG. No MSX, a interrupção de linha do V9938 a cada 2 linhas (linhas 0–244: 123 amostras por quadro) toca uma amostra no volume do canal B (tom e ruído B desligados), troca o banco ASCII8 a cada alofone e, junto, continua o ruído lento do canal A a cada 16 linhas. No openMSX o envelope gravado do canal B bate 0,975 com o esperado.

## Arquivos

| Arquivo | O que é |
|---|---|
| `src/trevas.asm` | base do OVNI 4.6: VDP, telas ON/SELECT, motor de som, teclado, RAM |
| `src/jogo.asm` | a lógica do jogo, escrevendo numa cópia do i8244 em RAM |
| `src/o2.asm` | modo 0: leva a cópia do i8244 para o SCREEN 5 |
| `src/o2m.asm` | modo 1: leva a mesma cópia para o SCREEN 8 |
| `src/o2dados.inc` | gerado: figuras, abertura, morte, estouro, sons |
| `src/voz.inc`, `src/voz.bin` | gerados: os 45 alofones do SP0256 (4 bits, 7373 Hz) e as 14 frases |
| `tools/voz/` | `gen_voz.py` + `sim.cpp`: sintetiza as frases com o núcleo do SP0256 do MAME e recorta os alofones |
| `ref/MEDIDAS.md` | tudo o que foi medido no original |
