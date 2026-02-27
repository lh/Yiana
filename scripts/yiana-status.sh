#!/usr/bin/env bash
set -euo pipefail

# Yiana Server Status Dashboard
# Pure bash, no dependencies beyond standard macOS utils.

# --- Colors and formatting ---
RST='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
WHITE='\033[37m'

# --- Paths ---
ICLOUD_DIR="$HOME/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents"
OCR_HEALTH="$HOME/Library/Application Support/YianaOCR/health"
EXTRACTION_HEALTH="$HOME/Library/Application Support/YianaExtraction/health"
OCR_LOG="$HOME/Library/Logs/yiana-ocr.log"
OCR_ERR_LOG="$HOME/Library/Logs/yiana-ocr-error.log"
EXTRACTION_LOG="$HOME/Library/Logs/yiana-extraction.log"
EXTRACTION_ERR_LOG="$HOME/Library/Logs/yiana-extraction-error.log"

now_epoch() { date +%s; }
file_epoch() { test -f "$1" && stat -f %m "$1" 2>/dev/null || echo 0; }
human_size() { ls -lh "$1" 2>/dev/null | awk '{print $5}' || echo "?"; }

age_color() {
  local age=$1
  if (( age < 120 )); then
    printf "${GREEN}"
  elif (( age < 600 )); then
    printf "${YELLOW}"
  else
    printf "${RED}"
  fi
}

age_text() {
  local s=$1
  if (( s < 60 )); then echo "${s}s"
  elif (( s < 3600 )); then echo "$(( s / 60 ))m $(( s % 60 ))s"
  elif (( s < 86400 )); then echo "$(( s / 3600 ))h $(( (s % 3600) / 60 ))m"
  else echo "$(( s / 86400 ))d $(( (s % 86400) / 3600 ))h"
  fi
}

# --- Service status ---
print_service() {
  local name="$1"
  local pid_cmd="$2"
  local health_dir="$3"
  local log_file="$4"
  local err_log="$5"

  local pid
  pid=$(eval "$pid_cmd" 2>/dev/null || true)
  local heartbeat="$health_dir/heartbeat.json"
  local last_error="$health_dir/last_error.json"
  local now
  now=$(now_epoch)

  # Status line
  printf "  ${BOLD}%-14s${RST}" "$name"
  if [[ -n "$pid" ]]; then
    printf " ${GREEN}UP${RST}  PID %-6s" "$pid"
  else
    printf " ${RED}DOWN${RST}  PID %-6s" "---"
  fi

  # Heartbeat
  local hb_epoch
  hb_epoch=$(file_epoch "$heartbeat")
  if [[ $hb_epoch -eq 0 ]]; then
    printf "  HB: ${RED}none${RST}"
  else
    local age=$(( now - hb_epoch ))
    printf "  HB: $(age_color $age)%s ago${RST}" "$(age_text $age)"
  fi

  printf "\n"

  # Last error
  if [[ -f "$last_error" ]]; then
    local err_epoch
    err_epoch=$(file_epoch "$last_error")
    local err_age=$(( now - err_epoch ))
    local err_msg
    err_msg=$(sed -n 's/.*"error" *: *"\(.*\)".*/\1/p' "$last_error" 2>/dev/null | head -n1)
    if [[ -n "$err_msg" ]]; then
      local truncated="${err_msg:0:60}"
      [[ ${#err_msg} -gt 60 ]] && truncated="${truncated}..."
      printf "  ${DIM}Last error:${RST} ${RED}%s${RST} ${DIM}(%s ago)${RST}\n" "$truncated" "$(age_text $err_age)"
    fi
  fi

  # Log sizes
  local log_size err_size
  log_size=$(human_size "$log_file")
  err_size=$(human_size "$err_log")
  printf "  ${DIM}Logs: stdout %s  stderr %s${RST}\n" "$log_size" "$err_size"
}

# --- Header ---
printf "\n"
printf "${BOLD}${CYAN}  Yiana Server Status${RST}  ${DIM}$(date "+%Y-%m-%d %H:%M:%S")${RST}\n"
printf "${DIM}  %s${RST}\n" "$(printf '%.0s─' {1..48})"

# --- Services ---
printf "\n${BOLD}  Services${RST}\n"
printf "${DIM}  %s${RST}\n" "$(printf '%.0s─' {1..48})"

print_service "OCR" "pgrep -x yiana-ocr" "$OCR_HEALTH" "$OCR_LOG" "$OCR_ERR_LOG"
printf "\n"
print_service "Extraction" "pgrep -f extraction_service.py" "$EXTRACTION_HEALTH" "$EXTRACTION_LOG" "$EXTRACTION_ERR_LOG"

# --- Data Stats ---
printf "\n${BOLD}  Data${RST}\n"
printf "${DIM}  %s${RST}\n" "$(printf '%.0s─' {1..48})"

doc_count=0
ocr_count=0
addr_count=0

if [[ -d "$ICLOUD_DIR" ]]; then
  doc_count=$(find "$ICLOUD_DIR" -maxdepth 1 -name "*.yianazip" 2>/dev/null | wc -l | tr -d ' ')
fi
if [[ -d "$ICLOUD_DIR/.ocr_results" ]]; then
  ocr_count=$(find "$ICLOUD_DIR/.ocr_results" -maxdepth 1 -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
fi
if [[ -d "$ICLOUD_DIR/.addresses" ]]; then
  addr_count=$(find "$ICLOUD_DIR/.addresses" -maxdepth 1 -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
fi

printf "  Documents: ${WHITE}%s${RST}   OCR results: ${WHITE}%s${RST}   Addresses: ${WHITE}%s${RST}\n" \
  "$doc_count" "$ocr_count" "$addr_count"

# --- Disk ---
printf "\n${BOLD}  Disk${RST}\n"
printf "${DIM}  %s${RST}\n" "$(printf '%.0s─' {1..48})"

disk_info=$(df -h / | tail -1)
disk_used=$(echo "$disk_info" | awk '{print $3}')
disk_avail=$(echo "$disk_info" | awk '{print $4}')
disk_pct=$(echo "$disk_info" | awk '{print $5}')

printf "  Used: ${WHITE}%s${RST}  Available: ${WHITE}%s${RST}  Capacity: ${WHITE}%s${RST}\n" \
  "$disk_used" "$disk_avail" "$disk_pct"

printf "\n"
