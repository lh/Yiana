#!/usr/bin/env bash
set -euo pipefail

# Unified Yiana Server Watchdog
# Monitors both OCR and Extraction services via heartbeat files.
# Sends Pushover alerts with per-service dedup (1-hour cooldown).
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

# Alert tracker shared across services
ALERT_TRACKER="$HOME/Library/Application Support/YianaOCR/health/last_alert.json"

OVERALL_OK=true

now_epoch() { date +%s; }
file_epoch() { test -f "$1" && stat -f %m "$1" || echo 0; }
ts() { date "+%Y-%m-%d %H:%M:%S"; }

send_alert() {
  local msg="$1"
  local priority="${2:-0}"
  local alert_key="${3:-default}"

  echo "$(ts) [ALERT] $msg" >&2

  # Dedup: check if we recently sent this exact alert
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

    # Update tracker
    mkdir -p "$(dirname "$ALERT_TRACKER")"
    if [[ -f "$ALERT_TRACKER" ]]; then
      sed -i.bak "s/\"$alert_key\":[0-9]*/\"$alert_key\":$now/" "$ALERT_TRACKER" 2>/dev/null \
        || echo "{\"$alert_key\":$now}" > "$ALERT_TRACKER"
      # If key wasn't in file yet, append it
      if ! grep -q "\"$alert_key\"" "$ALERT_TRACKER" 2>/dev/null; then
        # Replace trailing } with new key
        sed -i.bak "s/}$/,\"$alert_key\":$now}/" "$ALERT_TRACKER"
      fi
    else
      echo "{\"$alert_key\":$now}" > "$ALERT_TRACKER"
    fi
  else
    echo "$(ts) [WARN] PUSHOVER_USER or PUSHOVER_TOKEN not set" >&2
  fi
}

# Check a single service's heartbeat
# Args: service_name health_dir
check_service() {
  local name="$1"
  local health_dir="$2"
  local heartbeat="$health_dir/heartbeat.json"
  local last_error="$health_dir/last_error.json"

  local now
  now=$(now_epoch)
  local hb_epoch
  hb_epoch=$(file_epoch "$heartbeat")

  if [[ $hb_epoch -eq 0 ]]; then
    send_alert "$name: No heartbeat found. Service may not be running." 1 "${name}_no_heartbeat"
    echo "$(ts) [$name] DOWN - no heartbeat" >&2
    OVERALL_OK=false
    return
  fi

  local age=$(( now - hb_epoch ))
  if (( age > MAX_AGE )); then
    send_alert "$name: Heartbeat stale (${age}s). Service has stalled or crashed." 1 "${name}_stale"
    echo "$(ts) [$name] DOWN - heartbeat stale (${age}s)" >&2
    OVERALL_OK=false
    return
  fi

  # Surface recent errors (within last hour)
  if [[ -f "$last_error" ]]; then
    local err_epoch
    err_epoch=$(file_epoch "$last_error")
    local err_age=$(( now - err_epoch ))

    if (( err_age < 3600 )); then
      local err_msg
      err_msg=$(sed -n 's/.*"error"\s*:\s*"\(.*\)".*/\1/p' "$last_error" | head -n1)
      if [[ -n "$err_msg" ]]; then
        local err_hash
        err_hash=$(echo "$err_msg" | md5 | cut -c1-8)
        send_alert "$name error: $err_msg" 0 "${name}_error_$err_hash"
      fi
    fi
  fi

  echo "$(ts) [$name] OK - heartbeat age ${age}s"
}

# --- Check both services ---

OCR_HEALTH="$HOME/Library/Application Support/YianaOCR/health"
EXTRACTION_HEALTH="$HOME/Library/Application Support/YianaExtraction/health"

check_service "OCR" "$OCR_HEALTH"
check_service "Extraction" "$EXTRACTION_HEALTH"

if $OVERALL_OK; then
  exit 0
else
  exit 1
fi
