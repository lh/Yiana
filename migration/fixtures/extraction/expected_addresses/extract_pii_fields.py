#!/usr/bin/env python3
"""
extract_pii_fields.py

Reads all .json files in a folder and writes a CSV containing all PII-bearing
fields for manual review.

Usage:
    python3 extract_pii_fields.py /path/to/json/folder
    python3 extract_pii_fields.py /path/to/json/folder --output review.csv
"""

import json
import csv
import sys
import os
import argparse
from pathlib import Path


def safe(value):
    """Return value as string, or empty string if None."""
    return str(value) if value is not None else ""


def extract_records(filepath):
    """
    Extract all PII-bearing rows from a single JSON file.
    Returns a list of dicts, one per page entry plus one for the enriched record.
    """
    records = []

    with open(filepath, "r", encoding="utf-8") as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            print(f"WARNING: Could not parse {filepath.name}: {e}", file=sys.stderr)
            return []

    doc_id = safe(data.get("document_id"))
    extracted_at = safe(data.get("extracted_at"))
    filename = filepath.name

    # --- Enriched record (derived from filename / enrichment step) ---
    enriched = data.get("enriched", {}) or {}
    ep = enriched.get("patient", {}) or {}
    enriched_at = safe(enriched.get("enriched_at"))

    records.append({
        "source_file": filename,
        "document_id": doc_id,
        "record_type": "enriched",
        "page_number": "",
        "full_name": safe(ep.get("full_name")),
        "firstname": safe(ep.get("firstname")),
        "surname": safe(ep.get("surname")),
        "date_of_birth": safe(ep.get("date_of_birth")),
        "mrn": "",
        "phone_home": "",
        "phone_work": "",
        "phone_mobile": "",
        "address_line_1": "",
        "city": "",
        "postcode": "",
        "gp_name": "",
        "gp_practice": "",
        "specialist_name": "",
        "extraction_method": safe(ep.get("source")),
        "extraction_confidence": "",
        "extracted_at": extracted_at,
        "enriched_at": enriched_at,
    })

    # --- Page-level records ---
    for page in data.get("pages", []):
        pat = page.get("patient", {}) or {}
        phones = pat.get("phones", {}) or {}
        addr = page.get("address", {}) or {}
        gp = page.get("gp", {}) or {}
        ext = page.get("extraction", {}) or {}

        records.append({
            "source_file": filename,
            "document_id": doc_id,
            "record_type": f"page ({page.get('address_type', '')})",
            "page_number": safe(page.get("page_number")),
            "full_name": safe(pat.get("full_name")),
            "firstname": "",
            "surname": "",
            "date_of_birth": safe(pat.get("date_of_birth")),
            "mrn": safe(pat.get("mrn")),
            "phone_home": safe(phones.get("home")),
            "phone_work": safe(phones.get("work")),
            "phone_mobile": safe(phones.get("mobile")),
            "address_line_1": safe(addr.get("line_1")),
            "city": safe(addr.get("city")),
            "postcode": safe(addr.get("postcode")),
            "gp_name": safe(gp.get("name")),
            "gp_practice": safe(gp.get("practice")),
            "specialist_name": safe(page.get("specialist_name")),
            "extraction_method": safe(ext.get("method")),
            "extraction_confidence": safe(ext.get("confidence")),
            "extracted_at": extracted_at,
            "enriched_at": enriched_at,
        })

    return records


FIELDNAMES = [
    "source_file", "document_id", "record_type", "page_number",
    "full_name", "firstname", "surname", "date_of_birth",
    "mrn", "phone_home", "phone_work", "phone_mobile",
    "address_line_1", "city", "postcode",
    "gp_name", "gp_practice", "specialist_name",
    "extraction_method", "extraction_confidence",
    "extracted_at", "enriched_at",
]


def main():
    parser = argparse.ArgumentParser(description="Extract PII fields from JSON files to CSV.")
    parser.add_argument("folder", help="Folder containing .json files")
    parser.add_argument("--output", default="pii_review.csv", help="Output CSV filename (default: pii_review.csv)")
    parser.add_argument("--recursive", action="store_true", help="Search subfolders recursively")
    args = parser.parse_args()

    folder = Path(args.folder)
    if not folder.is_dir():
        print(f"ERROR: {folder} is not a directory.", file=sys.stderr)
        sys.exit(1)

    pattern = "**/*.json" if args.recursive else "*.json"
    json_files = sorted(folder.glob(pattern))

    if not json_files:
        print(f"No .json files found in {folder}", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(json_files)} JSON file(s). Processing...", file=sys.stderr)

    output_path = Path(args.output)
    total_rows = 0

    with open(output_path, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=FIELDNAMES)
        writer.writeheader()

        for filepath in json_files:
            records = extract_records(filepath)
            writer.writerows(records)
            total_rows += len(records)
            print(f"  {filepath.name}: {len(records)} row(s)", file=sys.stderr)

    print(f"\nDone. {total_rows} rows written to {output_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
