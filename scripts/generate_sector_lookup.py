#!/usr/bin/env python3
"""Generate postcode sector -> town lookup from ONS ONSPD data.

Reads the ONSPD CSV + BUA lookup, joins them, groups by postcode sector,
and outputs a Swift dictionary for PostcodeLookup.swift.

Usage:
    python3 generate_sector_lookup.py /path/to/ONSPD_FEB_2026
"""

import csv
import sys
from collections import Counter
from pathlib import Path


def load_bua_names(docs_dir: Path) -> dict[str, str]:
    """Load BUA code -> name mapping."""
    bua_file = next(docs_dir.glob("BUA Built Up Area*codes*.csv"))
    names = {}
    with open(bua_file, newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            code = row.get("BUA24CD", "").strip()
            name = row.get("BUA24NM", "").strip()
            if code and name:
                names[code] = name
    print(f"  {len(names)} BUA names loaded")
    return names


def extract_sector(postcode: str) -> str | None:
    """Extract sector from a postcode: 'RH6 7DG' -> 'RH6 7'."""
    pcd = postcode.strip().upper()
    parts = pcd.split()
    if len(parts) == 2 and len(parts[1]) >= 1:
        return f"{parts[0]} {parts[1][0]}"
    # Try to split non-spaced postcodes
    if len(pcd) >= 5 and " " not in pcd:
        outward = pcd[:-3]
        inward_first = pcd[-3]
        return f"{outward} {inward_first}"
    return None


def process_onspd(data_dir: Path, bua_names: dict[str, str]) -> dict[str, str]:
    """Read ONSPD CSV, join with BUA names, find most common town per sector."""
    csv_file = next(data_dir.glob("ONSPD_*_UK.csv"))
    print(f"  Reading {csv_file.name}...")

    # Count BUA names per sector
    sector_towns: dict[str, Counter] = {}
    rows_read = 0
    matched = 0

    with open(csv_file, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows_read += 1

            # Skip terminated postcodes
            if row.get("doterm", "").strip():
                continue

            pcd = row.get("pcds", "").strip()
            bua_code = row.get("bua24cd", "").strip()

            if not pcd or not bua_code:
                continue

            town = bua_names.get(bua_code)
            if not town:
                continue

            sector = extract_sector(pcd)
            if not sector:
                continue

            if sector not in sector_towns:
                sector_towns[sector] = Counter()
            sector_towns[sector][town] += 1
            matched += 1

            if rows_read % 500_000 == 0:
                print(f"    {rows_read:,} rows, {len(sector_towns):,} sectors, {matched:,} matched")

    print(f"  {rows_read:,} total rows, {matched:,} with BUA, {len(sector_towns):,} sectors")

    # Pick the most common town for each sector
    results = {}
    for sector, counter in sector_towns.items():
        results[sector] = counter.most_common(1)[0][0]

    return results


def generate_swift(results: dict[str, str]) -> str:
    """Generate Swift dictionary source code."""
    lines = ['    private static let sectorToTown: [String: String] = [']
    for sector in sorted(results.keys()):
        town = results[sector].replace('\\', '\\\\').replace('"', '\\"')
        lines.append(f'        "{sector}": "{town}",')
    lines.append('    ]')
    return '\n'.join(lines)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 generate_sector_lookup.py /path/to/ONSPD_FEB_2026")
        sys.exit(1)

    onspd_dir = Path(sys.argv[1])
    data_dir = onspd_dir / "Data"
    docs_dir = onspd_dir / "Documents"

    if not data_dir.exists():
        print(f"Error: {data_dir} not found")
        sys.exit(1)

    print("Step 1: Loading BUA names...")
    bua_names = load_bua_names(docs_dir)

    print("Step 2: Processing ONSPD postcodes...")
    results = process_onspd(data_dir, bua_names)

    print(f"\nStep 3: Generating Swift ({len(results)} sectors)...")
    swift_code = generate_swift(results)

    output = onspd_dir / "sector_lookup.swift"
    output.write_text(swift_code)
    print(f"  Written to {output}")
    print(f"  {len(swift_code):,} bytes")
