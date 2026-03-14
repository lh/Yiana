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

# Configuration - all paths derived from YIANA_DATA_DIR or iCloud container
# Set YIANA_DATA_DIR to override the base directory (e.g. ~/Data on server)
_default_icloud = os.path.expanduser('~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents')
ICLOUD_CONTAINER = os.getenv('YIANA_DATA_DIR', _default_icloud)
OCR_DIR = os.getenv('OCR_DIR', os.path.join(ICLOUD_CONTAINER, '.ocr_results'))
JSON_OUTPUT_DIR = os.getenv('JSON_OUTPUT', os.path.join(Path(__file__).parent, 'api_output'))
DB_PATH = os.getenv('DB_PATH', os.path.join(ICLOUD_CONTAINER, 'addresses.db'))
ADDRESSES_DIR = os.getenv('ADDRESSES_DIR', os.path.join(ICLOUD_CONTAINER, '.addresses'))
USE_LLM = os.getenv('USE_LLM', 'false').lower() == 'true'
OUTPUT_FORMAT = os.getenv('OUTPUT_FORMAT', 'both')  # 'db', 'json', 'both'
FAILURE_LOG_PATH = os.getenv('FAILURE_LOG_PATH', os.path.join(
    os.path.expanduser('~/Data'), '.extraction_failures.jsonl'
))

# Health monitoring — matches OCR service pattern (~/Library/Application Support/YianaOCR/health/)
HEALTH_DIR = os.path.join(
    os.path.expanduser('~/Library/Application Support'),
    'YianaExtraction', 'health'
)

# Set up logging
log_level = os.getenv('LOG_LEVEL', 'INFO')
logging.basicConfig(
    level=getattr(logging, log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def write_heartbeat(note: str = "scan"):
    """Write heartbeat JSON for external watchdog (atomic write)."""
    os.makedirs(HEALTH_DIR, exist_ok=True)
    payload = json.dumps({
        "timestamp": datetime.now().astimezone().isoformat(),
        "note": note
    })
    tmp = os.path.join(HEALTH_DIR, "heartbeat.json.tmp")
    dst = os.path.join(HEALTH_DIR, "heartbeat.json")
    try:
        with open(tmp, 'w') as f:
            f.write(payload)
        os.replace(tmp, dst)
    except OSError as e:
        logger.warning(f"Failed to write heartbeat: {e}")


def write_health_error(msg: str):
    """Record last error for external watchdog (atomic write)."""
    os.makedirs(HEALTH_DIR, exist_ok=True)
    payload = json.dumps({
        "timestamp": datetime.now().astimezone().isoformat(),
        "error": msg
    })
    tmp = os.path.join(HEALTH_DIR, "last_error.json.tmp")
    dst = os.path.join(HEALTH_DIR, "last_error.json")
    try:
        with open(tmp, 'w') as f:
            f.write(payload)
        os.replace(tmp, dst)
    except OSError as e:
        logger.warning(f"Failed to write health error: {e}")


def classify_failure(diagnostics: list, text: str) -> str:
    """Categorize a failure based on diagnostic reasons and page text."""
    if len(text.strip()) < 50:
        return 'insufficient_text'

    reasons = {d.get('reason', '') for d in diagnostics}
    has_partial = any(d.get('partial') for d in diagnostics)

    # Spire detected but couldn't parse
    if any(r.startswith('missing:') and d.get('extractor') == 'spire_form'
           for d in diagnostics for r in [d.get('reason', '')]):
        return 'spire_parse_failure'

    # Form fields detected but required fields missing
    if any(r.startswith('missing:') and d.get('extractor') == 'form'
           for d in diagnostics for r in [d.get('reason', '')]):
        return 'form_but_incomplete'

    # Postcode found but no name (partial match)
    if has_partial:
        return 'partial_match'

    # No postcode found by any extractor
    if all(r in ('no_form_fields', 'no_postcode_in_text', 'no_uk_postcode', 'not_spire_form')
           for r in reasons):
        return 'no_address_content'

    return 'unknown'


class OCRFileHandler(FileSystemEventHandler):
    """Handle new OCR files"""
    
    def __init__(self):
        self.extractor = AddressExtractor(DB_PATH)
        self.hybrid_extractor = HybridExtractor(use_llm=USE_LLM) if USE_LLM else None
        self.processed_files = self.load_processed_files()
        
        # Ensure output directories exist
        Path(JSON_OUTPUT_DIR).mkdir(parents=True, exist_ok=True)
        Path(ADDRESSES_DIR).mkdir(parents=True, exist_ok=True)
    
    def load_processed_files(self) -> set:
        """Load list of already processed files from .addresses/ dir and database"""
        processed = set()
        # Check .addresses/ directory (primary source of truth)
        addresses_dir = Path(ADDRESSES_DIR)
        if addresses_dir.exists():
            for f in addresses_dir.glob('*.json'):
                processed.add(f.stem)
        # Also check legacy database
        try:
            with sqlite3.connect(DB_PATH) as conn:
                cursor = conn.execute("SELECT DISTINCT document_id FROM extracted_addresses")
                processed.update(row[0] for row in cursor.fetchall())
        except Exception:
            pass
        return processed
    
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
                    diagnostics = None
                else:
                    diagnostics = []
                    result = self._extract_cascade(text, page_num, diagnostics)

                if result:
                    # Add metadata
                    result['document_id'] = doc_id
                    result['page_number'] = page_num
                    result['raw_text'] = text[:1000]
                    result['ocr_json'] = json.dumps(page)[:2000]

                    all_results.append(result)

                    logger.info(f"Extracted from {doc_id} page {page_num}: "
                              f"{result.get('full_name')} - {result.get('postcode')}")
                elif diagnostics is not None:
                    self._log_failure(doc_id, page_num, text, diagnostics)

            # Save results
            if all_results:
                # Always save to .addresses/ (iCloud-synced JSON)
                self.save_addresses_json(doc_id, all_results)
                self.processed_files.add(doc_id)

                # Save to database (legacy, kept for backward compatibility)
                if OUTPUT_FORMAT in ['db', 'both']:
                    self.extractor.save_to_database(all_results)

                # Save to api_output/ JSON (legacy, kept for backward compatibility)
                if OUTPUT_FORMAT in ['json', 'both']:
                    self.save_json_output(doc_id, all_results)

                logger.info(f"Saved {len(all_results)} records from {doc_id}")
            else:
                logger.warning(f"No data extracted from {doc_id}")

        except Exception as e:
            logger.error(f"Error processing {file_path}: {e}")
            write_health_error(str(e))

    def _extract_cascade(self, text: str, page_num: int, diagnostics: list) -> dict | None:
        """Try all extractors sequentially. Returns first success or None."""
        # 1. Spire form
        result = extract_from_spire_form(text, diagnostics=diagnostics)
        if result:
            result['extraction_method'] = 'spire_form'
            return result

        # 2. Form-based
        result = self.extractor.extract_from_form(text, page_num, diagnostics=diagnostics)
        if result:
            result['extraction_method'] = 'form'
            return result

        # 3. Label-based
        result = self.extractor.extract_from_label(text, page_num, diagnostics=diagnostics)
        if result:
            result['extraction_method'] = 'label'
            return result

        # 4. Unstructured
        result = self.extractor.extract_unstructured(text, page_num, diagnostics=diagnostics)
        if result:
            result['extraction_method'] = 'unstructured'
            return result

        return None

    def _log_failure(self, doc_id: str, page_num: int, text: str, diagnostics: list):
        """Append a failure record to the JSONL log."""
        record = {
            'document_id': doc_id,
            'page_number': page_num,
            'text_snippet': text[:300],
            'extractors_tried': diagnostics,
            'category': classify_failure(diagnostics, text),
            'timestamp': datetime.now().astimezone().isoformat(),
        }
        try:
            failure_dir = Path(FAILURE_LOG_PATH).parent
            failure_dir.mkdir(parents=True, exist_ok=True)
            with open(FAILURE_LOG_PATH, 'a') as f:
                f.write(json.dumps(record) + '\n')
        except OSError as e:
            logger.warning(f"Failed to write failure log: {e}")
    
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

    def save_addresses_json(self, doc_id: str, results: List[Dict]):
        """Save extraction results to .addresses/ directory as iCloud-synced JSON.

        If a file already exists for this document, preserves the overrides[] array
        (owned by the Swift app) and only replaces pages[] (owned by Devon).
        Uses atomic write (temp file + rename) to prevent partial writes.
        """
        output_file = Path(ADDRESSES_DIR) / f"{doc_id}.json"
        tmp_file = Path(ADDRESSES_DIR) / f"{doc_id}.json.tmp"

        # Preserve existing overrides and enriched data if file already exists
        existing_overrides = []
        existing_enriched = None
        if output_file.exists():
            try:
                with open(output_file, 'r') as f:
                    existing = json.load(f)
                existing_overrides = existing.get('overrides', [])
                existing_enriched = existing.get('enriched')
                logger.info(f"Preserving {len(existing_overrides)} existing overrides for {doc_id}")
            except (json.JSONDecodeError, OSError) as e:
                logger.warning(f"Could not read existing file for {doc_id}, overrides/enriched lost: {e}")

        # Build pages array with address_type and is_prime defaults
        pages = []
        for i, result in enumerate(results):
            # Default: first result per page is patient+prime, subsequent are not prime
            default_type = result.get('address_type', 'patient')
            default_prime = result.get('is_prime')

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
                },
                'address_type': default_type,
                'is_prime': default_prime,
                'specialist_name': result.get('specialist_name')
            }
            pages.append(page_data)

        output = {
            'schema_version': 1,
            'document_id': doc_id,
            'extracted_at': datetime.now().isoformat(),
            'page_count': len(pages),
            'pages': pages,
            'overrides': existing_overrides
        }
        if existing_enriched is not None:
            output['enriched'] = existing_enriched

        # Atomic write: write to temp, then rename
        try:
            with open(tmp_file, 'w') as f:
                json.dump(output, f, indent=2)
            os.replace(str(tmp_file), str(output_file))
            logger.info(f"Addresses JSON saved to {output_file}")
        except OSError as e:
            logger.error(f"Failed to write addresses JSON for {doc_id}: {e}")
            # Clean up temp file if it exists
            try:
                tmp_file.unlink(missing_ok=True)
            except OSError:
                pass


def process_existing_files(handler: OCRFileHandler):
    """Process all existing OCR files that haven't been processed yet"""
    ocr_dir = Path(OCR_DIR)
    
    if not ocr_dir.exists():
        logger.error(f"OCR directory not found: {OCR_DIR}")
        return
    
    json_files = list(ocr_dir.rglob('*.json'))
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
    observer.schedule(handler, OCR_DIR, recursive=True)
    observer.start()

    logger.info(f"Watching directory: {OCR_DIR}")
    logger.info(f"Output format: {OUTPUT_FORMAT}")
    logger.info(f"LLM enhancement: {'Enabled' if USE_LLM else 'Disabled'}")

    write_heartbeat("start")
    tick = 0
    try:
        while True:
            time.sleep(1)
            tick += 1
            if tick >= 60:
                write_heartbeat()
                tick = 0
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


def reprocess_failures():
    """Re-run extraction on OCR files that have no .addresses/ output.

    Bypasses the processed_files check so diagnostics are collected for
    documents that previously failed. Results (if any) are saved normally;
    failures are logged to the JSONL failure log.
    """
    ocr_dir = Path(OCR_DIR)
    addresses_dir = Path(ADDRESSES_DIR)

    if not ocr_dir.exists():
        logger.error(f"OCR directory not found: {OCR_DIR}")
        return

    # Find OCR files with no corresponding .addresses/ output
    existing_addresses = set()
    if addresses_dir.exists():
        existing_addresses = {f.stem for f in addresses_dir.glob('*.json')}

    all_ocr = list(ocr_dir.rglob('*.json'))
    to_reprocess = [f for f in all_ocr if f.stem not in existing_addresses]

    logger.info(f"Reprocessing {len(to_reprocess)} of {len(all_ocr)} OCR files (no .addresses/ output)")

    handler = OCRFileHandler()
    # Clear processed_files so nothing is skipped
    handler.processed_files = set()

    for i, file_path in enumerate(to_reprocess, 1):
        handler.process_file(str(file_path))
        if i % 100 == 0:
            logger.info(f"Progress: {i}/{len(to_reprocess)}")

    logger.info(f"Reprocessing complete. Failure log at: {FAILURE_LOG_PATH}")


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
    parser.add_argument('--reprocess-failures', action='store_true',
                       help='Re-run extraction on all OCR files with no .addresses/ output (populates failure log)')

    args = parser.parse_args()

    # Update global settings
    if args.use_llm:
        USE_LLM = True
    OUTPUT_FORMAT = args.format

    if args.query:
        query_database()
    elif args.reprocess_failures:
        reprocess_failures()
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