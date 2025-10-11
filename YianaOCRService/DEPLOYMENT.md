# YianaOCRService Deployment Guide

This guide explains how to deploy the YianaOCRService to a Mac that will run the OCR processing service. This can be:
- A dedicated Mac mini or Mac Studio (recommended for 24/7 operation)
- Your main Mac (OCR only runs when machine is on and connected)

---

## Prerequisites

### Development Machine (where you build)
- Xcode with Swift 5.9+ installed
- YianaOCRService source code
- SSH access to target machine

### Target Machine (where service runs)
- macOS 13.0 or later
- Remote Login enabled (System Settings → General → Sharing → Remote Login)
- iCloud Drive enabled with Yiana documents syncing
- Sufficient disk space for temporary OCR files

---

## Part 1: Initial Setup

### 1.1 Enable Remote Login on Target Machine

On the target Mac:

1. Open **System Settings**
2. Go to **General → Sharing**
3. Enable **Remote Login**
4. Note the SSH command shown (e.g., `ssh username@hostname.local`)
5. Allow access for the user who will run the service

**Important**: Note the following from the SSH command:
- **Username**: The part before `@`
- **Hostname**: The full hostname or IP address

### 1.2 Set Up SSH Key Authentication

On your development machine:

```bash
# Add your SSH key to ssh-agent
ssh-add ~/.ssh/id_ed25519

# If you don't have an SSH key, create one first:
# ssh-keygen -t ed25519 -C "your_email@example.com"
```

Copy your public key to the target machine:

```bash
ssh-copy-id username@hostname
```

Or manually:
1. Get your public key: `cat ~/.ssh/id_ed25519.pub`
2. On target machine, add it to `~/.ssh/authorized_keys`

Verify SSH access works:
```bash
ssh username@hostname
```

You should connect without entering a password (only SSH key passphrase via ssh-agent).

---

## Part 2: Determine Installation Paths

### 2.1 Find Your iCloud Documents Path

On the target machine, run:

```bash
ls -la ~/Library/Mobile\ Documents/ | grep -i yiana
```

The full path will be something like:
```
~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents
```

### 2.2 Choose Binary Installation Location

Recommended locations:
- `~/bin/yiana-ocr` (user-specific, no sudo needed)
- `/usr/local/bin/yiana-ocr` (system-wide, requires sudo)

For this guide, we'll use `~/bin/yiana-ocr`.

On target machine:
```bash
mkdir -p ~/bin
```

---

## Part 3: Create Deployment Script

On your development machine, create `deploy.sh` in the YianaOCRService directory:

```bash
#!/bin/bash

# YianaOCRService Deployment Script
# Customize these variables for your setup

set -e  # Exit on error

# TARGET CONFIGURATION - CUSTOMIZE THESE
TARGET_HOST="hostname.local"      # Or IP address like "192.168.1.100"
TARGET_USER="username"             # SSH username
TARGET_BIN_PATH="~/bin/yiana-ocr"  # Where to install the binary

# Build configuration
BUILD_DIR=".build/arm64-apple-macosx/release"
BINARY_NAME="yiana-ocr"

echo "🔨 Building YianaOCRService in release mode..."
swift build -c release

echo ""
echo "📦 Binary built: ${BUILD_DIR}/${BINARY_NAME}"
ls -lh "${BUILD_DIR}/${BINARY_NAME}"

echo ""
echo "🚀 Deploying to ${TARGET_HOST}..."
echo "   Target: ${TARGET_USER}@${TARGET_HOST}:${TARGET_BIN_PATH}"

# Stop any running service
echo ""
echo "🛑 Stopping service if running..."
ssh "${TARGET_USER}@${TARGET_HOST}" "launchctl unload ~/Library/LaunchAgents/com.vitygas.yiana-ocr.plist 2>/dev/null || true"

# Backup existing binary
echo ""
echo "💾 Backing up existing binary..."
ssh "${TARGET_USER}@${TARGET_HOST}" "if [ -f ${TARGET_BIN_PATH} ]; then cp ${TARGET_BIN_PATH} ${TARGET_BIN_PATH}.backup.\$(date +%Y%m%d-%H%M%S); fi"

# Copy new binary
echo ""
echo "📤 Copying new binary..."
scp "${BUILD_DIR}/${BINARY_NAME}" "${TARGET_USER}@${TARGET_HOST}:${TARGET_BIN_PATH}"

# Set executable permissions
echo ""
echo "🔐 Setting executable permissions..."
ssh "${TARGET_USER}@${TARGET_HOST}" "chmod +x ${TARGET_BIN_PATH}"

# Verify deployment
echo ""
echo "✅ Verifying deployment..."
ssh "${TARGET_USER}@${TARGET_HOST}" "ls -lh ${TARGET_BIN_PATH} && ${TARGET_BIN_PATH} --version"

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Create LaunchAgent plist (see Part 4)"
echo "2. Load the LaunchAgent to start the service"
```

Make it executable:
```bash
chmod +x deploy.sh
```

---

## Part 4: Create LaunchAgent

### 4.1 Get Your iCloud Documents Path

On target machine:
```bash
echo ~/Library/Mobile\ Documents/iCloud~com~vitygas~Yiana/Documents
```

Copy this full path.

### 4.2 Create LaunchAgent Plist

On your development machine, create `com.vitygas.yiana-ocr.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
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
    </dict>
</dict>
</plist>
```

**Important**: Replace `USERNAME` with your actual username on the target machine.

### 4.3 Deploy LaunchAgent

Copy the plist to target machine:

```bash
scp com.vitygas.yiana-ocr.plist username@hostname:~/Library/LaunchAgents/
```

Load the LaunchAgent:

```bash
ssh username@hostname "launchctl load ~/Library/LaunchAgents/com.vitygas.yiana-ocr.plist"
```

---

## Part 5: Verify Deployment

### 5.1 Check Service Status

```bash
ssh username@hostname "launchctl list | grep yiana"
```

Expected output: `PID	0	com.vitygas.yiana-ocr` (PID will be a number, exit code should be 0)

### 5.2 Check Process is Running

```bash
ssh username@hostname "ps aux | grep yiana-ocr | grep -v grep"
```

Should show the running process.

### 5.3 View Logs

```bash
# Standard output
ssh username@hostname "tail -f ~/Library/Logs/yiana-ocr.log"

# Errors
ssh username@hostname "tail -f ~/Library/Logs/yiana-ocr-error.log"
```

---

## Part 6: Testing OCR Processing

### 6.1 Create Test Document

On your iOS/iPad device or Mac running Yiana:

1. Create a new document by scanning a page with text
2. Wait for it to sync to iCloud
3. Check the document metadata - it should have `ocrCompleted: false`

### 6.2 Monitor Processing

On your development machine:

```bash
ssh username@hostname "tail -f ~/Library/Logs/yiana-ocr.log"
```

You should see:
- Document detected
- OCR processing started
- OCR completed
- Results saved

### 6.3 Verify Results

The OCR service creates a `.ocr_results` directory next to your documents with JSON/XML/hOCR output.

---

## Common Tasks

### Update to New Version

```bash
cd /path/to/YianaOCRService
./deploy.sh
```

The script automatically:
- Stops the service
- Backs up the old binary
- Deploys the new version
- Restarts the service (you need to load LaunchAgent again)

### Restart Service

```bash
ssh username@hostname "launchctl unload ~/Library/LaunchAgents/com.vitygas.yiana-ocr.plist && launchctl load ~/Library/LaunchAgents/com.vitygas.yiana-ocr.plist"
```

### Stop Service

```bash
ssh username@hostname "launchctl unload ~/Library/LaunchAgents/com.vitygas.yiana-ocr.plist"
```

### Start Service

```bash
ssh username@hostname "launchctl load ~/Library/LaunchAgents/com.vitygas.yiana-ocr.plist"
```

### View Logs in Real-Time

```bash
# Standard output
ssh username@hostname "tail -f ~/Library/Logs/yiana-ocr.log"

# Errors only
ssh username@hostname "tail -f ~/Library/Logs/yiana-ocr-error.log"
```

### Restore Previous Version

```bash
# List backups
ssh username@hostname "ls -lt ~/bin/yiana-ocr.backup.*"

# Restore most recent backup
ssh username@hostname "cp ~/bin/yiana-ocr.backup.TIMESTAMP ~/bin/yiana-ocr"

# Restart service
ssh username@hostname "launchctl unload ~/Library/LaunchAgents/com.vitygas.yiana-ocr.plist && launchctl load ~/Library/LaunchAgents/com.vitygas.yiana-ocr.plist"
```

---

## Troubleshooting

### Service Won't Start

1. Check error log:
   ```bash
   ssh username@hostname "cat ~/Library/Logs/yiana-ocr-error.log"
   ```

2. Common issues:
   - **Wrong path syntax**: Make sure paths use `--path` flag
   - **Permissions**: Binary must be executable (`chmod +x`)
   - **iCloud not syncing**: Verify iCloud Drive is enabled

### SSH Connection Issues

1. Verify Remote Login is enabled on target
2. Check ssh-agent has your key: `ssh-add -l`
3. Try manual connection: `ssh username@hostname`

### Documents Not Processing

1. Verify service is watching correct path:
   ```bash
   ssh username@hostname "ps aux | grep yiana-ocr"
   ```

2. Check document has `ocrCompleted: false`
3. Verify iCloud sync is working
4. Check logs for errors

### LaunchAgent Exit Code Not 0

```bash
ssh username@hostname "launchctl list | grep yiana"
```

If exit code is not 0:
1. Check error log
2. Unload and reload LaunchAgent
3. Verify plist syntax is correct
4. Ensure all paths in plist exist

---

## Single Mac Setup (No Dedicated Server)

If you're running on your main Mac instead of a dedicated server:

1. Follow all steps above, but use `localhost` or `127.0.0.1` as the hostname
2. The service will only run when your Mac is on and you're logged in
3. iCloud sync must be active
4. Consider energy saver settings - prevent sleep if you want continuous OCR

**Pros**:
- No additional hardware needed
- Simple setup

**Cons**:
- OCR only works when Mac is on
- May impact performance during heavy OCR tasks
- Documents won't be processed when Mac is sleeping

---

## Security Considerations

1. **SSH Keys**: Never commit private keys to git
2. **Firewall**: Ensure target machine's firewall allows SSH
3. **User Permissions**: Run service as non-admin user when possible
4. **Network**: Use VPN if accessing remotely over internet
5. **Logs**: Contain document paths - keep private

---

## Performance Notes

### Recommended Hardware (Dedicated Server)
- Mac mini M1/M2 or better
- 8GB+ RAM
- Fast SSD for temp files
- Reliable network connection to iCloud

### Expected Processing Times
- Simple document (1-5 pages): 5-30 seconds
- Medium document (10-20 pages): 1-3 minutes
- Large document (50+ pages): 5-15 minutes

### Monitoring Performance
```bash
# CPU and memory usage
ssh username@hostname "top -l 1 | grep yiana-ocr"

# Disk usage for OCR results
ssh username@hostname "du -sh ~/Library/Mobile\ Documents/iCloud~com~vitygas~Yiana/Documents/.ocr_results"
```

---

## Files Reference

### On Development Machine
- `deploy.sh` - Deployment script
- `com.vitygas.yiana-ocr.plist` - LaunchAgent configuration
- `.build/arm64-apple-macosx/release/yiana-ocr` - Built binary

### On Target Machine
- `~/bin/yiana-ocr` - Service binary
- `~/bin/yiana-ocr.backup.*` - Backup binaries
- `~/Library/LaunchAgents/com.vitygas.yiana-ocr.plist` - LaunchAgent
- `~/Library/Logs/yiana-ocr.log` - Standard output
- `~/Library/Logs/yiana-ocr-error.log` - Error output
- `~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/` - Watched directory
- `.ocr_results/` - OCR output directory

---

## Quick Start Checklist

- [ ] Remote Login enabled on target Mac
- [ ] SSH key authentication configured
- [ ] Noted username and hostname
- [ ] Identified iCloud documents path
- [ ] Created and customized `deploy.sh`
- [ ] Created and customized `com.vitygas.yiana-ocr.plist`
- [ ] Ran `./deploy.sh` successfully
- [ ] Copied LaunchAgent plist to target
- [ ] Loaded LaunchAgent
- [ ] Verified service is running
- [ ] Tested with sample document
- [ ] Confirmed OCR results generated

---

**Version**: 1.0.0
**Last Updated**: 2025-10-11
**Minimum macOS**: 13.0
**Swift Version**: 5.9+
