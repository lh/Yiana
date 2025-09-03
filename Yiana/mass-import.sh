#!/bin/bash

# Mass Import Script for Yiana
# Simple bash version for importing large numbers of PDFs

set -e

# Configuration
BATCH_SIZE=50
DELAY_SECONDS=10
APP_PATH="/Users/rose/Code/Yiana/Yiana/build/Build/Products/Debug/Yiana.app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    echo -e "${2}${1}${NC}"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] <pdf_directory>

Import large numbers of PDFs into Yiana in batches.

OPTIONS:
    -b, --batch-size NUM    Number of files per batch (default: 50)
    -d, --delay NUM         Seconds to wait between batches (default: 10)
    -n, --dry-run          Show what would be imported without doing it
    -h, --help             Show this help message

EXAMPLES:
    # Import all PDFs from a directory
    $0 ~/Documents/PDFs

    # Import with custom batch size
    $0 -b 25 ~/Documents/PDFs

    # Dry run to preview
    $0 --dry-run ~/Documents/PDFs
EOF
    exit 0
}

# Parse command line arguments
DRY_RUN=false
PDF_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--batch-size)
            BATCH_SIZE="$2"
            shift 2
            ;;
        -d|--delay)
            DELAY_SECONDS="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            PDF_DIR="$1"
            shift
            ;;
    esac
done

# Validate input
if [ -z "$PDF_DIR" ]; then
    print_color "Error: No directory specified" "$RED"
    show_usage
fi

if [ ! -d "$PDF_DIR" ]; then
    print_color "Error: Directory does not exist: $PDF_DIR" "$RED"
    exit 1
fi

# Find all PDF files
print_color "🔍 Searching for PDFs in: $PDF_DIR" "$GREEN"

# Use find to get all PDFs recursively
mapfile -t PDF_FILES < <(find "$PDF_DIR" -type f -name "*.pdf" | sort)

TOTAL_FILES=${#PDF_FILES[@]}

if [ $TOTAL_FILES -eq 0 ]; then
    print_color "❌ No PDF files found" "$RED"
    exit 1
fi

# Calculate number of batches
TOTAL_BATCHES=$(( (TOTAL_FILES + BATCH_SIZE - 1) / BATCH_SIZE ))

print_color "📚 Found $TOTAL_FILES PDF files" "$GREEN"
print_color "📦 Will process in $TOTAL_BATCHES batches of up to $BATCH_SIZE files" "$YELLOW"

# Dry run mode
if [ "$DRY_RUN" = true ]; then
    print_color "\n🔍 DRY RUN MODE - No files will be imported" "$YELLOW"
    
    for ((batch=0; batch<TOTAL_BATCHES; batch++)); do
        start=$((batch * BATCH_SIZE))
        end=$((start + BATCH_SIZE))
        if [ $end -gt $TOTAL_FILES ]; then
            end=$TOTAL_FILES
        fi
        
        echo ""
        print_color "Batch $((batch + 1)): Files $((start + 1)) to $end" "$YELLOW"
        
        # Show first few files in batch
        for ((i=start; i<end && i<start+3; i++)); do
            basename "${PDF_FILES[$i]}"
        done
        
        remaining=$((end - start - 3))
        if [ $remaining -gt 0 ]; then
            echo "  ... and $remaining more files"
        fi
    done
    
    exit 0
fi

# Start Yiana if not running
print_color "\n🚀 Opening Yiana..." "$GREEN"
open "$APP_PATH"
sleep 3

# Create temp directory for batch operations
TEMP_DIR="/tmp/yiana_mass_import_$$"
mkdir -p "$TEMP_DIR"

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Process batches
for ((batch=0; batch<TOTAL_BATCHES; batch++)); do
    start=$((batch * BATCH_SIZE))
    end=$((start + BATCH_SIZE))
    if [ $end -gt $TOTAL_FILES ]; then
        end=$TOTAL_FILES
    fi
    
    current_batch=$((batch + 1))
    
    echo ""
    print_color "📥 Processing batch $current_batch/$TOTAL_BATCHES" "$GREEN"
    print_color "   Files $((start + 1)) to $end of $TOTAL_FILES" "$YELLOW"
    
    # Create array of files for this batch
    batch_files=()
    for ((i=start; i<end; i++)); do
        batch_files+=("${PDF_FILES[$i]}")
    done
    
    # Send batch to Yiana using the open command
    # This will trigger Yiana's import dialog
    open -a "$APP_PATH" "${batch_files[@]}"
    
    print_color "   ✅ Batch $current_batch sent to Yiana" "$GREEN"
    
    # Wait between batches (except for the last one)
    if [ $current_batch -lt $TOTAL_BATCHES ]; then
        print_color "   ⏳ Waiting $DELAY_SECONDS seconds before next batch..." "$YELLOW"
        
        # Countdown timer
        for ((remaining=DELAY_SECONDS; remaining>0; remaining--)); do
            echo -ne "      $remaining seconds remaining...\r"
            sleep 1
        done
        echo -ne "      Ready!                      \r"
        echo ""
    fi
done

echo ""
print_color "✅ All batches sent successfully!" "$GREEN"
print_color "📝 Total: $TOTAL_FILES files in $TOTAL_BATCHES batches" "$GREEN"
print_color "⚠️  Please check Yiana to confirm all imports completed" "$YELLOW"

# Note about manual confirmation
cat << EOF

IMPORTANT NOTES:
1. Each batch will open Yiana's import dialog
2. You'll need to click "Import All" for each batch
3. Wait for each batch to complete before the next one starts
4. Consider using smaller batch sizes for better stability

To automate further, you may want to:
- Use Automator or Keyboard Maestro for clicking "Import All"
- Adjust batch size based on your system's performance
- Monitor Activity Monitor for memory usage during import
EOF