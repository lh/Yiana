#!/bin/bash

# Setup script for debug PDF sync
# Provides commands to start/stop the sync service

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.vitygas.yiana.debug-pdf-sync.plist"
LAUNCHD_LABEL="com.vitygas.yiana.debug-pdf-sync"

show_status() {
    echo "=== Debug PDF Sync Status ==="
    if launchctl list | grep -q "$LAUNCHD_LABEL"; then
        echo "Status: RUNNING"
        echo ""
        echo "Recent activity:"
        tail -10 "/Users/rose/Code/Yiana/temp-debug-files/debug-pdf-sync.log" 2>/dev/null || echo "No logs yet"
    else
        echo "Status: STOPPED"
    fi
}

case "$1" in
    start)
        echo "Starting debug PDF sync service..."
        launchctl load "$LAUNCHD_PLIST"
        echo "Service started. Run '$0 status' to check status."
        ;;

    stop)
        echo "Stopping debug PDF sync service..."
        launchctl unload "$LAUNCHD_PLIST"
        echo "Service stopped."
        ;;

    restart)
        echo "Restarting debug PDF sync service..."
        launchctl unload "$LAUNCHD_PLIST" 2>/dev/null
        launchctl load "$LAUNCHD_PLIST"
        echo "Service restarted."
        ;;

    status)
        show_status
        ;;

    logs)
        echo "=== Debug PDF Sync Logs ==="
        echo "Press Ctrl+C to stop watching"
        tail -f "/Users/rose/Code/Yiana/temp-debug-files/debug-pdf-sync.log"
        ;;

    install-fswatch)
        echo "Installing fswatch via Homebrew..."
        brew install fswatch
        echo "fswatch installed. You can now use watch-debug-pdf-fswatch.sh"
        ;;

    *)
        echo "Debug PDF Sync Manager"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|install-fswatch}"
        echo ""
        echo "Commands:"
        echo "  start           - Start the launchd service (automatic sync)"
        echo "  stop            - Stop the launchd service"
        echo "  restart         - Restart the launchd service"
        echo "  status          - Show current status"
        echo "  logs            - Watch sync logs in real-time"
        echo "  install-fswatch - Install fswatch for alternative method"
        echo ""
        echo "Alternative methods:"
        echo "  Manual sync:    $SCRIPT_DIR/sync-debug-pdf.sh"
        echo "  fswatch method: $SCRIPT_DIR/watch-debug-pdf-fswatch.sh"
        exit 1
        ;;
esac
