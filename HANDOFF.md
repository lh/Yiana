# Session Handoff — 2026-02-27

## What was completed

### Unified Devon Server Monitoring
The extraction service had no health monitoring — it crash-looped 15,847 times with zero alerting. Now both OCR and Extraction have matching infrastructure.

#### 1. Extraction service heartbeat (`AddressExtractor/extraction_service.py`)
- Added `HEALTH_DIR` constant: `~/Library/Application Support/YianaExtraction/health/`
- Added `write_heartbeat(note)` and `write_health_error(msg)` — atomic JSON writes matching OCR's `HealthMonitor.swift` pattern
- `watch_directory()`: writes heartbeat every 60s (tick counter), plus on startup with `note: "start"`
- `process_file()` except block: calls `write_health_error(str(e))`

#### 2. Unified watchdog (`scripts/yiana-watchdog.sh`)
- Replaces `YianaOCRService/scripts/ocr_watchdog_pushover.sh` — single script checks both services
- Parameterized `check_service()` function with per-service dedup via prefixed alert keys (`OCR_stale`, `Extraction_no_heartbeat`)
- Same Pushover API integration, 1-hour cooldown, title "Yiana Server Alert"
- Exit 1 if any service unhealthy

#### 3. Extraction log rotation (`scripts/yiana-extraction.newsyslog.conf`)
- Matches OCR config: 10MB max, 3 rotated copies, bzip2 (`J`), no signal (`N`)
- Covers `yiana-extraction.log` and `yiana-extraction-error.log`

#### 4. Terminal dashboard (`scripts/yiana-status.sh`)
- ANSI colors + box-drawing, shows per-service: UP/DOWN, PID, heartbeat age (color-coded), last error (truncated), log sizes
- Data stats: document count, OCR results, addresses extracted
- Disk usage summary
- Pure bash, tested locally

## Deployment steps (on Devon)

```bash
# 1. Pull code
cd ~/Code/Yiana && git pull

# 2. Restart extraction service (picks up heartbeat code)
launchctl unload ~/Library/LaunchAgents/com.vitygas.yiana-extraction.plist
launchctl load ~/Library/LaunchAgents/com.vitygas.yiana-extraction.plist

# 3. Verify heartbeat appears (wait ~60s)
cat ~/Library/Application\ Support/YianaExtraction/health/heartbeat.json

# 4. Install log rotation
sudo cp ~/Code/Yiana/scripts/yiana-extraction.newsyslog.conf /etc/newsyslog.d/
sudo newsyslog -nv -f /etc/newsyslog.d/yiana-extraction.newsyslog.conf

# 5. Deploy scripts
cp ~/Code/Yiana/scripts/yiana-watchdog.sh ~/
cp ~/Code/Yiana/scripts/yiana-status.sh ~/

# 6. Update crontab (replace old ocr_watchdog_pushover.sh with yiana-watchdog.sh)
crontab -e
# */5 * * * * ~/yiana-watchdog.sh >> ~/Library/Logs/yiana-watchdog.log 2>&1

# 7. Optional: auto-display on login
echo '~/yiana-status.sh' >> ~/.zshrc

# 8. Test
~/yiana-watchdog.sh
~/yiana-status.sh
```

## Verification checklist
- [ ] Heartbeat JSON exists in `~/Library/Application Support/YianaExtraction/health/`
- [ ] `~/yiana-watchdog.sh` prints OK for both services, exits 0
- [ ] `~/yiana-status.sh` renders both services green
- [ ] Stop extraction, wait >10min, watchdog sends Pushover alert for extraction only

## Files changed
- `AddressExtractor/extraction_service.py` — heartbeat + health error helpers, integrated into watch loop and error handler
- `scripts/yiana-watchdog.sh` — **new** unified watchdog
- `scripts/yiana-extraction.newsyslog.conf` — **new** log rotation config
- `scripts/yiana-status.sh` — **new** terminal dashboard

## What's next
- Search behaviour in sidebar layout (scope to current folder vs global)
- Sidebar width persistence
- Empty sidebar state polish

## Known issues
- Old `ocr_watchdog_pushover.sh` still exists in `YianaOCRService/scripts/` — can be removed after confirming unified watchdog works on Devon
- Existing scans created before 2026-02-22 still have the old 24pt border baked into their PDF data
