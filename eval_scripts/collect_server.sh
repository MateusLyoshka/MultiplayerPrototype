#!/usr/bin/env bash
# =============================================================================
# Coletor de metricas no servidor central - TCC Cyber Resistance.
#
# Roda numa maquina Linux que esta executando o servidor (Godot headless).
# Inicia o Godot ANTES de rodar este script (precisa achar o processo).
#
# Uso:
#   sudo apt install nethogs tshark         # uma vez
#   chmod +x eval_scripts/collect_server.sh # uma vez
#   sudo eval_scripts/collect_server.sh [porta_lobby]
#
# Para interromper: Ctrl+C. Os arquivos sao fechados corretamente.
#
# Saidas em eval_results/server_<timestamp>/ :
#   meta.txt        - timestamps de inicio e fim (unix + ISO), porta usada
#   cpu_mem.csv     - amostragem 1Hz: timestamp,pid,cpu_pct,rss_kb,cmd
#                     (cpu_pct = % de um nucleo, pode passar de 100 em multithread)
#   nethogs.log     - saida do nethogs em modo trace (-t), banda por processo
#   capture.pcapng  - captura UDP filtrada pela porta do lobby
#
# Como extrair cada metrica do TCC (apos a sessao):
#   - Banda media/pico por processo: nethogs.log
#   - PPS:                          Wireshark > Statistics > I/O Graph
#   - Tamanho medio de pacote:      Wireshark > Statistics > Packet Lengths
#   - Categoria de pacote (lobby):  filtro de display por primeiro byte do
#                                   payload UDP, ex. udp.payload[0] == 00
#                                   (mapeia para PacketTypeClass.PACKET_TYPE).
#   - CPU/memoria:                  cpu_mem.csv -> Excel/Python
#   - RTT/perda:                    nao saem do tshark crus (ENet faz
#                                   retransmissao interna). Opcao: imprimir
#                                   server_peer.get_statistic(...) no
#                                   network_handler.gd periodicamente.
# =============================================================================

set -u

PORT="${1:-7777}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SESS="server_$(date +%Y%m%d_%H%M%S)"
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
echo "[*] porta:  $PORT"

{
    echo "start_unix=$(date +%s)"
    echo "start_iso=$(date -Iseconds)"
    echo "port=$PORT"
    echo "host=$(hostname)"
} > "$OUT/meta.txt"

# -- CPU/memoria 1Hz --
# pgrep -f 'godot' pega TODOS os processos cujo cmdline contem 'godot' (case-sens).
# Se voce roda o Godot headless via `godot --headless ...`, o nome do binario
# basta. Se renomeou, ajuste o padrao abaixo.
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

# -- Banda por processo (nethogs) --
nethogs -t -d 1 > "$OUT/nethogs.log" 2>/dev/null &
PID_NH=$!

# -- Captura de pacotes do lobby (Layer 1) --
# Captura em -i any para nao depender do nome da interface.
tshark -i any -f "udp port $PORT" -w "$OUT/capture.pcapng" >/dev/null 2>&1 &
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
