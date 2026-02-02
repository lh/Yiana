# Yiana Backend Services - Troubleshooting Guide

## Services Overview

Two backend services run on Devon (Mac mini, 192.168.1.137):

| Service | Language | Process | Purpose |
|---------|----------|---------|---------|
| **YianaOCRService** | Swift | `/Users/devon/bin/yiana-ocr` | Watches for `.yianazip` files, runs OCR via Vision framework |
| **Extraction Service** | Python | `extraction_service.py` | Watches OCR results, extracts addresses from OCR text |

## Quick Health Check

SSH into Devon and run:

```bash
# OCR service
sudo launchctl list | grep yiana
ps aux | grep yiana-ocr | grep -v grep
cat ~/Library/Application\ Support/YianaOCR/health/heartbeat.json

# Extraction service
ps aux | grep extraction_service | grep -v grep
tail -5 /private/tmp/address_extraction.log
```

## Diagnostic Flowchart

### Documents not being OCR-ed

```
Is yiana-ocr process running?
├── NO → Is the LaunchDaemon loaded?
│         ├── NO → sudo launchctl load /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
│         └── YES (but not running) → Check error log: ~/Library/Logs/yiana-ocr-error.log
└── YES → Is the heartbeat recent?
          ├── NO (stale > 10 min) → Service may be stuck. Check error log, consider restart.
          └── YES → Check if specific document exists in iCloud:
                    ls ~/Library/Mobile\ Documents/iCloud~com~vitygas~Yiana/Documents/*.yianazip
                    → If file missing, iCloud sync issue (not a service problem)
```

### Addresses not appearing for OCR-ed documents

```
Does the OCR JSON exist in .ocr_results/?
├── NO → OCR hasn't completed yet. Check OCR service logs.
└── YES → Is the extraction service running?
          ├── NO → Start it (see below)
          └── YES → Check extraction log: /private/tmp/address_extraction.log
                    ├── File not mentioned → Watchdog didn't detect it (see Watchdog Issues)
                    ├── "No data extracted" → File doesn't contain extractable addresses
                    └── "Saved N records" → Check if DB was overwritten by iCloud sync
                        → Verify: sqlite3 addresses.db "SELECT * WHERE document_id LIKE '%name%'"
                        → If missing despite "Saved" in log: iCloud overwrote the DB (known issue)
```

## OCR Service (Swift)

### Log Locations

- **Stdout**: `~/Library/Logs/yiana-ocr.log`
- **Stderr**: `~/Library/Logs/yiana-ocr-error.log` (main log - most output goes here)
- **Health**: `~/Library/Application Support/YianaOCR/health/heartbeat.json`
- **Errors**: `~/Library/Application Support/YianaOCR/health/last_error.json`

### Service Won't Start After Reboot

The OCR service runs as a **LaunchDaemon** (system-level), so it should start at boot without requiring login. If it doesn't:

```bash
# Check if daemon is loaded
sudo launchctl list | grep yiana

# If not loaded
sudo launchctl load /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist

# If load fails, check plist syntax
plutil -lint /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
```

### Stale Heartbeat / Watchdog Alerts

The heartbeat is updated after each document is processed. If it goes stale:

1. **Service is processing a very large file** - check error log for current activity
2. **Service crashed** - check `ps aux | grep yiana-ocr`
3. **No new documents to process** - heartbeat only updates during active scans

```bash
# Check heartbeat age
cat ~/Library/Application\ Support/YianaOCR/health/heartbeat.json

# Check last error
cat ~/Library/Application\ Support/YianaOCR/health/last_error.json

# Restart if needed
sudo launchctl unload /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
sudo launchctl load /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
```

### Multiple yiana-ocr Processes

Can happen if an old LaunchAgent registration lingers alongside the new LaunchDaemon:

```bash
# Kill all instances
pkill -9 -f 'yiana-ocr'

# Remove any user-level LaunchAgent
launchctl remove com.vitygas.yiana-ocr 2>/dev/null

# Reload only the daemon
sudo launchctl load /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist

# Verify single process
ps aux | grep yiana-ocr | grep -v grep
```

### "File exists" Errors

Non-critical. Occurs when OCR results directory already exists. Safe to ignore.

### CoreText Font Warnings

Non-critical. Occurs when processing PDFs with system font references. Does not affect OCR quality.

## Extraction Service (Python)

### Log Location

- **Main log**: `/private/tmp/address_extraction.log`
- **JSON output**: `/Users/devon/Code/Yiana/AddressExtractor/api_output/`

### Starting the Service

```bash
cd /Users/devon/Code/Yiana/AddressExtractor
source .venv/bin/activate
python extraction_service.py > /private/tmp/address_extraction.log 2>&1 &
```

### Checking What Was Extracted

```bash
# Check the extraction log
grep "Extracted from" /private/tmp/address_extraction.log | tail -20

# Check specific document
grep "Ascough" /private/tmp/address_extraction.log

# Check JSON output (reliable - not affected by iCloud)
cat /Users/devon/Code/Yiana/AddressExtractor/api_output/DOCUMENT_NAME.json
```

### Watchdog Not Detecting New Files

The extraction service uses Python's `watchdog` library with FSEvents to detect new `.json` files in `.ocr_results/`. If files aren't being picked up:

1. **Verify the watcher is monitoring the right directory**:
   ```bash
   lsof -p $(pgrep -f extraction_service) | grep ocr_results
   ```

2. **Check if the file exists**:
   ```bash
   ls -la ~/Library/Mobile\ Documents/iCloud~com~vitygas~Yiana/Documents/.ocr_results/FILENAME.json
   ```

3. **Force reprocessing** by restarting the service (it runs `process_existing_files` on startup)

### Database Writes Lost (iCloud Sync Issue)

**Known issue**: SQLite databases in iCloud-synced directories can lose data because iCloud does whole-file sync and may overwrite local changes with a version from another device.

**Symptoms**:
- Extraction log shows "Saved N records to database"
- But `sqlite3 addresses.db "SELECT ..."` doesn't show the data
- DB file modification time is older than the extraction log entry

**Verification**:
```bash
# Check DB modification time
ls -la ~/Library/Mobile\ Documents/iCloud~com~vitygas~Yiana/Documents/addresses.db

# Compare with extraction log timestamps
grep "Saved" /private/tmp/address_extraction.log | tail -10

# Check JSON output (unaffected by iCloud)
ls -lt /Users/devon/Code/Yiana/AddressExtractor/api_output/ | head -10
```

**Workaround**: The JSON output files in `api_output/` are on local disk and are not affected. These contain the same extracted data.

### Repeated Processing of Same File

Files that yield no extractable data get reprocessed on every `on_modified` event because they're never added to `processed_files`. This is a known issue visible in the log as repeated "No data extracted from X" messages. It's wasteful but not harmful.

## Database

### Checking the Database

```bash
# Tables
sqlite3 addresses.db '.tables'

# Recent extractions
sqlite3 addresses.db 'SELECT id, document_id, full_name, postcode, extracted_at FROM extracted_addresses ORDER BY id DESC LIMIT 10;'

# Count totals
sqlite3 addresses.db 'SELECT COUNT(*) FROM extracted_addresses;'

# Search for specific document
sqlite3 addresses.db "SELECT * FROM extracted_addresses WHERE document_id LIKE '%name%';"
```

### Schema

Key tables:
- `extracted_addresses` - Main address data (patient and GP records)
- `address_overrides` - Manual corrections
- `address_exclusions` - Patterns to exclude (hospitals, businesses)
- `gp_practices` - GP practice lookup data

## iCloud Sync

### Checking iCloud Sync Status

```bash
# List documents in iCloud container
ls ~/Library/Mobile\ Documents/iCloud~com~vitygas~Yiana/Documents/

# Check for files still downloading (have .icloud extension)
find ~/Library/Mobile\ Documents/iCloud~com~vitygas~Yiana -name '*.icloud'

# Force download a file
brctl download ~/Library/Mobile\ Documents/iCloud~com~vitygas~Yiana/Documents/FILENAME
```

### Known iCloud Limitations

1. **SQLite databases**: iCloud does whole-file sync - don't store writable SQLite DBs in iCloud
2. **Large files**: May take time to sync, OCR service will retry with "No PDF data found yet"
3. **Conflict resolution**: iCloud may silently choose one version over another with no notification

## Network Issues

### Devon Not Reachable

```bash
# From development machine
ping 192.168.1.137

# If unreachable, try mDNS name
ping Devon-6.local

# Check SSH
ssh devon@Devon-6.local
```

### SSH Permission Denied

```bash
# Check if key is loaded
ssh-add -l

# If empty, add key
ssh-add ~/.ssh/id_ed25519
```

## Useful Commands Reference

```bash
# Full status check
ssh devon@Devon-6.local "\
  echo '=== OCR SERVICE ===' && \
  ps aux | grep yiana-ocr | grep -v grep && \
  echo '' && \
  echo '=== EXTRACTION SERVICE ===' && \
  ps aux | grep extraction_service | grep -v grep && \
  echo '' && \
  echo '=== HEARTBEAT ===' && \
  cat ~/Library/Application\ Support/YianaOCR/health/heartbeat.json && \
  echo '' && \
  echo '=== LAST OCR ERROR ===' && \
  cat ~/Library/Application\ Support/YianaOCR/health/last_error.json && \
  echo '' && \
  echo '=== RECENT OCR LOG ===' && \
  tail -5 ~/Library/Logs/yiana-ocr-error.log && \
  echo '' && \
  echo '=== RECENT EXTRACTION LOG ===' && \
  tail -5 /private/tmp/address_extraction.log"
```

---

**Last Updated**: 2026-02-02
