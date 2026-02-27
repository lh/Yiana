#!/usr/bin/env python3
"""
Batch process all existing OCR files
"""

import os
import sqlite3
import logging
from pathlib import Path
from address_extractor import AddressExtractor

# Configuration - override with YIANA_DATA_DIR or individual env vars
_default_icloud = os.path.expanduser('~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents')
_data_dir = os.getenv('YIANA_DATA_DIR', _default_icloud)
OCR_DIR = Path(os.getenv('OCR_DIR', os.path.join(_data_dir, '.ocr_results')))
DB_PATH = os.getenv('DB_PATH', os.path.join(_data_dir, 'addresses.db'))

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def process_file(file_path: Path, extractor: AddressExtractor):
    """Process a single OCR file"""
    doc_id = file_path.stem

    logger.info(f"Processing: {doc_id}")

    try:
        # Use the extractor's built-in method
        results = extractor.extract_from_ocr_json(str(file_path), doc_id)

        if results:
            # Save to database
            extractor.save_to_database(results)
            logger.info(f"  ✓ Extracted {len(results)} address(es)")
            return len(results)
        else:
            logger.info(f"  ○ No addresses found")
            return 0

    except Exception as e:
        logger.error(f"  ✗ Error processing {doc_id}: {e}")
        import traceback
        traceback.print_exc()
        return 0


def main():
    logger.info(f"Starting batch processing")
    logger.info(f"OCR directory: {OCR_DIR}")
    logger.info(f"Database: {DB_PATH}")

    # Initialize extractor
    extractor = AddressExtractor(DB_PATH)

    # Get all JSON files
    json_files = sorted(OCR_DIR.glob("*.json"))

    if not json_files:
        logger.warning("No JSON files found!")
        return

    logger.info(f"Found {len(json_files)} OCR files to process\n")

    # Process each file
    total_addresses = 0
    processed_count = 0

    for json_file in json_files:
        count = process_file(json_file, extractor)
        total_addresses += count
        if count > 0:
            processed_count += 1

    logger.info(f"\n{'='*60}")
    logger.info(f"Batch processing complete!")
    logger.info(f"Files processed: {len(json_files)}")
    logger.info(f"Files with addresses: {processed_count}")
    logger.info(f"Total addresses extracted: {total_addresses}")
    logger.info(f"{'='*60}")

    # Show database stats
    try:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.execute("SELECT COUNT(*) FROM extracted_addresses")
            total_in_db = cursor.fetchone()[0]

            cursor = conn.execute("SELECT COUNT(DISTINCT document_id) FROM extracted_addresses")
            docs_in_db = cursor.fetchone()[0]

            logger.info(f"\nDatabase statistics:")
            logger.info(f"Total addresses in database: {total_in_db}")
            logger.info(f"Documents with addresses: {docs_in_db}")
    except Exception as e:
        logger.error(f"Error reading database stats: {e}")


if __name__ == "__main__":
    main()
