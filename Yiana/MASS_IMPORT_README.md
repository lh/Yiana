# Yiana Mass Import Tools

Tools for importing large numbers of PDF files into Yiana without overwhelming the system.

## Overview

When you need to import thousands of PDFs, these scripts will:
- Break files into manageable batches (default: 50 files)
- Send each batch to Yiana with delays between batches
- Provide progress tracking and error handling
- Support dry-run mode to preview operations

## Available Scripts

### 1. Python Script (`mass-import.py`)
More feature-rich with better error handling.

```bash
# Basic usage - import all PDFs from a folder
python3 mass-import.py ~/Documents/PDFs

# Custom batch size and delay
python3 mass-import.py ~/Documents/PDFs --batch-size 25 --delay 15

# Dry run to preview what will be imported
python3 mass-import.py ~/Documents/PDFs --dry-run

# Import only specific pattern
python3 mass-import.py ~/Documents --pattern "Report*.pdf"
```

### 2. Bash Script (`mass-import.sh`)
Simpler, no Python dependencies required.

```bash
# Basic usage
./mass-import.sh ~/Documents/PDFs

# Custom batch size
./mass-import.sh -b 25 ~/Documents/PDFs

# Dry run mode
./mass-import.sh --dry-run ~/Documents/PDFs
```

## How It Works

1. **Discovery**: Recursively finds all PDF files in the specified directory
2. **Batching**: Divides files into batches (default: 50 files per batch)
3. **Import**: Opens each batch in Yiana, triggering the import dialog
4. **Delay**: Waits between batches (default: 10 seconds) to allow processing
5. **Repeat**: Continues until all files are processed

## Important Notes

### Manual Interaction Required
- Each batch will open Yiana's import dialog
- You need to click "Import All" for each batch
- The script waits between batches to give you time to complete each import

### Performance Considerations
- **Batch Size**: 
  - 25-50 files: Good for most systems
  - 100 files: For powerful machines with lots of RAM
  - 10-25 files: For slower systems or very large PDFs

- **Delay Between Batches**:
  - 10 seconds: Minimum recommended
  - 15-30 seconds: For larger batches
  - 60+ seconds: If doing OCR processing

### System Resources
- Monitor Activity Monitor during import
- Each PDF uses memory for thumbnail generation
- Yiana limits thumbnails to first 100 files per batch
- Maximum 500 files per batch (hard limit in Yiana)

## Example: Importing 2000 Files

```bash
# Recommended approach for 2000 files
python3 mass-import.py ~/LargePDFCollection --batch-size 40 --delay 20

# This will create 50 batches of 40 files each
# Total time: ~17 minutes (plus manual clicking time)
```

## Automation Tips

### Using Automator (macOS)
Create an Automator workflow to:
1. Watch for Yiana's import dialog
2. Automatically click "Import All"
3. Wait for completion

### Using Keyboard Maestro
Create a macro that:
1. Detects the import dialog window
2. Waits 2 seconds
3. Clicks the "Import All" button
4. Waits for the dialog to close

### Using AppleScript
```applescript
-- Auto-click Import All when dialog appears
tell application "System Events"
    tell process "Yiana"
        if exists window "Import Multiple PDFs" then
            click button "Import All" of window "Import Multiple PDFs"
        end if
    end tell
end tell
```

## Troubleshooting

### Files Not Appearing in Import Dialog
- Check that PDFs are valid (not corrupted)
- Ensure batch size isn't too large
- Try smaller batches (10-25 files)

### Yiana Becomes Unresponsive
- Reduce batch size
- Increase delay between batches
- Close other applications to free memory

### Some Files Not Imported
- Check Yiana's import results dialog
- Look for files with special characters in names
- Verify PDF files aren't password protected

## Advanced Usage

### Processing Specific Directories
```bash
# Import from multiple directories sequentially
for dir in ~/Documents/Reports ~/Documents/Invoices ~/Documents/Receipts; do
    python3 mass-import.py "$dir" --batch-size 30
    sleep 60  # Wait 1 minute between directories
done
```

### Filtering by Date
```bash
# Find and import only recent PDFs (modified in last 30 days)
find ~/Documents -name "*.pdf" -mtime -30 -exec cp {} /tmp/recent_pdfs/ \;
python3 mass-import.py /tmp/recent_pdfs/
```

### Progress Logging
```bash
# Log the import process
python3 mass-import.py ~/Documents/PDFs 2>&1 | tee import_log.txt
```

## Safety Features

- **Dry Run Mode**: Preview without importing
- **Batch Limits**: Maximum 500 files per batch
- **Temporary Symlinks**: Doesn't move/copy original files
- **Automatic Cleanup**: Removes temporary files after import
- **Graceful Cancellation**: Ctrl+C stops cleanly

## Requirements

- macOS (for Yiana)
- Python 3.6+ (for Python script)
- Bash 4+ (for shell script)
- Sufficient disk space for Yiana documents
- 8GB+ RAM recommended for large imports

## Support

For issues with:
- **Mass import scripts**: Check this README
- **Yiana import dialog**: Check Yiana documentation
- **Memory/performance**: Reduce batch size and increase delays