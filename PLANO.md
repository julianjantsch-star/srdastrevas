# SENHOR DAS TREVAS — MSX2+ (plano, 19/09/2026)

Adaptação de *Senhor das Trevas!* (Odyssey, Philips 1983 = *Attack of the Timelord!*, Magnavox 1982, Ed Averett; na Europa *Terrahawks*). Mesmo molde do OVNI: abertura igual à do console (SELECT GAME), **modo 0 = original** (SCREEN 5, idêntico ao console) e **modo 1 = moderno** (SCREEN 8).

## 1. O que já se sabe (fontes públicas — tudo a confirmar na gravação)

| Item | Informação | Fonte |
|---|---|---|
| Início | tecla 1 começa; **tecla 0 desliga a "transmissão" do rosto** | Bojogá / manual |
| Abertura de cada rodada | o rosto vermelho do Senhor das Trevas aparece e "fala"; abre uma fenda multicolorida no centro, de onde saem as naves | Wikipedia, odyssey2.info |
| Naves | saem da fenda e formam uma **fila que serpenteia** pelo alto da tela, muito rápida | idem |
| Jogador | máquina do tempo no chão, só anda na horizontal; canhão laser, **um tiro na tela por vez**, rápido | odyssey2.info |
| Arma 1 (nível 1+) | mísseis: setas brancas, caem reto — **2 pontos** | manual |
| Arma 2 (nível 2+) | minas de antimatéria, vermelhas, seguem o jogador — **4 pontos** | manual |
| Arma 3 (nível 3+) | aniquiladores, verdes pulsantes: caem e depois **rolam pelo chão** vindo pelos lados; só morrem no ar — **8 pontos** | manual / review |
| Arma 4 (nível 4+) | matadores nucleônicos, losangos brilhantes que **antecipam** a posição do jogador — **16 pontos** | manual / review |
| Nave inimiga | **5 pontos** | manual |
| Progressão | destruir todas as naves = próximo nível; **256 níveis**, cada vez mais rápido; depois do 4º todas as armas juntas | manual |
| Morte | fontes divergem: "uma vida só" × "perde e volta um nível" → **medir** | — |
| Recorde | nome pelo teclado, como no OVNI | Bojogá |

## 2. A "voz"

| Fato | Consequência |
|---|---|
| A fala de verdade ("Goodbye, Earthling"…) vem do módulo **The Voice** (chip de fala SP0256 + ROM de fonemas), que **não saiu no Brasil** | não é ruído da CPU; no Odyssey brasileiro ela não existia |
| Sem o módulo, o rosto mexe a boca com um **resmungo feito pelo próprio chip de som** (i8244: o registrador de 24 bits recarregado quadro a quadro) — é o que se ouvia aqui | é isso que o modo original reproduz |
| O método do OVNI serve: ler o programa do chip pela grade do relógio (983/3933 Hz) e tocar bit a bit pela interrupção de linha | se o resmungo usa o relógio rápido com padrões arbitrários, a ISR roda a cada 4 linhas (~27 % da CPU) — cabe, porque na cena do rosto quase nada se mexe |
| Modo moderno | opção: fala amostrada (PCM de 1 bit/4 bits pelo PSG) com as frases do The Voice — decidir depois |

## 3. O desafio novo: fases

O OVNI tinha um estado de jogo só. Aqui há uma **máquina de estados por rodada** e uma **tabela de níveis**:

| Estado | O que acontece |
|---|---|
| ROSTO | rosto + resmungo (pulável com 0) |
| FENDA | fenda gira, naves saem uma a uma |
| COMBATE | fila serpenteia, solta armas conforme o nível |
| LIMPO | última nave morta → elogio/ameaça → nível+1 |
| MORTE | explosão → volta (um nível? fim?) |

Tabela de nível (a medir): nº de naves, velocidade da fila, trajetória, cadência de disparo, armas habilitadas, velocidade das armas. O nível é 1 byte (256 níveis, dá a volta).

## 4. Reaproveitado do OVNI

| Peça | Arquivo do OVNI |
|---|---|
| Abertura SELECT GAME, fonte do console, paleta O2 | cabeçalho + `30_desenho.asm` |
| Motor de som por tabela + ruído lento por interrupção de linha (IM 2) | `50_sons.asm` (guia: `../SONS_ODYSSEY_NO_MSX.md`) |
| Teclado/joystick, nome do recorde, calibragem CPU/VDP | `45_teclado.asm`, `20_jogo.asm` |
| Modo moderno SCREEN 8 (sprites sombreados, fundo de estrelas) | `35_moderno.asm` |
| Emulador de teste, PSG, baterias de prova, análise de wav/vídeo | `tools/`, `ref/*.cjs` |

Fonte novo e **limpo** (um `src/` montado direto, sem a pilha de `fixNN.cjs`).

## 5. Etapas

| # | Etapa | Depende de |
|---|---|---|
| 1 | Gravações de referência do console (ver abaixo) | **Julian** |
| 2 | Medir: sprites (rosto, fenda, naves, 4 armas, canhão), paleta, trajetória da fila, tabela de níveis, tempos da abertura e da morte | 1 |
| 3 | Medir sons pela grade do chip (resmungo, tiro, explosões, cada arma) | 1 |
| 4 | Esqueleto: boot → SELECT GAME → máquina de estados vazia, nos dois modos | — |
| 5 | Modo original completo + bateria de testes | 2, 3 |
| 6 | Modo moderno | 5 |
| 7 | ROM 1.0 para teste no MSX real | 5 |

### Andamento (01/10/2026)

| # | Situação |
|---|---|
| 4 | **feito**: boot → ON → SELECT GAME → jogo |
| 5 | **jogável com valores provisórios** (manual/resenhas): rosto que fala (0 desliga), fenda que solta a fila, fila serpenteando, canhão com um tiro por vez, as 4 armas liberadas por nível (todas do 4º em diante), pontos 5/2/4/8/16, 3 vidas (o nível recomeça), 256 níveis, fim de jogo com recorde e nome. Tudo o que é chute está marcado `PROVISORIO` em `src/jogo.asm`, esperando as gravações |
| 6 | modo 1 ainda roda o mesmo jogo do modo 0 |

### Gravações que preciso (como as do OVNI)

| # | O quê |
|---|---|
| 1 | Do ligar até o fim do nível 1, **sem apertar 0** (rosto + resmungo completos) |
| 2 | Níveis 1 a 5 seguidos, para ver cada arma nova e o que muda depois do 4º |
| 3 | Várias mortes (por míssil, por mina, por aniquilador no chão) e o que vem depois |
| 4 | Fim de jogo com recorde e digitação do nome |
| 5 | Se possível, áudio por cabo; se for microfone, sala silenciosa |

## Fontes

- https://en.wikipedia.org/wiki/Attack_of_the_Timelord!
- https://odyssey2.info/reviews/attack-of-the-timelord-6
- https://odyssey2.info/library/manuals/us_timelord/Attack%20of%20the%20Timelord%20(USA).pdf
- https://bojoga.com.br/artigos/retroplay/odyssey/senhor-das-trevas-philips-1983/
- https://experienciaodyssey.com.br/senhordastrevas/
