#!/usr/bin/env bash
# =============================================================================
# Coletor de metricas no cliente (aluno ou professor) - TCC Cyber Resistance.
#
# Roda numa maquina Linux que esta executando o Godot do cliente.
# Inicia o Godot ANTES de rodar este script (precisa achar o processo).
#
# Uso:
#   sudo apt install nethogs tshark         # uma vez
#   chmod +x eval_scripts/collect_client.sh # uma vez
#   sudo eval_scripts/collect_client.sh [label]
#
# Parametros:
#   label   rotulo da pasta de saida. Use "host", "aluno01", "professor"...
#           Default: "client".
#
# Para interromper: Ctrl+C. Os arquivos sao fechados corretamente.
#
# Saidas em eval_results/<label>_<timestamp>/ :
#   meta.txt        - timestamps de inicio/fim (unix + ISO), label, hostname
#   cpu_mem.csv     - amostragem 1Hz: timestamp,pid,cpu_pct,rss_kb,cmd
#                     (cpu_pct = % de um nucleo, pode passar de 100 em multithread)
#   nethogs.log     - banda por processo (-t)
#   capture.pcapng  - captura de TODO trafego UDP da maquina
#                     (filtra-se depois no Wireshark, ja que a porta Layer 2
#                      do host e sorteada por get_random_port())
#
# Como extrair cada metrica do TCC (apos a sessao):
#   - Banda media/pico por processo: nethogs.log
#   - PPS:              Wireshark > Statistics > I/O Graph (Y = packets/s)
#   - Tamanho medio:    Wireshark > Statistics > Packet Lengths
#   - Categoria (in-game): filtro por primeiro byte do payload UDP, ex.:
#                       udp.payload[0] == 00  (PLAYER_PACKET)
#                       udp.payload[0] == 0a  (TEXT_PACKET)
#                       udp.payload[0] == 0b  (SCENE_SYNC_PACKET)
#                       udp.payload[0] == 0c  (SCENE_FORCE_PACKET)
#                       udp.payload[0] == 14  (MINIGAME_ASSIGN)
#                       udp.payload[0] == 15  (MINIGAME_ANSWER)
#                       udp.payload[0] == 16  (MINIGAME_PROGRESS)
#                       udp.payload[0] == 17  (MINIGAME_GRADE_RESULT)
#                       Tabela completa em
#                       client/prototype/scripts/in_game_packets/base/player_base.gd
#   - CPU/memoria:      cpu_mem.csv -> Excel/Python
#   - Fases da sessao:  anote em paralelo (em outro terminal) os timestamps
#                       Unix das transicoes com  date +%s  e fatie o CSV depois.
# =============================================================================

set -u

LABEL="${1:-client}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SESS="${LABEL}_$(date +%Y%m%d_%H%M%S)"
OUT="$ROOT/eval_results/$SESS"
mkdir -p "$OUT"

require() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "[!] '$1' nao encontrado no PATH. Instale antes de rodar." >&2
        exit 1
    }
}
require nethogs
require tshark
require pgrep

echo "[*] sessao: $SESS"
echo "[*] saida:  $OUT"

{
    echo "start_unix=$(date +%s)"
    echo "start_iso=$(date -Iseconds)"
    echo "label=$LABEL"
    echo "host=$(hostname)"
} > "$OUT/meta.txt"

# -- CPU/memoria 1Hz --
{
    echo "timestamp,pid,cpu_pct,rss_kb,cmd"
    while true; do
        ts=$(date +%s)
        pgrep -f "godot" | while read -r pid; do
            ps -p "$pid" -o pid=,pcpu=,rss=,comm= 2>/dev/null \
                | awk -v t="$ts" 'NF{print t","$1","$2","$3","$4}'
        done
        sleep 1
    done
} > "$OUT/cpu_mem.csv" 2>/dev/null &
PID_CM=$!

# -- Banda por processo --
nethogs -t -d 1 > "$OUT/nethogs.log" 2>/dev/null &
PID_NH=$!

# -- Captura de pacotes (todo UDP) --
# Sem filtro de porta porque a porta da camada in-game eh sorteada por
# get_random_port() em start_room. A separacao Layer 1 / Layer 2 fica para
# a analise pos-sessao, pelo IP/porta de origem-destino.
tshark -i any -f "udp" -w "$OUT/capture.pcapng" >/dev/null 2>&1 &
PID_TS=$!

cleanup() {
    echo
    echo "[*] parando coleta..."
    # SIGTERM faz o tshark finalizar o pcapng corretamente.
    kill -TERM "$PID_CM" "$PID_NH" "$PID_TS" 2>/dev/null
    wait 2>/dev/null
    {
        echo "end_unix=$(date +%s)"
        echo "end_iso=$(date -Iseconds)"
    } >> "$OUT/meta.txt"
    echo "[*] OK. Arquivos em: $OUT"
    exit 0
}
trap cleanup INT TERM

echo "[*] coletando (Ctrl+C para parar)..."
wait
