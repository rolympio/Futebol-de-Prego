# Resultados dos testes automatizados

Gerado por `godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd` (Godot 4.3, Linux, sem GPU).

```
  OK    gol reto no gol de cima
  OK    gol reto no gol de baixo
  OK    chute fraco para antes do gol  (parou em y=51)
  OK    gols em diagonal detectados  (20/20)
  OK    chute na linha de fundo fora do gol não é gol
  OK    moeda nunca atravessa pregos  (penetração máx 0.000 px)
  OK    moeda nunca sai do tabuleiro  (0 saídas)
  OK    moeda sempre para em < 12,5 s  (0 sem parar)
        (gols em 500 chutes aleatórios: 19)
  OK    prévia de mira curta  (123 px)
  OK    simulação determinística
  OK    formação piramide x piramide  (22 pregos, dist. mín 85)
  OK    formação piramide x 442  (22 pregos, dist. mín 76)
  OK    formação piramide x 433  (22 pregos, dist. mín 70)
  OK    formação 442 x piramide  (22 pregos, dist. mín 76)
  OK    formação 442 x 442  (22 pregos, dist. mín 76)
  OK    formação 442 x 433  (22 pregos, dist. mín 71)
  OK    formação 433 x piramide  (22 pregos, dist. mín 70)
  OK    formação 433 x 442  (22 pregos, dist. mín 71)
  OK    formação 433 x 433  (22 pregos, dist. mín 71)
  OK    desafio 1 'Primeiro chute' tem solução em 1 chute  (58 soluções de 1800)
  OK    desafio 2 'Passe o goleiro' tem solução em 1 chute  (36 soluções de 1800)
  OK    desafio 3 'Barreira' tem solução em 1 chute  (20 soluções de 1800)
  OK    desafio 4 'Tabela na lateral' tem solução em 1 chute  (13 soluções de 1800)
  OK    desafio 5 'Zigue-zague' tem solução em 1 chute  (20 soluções de 1800)
  OK    desafio 6 'Corredor' tem solução em 1 chute  (37 soluções de 1800)
  OK    desafio 7 'Muralha' tem solução em 1 chute  (2 soluções de 1800)
  OK    desafio 8 'Tiro de longe' tem solução em 1 chute  (2 soluções de 1800)
  OK    IA nível 0 escolhe chute válido  (59 ms no PC)
  OK    IA nível 1 escolhe chute válido  (188 ms no PC)
  OK    IA nível 2 escolhe chute válido  (602 ms no PC)
  OK    IA avançada converte gol livre  (10/10)
  OK    iniciante acerta menos ou igual ao avançado  (iniciante 5/10)
  OK    menu abre
  OK    tela 'setup' abre
  OK    tela 'challenges' abre
  OK    tela 'settings' abre
  OK    tela 'help' abre
  OK    tela 'menu' abre
  OK    partida começa aguardando o chute
  OK    tutorial aparece no primeiro acesso
  OK    arrasto curto cancela (não chuta)
  OK    arrasto longo dispara
  OK    puxar para baixo lança para cima (sentido oposto)  (vy=-1462)
  OK    tutorial some após 1º chute
  OK    toque durante a jogada é ignorado
  OK    moeda para e próxima jogada começa
  OK    vez passa para o outro time
  OK    gol detectado na partida
  OK    placar soma, moeda ao centro, quem sofreu sai jogando
  OK    pausa congela o jogo
  OK    retomar funciona
  OK    sair do app pausa automaticamente
  OK    partida termina com tela de resultado  (placar 3 x 0)
  OK    revanche reinicia a partida
  OK    CPU assume a vez
  OK    CPU mira e chuta
  OK    fim de tempo empatado ativa gol de ouro
  OK    treino: botão pênalti posiciona a moeda
  OK    treino: gol reinicia no centro
  OK    desafio 1 concluído e estrelas salvas  (2 estrelas)
  OK    desafio 2 desbloqueado
RESULTADO: 61 ok, 0 falhas
```

## Teste de rede (servidor + convidado em 2 processos)

`bash tests/net_test.sh <godot>`

```
----
  OK    convidado entra pelo código, cor repetida é trocada, tabuleiro invertido
  OK    servidor recebe nome do convidado
  OK    servidor chuta
  OK    convidado chuta (jogada validada pelo servidor)
  OK    gol do servidor chega ao convidado
  OK    servidor detecta queda e aguarda
  OK    convidado reconecta e recebe o estado
  OK    partida continua após reconexão
  OK    placar final igual nos dois (3-0)
  OK    física igual nos dois aparelhos (diferença máx. 0.1024 px)
  OK    revanche reinicia no servidor
  OK    revanche reinicia no convidado
  OK    saída do adversário é avisada
RESULTADO REDE: tudo ok
```
