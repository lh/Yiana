#!/usr/bin/env python3
"""
Address Extraction Service
Watches for new OCR files and automatically extracts addresses
"""

import json
import time
import sqlite3
import logging
from pathlib import Path
from datetime import datetime
from typing import Dict, List
import argparse
import os
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

from address_extractor import AddressExtractor
from llm_extractor import HybridExtractor
from spire_form_extractor import extract_from_spire_form

# Configuration
OCR_DIR = os.getenv('OCR_DIR', '/Users/rose/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/.ocr_results/OCR')
JSON_OUTPUT_DIR = os.getenv('JSON_OUTPUT', '/Users/rose/Code/Yiana/AddressExtractor/api_output')
DB_PATH = os.getenv('DB_PATH', 'addresses.db')
USE_LLM = os.getenv('USE_LLM', 'false').lower() == 'true'
OUTPUT_FORMAT = os.getenv('OUTPUT_FORMAT', 'both')  # 'db', 'json', 'both'

# Set up logging
log_level = os.getenv('LOG_LEVEL', 'INFO')
logging.basicConfig(
    level=getattr(logging, log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class OCRFileHandler(FileSystemEventHandler):
    """Handle new OCR files"""
    
    def __init__(self):
        self.extractor = AddressExtractor(DB_PATH)
        self.hybrid_extractor = HybridExtractor(use_llm=USE_LLM) if USE_LLM else None
        self.processed_files = self.load_processed_files()
        
        # Ensure output directory exists
        Path(JSON_OUTPUT_DIR).mkdir(parents=True, exist_ok=True)
    
    def load_processed_files(self) -> set:
        """Load list of already processed files from database"""
        try:
            with sqlite3.connect(DB_PATH) as conn:
                cursor = conn.execute("SELECT DISTINCT document_id FROM extracted_addresses")
                return {row[0] for row in cursor.fetchall()}
        except:
            return set()
    
    def on_created(self, event):
        """Handle new file creation"""
        if not event.is_directory and event.src_path.endswith('.json'):
            # Wait a moment for file to be fully written
            time.sleep(0.5)
            self.process_file(event.src_path)
    
    def on_modified(self, event):
        """Handle file modification"""
        if not event.is_directory and event.src_path.endswith('.json'):
            doc_id = Path(event.src_path).stem
            if doc_id not in self.processed_files:
                time.sleep(0.5)
                self.process_file(event.src_path)
    
    def process_file(self, file_path: str):
        """Process a single OCR file"""
        doc_id = Path(file_path).stem
        
        # Skip if already processed
        if doc_id in self.processed_files:
            logger.debug(f"Skipping already processed: {doc_id}")
            return
        
        logger.info(f"Processing: {file_path}")
        
        try:
            with open(file_path, 'r') as f:
                ocr_data = json.load(f)
            
            all_results = []
            
            for page in ocr_data.get('pages', []):
                page_num = page.get('pageNumber', 1)
                text = page.get('text', '')
                
                # Extract based on configuration
                if self.hybrid_extractor:
                    result = self.hybrid_extractor.extract(text, page_num)
                else:
                    # Try Spire form first
                    if "Spire Healthcare" in text:
                        result = extract_from_spire_form(text)
                        if result:
                            result['extraction_method'] = 'spire_form'
                    else:
                        # Try standard extraction
                        result = self.extractor.extract_from_form(text, page_num)
                        if not result:
                            result = self.extractor.extract_from_label(text, page_num)
                        if not result:
                            result = self.extractor.extract_unstructured(text, page_num)
                
                if result:
                    # Add metadata
                    result['document_id'] = doc_id
                    result['page_number'] = page_num
                    result['raw_text'] = text[:1000]
                    result['ocr_json'] = json.dumps(page)[:2000]
                    
                    all_results.append(result)
                    
                    logger.info(f"Extracted from {doc_id} page {page_num}: "
                              f"{result.get('full_name')} - {result.get('postcode')}")
            
            # Save results
            if all_results:
                # Save to database
                if OUTPUT_FORMAT in ['db', 'both']:
                    self.extractor.save_to_database(all_results)
                    self.processed_files.add(doc_id)
                
                # Save to JSON
                if OUTPUT_FORMAT in ['json', 'both']:
                    self.save_json_output(doc_id, all_results)
                
                logger.info(f"Saved {len(all_results)} records from {doc_id}")
            else:
                logger.warning(f"No data extracted from {doc_id}")
        
        except Exception as e:
            logger.error(f"Error processing {file_path}: {e}")
    
    def save_json_output(self, doc_id: str, results: List[Dict]):
        """Save extraction results as JSON"""
        output_file = Path(JSON_OUTPUT_DIR) / f"{doc_id}.json"
        
        # Format for API consumption
        output = {
            'document_id': doc_id,
            'extracted_at': datetime.now().isoformat(),
            'page_count': len(results),
            'pages': []
        }
        
        for result in results:
            page_data = {
                'page_number': result.get('page_number'),
                'patient': {
                    'full_name': result.get('full_name'),
                    'date_of_birth': result.get('date_of_birth'),
                    'phones': {
                        'home': result.get('phone_home'),
                        'work': result.get('phone_work'),
                        'mobile': result.get('phone_mobile')
                    }
                },
                'address': {
                    'line_1': result.get('address_line_1'),
                    'line_2': result.get('address_line_2'),
                    'city': result.get('city'),
                    'county': result.get('county'),
                    'postcode': result.get('postcode'),
                    'postcode_valid': result.get('postcode_valid'),
                    'postcode_district': result.get('postcode_district')
                },
                'gp': {
                    'name': result.get('gp_name'),
                    'practice': result.get('gp_practice'),
                    'address': result.get('gp_address'),
                    'postcode': result.get('gp_postcode')
                },
                'extraction': {
                    'method': result.get('extraction_method'),
                    'confidence': result.get('extraction_confidence')
                }
            }
            output['pages'].append(page_data)
        
        with open(output_file, 'w') as f:
            json.dump(output, f, indent=2)
        
        logger.info(f"JSON output saved to {output_file}")


def process_existing_files(handler: OCRFileHandler):
    """Process all existing OCR files that haven't been processed yet"""
    ocr_dir = Path(OCR_DIR)
    
    if not ocr_dir.exists():
        logger.error(f"OCR directory not found: {OCR_DIR}")
        return
    
    json_files = list(ocr_dir.glob('*.json'))
    unprocessed = [f for f in json_files if f.stem not in handler.processed_files]
    
    if unprocessed:
        logger.info(f"Found {len(unprocessed)} unprocessed files")
        for file_path in unprocessed:
            handler.process_file(str(file_path))
    else:
        logger.info("All existing files already processed")


def watch_directory(handler: OCRFileHandler):
    """Watch OCR directory for new files"""
    observer = Observer()
    observer.schedule(handler, OCR_DIR, recursive=False)
    observer.start()
    
    logger.info(f"Watching directory: {OCR_DIR}")
    logger.info(f"Output format: {OUTPUT_FORMAT}")
    logger.info(f"LLM enhancement: {'Enabled' if USE_LLM else 'Disabled'}")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        logger.info("Stopping file watcher")
    
    observer.join()


def query_database():
    """Interactive database query mode"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    
    print("\nAddress Database Query Mode")
    print("Enter SQL queries or 'quit' to exit")
    print("Example: SELECT * FROM extracted_addresses WHERE city = 'Crawley'")
    print("-" * 60)
    
    while True:
        query = input("\nSQL> ").strip()
        
        if query.lower() in ['quit', 'exit', 'q']:
            break
        
        if not query:
            continue
        
        try:
            cursor = conn.execute(query)
            rows = cursor.fetchall()
            
            if rows:
                # Print column names
                columns = rows[0].keys()
                print("\n" + " | ".join(columns))
                print("-" * (len(columns) * 15))
                
                # Print rows
                for row in rows[:20]:  # Limit to 20 rows
                    values = [str(row[col])[:20] for col in columns]
                    print(" | ".join(values))
                
                if len(rows) > 20:
                    print(f"\n... and {len(rows) - 20} more rows")
            else:
                print("No results")
        
        except sqlite3.Error as e:
            print(f"Error: {e}")
    
    conn.close()


def main():
    """Main entry point"""
    global USE_LLM, OUTPUT_FORMAT
    
    parser = argparse.ArgumentParser(description='Address Extraction Service')
    parser.add_argument('--watch', action='store_true', 
                       help='Watch for new files continuously')
    parser.add_argument('--no-watch', action='store_true',
                       help='Process existing files only')
    parser.add_argument('--use-llm', action='store_true',
                       help='Enable LLM enhancement')
    parser.add_argument('--query', action='store_true',
                       help='Query the database interactively')
    parser.add_argument('--format', choices=['db', 'json', 'both'],
                       default=OUTPUT_FORMAT,
                       help='Output format')
    
    args = parser.parse_args()
    
    # Update global settings
    if args.use_llm:
        USE_LLM = True
    OUTPUT_FORMAT = args.format
    
    if args.query:
        query_database()
    else:
        # Initialize handler
        handler = OCRFileHandler()
        
        # Process existing files
        if not args.watch or args.no_watch:
            process_existing_files(handler)
        
        # Watch for new files
        if args.watch and not args.no_watch:
            watch_directory(handler)
        elif not args.no_watch:
            # Default: process existing and watch
            process_existing_files(handler)
            watch_directory(handler)


if __name__ == "__main__":
    main()