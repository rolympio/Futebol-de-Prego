# Decisões de design – versão 2.0

## Por que a v1 parecia "Atari"
A v1 usava telas estáticas e física genérica. A v2 foi refeita com foco em **sensação ao toque**:
física própria em passo fixo (120 Hz, sub-passos), prévia de trajetória, animações com mola, rastro, partículas, tremor de tela no gol, sons e vibração.

## Controle (estilingue)
- Toque em qualquer ponto do tabuleiro e puxe. **A moeda vai no sentido oposto ao arrasto.**
- Força = distância puxada (máx. 230 unidades do campo); anel e seta vão de verde → amarelo → vermelho.
- Puxada menor que 24 unidades = cancelado (mostra um "x"). Toques durante o movimento são ignorados.
- Mira assistida (opcional): mostra o caminho só até a 1ª colisão + um trecho curto, sem revelar o resultado final.

## Campo (inspirado nos tabuleiros enviados)
- Vertical, 600 × 1000, moldura de madeira, gols como fendas na borda com rede.
- Gol de 132 (22% da largura ≈ 3 moedas): proporcional às áreas desenhadas, mais largo que a fenda real para ser jogável no celular.
- 11 pregos por time, numerados de 1 a 11. Formações: Pirâmide 2-3-5 (clássica), 4-4-2 e 4-3-3.
  Um ajuste automático garante distância mínima de 70 entre pregos (a moeda sempre passa) e a boca do gol livre.
- Bordas rebatem a moeda: não existe bola fora (decisão para fluidez). Cantos chanfrados evitam moeda presa.
- Temas: Campinho (padrão), Tábua de madeira, Arena noturna. Mesmas dimensões e física em todos.

## Regras padrão
- **Rápida**: 3 gols ou 3 minutos; a vez passa a cada chute; empate no fim = gol de ouro.
- **Clássica**: gols (3/5/7/livre), tempo (sem/3/5/10 min) e regra opcional "tocou só em prego do próprio time = joga de novo" (máx. 2 extras).
- Gol só conta com a moeda **inteira** além da linha. Quem sofre o gol sai do centro.

## Física
Restituição 0,80 nos pregos e 0,62 nas bordas; atrito proporcional + constante (para naturalmente);
velocidade de 260 a 2150 un/s. Todas as "bolas" (dourada, prata, cobre, ficha telefônica) têm física idêntica.

## IA
Simula de 60 a 432 chutes candidatos com a mesma física, pontua (gol, gol contra, avanço, perigo no próprio gol, nova jogada)
e aplica ruído humano: iniciante ±9°, médio ±3,5°, avançado ±0,9°. O cálculo é distribuído entre quadros (a tela não trava).

## Fora desta versão (limitações conhecidas)
- Multijogador em rede Wi-Fi/QR e convites: não implementados nesta versão.
- Editor de formação personalizada: apenas 3 formações prontas.
- Arenas inspiradas em estádios reais: não incluídas.
- Coleção de moedas históricas com textos revisados: só 4 aparências genéricas.
- Testado em Linux (sem GPU) e por capturas renderizadas; ainda falta testar em aparelho Android real.
