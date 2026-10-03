# Senhor das Trevas — medidas do original

Fonte: o cartucho original (`o2_45.bin`, o mesmo que o Odyssey Vault carrega) rodando no **MAME 0.264** (`odyssey2`, sem The Voice, como no Brasil), dirigido por roteiro Lua (`ref/mame/`). Cada escrita do programa no i8244 (vídeo e som) é registrada quadro a quadro. Então tudo aqui é o que o chip recebeu, não uma estimativa de vídeo.

Joystick: o jogo lê a **porta direita** (no MAME, `:JOY.1`, campos `P2 ...`).

## Coordenadas

| Chip | Tela do console | MSX (este port) |
|---|---|---|
| x (0–~170) | (x+5)×2 px | **x × 3/2** (1,5 px por unidade; o campo de 5 a 165 cabe em 256) |
| y (linhas) | 1 linha | **y − 14** (o chip não mostra nada acima da 14ª linha no NTSC) |
| caractere | 8 unid. × até 7 linhas duplas | 12 × 14 px |
| figura (sprite) | 8 × 8 (16 × 16 ampliada) | 12 × 8 (24 × 16) |

Cores de objeto (3 bits): `0` cinza escuro, `1` vermelho, `2` verde, `3` amarelo, `4` azul, `5` magenta, `6` ciano, `7` branco → paleta do OVNI: `c == 0 ? 1 : c + 8`. Fundo preto. A caixa do placar é a **grade** do chip, em magenta escuro.

## Placar (os 4 quadros de texto, embaixo, y = 199)

`RRRR→?????? PPPP`: recorde (amarelo), seta (vermelha), nome do recorde (amarelo), espaço, pontos (branco).

## Uma partida

* **Uma vida só.** Morreu: se os pontos passaram o recorde, eles viram o recorde; os pontos zeram e o jogo recomeça pela abertura.
* Pontos: **nave 5** (aparece em dois passos: +2 e, 4 quadros depois, +3), **míssil abatido 2**.
* Nível limpo (8 naves mortas): ~270 quadros e nova abertura, nível + 1.

## Abertura de cada rodada (quadros a partir do fim da anterior)

1. 6 quadros vazios; então o rosto (figura 0, vermelha, centro y 90 x 77) e os **8 raios** (caracteres 46/59 = diagonais, 40 = horizontal, 20 = vertical) saem do centro em ciclos que crescem (raio 0..3, 0..4, 0..5, 0..6) e depois encolhem, com as cores girando. O rosto troca entre 4 formas.
2. A cruz (figura 1) cresce de um ponto e vira um **cata-vento** de 5 formas que gira uma forma por quadro; a cor sobe 1 a cada 8 quadros.
3. A cruz fica **ampliada** (16 × 16) em y 84 x 72 e solta as naves.

## A fila

* 8 naves (nível 1). Cada nave é o caractere 62 começando na linha 5: só aparece um traço.
* A primeira sai da cruz andando 1/quadro para a direita; as outras saem a cada ~8–10 quadros e seguem **o mesmo rastro**.
* O líder anda **2 unidades por quadro** em 8 direções; numa curva passa por uma direção intermediária (2,1)/(1,2) por 1 quadro e gira 45° a cada ~7 quadros.
* **A cor das naves é a direção**: muda um passo a cada 45° de curva.

## Canhão (caracteres 46 + 59 na linha 178) e laser (figura 0)

* Aparece ~15 quadros depois da última nave sair.
* Anda de x = 9 a 137. Acelera: 1/quadro nos primeiros 8 quadros, depois +1 a cada 4 quadros (visto até 7).
* Laser: figura 0 (`1010101010101010`, um traço vertical) parada no centro do canhão (x + 4) quando não atira; sobe **8 linhas por quadro** de 178 a 34 (18 quadros) e volta. Um tiro por vez.

## Armas das naves (figuras 1–3, até 3 ao mesmo tempo)

| Nível | Arma | Movimento | Forma |
|---|---|---|---|
| 1+ | míssil (branco) | cai 2/quadro em linha reta | 2 formas, troca a cada 3 quadros |
| 2+ | mina (vermelho/verde) | cai 1/quadro; anda 1 para o lado do canhão em 2 de cada 3 quadros | ponto, 2 formas |

## Som (registradores 0xA7–0xAA)

0xAA: bit 7 liga, bit 5 relógio rápido (a cada 4 linhas = 3933 Hz; senão a cada 16 = 983 Hz), bit 4 ruído (realimentação bit 0 ⊕ bit 5 no bit 15), bits 0–3 volume (largura de pulso, linear). 0xA7–0xA9: o padrão de 24 bits que gira.

## Mais medidas (03/10)

* **Armas por nível**: nível 1 só mísseis; nível 2 sobretudo minas (87 de 103); nível 3 entram os aniquiladores (4 formas, verde/amarelo: caem 1/quadro e, no chão, rolam ½/quadro para o canhão). O matador nucleônico (losango, 2 formas) está na tabela de formas do cartucho (0xDEA, 0xDF2), mas o robô não chegou ao nível 4 para vê-lo voar.
* **Estouro de nave**: a figura 0 (o laser) fica onde acertou e passa por ponto, ponto maior, anel, anel grande, com a cor subindo — 31 quadros. Os 5 pontos entram +2 e, 4 quadros depois, +3.
* **Fim de nível**: depois da última nave o canhão continua livre ~116 quadros; tudo some, 4 quadros, nova abertura.
* **Morte**: as naves congelam; figura 0 no canhão e figura 1 ampliada (169, x do canhão) passam pelos mesmos pontos e anéis por 62 quadros; tela vazia; partida nova com o recorde atualizado. **Uma vida só.**
* **Nome do recorde**: cada letra digitada (a qualquer momento) ocupa a próxima posição do `??????`.
* **Caminho da fila**: sorteado — quatro rodadas gravadas saem do mesmo ponto (78, 98) e vão para lados diferentes.
* **Caixa do placar**: barras horizontais nas linhas 192–194 e 216–218, verticais de 2 unidades nas pontas (x 8 e 152 do chip).
* **Sons**: tiro = ruído rápido, 1967 Hz ×2, ruído, zumbido de 164 Hz ×4; estouro = (ruído, 164 Hz, 41 Hz subindo) ×3, 31 quadros; marcha de fundo = ciclo de 36 quadros de 41 Hz; arma solta = 164/328 Hz + ruído; abertura = ruídos lentos (983 Hz) com as sementes do chip. Todos convertidos automaticamente (`tools/gen_o2.cjs`).

## A fala (The Voice), medida em 03/10

* MAME com `-cart1 voice -cart2 timelord` (lista de software `videopac`). O jogo escreve na RAM externa (P1 & 0x50 = 0) no endereço 0x80 + alofone, com o bit 5 do dado em 1; 0x64 abre e fecha a frase.
* **14 frases** no cartucho (0x105–0x21F, bit 7 ligado, fim = 0x01). Tabela em 0x25A: abertura = uma das 11 primeiras (sorteada; 40 aberturas gravadas, todas as 11 apareceram); depois 94 a6 3d 83 b5 b5 e d3 c4 d3 ea d3 (as três últimas: "A commendable defense", "Not bad human", "You are a worthy opponent" — elogios, que o port usa ao limpar o nível; o robô do MAME não limpou nível para confirmar o momento).
* A 1ª palavra sai **29 quadros depois do rosto**; com a fala, o rosto fica 172 quadros em vez de 78 (o jogo espera a frase acabar e segue ~33 quadros depois).
* O chip roda a 3,12 MHz ÷ 336 = **9286 Hz**: as durações das frases gravadas no MAME batem com a síntese avulsa (1,81 s = "Seize the planet" etc.).
