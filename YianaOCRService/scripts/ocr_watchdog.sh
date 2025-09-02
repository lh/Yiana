#!/usr/bin/env bash
set -euo pipefail

# Simple watchdog: alerts if OCR heartbeat is stale or if last_error exists.
# Usage: ./ocr_watchdog.sh [--max-age-seconds 180]

MAX_AGE=180
if [[ "${1:-}" == "--max-age-seconds" && -n "${2:-}" ]]; then
  MAX_AGE="$2"; shift 2
fi

HEALTH_DIR="$HOME/Library/Application Support/YianaOCR/health"
HEARTBEAT="$HEALTH_DIR/heartbeat.json"
LAST_ERROR="$HEALTH_DIR/last_error.json"

alert() {
  local msg="$1"
  echo "[OCR WATCHDOG] $msg" >&2
  # macOS user notification (may require Terminal/osascript permissions)
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$msg\" with title \"Yiana OCR Watchdog\""
  fi
}

now_epoch() { date +%s; }
file_epoch() { test -f "$1" && stat -f %m "$1" || echo 0; }

# Check heartbeat freshness
NOW=$(now_epoch)
HB_EPOCH=$(file_epoch "$HEARTBEAT")
if [[ $HB_EPOCH -eq 0 ]]; then
  alert "No heartbeat found at $HEARTBEAT"
  exit 1
fi

AGE=$(( NOW - HB_EPOCH ))
if (( AGE > MAX_AGE )); then
  alert "Heartbeat stale ($AGE s > $MAX_AGE s). OCR service may have stalled."
fi

# Surface last error if present
if [[ -f "$LAST_ERROR" ]]; then
  ERR_MSG=$(sed -n 's/.*"error"\s*:\s*"\(.*\)".*/\1/p' "$LAST_ERROR" | head -n1)
  [[ -n "$ERR_MSG" ]] && alert "Last OCR error: $ERR_MSG"
fi

echo "OK - heartbeat age ${AGE}s"

