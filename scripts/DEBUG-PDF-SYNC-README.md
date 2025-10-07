# Debug PDF Auto-Sync Setup

Automatically copy `_Debug-Rendered-Text-Page.pdf` from iCloud to local directory when it changes.

## Quick Start (Recommended: launchd)

This is the most reliable, native macOS solution. It runs automatically in the background.

```bash
# Start automatic sync service
./scripts/setup-debug-pdf-sync.sh start

# Check status
./scripts/setup-debug-pdf-sync.sh status

# View logs
./scripts/setup-debug-pdf-sync.sh logs

# Stop service
./scripts/setup-debug-pdf-sync.sh stop
```

## How It Works

### Method 1: launchd with WatchPaths (RECOMMENDED)
- **Pros**: Native macOS, no dependencies, reliable, automatic on login, lightweight
- **Cons**: None significant
- **Best for**: Production use, set-it-and-forget-it

The launchd service monitors the specific file and runs the sync script whenever it changes.

**Files**:
- `/Users/rose/Library/LaunchAgents/com.vitygas.yiana.debug-pdf-sync.plist` - launchd configuration
- `/Users/rose/Code/Yiana/scripts/sync-debug-pdf.sh` - Copy script
- `/Users/rose/Code/Yiana/scripts/setup-debug-pdf-sync.sh` - Control script
- `/Users/rose/Code/Yiana/temp-debug-files/debug-pdf-sync.log` - Activity log

### Method 2: fswatch (Alternative)
- **Pros**: More flexible for complex scenarios, visible feedback
- **Cons**: Requires Homebrew installation, must run in terminal
- **Best for**: Development/debugging, temporary monitoring

**Setup**:
```bash
# Install fswatch
brew install fswatch

# Or use the setup script
./scripts/setup-debug-pdf-sync.sh install-fswatch

# Run watcher (stays in foreground)
./scripts/watch-debug-pdf-fswatch.sh
```

### Method 3: Manual Sync
For one-time copies:
```bash
./scripts/sync-debug-pdf.sh
```

## Comparison

| Method | Auto-Start | Background | Dependencies | Setup Complexity |
|--------|-----------|------------|--------------|------------------|
| **launchd** | ✅ Yes | ✅ Yes | None | Simple |
| **fswatch** | ❌ No | ❌ No (terminal) | Homebrew | Simple |
| **Manual** | ❌ No | N/A | None | Trivial |

## Management Commands

```bash
# Start sync service (runs on every login)
./scripts/setup-debug-pdf-sync.sh start

# Stop sync service
./scripts/setup-debug-pdf-sync.sh stop

# Restart sync service (useful after editing scripts)
./scripts/setup-debug-pdf-sync.sh restart

# Check if running
./scripts/setup-debug-pdf-sync.sh status

# Watch logs in real-time
./scripts/setup-debug-pdf-sync.sh logs

# Manual sync
./scripts/sync-debug-pdf.sh
```

## Troubleshooting

### Check if launchd service is running
```bash
launchctl list | grep com.vitygas.yiana.debug-pdf-sync
```

### View logs
```bash
# Standard output
cat /Users/rose/Code/Yiana/temp-debug-files/debug-pdf-sync.log

# Errors
cat /Users/rose/Code/Yiana/temp-debug-files/debug-pdf-sync.error.log
```

### Force immediate sync
```bash
launchctl kickstart -k gui/$(id -u)/com.vitygas.yiana.debug-pdf-sync
```

### Service not starting?
1. Check plist syntax: `plutil -lint ~/Library/LaunchAgents/com.vitygas.yiana.debug-pdf-sync.plist`
2. Check script permissions: `ls -l /Users/rose/Code/Yiana/scripts/sync-debug-pdf.sh`
3. Check paths exist: `ls -l "/Users/rose/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/_Debug-Rendered-Text-Page.pdf"`

### File not syncing?
1. Verify source file exists and is being updated
2. Check launchd service status
3. Look for errors in error log
4. Try manual sync to test script: `./scripts/sync-debug-pdf.sh`

## File Paths

- **Source**: `/Users/rose/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/_Debug-Rendered-Text-Page.pdf`
- **Destination**: `/Users/rose/Code/Yiana/temp-debug-files/_Debug-Rendered-Text-Page.pdf`
- **Logs**: `/Users/rose/Code/Yiana/temp-debug-files/debug-pdf-sync.log`

## Uninstall

```bash
# Stop and remove launchd service
./scripts/setup-debug-pdf-sync.sh stop
rm ~/Library/LaunchAgents/com.vitygas.yiana.debug-pdf-sync.plist

# Remove scripts (optional)
rm -rf /Users/rose/Code/Yiana/scripts/sync-debug-pdf.sh
rm -rf /Users/rose/Code/Yiana/scripts/watch-debug-pdf-fswatch.sh
rm -rf /Users/rose/Code/Yiana/scripts/setup-debug-pdf-sync.sh
```

## Technical Details

### launchd Configuration
- **WatchPaths**: Monitors specific file for changes
- **RunAtLoad**: Executes once when service loads (initial sync)
- **KeepAlive**: false (only runs when file changes, not continuously)
- **StandardOutPath/StandardErrorPath**: Captures all output to log files

### Why launchd Over Others?
1. **Native**: Built into macOS, no external dependencies
2. **Reliable**: Apple's standard for background tasks
3. **Efficient**: Only runs when file actually changes
4. **Persistent**: Survives reboots, automatically starts on login
5. **Debuggable**: Built-in logging and management tools

### fswatch vs launchd
- **fswatch**: Better for watching directories, complex patterns, temporary monitoring
- **launchd**: Better for watching specific files, production use, persistent monitoring
