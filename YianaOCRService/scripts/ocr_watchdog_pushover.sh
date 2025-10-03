#!/usr/bin/env bash
set -euo pipefail

# OCR Watchdog with Pushover notifications
# Usage: ./ocr_watchdog_pushover.sh [--max-age-seconds 600]
#
# Setup:
# 1. Sign up at pushover.net
# 2. Get your User Key and create an API Token
# 3. Set environment variables:
#    export PUSHOVER_USER="your-user-key"
#    export PUSHOVER_TOKEN="your-api-token"
# 4. Add to crontab: */5 * * * * ~/ocr_watchdog_pushover.sh

MAX_AGE=600  # 10 minutes default
if [[ "${1:-}" == "--max-age-seconds" && -n "${2:-}" ]]; then
  MAX_AGE="$2"; shift 2
fi

HEALTH_DIR="$HOME/Library/Application Support/YianaOCR/health"
HEARTBEAT="$HEALTH_DIR/heartbeat.json"
LAST_ERROR="$HEALTH_DIR/last_error.json"

# Pushover credentials (set as environment variables or add here)
PUSHOVER_USER="${PUSHOVER_USER:-}"
PUSHOVER_TOKEN="${PUSHOVER_TOKEN:-}"

alert() {
  local msg="$1"
  local priority="${2:-0}"  # -2=silent, -1=quiet, 0=normal, 1=high, 2=emergency

  echo "[OCR WATCHDOG] $msg" >&2

  # Send Pushover notification
  if [[ -n "$PUSHOVER_USER" && -n "$PUSHOVER_TOKEN" ]]; then
    curl -s \
      --form-string "token=$PUSHOVER_TOKEN" \
      --form-string "user=$PUSHOVER_USER" \
      --form-string "title=Yiana OCR Alert" \
      --form-string "message=$msg" \
      --form-string "priority=$priority" \
      https://api.pushover.net/1/messages.json >/dev/null 2>&1
  else
    echo "WARNING: PUSHOVER_USER or PUSHOVER_TOKEN not set" >&2
  fi
}

now_epoch() { date +%s; }
file_epoch() { test -f "$1" && stat -f %m "$1" || echo 0; }

# Check heartbeat freshness
NOW=$(now_epoch)
HB_EPOCH=$(file_epoch "$HEARTBEAT")

if [[ $HB_EPOCH -eq 0 ]]; then
  alert "⚠️ No heartbeat found. OCR service may not be running." 1
  exit 1
fi

AGE=$(( NOW - HB_EPOCH ))
if (( AGE > MAX_AGE )); then
  alert "🔴 Heartbeat stale (${AGE}s old). OCR service has stalled or crashed." 1
  exit 1
fi

# Surface last error if present
if [[ -f "$LAST_ERROR" ]]; then
  ERR_EPOCH=$(file_epoch "$LAST_ERROR")
  ERR_AGE=$(( NOW - ERR_EPOCH ))

  # Only alert if error is recent (within last hour)
  if (( ERR_AGE < 3600 )); then
    ERR_MSG=$(sed -n 's/.*"error"\s*:\s*"\(.*\)".*/\1/p' "$LAST_ERROR" | head -n1)
    if [[ -n "$ERR_MSG" ]]; then
      alert "⚠️ OCR error: $ERR_MSG" 0
    fi
  fi
fi

echo "✅ OK - heartbeat age ${AGE}s"
