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

## Multijogador no Wi-Fi (v2.1)
- O criador da sala é o servidor autoritativo (ENet, porta UDP 27620). Ele decide gols, placar, vez e tempo.
- Só trafegam a jogada (direção + força + posição inicial) e uma "foto" do estado ao fim de cada lance.
  A física é determinística; a foto corrige qualquer diferença mínima entre aparelhos (no teste: 0,1 px).
- Código da sala = 3º e 4º números do IP do servidor (ex.: 192.168.4.37 → 1061). O convidado completa com o próprio IP.
  Também aceita o IP completo. Há descoberta automática por broadcast UDP (porta 27621), de melhor esforço.
- O convidado vê o tabuleiro girado 180°: ele também ataca "para cima".
- Convite: botão abre o WhatsApp (wa.me) com a mensagem e o código. Não abre o jogo direto, porque o WhatsApp
  só deixa clicáveis links https, e isso exigiria um site próprio (App Links).
- Queda de conexão: o servidor congela o relógio e espera; o convidado tem o botão "Reconectar" e recebe o estado completo.
- Cor repetida: o servidor troca a cor do convidado. Versões diferentes do protocolo são recusadas com mensagem.
- Permissão nova: internet (necessária para sockets, mesmo só na rede local). Nenhum dado sai da rede local.
- Não funciona em redes que isolam aparelhos (Wi-Fi corporativo, de hotel ou de visitantes).

## Fora desta versão (limitações conhecidas)
- Partida pela internet (fora da mesma rede): exige servidor/relay externo; ver avaliação no projeto.
- Editor de formação personalizada: apenas 3 formações prontas.
- Arenas inspiradas em estádios reais: não incluídas.
- Coleção de moedas históricas com textos revisados: só 4 aparências genéricas.
- Testado em Linux (sem GPU), por capturas renderizadas e com 2 processos em rede; ainda falta testar em aparelhos Android reais.
