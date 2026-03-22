#!/usr/bin/env python3
"""Generate postcode sector -> town and county lookup from ONS ONSPD data.

Reads the ONSPD CSV + BUA/CTY lookups, joins them, groups by postcode sector,
and outputs Swift dictionaries for PostcodeLookup.swift.

Usage:
    python3 generate_sector_lookup.py /path/to/ONSPD_FEB_2026
"""

import csv
import re
import sys
from collections import Counter
from pathlib import Path


def load_lookup(docs_dir: Path, glob: str, code_col: str, name_col: str) -> dict[str, str]:
    """Load a code -> name mapping from an ONS lookup CSV."""
    lookup_file = next(docs_dir.glob(glob))
    names = {}
    with open(lookup_file, newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            code = row.get(code_col, "").strip()
            name = row.get(name_col, "").strip()
            if code and name:
                names[code] = name
    print(f"  {len(names)} entries from {lookup_file.name}")
    return names


def extract_sector(postcode: str) -> str | None:
    """Extract sector from a postcode: 'RH6 7DG' -> 'RH6 7'."""
    pcd = postcode.strip().upper()
    parts = pcd.split()
    if len(parts) == 2 and len(parts[1]) >= 1:
        return f"{parts[0]} {parts[1][0]}"
    if len(pcd) >= 5 and " " not in pcd:
        outward = pcd[:-3]
        inward_first = pcd[-3]
        return f"{outward} {inward_first}"
    return None


def process_onspd(data_dir: Path, bua_names: dict[str, str], cty_names: dict[str, str]):
    """Read ONSPD CSV, join with BUA + CTY names, find most common per sector."""
    csv_file = next(data_dir.glob("ONSPD_*_UK.csv"))
    print(f"  Reading {csv_file.name}...")

    sector_towns: dict[str, Counter] = {}
    sector_counties: dict[str, Counter] = {}
    rows_read = 0

    with open(csv_file, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows_read += 1

            if row.get("doterm", "").strip():
                continue

            pcd = row.get("pcds", "").strip()
            sector = extract_sector(pcd)
            if not sector:
                continue

            # Town from BUA
            bua_code = row.get("bua24cd", "").strip()
            if bua_code:
                town = bua_names.get(bua_code)
                if town:
                    if sector not in sector_towns:
                        sector_towns[sector] = Counter()
                    sector_towns[sector][town] += 1

            # County from CTY
            cty_code = row.get("cty25cd", "").strip()
            if cty_code:
                county = cty_names.get(cty_code)
                if county:
                    if sector not in sector_counties:
                        sector_counties[sector] = Counter()
                    sector_counties[sector][county] += 1

            if rows_read % 500_000 == 0:
                print(f"    {rows_read:,} rows, {len(sector_towns):,} towns, {len(sector_counties):,} counties")

    print(f"  {rows_read:,} total rows, {len(sector_towns):,} town sectors, {len(sector_counties):,} county sectors")

    towns = {s: c.most_common(1)[0][0] for s, c in sector_towns.items()}
    counties = {s: c.most_common(1)[0][0] for s, c in sector_counties.items()}
    return towns, counties


def clean_name(name: str) -> str:
    """Strip parenthetical disambiguators: 'Horley (Reigate and Banstead)' -> 'Horley'."""
    return re.sub(r' \([^)]+\)', '', name).strip()


def generate_swift_dict(name: str, results: dict[str, str]) -> str:
    """Generate a Swift dictionary."""
    lines = [f'    private static let {name}: [String: String] = [']
    for sector in sorted(results.keys()):
        value = clean_name(results[sector]).replace('\\', '\\\\').replace('"', '\\"')
        lines.append(f'        "{sector}": "{value}",')
    lines.append('    ]')
    return '\n'.join(lines)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 generate_sector_lookup.py /path/to/ONSPD_FEB_2026")
        sys.exit(1)

    onspd_dir = Path(sys.argv[1])
    data_dir = onspd_dir / "Data"
    docs_dir = onspd_dir / "Documents"

    print("Step 1: Loading lookup tables...")
    bua_names = load_lookup(docs_dir, "BUA Built Up Area*codes*.csv", "BUA24CD", "BUA24NM")
    cty_names = load_lookup(docs_dir, "CTY County*codes*.csv", "CTY25CD", "CTY25NM")

    print("Step 2: Processing ONSPD postcodes...")
    towns, counties = process_onspd(data_dir, bua_names, cty_names)

    print(f"\nStep 3: Generating Swift ({len(towns)} towns, {len(counties)} counties)...")
    town_code = generate_swift_dict("sectorToTown", towns)
    county_code = generate_swift_dict("sectorToCounty", counties)

    output = onspd_dir / "sector_lookup.swift"
    output.write_text(town_code + "\n\n" + county_code)
    print(f"  Written to {output}")
