#!/usr/bin/env bash
# Roda servidor e convidado em processos separados e confere o resultado.
# Uso: tests/net_test.sh [caminho_do_godot]
set -u
GODOT="${1:-godot}"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
CODE="$TMP/code.txt"
"$GODOT" --headless --path "$DIR" --script res://tests/net_test.gd -- host "$CODE" > "$TMP/host.log" 2>&1 &
HP=$!
sleep 2
"$GODOT" --headless --path "$DIR" --script res://tests/net_test.gd -- client "$CODE" > "$TMP/client.log" 2>&1 &
CP=$!
wait $CP; wait $HP
grep -h "^NET|" "$TMP/host.log" "$TMP/client.log"
echo "----"
fail=0
chk() { if grep -q "$2" "$TMP/$1.log"; then echo "  OK    $3"; else echo "  FALHA $3"; fail=1; fi; }
chk client "NET|client|partida|cores 0 x 1|tabuleiro_invertido true" "convidado entra pelo código, cor repetida é trocada, tabuleiro invertido"
chk host   "NET|host|partida|.*nomes Ana x Beto" "servidor recebe nome do convidado"
chk host   "chute_host|1" "servidor chuta"
chk client "chute_cliente|1" "convidado chuta (jogada validada pelo servidor)"
chk client "gol_recebido|time 0" "gol do servidor chega ao convidado"
chk host   "aguardando_reconexao" "servidor detecta queda e aguarda"
chk client "reconectou|ok" "convidado reconecta e recebe o estado"
chk host   "retomou" "partida continua após reconexão"
HS=$(grep -o "NET|host|fim_partida|placar [0-9]*-[0-9]*" "$TMP/host.log" | grep -o "[0-9]*-[0-9]*$")
CS=$(grep -o "NET|client|fim_partida|placar [0-9]*-[0-9]*" "$TMP/client.log" | grep -o "[0-9]*-[0-9]*$")
if [ -n "$HS" ] && [ "$HS" = "$CS" ]; then echo "  OK    placar final igual nos dois ($HS)"; else echo "  FALHA placar final (host '$HS' x convidado '$CS')"; fail=1; fi
D=$(grep -o "maior_diferenca [0-9.]*" "$TMP/client.log" | grep -o "[0-9.]*$")
if [ -n "$D" ] && awk "BEGIN{exit !($D < 0.5)}"; then echo "  OK    física igual nos dois aparelhos (diferença máx. $D px)"; else echo "  FALHA diferença de física '$D'"; fail=1; fi
chk host   "revanche|ok" "revanche reinicia no servidor"
chk client "revanche|ok" "revanche reinicia no convidado"
chk client "adversario_saiu_detectado|ok" "saída do adversário é avisada"
if grep -qE "SCRIPT ERROR" "$TMP/host.log" "$TMP/client.log" | grep -v "Identifier not found"; then :; fi
grep -hE "SCRIPT ERROR|ERROR:" "$TMP/host.log" "$TMP/client.log" | grep -v "Identifier not found: Sfx\|Compile Error: $\|Failed to load script\|net_test.gd\|at: " | sort | uniq -c | head
echo "RESULTADO REDE: $([ $fail = 0 ] && echo 'tudo ok' || echo 'há falhas')"
exit $fail
