# Yiana OCR Server Setup Guide

Complete guide to setting up and running YianaOCRService on a macOS server. This covers both the Swift OCR service and the Python extraction service.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Server Preparation](#2-server-preparation)
3. [Build and Install](#3-build-and-install)
4. [LaunchDaemon Configuration](#4-launchdaemon-configuration)
5. [Log Management](#5-log-management)
6. [Health Monitoring](#6-health-monitoring)
7. [Extraction Service (Optional)](#7-extraction-service-optional)
8. [Deployment Workflow](#8-deployment-workflow)
9. [Troubleshooting](#9-troubleshooting)
10. [Quick Reference](#10-quick-reference)
11. [Personal Parameters](#11-personal-parameters)

---

## 1. Prerequisites

### Hardware
- Mac mini, Mac Studio, or any always-on Mac (Apple Silicon recommended)
- 8GB+ RAM
- Fast SSD with sufficient space for documents and temporary OCR files
- Reliable network connection

### Software
- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools or full Xcode with Swift 5.9+
- iCloud Drive enabled and syncing the Yiana container

### Development Machine
- Swift 5.9+ (for building the binary)
- SSH access to the server
- Source code for YianaOCRService

---

## 2. Server Preparation

### 2.1 Enable Remote Login

On the server:

1. Open **System Settings > General > Sharing**
2. Enable **Remote Login**
3. Note the SSH command shown (username and hostname)

### 2.2 SSH Key Authentication

On your development machine:

```bash
# Generate a key if you don't have one
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy it to the server
ssh-copy-id <USER>@<HOST>

# Verify passwordless login
ssh <USER>@<HOST>
```

### 2.3 Create Directories

On the server:

```bash
mkdir -p ~/bin
mkdir -p ~/Library/Logs
```

### 2.4 Verify iCloud Documents Path

```bash
ls ~/Library/Mobile\ Documents/iCloud~com~vitygas~Yiana/Documents/
```

If this path doesn't exist, ensure iCloud Drive is enabled and the Yiana app has synced at least one document.

### 2.5 Auto-Restart After Power Failure

```bash
sudo pmset -a autorestart 1
```

This tells macOS to boot automatically after a power outage.

---

## 3. Build and Install

### 3.1 Build the Binary

On your development machine:

```bash
cd YianaOCRService
swift build -c release
```

Binary location: `.build/arm64-apple-macosx/release/yiana-ocr`

### 3.2 Copy to Server

```bash
scp .build/arm64-apple-macosx/release/yiana-ocr <USER>@<HOST>:~/bin/yiana-ocr
ssh <USER>@<HOST> "chmod +x ~/bin/yiana-ocr"
```

### 3.3 Verify

```bash
ssh <USER>@<HOST> "~/bin/yiana-ocr --version"
```

---

## 4. LaunchDaemon Configuration

The OCR service runs as a **LaunchDaemon** (system-level), not a LaunchAgent. This means it starts at boot without requiring a user login, and survives power outages (with `pmset autorestart`).

| Property | LaunchAgent | LaunchDaemon |
|---|---|---|
| Location | `~/Library/LaunchAgents/` | `/Library/LaunchDaemons/` |
| Starts when | User logs in (GUI session) | System boots |
| Owned by | User | root:wheel |
| Management | `launchctl load/unload` | `sudo launchctl load/unload` |
| Survives reboot without login | No | **Yes** |

### 4.1 Create the Plist

Create `com.vitygas.yiana-ocr.plist` with the following content. Replace every `USERNAME` with the actual username on the server:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.vitygas.yiana-ocr</string>

    <key>ProgramArguments</key>
    <array>
        <string>/Users/USERNAME/bin/yiana-ocr</string>
        <string>watch</string>
        <string>--path</string>
        <string>/Users/USERNAME/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents</string>
    </array>

    <key>UserName</key>
    <string>USERNAME</string>

    <key>GroupName</key>
    <string>staff</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/Users/USERNAME/Library/Logs/yiana-ocr.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/USERNAME/Library/Logs/yiana-ocr-error.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>/Users/USERNAME</string>
    </dict>

    <key>WorkingDirectory</key>
    <string>/Users/USERNAME</string>
</dict>
</plist>
```

### 4.2 Install on Server

```bash
# Copy to server
scp com.vitygas.yiana-ocr.plist <USER>@<HOST>:/tmp/

# SSH in and install (requires sudo)
ssh <USER>@<HOST>
sudo mv /tmp/com.vitygas.yiana-ocr.plist /Library/LaunchDaemons/
sudo chown root:wheel /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
sudo chmod 644 /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
sudo launchctl load /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
```

### 4.3 Remove Any Old LaunchAgent

If the service was previously running as a LaunchAgent, remove it to prevent duplicate processes:

```bash
launchctl remove com.vitygas.yiana-ocr 2>/dev/null
rm ~/Library/LaunchAgents/com.vitygas.yiana-ocr.plist 2>/dev/null
```

### 4.4 Verify

```bash
sudo launchctl list | grep yiana
ps aux | grep yiana-ocr | grep -v grep
```

Expected launchctl output: `<PID>  0  com.vitygas.yiana-ocr` (exit code 0 = healthy).

### 4.5 Log Level

The default log level is `notice`. To increase verbosity for debugging, add `--log-level` to the `ProgramArguments` array in the plist:

```xml
<string>--log-level</string>
<string>info</string>
```

Available levels: `trace`, `debug`, `info`, `notice` (default), `warning`, `error`, `critical`.

**Important:** Do not leave `info` or lower in production. At `info` level, the error log grows by thousands of lines per scan cycle (with ~3000 documents, this can reach 14GB+ over days).

---

## 5. Log Management

### 5.1 Log Files

| File | Contents | Notes |
|---|---|---|
| `~/Library/Logs/yiana-ocr-error.log` | All `notice`+ log output (main log) | swift-log writes to stderr by default |
| `~/Library/Logs/yiana-ocr.log` | stdout (mostly empty) | Only receives `print()` output, not logger output |

### 5.2 Log Rotation with newsyslog

Without rotation, logs grow without limit. macOS includes `newsyslog` for automatic rotation.

Create `/etc/newsyslog.d/yiana-ocr.conf` (requires sudo):

```
# Yiana OCR service log rotation
# logfilename                                                    [owner:group]  mode count size  when flags
/Users/USERNAME/Library/Logs/yiana-ocr-error.log                 USERNAME:staff  644  3     10240 *    JN
/Users/USERNAME/Library/Logs/yiana-ocr.log                       USERNAME:staff  644  3     10240 *    JN
```

Replace `USERNAME` with the server username.

**Flags explained:**
- `J` = compress rotated files with bzip2
- `N` = no signal to process (safe — process keeps writing to old fd until next restart, when launchd opens the new file)
- `3` = keep 3 rotated copies
- `10240` = rotate when file exceeds 10MB

**Install:**

```bash
sudo tee /etc/newsyslog.d/yiana-ocr.conf << 'EOF'
# Yiana OCR service log rotation
# logfilename                                                    [owner:group]  mode count size  when flags
/Users/USERNAME/Library/Logs/yiana-ocr-error.log                 USERNAME:staff  644  3     10240 *    JN
/Users/USERNAME/Library/Logs/yiana-ocr.log                       USERNAME:staff  644  3     10240 *    JN
EOF
```

**Verify:**

```bash
sudo newsyslog -nv -f /etc/newsyslog.d/yiana-ocr.conf
```

**Manual rotation:**

```bash
sudo newsyslog -v -f /etc/newsyslog.d/yiana-ocr.conf
```

### 5.3 How Rotation Interacts with launchd

newsyslog renames the log file and creates a new empty one. The running process still holds a file descriptor to the old (renamed) file and continues writing there. On next service restart (deploy, crash, reboot), launchd opens the new file. This means a rotated file may grow slightly between rotation and the next restart — this is normal and expected. Subsequent rotation cycles clean up old files.

---

## 6. Health Monitoring

The OCR service writes health data independently of the log files:

- `~/Library/Application Support/YianaOCR/health/heartbeat.json` — updated on start and after each scan cycle
- `~/Library/Application Support/YianaOCR/health/last_error.json` — overwritten when a processing error occurs

### 6.1 Basic Watchdog (macOS Notifications)

The script `scripts/ocr_watchdog.sh` checks heartbeat freshness and alerts via macOS notifications:

```bash
# Manual check
./scripts/ocr_watchdog.sh --max-age-seconds 300

# Output: "OK - heartbeat age 45s" or an alert
```

### 6.2 Pushover Notifications (Recommended for Headless Servers)

For servers without a display, use `scripts/ocr_watchdog_pushover.sh` to send push notifications to your phone.

**Setup:**

1. Sign up at https://pushover.net/ and install the app on your phone
2. Get your **User Key** and create an **API Token** (name it "Yiana OCR")
3. Deploy to the server:

```bash
scp scripts/ocr_watchdog_pushover.sh <USER>@<HOST>:~/ocr_watchdog.sh
ssh <USER>@<HOST> "chmod +x ~/ocr_watchdog.sh"
```

4. Add credentials to the server's shell profile (`~/.zshrc` or `~/.bash_profile`):

```bash
export PUSHOVER_USER="your-user-key"
export PUSHOVER_TOKEN="your-api-token"
```

5. Set up a cron job (every 5 minutes):

```bash
crontab -e

# Add:
PUSHOVER_USER=your-user-key
PUSHOVER_TOKEN=your-api-token
*/5 * * * * $HOME/ocr_watchdog.sh --max-age-seconds 600 >> $HOME/ocr_watchdog.log 2>&1
```

**Alert levels:**
- Normal operation: no notifications
- Recent error: normal-priority push
- Stale heartbeat / service down: high-priority push (bypasses quiet hours)

---

## 7. Extraction Service (Optional)

The extraction service is a Python process that watches OCR results and extracts structured data (addresses, demographics). It runs as a LaunchAgent (user-level).

### 7.1 Setup

```bash
cd AddressExtractor
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 7.2 LaunchAgent

Copy `AddressExtractor/com.vitygas.yiana-extraction.plist` to `~/Library/LaunchAgents/` on the server and load it:

```bash
launchctl load ~/Library/LaunchAgents/com.vitygas.yiana-extraction.plist
```

### 7.3 Logs

- `~/Library/Logs/yiana-extraction.log` — stdout
- `~/Library/Logs/yiana-extraction-error.log` — stderr

### 7.4 Known Limitation: SQLite and iCloud

SQLite databases in iCloud-synced directories can lose data because iCloud does whole-file sync. The extraction service also writes JSON output to a local (non-iCloud) directory as a reliable fallback.

---

## 8. Deployment Workflow

### 8.1 Automated Deployment

A deployment script automates build, stop, copy, restart:

```bash
cd YianaOCRService
./deploy.sh
```

**What it does:**
1. Builds the binary in release mode
2. Stops any running yiana-ocr process on the server
3. Backs up the existing binary with a timestamp
4. Copies the new binary
5. Sets executable permissions
6. Lets launchd restart the service (KeepAlive=true)
7. Verifies the new process is running

### 8.2 Manual Deployment

If the script fails:

```bash
# 1. Build
cd YianaOCRService && swift build -c release

# 2. Stop service (on server, requires sudo for LaunchDaemon)
ssh <USER>@<HOST> "pkill -x yiana-ocr || true"
sleep 2
ssh <USER>@<HOST> "pkill -x yiana-ocr || true"

# 3. Backup
ssh <USER>@<HOST> "cp ~/bin/yiana-ocr ~/bin/yiana-ocr.backup.$(date +%Y%m%d-%H%M%S)"

# 4. Copy
scp .build/arm64-apple-macosx/release/yiana-ocr <USER>@<HOST>:~/bin/yiana-ocr

# 5. Set permissions and let launchd restart
ssh <USER>@<HOST> "chmod +x ~/bin/yiana-ocr"
ssh <USER>@<HOST> "pkill -x yiana-ocr || true"
sleep 3

# 6. Verify
ssh <USER>@<HOST> "pgrep -lf yiana-ocr"
```

### 8.3 Rollback

```bash
# List backups
ssh <USER>@<HOST> "ls -lt ~/bin/yiana-ocr.backup.*"

# Restore most recent
ssh <USER>@<HOST> 'cp $(ls -t ~/bin/yiana-ocr.backup.* | head -1) ~/bin/yiana-ocr'

# Restart
ssh <USER>@<HOST> "pkill -x yiana-ocr || true"
```

---

## 9. Troubleshooting

### Service Won't Start

```bash
# Is the daemon loaded?
sudo launchctl list | grep yiana

# If not, load it
sudo launchctl load /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist

# Check plist syntax
plutil -lint /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist

# Check error log
cat ~/Library/Logs/yiana-ocr-error.log
```

### Multiple Processes Running

Can happen if a LaunchAgent registration lingers alongside the LaunchDaemon:

```bash
pkill -9 -f 'yiana-ocr'
launchctl remove com.vitygas.yiana-ocr 2>/dev/null
sudo launchctl load /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
ps aux | grep yiana-ocr | grep -v grep
```

### Documents Not Being Processed

1. Verify service is running: `ps aux | grep yiana-ocr | grep -v grep`
2. Check it's watching the correct path (visible in process args)
3. Check for iCloud placeholder files (`.icloud` extension means not downloaded yet):
   ```bash
   find ~/Library/Mobile\ Documents/iCloud~com~vitygas~Yiana -name '*.icloud'
   ```
4. Force download: `brctl download <path-to-file>`
5. Check error log for processing failures

### Stale Heartbeat

The heartbeat updates during active scans. If stale:

```bash
cat ~/Library/Application\ Support/YianaOCR/health/heartbeat.json
cat ~/Library/Application\ Support/YianaOCR/health/last_error.json
```

Possible causes:
- Service is stuck processing a large file (check error log)
- Service crashed (check `ps aux`)
- No new documents to process (heartbeat only updates during scans)

### Log File Growing Too Large

If the error log grows unexpectedly:

```bash
# Check current size
ls -lh ~/Library/Logs/yiana-ocr-error.log

# Truncate in place (safe while process is running)
> ~/Library/Logs/yiana-ocr-error.log

# Verify newsyslog is configured
sudo newsyslog -nv -f /etc/newsyslog.d/yiana-ocr.conf
```

If the log is filling with info-level messages, ensure the `--log-level` is not set below `notice` in the LaunchDaemon plist.

### Daemon Exit Code Not 0

```bash
sudo launchctl list | grep yiana
# Output: <PID>  <EXIT_CODE>  com.vitygas.yiana-ocr
```

If the exit code is non-zero, check the error log and reload:

```bash
sudo launchctl unload /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
sudo launchctl load /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
```

### Non-Critical Warnings (Safe to Ignore)

- **"File exists" errors** — OCR results directory already exists
- **CoreText font warnings** — System font references in PDFs, doesn't affect OCR quality

---

## 10. Quick Reference

### Service Management (requires sudo)

```bash
# Status
sudo launchctl list | grep yiana
ps aux | grep yiana-ocr | grep -v grep

# Restart
sudo launchctl unload /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
sudo launchctl load /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist

# Stop
sudo launchctl unload /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist

# Start
sudo launchctl load /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
```

### Logs

```bash
# Live error log
tail -f ~/Library/Logs/yiana-ocr-error.log

# Health check
cat ~/Library/Application\ Support/YianaOCR/health/heartbeat.json
cat ~/Library/Application\ Support/YianaOCR/health/last_error.json

# Manual log rotation
sudo newsyslog -v -f /etc/newsyslog.d/yiana-ocr.conf
```

### Files on Server

| Path | Purpose |
|---|---|
| `~/bin/yiana-ocr` | Service binary |
| `~/bin/yiana-ocr.backup.*` | Timestamped backups |
| `/Library/LaunchDaemons/com.vitygas.yiana-ocr.plist` | LaunchDaemon config (owned by root) |
| `/etc/newsyslog.d/yiana-ocr.conf` | Log rotation config (owned by root) |
| `~/Library/Logs/yiana-ocr-error.log` | Main log (stderr) |
| `~/Library/Logs/yiana-ocr.log` | stdout log (mostly empty) |
| `~/Library/Application Support/YianaOCR/health/` | Heartbeat and error files |
| `~/Library/Application Support/YianaOCR/processed.json` | Tracking file for processed documents |
| `~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/` | Watched documents directory |
| `<Documents>/.ocr_results/` | OCR output (JSON/XML/hOCR) |

### Setup Checklist

- [ ] Remote Login enabled on server
- [ ] SSH key authentication configured
- [ ] `~/bin` directory created
- [ ] iCloud documents path verified
- [ ] `pmset autorestart` enabled
- [ ] Binary built and copied
- [ ] LaunchDaemon plist installed (root:wheel, 644)
- [ ] Old LaunchAgent removed (if migrating)
- [ ] Service running and verified
- [ ] newsyslog log rotation configured
- [ ] Pushover monitoring set up (optional)
- [ ] Test document processed successfully

---

## 11. Personal Parameters

This section records instance-specific values. Replace placeholders in the guide above with these values for your deployment.

```
SERVER_HOST=<your server IP or hostname>
SERVER_USER=<your server username>
DOCUMENTS_PATH=/Users/<SERVER_USER>/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents
BINARY_PATH=/Users/<SERVER_USER>/bin/yiana-ocr
```

---

**Last Updated**: 2026-02-08
**YianaOCRService Version**: 1.0.0
**Minimum macOS**: 13.0
**Swift Version**: 5.9+
