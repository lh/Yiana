# YianaOCRService: LaunchDaemon Setup Guide

## Background

The YianaOCRService watches an iCloud Documents folder for `.yianazip` files and performs OCR processing on them. It was originally configured as a macOS **LaunchAgent**, which requires a user to be logged into a GUI session. After power outages or reboots where no one logs in, the service would not start.

The solution is to run the service as a **LaunchDaemon** instead, which operates at the system level and starts at boot regardless of whether any user is logged in.

## Prerequisites

- macOS server (tested on Mac mini)
- The `yiana-ocr` binary built and placed at `/Users/<username>/bin/yiana-ocr`
- An iCloud container syncing Yiana documents to the server
- SSH access to the server

## Setup Steps

### 1. Build the binary

On your development machine:

```bash
cd YianaOCRService
swift build -c release
```

The binary will be at `.build/arm64-apple-macosx/release/yiana-ocr`.

### 2. Copy the binary to the server

```bash
scp .build/arm64-apple-macosx/release/yiana-ocr <user>@<server>:/Users/<user>/bin/yiana-ocr
ssh <user>@<server> "chmod +x /Users/<user>/bin/yiana-ocr"
```

### 3. Create the LaunchDaemon plist

Create a file called `com.vitygas.yiana-ocr.plist` with the following contents. Adjust the username, paths, and label as needed:

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

    <!-- Run as the user who owns the iCloud container -->
    <key>UserName</key>
    <string>USERNAME</string>

    <key>GroupName</key>
    <string>staff</string>

    <!-- Start at system boot -->
    <key>RunAtLoad</key>
    <true/>

    <!-- Restart if it crashes -->
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

Replace all instances of `USERNAME` with the actual username on the server.

### 4. Install the plist on the server

Copy the plist to the server and install it:

```bash
scp com.vitygas.yiana-ocr.plist <user>@<server>:/tmp/

# SSH into the server, then:
sudo mv /tmp/com.vitygas.yiana-ocr.plist /Library/LaunchDaemons/
sudo chown root:wheel /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
sudo chmod 644 /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
```

### 5. Remove any existing LaunchAgent

If the service was previously running as a LaunchAgent, remove it to prevent duplicate processes:

```bash
# Unload user-level agent (no sudo)
launchctl remove com.vitygas.yiana-ocr 2>/dev/null

# Delete the old plist
rm ~/Library/LaunchAgents/com.vitygas.yiana-ocr.plist 2>/dev/null
```

### 6. Load the daemon

```bash
sudo launchctl load /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
```

### 7. Configure auto-restart after power failure

```bash
sudo pmset -a autorestart 1
```

This tells macOS to automatically boot the Mac after a power outage.

### 8. Verify

```bash
# Check daemon is registered
sudo launchctl list | grep yiana

# Check process is running
ps aux | grep yiana-ocr | grep -v grep

# Check logs
tail -20 ~/Library/Logs/yiana-ocr-error.log
```

Expected `launchctl` output: `<PID>  0  com.vitygas.yiana-ocr` (exit code 0 = healthy).

## LaunchAgent vs LaunchDaemon

| Property | LaunchAgent | LaunchDaemon |
|---|---|---|
| Location | `~/Library/LaunchAgents/` | `/Library/LaunchDaemons/` |
| Starts when | User logs in (GUI session) | System boots |
| Owned by | User | root:wheel |
| Management | `launchctl load/unload` | `sudo launchctl load/unload` |
| Survives reboot without login | No | Yes |
| Survives power outage | No | Yes (with `pmset autorestart`) |

## Common Management Commands

```bash
# Check status
sudo launchctl list | grep yiana
ps aux | grep yiana-ocr | grep -v grep

# View logs
tail -f ~/Library/Logs/yiana-ocr.log
tail -f ~/Library/Logs/yiana-ocr-error.log

# Restart
sudo launchctl unload /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
sudo launchctl load /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist

# Stop
sudo launchctl unload /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist

# Start
sudo launchctl load /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
```

## Troubleshooting

### Service not running after reboot

Check if the daemon is loaded:
```bash
sudo launchctl list | grep yiana
```

If not listed, load it manually. If it fails to load, check the plist syntax:
```bash
plutil -lint /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
```

### Multiple processes running

This can happen if a user-level LaunchAgent is still registered alongside the daemon:
```bash
# Kill all instances
pkill -9 -f 'yiana-ocr'

# Remove any user-level registration
launchctl remove com.vitygas.yiana-ocr

# Reload daemon
sudo launchctl load /Library/LaunchDaemons/com.vitygas.yiana-ocr.plist
```

### Health monitor reports stale heartbeat

The service writes a heartbeat file to `~/Library/Application Support/YianaOCR/health/heartbeat.json`. Check its contents:
```bash
cat ~/Library/Application\ Support/YianaOCR/health/heartbeat.json
```

If the timestamp is old but the process is running, the service may be stuck on a specific document. Check the error log and consider restarting.

### "File exists" errors in log

These are non-critical and occur when the OCR results directory already exists. They can be safely ignored.
