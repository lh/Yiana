#!/usr/bin/env bash
set -euo pipefail

# Yiana Server Watchdog
# Monitors OCR service via heartbeat file.
# Sends Pushover alerts with dedup (1-hour cooldown).
#
# Usage: ./yiana-watchdog.sh [--max-age-seconds 600]
#
# Setup:
#   export PUSHOVER_USER="your-user-key"
#   export PUSHOVER_TOKEN="your-api-token"
#   Add to crontab: */5 * * * * ~/yiana-watchdog.sh

MAX_AGE=600  # 10 minutes default
if [[ "${1:-}" == "--max-age-seconds" && -n "${2:-}" ]]; then
  MAX_AGE="$2"; shift 2
fi

PUSHOVER_USER="${PUSHOVER_USER:-}"
PUSHOVER_TOKEN="${PUSHOVER_TOKEN:-}"
MIN_ALERT_INTERVAL=3600  # 1 hour between duplicate alerts

ALERT_TRACKER="$HOME/Library/Application Support/YianaOCR/health/last_alert.json"

now_epoch() { date +%s; }
file_epoch() { test -f "$1" && stat -f %m "$1" || echo 0; }
ts() { date "+%Y-%m-%d %H:%M:%S"; }

send_alert() {
  local msg="$1"
  local priority="${2:-0}"
  local alert_key="${3:-default}"

  echo "$(ts) [ALERT] $msg" >&2

  local last_alert_time=0
  if [[ -f "$ALERT_TRACKER" ]]; then
    last_alert_time=$(grep -o "\"$alert_key\":[0-9]*" "$ALERT_TRACKER" 2>/dev/null | cut -d: -f2 || echo 0)
  fi

  local now
  now=$(now_epoch)
  local time_since_last=$(( now - last_alert_time ))

  if [[ $priority -lt 1 ]] && (( time_since_last < MIN_ALERT_INTERVAL )); then
    echo "$(ts) [DEDUP] Skipping '$alert_key' (sent ${time_since_last}s ago)" >&2
    return 0
  fi

  if [[ -n "$PUSHOVER_USER" && -n "$PUSHOVER_TOKEN" ]]; then
    curl -s \
      --form-string "token=$PUSHOVER_TOKEN" \
      --form-string "user=$PUSHOVER_USER" \
      --form-string "title=Yiana Server Alert" \
      --form-string "message=$msg" \
      --form-string "priority=$priority" \
      https://api.pushover.net/1/messages.json >/dev/null 2>&1

    mkdir -p "$(dirname "$ALERT_TRACKER")"
    if [[ -f "$ALERT_TRACKER" ]]; then
      sed -i.bak "s/\"$alert_key\":[0-9]*/\"$alert_key\":$now/" "$ALERT_TRACKER" 2>/dev/null \
        || echo "{\"$alert_key\":$now}" > "$ALERT_TRACKER"
      if ! grep -q "\"$alert_key\"" "$ALERT_TRACKER" 2>/dev/null; then
        sed -i.bak "s/}$/,\"$alert_key\":$now}/" "$ALERT_TRACKER"
      fi
    else
      echo "{\"$alert_key\":$now}" > "$ALERT_TRACKER"
    fi
  else
    echo "$(ts) [WARN] PUSHOVER_USER or PUSHOVER_TOKEN not set" >&2
  fi
}

# --- Check OCR service heartbeat ---

OCR_HEALTH="$HOME/Library/Application Support/YianaOCR/health"
HEARTBEAT="$OCR_HEALTH/heartbeat.json"
LAST_ERROR="$OCR_HEALTH/last_error.json"

now=$(now_epoch)
hb_epoch=$(file_epoch "$HEARTBEAT")

if [[ $hb_epoch -eq 0 ]]; then
  send_alert "OCR: No heartbeat found. Service may not be running." 1 "ocr_no_heartbeat"
  echo "$(ts) [OCR] DOWN - no heartbeat" >&2
  exit 1
fi

age=$(( now - hb_epoch ))
if (( age > MAX_AGE )); then
  send_alert "OCR: Heartbeat stale (${age}s). Service has stalled or crashed." 1 "ocr_stale"
  echo "$(ts) [OCR] DOWN - heartbeat stale (${age}s)" >&2
  exit 1
fi

# Surface recent errors (within last hour)
if [[ -f "$LAST_ERROR" ]]; then
  err_epoch=$(file_epoch "$LAST_ERROR")
  err_age=$(( now - err_epoch ))

  if (( err_age < 3600 )); then
    err_msg=$(sed -n 's/.*"error"\s*:\s*"\(.*\)".*/\1/p' "$LAST_ERROR" | head -n1)
    if [[ -n "$err_msg" ]]; then
      err_hash=$(echo "$err_msg" | md5 | cut -c1-8)
      send_alert "OCR error: $err_msg" 0 "ocr_error_$err_hash"
    fi
  fi
fi

echo "$(ts) [OCR] OK - heartbeat age ${age}s"
exit 0
