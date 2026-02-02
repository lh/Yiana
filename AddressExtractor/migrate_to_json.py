#!/usr/bin/env python3
"""
Migration script: Populate .addresses/ JSON files from existing addresses.db

One-time migration to convert SQLite address data to the new JSON sync format.
Reads all records from addresses.db, groups by document_id, and writes one JSON
per document to .addresses/ in the iCloud container.

Existing overrides from the address_overrides table are preserved in each file's
overrides[] array.

Usage:
    python migrate_to_json.py [--dry-run] [--db-path PATH] [--output-dir PATH]
"""

import json
import os
import sqlite3
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional


ICLOUD_CONTAINER = os.path.expanduser(
    '~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents'
)
DEFAULT_DB_PATH = os.path.join(ICLOUD_CONTAINER, 'addresses.db')
DEFAULT_ADDRESSES_DIR = os.path.join(ICLOUD_CONTAINER, '.addresses')


def read_all_addresses(db_path: str) -> List[Dict]:
    """Read all extracted addresses from the database."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.execute("SELECT * FROM extracted_addresses ORDER BY document_id, page_number")
    rows = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return rows


def read_all_overrides(db_path: str) -> List[Dict]:
    """Read all address overrides from the database."""
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.execute("SELECT * FROM address_overrides ORDER BY original_id, override_date")
        rows = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return rows
    except sqlite3.OperationalError:
        # Table doesn't exist
        return []


def group_by_document(addresses: List[Dict]) -> Dict[str, List[Dict]]:
    """Group address records by document_id."""
    groups: Dict[str, List[Dict]] = {}
    for addr in addresses:
        doc_id = addr['document_id']
        groups.setdefault(doc_id, []).append(addr)
    return groups


def build_override_map(overrides: List[Dict]) -> Dict[int, List[Dict]]:
    """Map original_id -> list of overrides."""
    result: Dict[int, List[Dict]] = {}
    for ov in overrides:
        orig_id = ov.get('original_id')
        if orig_id is not None:
            result.setdefault(orig_id, []).append(ov)
    return result


def address_to_page_entry(addr: Dict) -> Dict:
    """Convert a DB address row to a page entry in the JSON schema."""
    return {
        'page_number': addr.get('page_number', 1),
        'patient': {
            'full_name': addr.get('full_name'),
            'date_of_birth': addr.get('date_of_birth'),
            'phones': {
                'home': addr.get('phone_home'),
                'work': addr.get('phone_work'),
                'mobile': addr.get('phone_mobile'),
            }
        },
        'address': {
            'line_1': addr.get('address_line_1'),
            'line_2': addr.get('address_line_2'),
            'city': addr.get('city'),
            'county': addr.get('county'),
            'postcode': addr.get('postcode'),
            'postcode_valid': bool(addr.get('postcode_valid')) if addr.get('postcode_valid') is not None else None,
            'postcode_district': addr.get('postcode_district'),
        },
        'gp': {
            'name': addr.get('gp_name'),
            'practice': addr.get('gp_practice'),
            'address': addr.get('gp_address'),
            'postcode': addr.get('gp_postcode'),
        },
        'extraction': {
            'method': addr.get('extraction_method'),
            'confidence': addr.get('extraction_confidence'),
        },
        'address_type': addr.get('address_type', 'patient'),
        'is_prime': bool(addr.get('is_prime')) if addr.get('is_prime') is not None else None,
        'specialist_name': addr.get('specialist_name'),
    }


def override_to_entry(ov: Dict, original_addr: Dict) -> Dict:
    """Convert a DB override row to an override entry in the JSON schema."""
    return {
        'page_number': ov.get('page_number', original_addr.get('page_number', 1)),
        'match_address_type': original_addr.get('address_type', 'patient'),
        'patient': {
            'full_name': ov.get('full_name'),
            'date_of_birth': ov.get('date_of_birth'),
            'phones': {
                'home': ov.get('phone_home'),
                'work': ov.get('phone_work'),
                'mobile': ov.get('phone_mobile'),
            }
        },
        'address': {
            'line_1': ov.get('address_line_1'),
            'line_2': ov.get('address_line_2'),
            'city': ov.get('city'),
            'county': ov.get('county'),
            'postcode': ov.get('postcode'),
        },
        'gp': {
            'name': ov.get('gp_name'),
            'practice': ov.get('gp_practice'),
            'address': ov.get('gp_address'),
            'postcode': ov.get('gp_postcode'),
        },
        'address_type': ov.get('address_type', original_addr.get('address_type', 'patient')),
        'is_prime': bool(ov.get('is_prime')) if ov.get('is_prime') is not None else None,
        'specialist_name': ov.get('specialist_name'),
        'override_reason': ov.get('override_reason', 'migrated'),
        'override_date': ov.get('override_date', datetime.now().isoformat()),
    }


def migrate(db_path: str, output_dir: str, dry_run: bool = False):
    """Run the migration."""
    print(f"Reading from: {db_path}")
    print(f"Writing to:   {output_dir}")

    if not os.path.exists(db_path):
        print(f"ERROR: Database not found at {db_path}")
        return

    addresses = read_all_addresses(db_path)
    overrides = read_all_overrides(db_path)
    override_map = build_override_map(overrides)

    print(f"Found {len(addresses)} address records")
    print(f"Found {len(overrides)} override records")

    grouped = group_by_document(addresses)
    print(f"Found {len(grouped)} documents")

    if not dry_run:
        Path(output_dir).mkdir(parents=True, exist_ok=True)

    total_pages = 0
    total_overrides = 0

    for doc_id, doc_addresses in grouped.items():
        pages = []
        doc_overrides = []

        # Build an id -> addr map for looking up originals for overrides
        id_map = {addr['id']: addr for addr in doc_addresses if addr.get('id') is not None}

        for addr in doc_addresses:
            pages.append(address_to_page_entry(addr))

            # Check for overrides for this address
            addr_id = addr.get('id')
            if addr_id and addr_id in override_map:
                for ov in override_map[addr_id]:
                    doc_overrides.append(override_to_entry(ov, addr))

        output = {
            'schema_version': 1,
            'document_id': doc_id,
            'extracted_at': doc_addresses[0].get('extracted_at', datetime.now().isoformat()),
            'page_count': len(pages),
            'pages': pages,
            'overrides': doc_overrides,
        }

        total_pages += len(pages)
        total_overrides += len(doc_overrides)

        if dry_run:
            print(f"  [DRY RUN] Would write {doc_id}.json ({len(pages)} pages, {len(doc_overrides)} overrides)")
        else:
            output_file = Path(output_dir) / f"{doc_id}.json"
            tmp_file = Path(output_dir) / f"{doc_id}.json.tmp"

            with open(tmp_file, 'w') as f:
                json.dump(output, f, indent=2)
            os.replace(str(tmp_file), str(output_file))

            print(f"  Written {doc_id}.json ({len(pages)} pages, {len(doc_overrides)} overrides)")

    print(f"\nMigration complete:")
    print(f"  Documents: {len(grouped)}")
    print(f"  Pages:     {total_pages}")
    print(f"  Overrides: {total_overrides}")

    # Verification
    if not dry_run:
        json_count = len(list(Path(output_dir).glob('*.json')))
        if json_count == len(grouped):
            print(f"  Verification: OK ({json_count} JSON files match {len(grouped)} documents)")
        else:
            print(f"  WARNING: {json_count} JSON files but {len(grouped)} documents expected")

        if total_pages == len(addresses):
            print(f"  Verification: OK ({total_pages} pages match {len(addresses)} DB records)")
        else:
            print(f"  WARNING: {total_pages} pages but {len(addresses)} DB records expected")


def main():
    parser = argparse.ArgumentParser(description='Migrate addresses.db to .addresses/ JSON files')
    parser.add_argument('--dry-run', action='store_true',
                        help='Show what would be done without writing files')
    parser.add_argument('--db-path', default=DEFAULT_DB_PATH,
                        help=f'Path to addresses.db (default: {DEFAULT_DB_PATH})')
    parser.add_argument('--output-dir', default=DEFAULT_ADDRESSES_DIR,
                        help=f'Path to .addresses/ directory (default: {DEFAULT_ADDRESSES_DIR})')

    args = parser.parse_args()
    migrate(args.db_path, args.output_dir, args.dry_run)


if __name__ == '__main__':
    main()
