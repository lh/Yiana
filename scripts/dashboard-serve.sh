#!/usr/bin/env bash
# dashboard-serve.sh — Run data collector + typst-live on Devon
#
# Usage (on Devon):
#   bash ~/Code/Yiana/scripts/dashboard-serve.sh
#
# Then open http://Devon-6.local:5599 from any device on the network.
# The page auto-reloads when data changes (typst-live injects websocket).

set -euo pipefail

export PATH="/opt/homebrew/bin:$HOME/.cargo/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTERVAL="${1:-60}"  # refresh interval in seconds, default 60

cleanup() {
    echo "Stopping..."
    kill "$COLLECTOR_PID" "$TYPST_PID" 2>/dev/null || true
    exit 0
}
trap cleanup INT TERM

# Initial data collection so typst has something to compile
python3 "$SCRIPT_DIR/dashboard-collector.py"

# Start typst-live (serves on all interfaces, auto-reloads browser)
typst-live "$SCRIPT_DIR/dashboard.typ" \
    --address 0.0.0.0 \
    --port 5599 \
    --no-browser-tab &
TYPST_PID=$!

# Start collector loop in background
(
    while true; do
        sleep "$INTERVAL"
        python3 "$SCRIPT_DIR/dashboard-collector.py" 2>&1 || true
    done
) &
COLLECTOR_PID=$!

echo "Dashboard live at http://$(hostname):5599"
echo "Data refreshes every ${INTERVAL}s. Ctrl-C to stop."
wait
