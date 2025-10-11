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
ALERT_TRACKER="$HEALTH_DIR/last_alert.json"

# Pushover credentials (set as environment variables or add here)
PUSHOVER_USER="${PUSHOVER_USER:-}"
PUSHOVER_TOKEN="${PUSHOVER_TOKEN:-}"

# Minimum time between alerts for the same issue (1 hour = 3600 seconds)
MIN_ALERT_INTERVAL=3600

alert() {
  local msg="$1"
  local priority="${2:-0}"  # -2=silent, -1=quiet, 0=normal, 1=high, 2=emergency
  local alert_key="${3:-default}"  # Unique key for this alert type

  echo "[OCR WATCHDOG] $msg" >&2

  # Check if we've recently sent this alert
  local last_alert_time=0
  if [[ -f "$ALERT_TRACKER" ]]; then
    last_alert_time=$(grep -o "\"$alert_key\":[0-9]*" "$ALERT_TRACKER" 2>/dev/null | cut -d: -f2 || echo 0)
  fi

  local time_since_last=$(($(now_epoch) - last_alert_time))

  # Skip if we sent same alert recently (unless it's high priority)
  if [[ $priority -lt 1 ]] && (( time_since_last < MIN_ALERT_INTERVAL )); then
    echo "[OCR WATCHDOG] Skipping alert (sent ${time_since_last}s ago, waiting ${MIN_ALERT_INTERVAL}s)" >&2
    return 0
  fi

  # Send Pushover notification
  if [[ -n "$PUSHOVER_USER" && -n "$PUSHOVER_TOKEN" ]]; then
    curl -s \
      --form-string "token=$PUSHOVER_TOKEN" \
      --form-string "user=$PUSHOVER_USER" \
      --form-string "title=Yiana OCR Alert" \
      --form-string "message=$msg" \
      --form-string "priority=$priority" \
      https://api.pushover.net/1/messages.json >/dev/null 2>&1

    # Record that we sent this alert
    mkdir -p "$HEALTH_DIR"
    local now=$(now_epoch)
    if [[ -f "$ALERT_TRACKER" ]]; then
      # Update existing tracker
      sed -i.bak "s/\"$alert_key\":[0-9]*/\"$alert_key\":$now/" "$ALERT_TRACKER" 2>/dev/null || echo "{\"$alert_key\":$now}" > "$ALERT_TRACKER"
    else
      echo "{\"$alert_key\":$now}" > "$ALERT_TRACKER"
    fi
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
  alert "⚠️ No heartbeat found. OCR service may not be running." 1 "no_heartbeat"
  exit 1
fi

AGE=$(( NOW - HB_EPOCH ))
if (( AGE > MAX_AGE )); then
  alert "🔴 Heartbeat stale (${AGE}s old). OCR service has stalled or crashed." 1 "stale_heartbeat"
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
      # Create hash of error message as unique key
      ERR_HASH=$(echo "$ERR_MSG" | md5 | cut -c1-8)
      alert "⚠️ OCR error: $ERR_MSG" 0 "error_$ERR_HASH"
    fi
  fi
fi

echo "✅ OK - heartbeat age ${AGE}s"
