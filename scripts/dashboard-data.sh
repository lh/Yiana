#!/usr/bin/env bash
# dashboard-data.sh — Collects live data from Devon and writes dashboard-data.json
#
# Usage:
#   bash scripts/dashboard-data.sh              # one-shot
#   watch -n 60 bash scripts/dashboard-data.sh  # auto-refresh every 60s
#
# Pair with: typst watch scripts/dashboard.typ

set -euo pipefail

DEVON="devon@Devon-6.local"
SSH_OPTS="-o ConnectTimeout=5 -o BatchMode=yes"
OUT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_FILE="$OUT_DIR/dashboard-data.json"

ssh $SSH_OPTS "$DEVON" 'python3 << "PYEOF"
import json, os, time, subprocess
from datetime import datetime, timezone, timedelta
from pathlib import Path

DEVON_HOME = "/Users/devon"
ICLOUD_DOCS = f"{DEVON_HOME}/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents"
OCR_RESULTS = f"{ICLOUD_DOCS}/.ocr_results"
ADDRESSES = f"{ICLOUD_DOCS}/.addresses"
LOG_DIR = f"{DEVON_HOME}/Library/Logs"
HEALTH_DIR = f"{DEVON_HOME}/Library/Application Support/YianaOCR/health"
EXTRACTION_HEALTH = f"{DEVON_HOME}/Library/Application Support/YianaExtraction/health"

now = datetime.now(timezone.utc)
now_ts = now.timestamp()

def file_size_str(path):
    try:
        size = os.path.getsize(path)
        if size < 1024: return f"{size}B"
        elif size < 1048576: return f"{size // 1024}K"
        elif size < 1073741824: return f"{size // 1048576}M"
        else: return f"{round(size / 1073741824, 1)}G"
    except: return "0B"

def read_heartbeat(health_dir):
    try:
        with open(os.path.join(health_dir, "heartbeat.json")) as f:
            hb = json.load(f)
        ts = datetime.fromisoformat(hb["timestamp"].replace("Z", "+00:00"))
        age = int((now - ts).total_seconds())
        note = hb.get("note", "")
        return age, note
    except:
        return 9999, "unknown"

def read_last_error(health_dir):
    try:
        with open(os.path.join(health_dir, "last_error.json")) as f:
            err = json.load(f)
        if not err or err == {}: return None
        ts = datetime.fromisoformat(err["timestamp"].replace("Z", "+00:00"))
        age = int((now - ts).total_seconds())
        msg = err.get("error", "unknown")
        if len(msg) > 80: msg = msg[:77] + "..."
        return {"message": msg, "age_seconds": age}
    except:
        return None

def get_pid(name):
    try:
        result = subprocess.run(["pgrep", "-x", name], capture_output=True, text=True)
        return result.stdout.strip() or "0"
    except:
        return "0"

def count_files(directory, pattern="*.json", recursive=False):
    try:
        p = Path(directory)
        if recursive:
            return len(list(p.rglob(pattern)))
        return len(list(p.glob(pattern)))
    except:
        return 0

def count_yianazip(directory):
    count = 0
    try:
        for root, dirs, files in os.walk(directory):
            # Skip hidden dirs and Trash
            dirs[:] = [d for d in dirs if not d.startswith(".") and d != ".Trash"]
            for f in files:
                if f.endswith(".yianazip"):
                    count += 1
    except: pass
    return count

def get_disk():
    try:
        result = subprocess.run(["df", "-h", "/"], capture_output=True, text=True)
        line = result.stdout.strip().split("\n")[-1]
        parts = line.split()
        used = parts[2]
        avail = parts[3]
        pct = int(parts[4].replace("%", ""))
        return {"used": used, "available": avail, "capacity_percent": pct}
    except:
        return {"used": "?", "available": "?", "capacity_percent": 0}

def ocr_history_7d():
    """Count OCR results by modification date for the last 7 days."""
    history = {}
    today = datetime.now().date()
    for i in range(6, -1, -1):
        d = today - timedelta(days=i)
        history[d.isoformat()] = 0

    try:
        processed_file = os.path.join(
            DEVON_HOME, "Library", "Application Support", "YianaOCR", "processed.json"
        )
        with open(processed_file) as f:
            processed = json.load(f)
        for fname, info in processed.items():
            if isinstance(info, dict) and "processedAt" in info:
                ts = info["processedAt"]
                d = datetime.fromtimestamp(ts).date()
                key = d.isoformat()
                if key in history:
                    history[key] += 1
    except:
        pass

    return [{"date": k, "count": v} for k, v in history.items()]

def ocr_today_count():
    """Count documents processed today."""
    today_start = datetime.combine(datetime.now().date(), datetime.min.time()).timestamp()
    count = 0
    try:
        processed_file = os.path.join(
            DEVON_HOME, "Library", "Application Support", "YianaOCR", "processed.json"
        )
        with open(processed_file) as f:
            processed = json.load(f)
        for fname, info in processed.items():
            if isinstance(info, dict) and "processedAt" in info:
                if info["processedAt"] >= today_start:
                    count += 1
    except:
        pass
    return count

# --- Collect ---
ocr_pid = get_pid("yiana-ocr")
ocr_hb_age, ocr_note = read_heartbeat(HEALTH_DIR)
ocr_err = read_last_error(HEALTH_DIR)

ext_pid = subprocess.run(["pgrep", "-f", "extraction_service.py"], capture_output=True, text=True).stdout.strip().split("\\n")[0] or "0"
ext_hb_age, ext_note = read_heartbeat(EXTRACTION_HEALTH)
ext_err = read_last_error(EXTRACTION_HEALTH)

total_docs = count_yianazip(ICLOUD_DOCS)
ocr_results = count_files(OCR_RESULTS, "*.json", recursive=True)
addresses = count_files(ADDRESSES, "*.json")
pending = max(0, total_docs - ocr_results)

dashboard = {
    "timestamp": now.strftime("%Y-%m-%d %H:%M:%S UTC"),
    "services": [
        {
            "name": "OCR",
            "status": "up" if ocr_pid != "0" else "down",
            "pid": ocr_pid,
            "heartbeat_age_seconds": ocr_hb_age,
            "last_error": ocr_err,
            "log_size": file_size_str(f"{LOG_DIR}/yiana-ocr.log"),
            "err_log_size": file_size_str(f"{LOG_DIR}/yiana-ocr-error.log"),
        },
        {
            "name": "Extraction",
            "status": "up" if ext_pid != "0" else "down",
            "pid": ext_pid,
            "heartbeat_age_seconds": ext_hb_age,
            "last_error": ext_err,
            "log_size": file_size_str(f"{LOG_DIR}/yiana-extraction.log"),
            "err_log_size": file_size_str(f"{LOG_DIR}/yiana-extraction-error.log"),
        },
    ],
    "data": {
        "documents": total_docs,
        "ocr_results": ocr_results,
        "addresses": addresses,
        "pending_ocr": pending,
        "ocr_today": ocr_today_count(),
    },
    "ocr_history": ocr_history_7d(),
    "disk": get_disk(),
}

print(json.dumps(dashboard, indent=2))
PYEOF' > "$OUT_FILE"

echo "Updated $OUT_FILE at $(date '+%H:%M:%S')"
