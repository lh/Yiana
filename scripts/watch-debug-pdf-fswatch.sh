#!/bin/bash

# Watch Debug PDF with fswatch
# Monitors the iCloud debug PDF and copies it when it changes

SOURCE_DIR="/Users/rose/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents"
SOURCE_FILE="_Debug-Rendered-Text-Page.pdf"
DEST="/Users/rose/Code/Yiana/temp-debug-files/_Debug-Rendered-Text-Page.pdf"
SYNC_SCRIPT="/Users/rose/Code/Yiana/scripts/sync-debug-pdf.sh"

# Check if fswatch is installed
if ! command -v fswatch &> /dev/null; then
    echo "ERROR: fswatch is not installed"
    echo "Install with: brew install fswatch"
    exit 1
fi

# Ensure destination directory exists
mkdir -p "$(dirname "$DEST")"

echo "Starting watch on: $SOURCE_DIR/$SOURCE_FILE"
echo "Destination: $DEST"
echo "Press Ctrl+C to stop"
echo ""

# Initial sync
"$SYNC_SCRIPT"

# Watch for changes and sync
fswatch -0 -e ".*" -i "\\.pdf$" "$SOURCE_DIR" | while read -d "" event; do
    if [[ "$event" == *"$SOURCE_FILE"* ]]; then
        "$SYNC_SCRIPT"
    fi
done
