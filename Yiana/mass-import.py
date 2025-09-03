#!/usr/bin/env python3
"""
Mass Import Utility for Yiana
Processes large numbers of PDFs by feeding them to Yiana in manageable batches.

Usage:
    python3 mass-import.py /path/to/pdf/folder [options]
    
Options:
    --batch-size N     Number of files per batch (default: 50)
    --delay N          Seconds to wait between batches (default: 10)
    --pattern GLOB     File pattern to match (default: "*.pdf")
    --dry-run          Show what would be imported without doing it
"""

import os
import sys
import time
import glob
import subprocess
import argparse
from pathlib import Path
import tempfile
import shutil

class YianaMassImporter:
    def __init__(self, batch_size=50, delay=10):
        self.batch_size = batch_size
        self.delay = delay
        self.app_path = "/Users/rose/Code/Yiana/Yiana/build/Build/Products/Debug/Yiana.app"
        self.temp_dir = Path(tempfile.gettempdir()) / "YianaMassImport"
        self.temp_dir.mkdir(exist_ok=True)
        
    def find_pdfs(self, source_path, pattern="*.pdf"):
        """Find all PDFs matching the pattern in the source directory."""
        source = Path(source_path)
        if not source.exists():
            raise ValueError(f"Source path does not exist: {source_path}")
        
        if source.is_file():
            return [source] if source.suffix.lower() == '.pdf' else []
        
        # Recursive search for PDFs
        pdf_files = list(source.rglob(pattern))
        return sorted(pdf_files)
    
    def create_batch_folder(self, files, batch_num):
        """Create a temporary folder with symlinks to batch files."""
        batch_dir = self.temp_dir / f"batch_{batch_num:04d}"
        batch_dir.mkdir(exist_ok=True)
        
        # Create symlinks to avoid copying large files
        for i, file in enumerate(files):
            link_name = batch_dir / f"{i:03d}_{file.name}"
            if link_name.exists():
                link_name.unlink()
            try:
                link_name.symlink_to(file.absolute())
            except OSError:
                # Fall back to copying if symlinks aren't supported
                shutil.copy2(file, link_name)
        
        return batch_dir
    
    def import_batch_with_applescript(self, batch_dir):
        """Use AppleScript to automate the import process."""
        # Create AppleScript to open files in Yiana
        script = f'''
        tell application "Finder"
            set fileList to every file of folder (POSIX file "{batch_dir}" as alias) whose name extension is "pdf"
            set filePaths to {{}}
            repeat with aFile in fileList
                set end of filePaths to POSIX path of (aFile as alias)
            end repeat
        end tell
        
        tell application "Yiana"
            activate
            -- Open the files (this will trigger the import dialog)
            open filePaths
        end tell
        '''
        
        # Execute AppleScript
        result = subprocess.run(
            ['osascript', '-e', script],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            print(f"Warning: AppleScript error: {result.stderr}")
            return False
        return True
    
    def import_batch_with_open(self, files):
        """Use the 'open' command to send files to Yiana."""
        # Build the open command with all files
        cmd = ['open', '-a', self.app_path] + [str(f) for f in files]
        
        try:
            subprocess.run(cmd, check=True)
            return True
        except subprocess.CalledProcessError as e:
            print(f"Error opening files: {e}")
            return False
    
    def process_all(self, source_path, pattern="*.pdf", dry_run=False):
        """Process all PDFs in batches."""
        print(f"🔍 Searching for PDFs in: {source_path}")
        pdf_files = self.find_pdfs(source_path, pattern)
        
        if not pdf_files:
            print("❌ No PDF files found")
            return
        
        total_files = len(pdf_files)
        total_batches = (total_files + self.batch_size - 1) // self.batch_size
        
        print(f"📚 Found {total_files} PDF files")
        print(f"📦 Will process in {total_batches} batches of up to {self.batch_size} files")
        
        if dry_run:
            print("\n🔍 DRY RUN - Showing what would be imported:")
            for i in range(0, total_files, self.batch_size):
                batch = pdf_files[i:i + self.batch_size]
                print(f"\nBatch {i//self.batch_size + 1}:")
                for file in batch[:5]:  # Show first 5 files
                    print(f"  - {file.name}")
                if len(batch) > 5:
                    print(f"  ... and {len(batch) - 5} more files")
            return
        
        # Ensure Yiana is running
        print("\n🚀 Starting Yiana...")
        subprocess.run(['open', self.app_path])
        time.sleep(3)  # Give app time to start
        
        # Process each batch
        for batch_num, i in enumerate(range(0, total_files, self.batch_size), 1):
            batch = pdf_files[i:i + self.batch_size]
            
            print(f"\n📥 Processing batch {batch_num}/{total_batches}")
            print(f"   Files {i+1}-{min(i+len(batch), total_files)} of {total_files}")
            
            # Create batch folder with symlinks
            batch_dir = self.create_batch_folder(batch, batch_num)
            
            # Try to import using open command (simpler and more reliable)
            success = self.import_batch_with_open(batch)
            
            if success:
                print(f"   ✅ Batch {batch_num} sent to Yiana")
            else:
                print(f"   ⚠️  Batch {batch_num} may have had issues")
            
            # Wait before next batch
            if batch_num < total_batches:
                print(f"   ⏳ Waiting {self.delay} seconds before next batch...")
                for remaining in range(self.delay, 0, -1):
                    print(f"      {remaining}...", end='\r')
                    time.sleep(1)
                print("      Ready!    ")
        
        print(f"\n✅ All batches sent! Total: {total_files} files in {total_batches} batches")
        print("📝 Please check Yiana to confirm all imports completed successfully")
        
        # Cleanup
        print("🧹 Cleaning up temporary files...")
        shutil.rmtree(self.temp_dir, ignore_errors=True)

def main():
    parser = argparse.ArgumentParser(
        description="Mass import PDFs into Yiana",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Import all PDFs from a folder with default settings
    python3 mass-import.py ~/Documents/PDFs
    
    # Import with custom batch size and delay
    python3 mass-import.py ~/Documents/PDFs --batch-size 25 --delay 15
    
    # Dry run to see what would be imported
    python3 mass-import.py ~/Documents/PDFs --dry-run
    
    # Import only files matching a pattern
    python3 mass-import.py ~/Documents --pattern "Report*.pdf"
        """
    )
    
    parser.add_argument('source', help='Path to folder containing PDFs')
    parser.add_argument('--batch-size', type=int, default=50,
                        help='Number of files per batch (default: 50)')
    parser.add_argument('--delay', type=int, default=10,
                        help='Seconds to wait between batches (default: 10)')
    parser.add_argument('--pattern', default='*.pdf',
                        help='File pattern to match (default: *.pdf)')
    parser.add_argument('--dry-run', action='store_true',
                        help='Show what would be imported without doing it')
    
    args = parser.parse_args()
    
    # Validate batch size
    if args.batch_size < 1 or args.batch_size > 500:
        print("❌ Batch size must be between 1 and 500")
        sys.exit(1)
    
    # Create importer and process
    importer = YianaMassImporter(
        batch_size=args.batch_size,
        delay=args.delay
    )
    
    try:
        importer.process_all(
            args.source,
            pattern=args.pattern,
            dry_run=args.dry_run
        )
    except KeyboardInterrupt:
        print("\n\n⚠️  Import cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()