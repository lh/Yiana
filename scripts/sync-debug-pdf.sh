#!/bin/bash

# Sync Debug PDF Script
# Copies the debug PDF from iCloud to local temp directory

SOURCE="/Users/rose/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/_Debug-Rendered-Text-Page.pdf"
DEST="/Users/rose/Code/Yiana/temp-debug-files/_Debug-Rendered-Text-Page.pdf"

# Ensure destination directory exists
mkdir -p "$(dirname "$DEST")"

# Copy file if it exists
if [ -f "$SOURCE" ]; then
    cp "$SOURCE" "$DEST"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Copied debug PDF from iCloud to local directory"
    exit 0
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Source file not found: $SOURCE"
    exit 1
fi
