#!/usr/bin/env python3
"""
Generate NHS lookup test fixtures from the real nhs_lookup.db.

NHS ODS data is published by NHS Digital under the Open Government Licence.
All data here is public — no PHI concerns.

Usage:
    python3 migration/generate_nhs_lookup_fixtures.py
"""

import json
import sqlite3
import sys
from pathlib import Path

DB_PATH = Path(__file__).parent.parent / "AddressExtractor" / "nhs_lookup.db"
FIXTURES_DIR = Path(__file__).parent / "fixtures" / "nhs_lookup"


def query_db(sql: str, params: tuple = ()) -> list[dict]:
    with sqlite3.connect(str(DB_PATH)) as conn:
        conn.row_factory = sqlite3.Row
        return [dict(r) for r in conn.execute(sql, params).fetchall()]


def generate():
    if not DB_PATH.exists():
        print(f"ERROR: nhs_lookup.db not found at {DB_PATH}")
        sys.exit(1)

    FIXTURES_DIR.mkdir(parents=True, exist_ok=True)

    test_cases = []

    # =========================================================================
    # EXACT MATCH CASES (1-15): postcode → known practice(s)
    # Geographically spread across England
    # =========================================================================

    exact_postcodes = [
        # (postcode, description) — single practice
        ("AL3 8LJ", "Hertfordshire — single practice"),
        ("BH17 8UE", "Dorset — single practice"),
        ("CO10 2TD", "Essex — single practice"),
        ("DY14 8TY", "West Midlands — single practice"),
        ("EX16 9NB", "Devon — single practice"),
        ("FY6 7NJ", "Lancashire — single practice"),
        ("HP22 5LB", "Buckinghamshire — single practice"),
        ("LS28 6PE", "Leeds — single practice"),
        ("M30 0TU", "Manchester — single practice"),
        ("NR25 7PQ", "Norfolk — single practice"),
        ("OX26 3EU", "Oxfordshire — single practice"),
        ("PE19 2HD", "Cambridgeshire — single practice"),
        ("RH8 0BQ", "Surrey — single practice"),
        ("SE10 0QN", "London SE — single practice"),
        ("UB3 2AP", "London W — single practice"),
    ]

    for i, (postcode, description) in enumerate(exact_postcodes, 1):
        practices = query_db(
            "SELECT ods_code, name, address_line1, address_line2, town, county, postcode "
            "FROM gp_practices WHERE postcode = ? AND status = 'Active'",
            (postcode,),
        )

        test_cases.append({
            "id": i,
            "type": "exact_match",
            "description": description,
            "input": {
                "postcode": postcode,
                "name_hint": None,
                "address_hint": None,
            },
            "expected": {
                "match_count": len(practices),
                "matches": practices,
            },
        })

    # =========================================================================
    # MULTI-PRACTICE EXACT MATCH (16-18): postcodes with 2-3 practices
    # =========================================================================

    multi_postcodes = [
        ("B19 1HS", "Birmingham — 2 practices at same postcode"),
        ("TN1 2DX", "Tunbridge Wells — 2 practices"),
        ("RG12 1LH", "Bracknell — 3 practices"),
    ]

    for i, (postcode, description) in enumerate(multi_postcodes, 16):
        practices = query_db(
            "SELECT ods_code, name, address_line1, address_line2, town, county, postcode "
            "FROM gp_practices WHERE postcode = ? AND status = 'Active'",
            (postcode,),
        )

        test_cases.append({
            "id": i,
            "type": "exact_match_multiple",
            "description": description,
            "input": {
                "postcode": postcode,
                "name_hint": None,
                "address_hint": None,
            },
            "expected": {
                "match_count": len(practices),
                "matches": practices,
            },
        })

    # =========================================================================
    # EXACT MATCH WITH NAME HINT (19-20): hint should sort results
    # =========================================================================

    # Pick a multi-practice postcode and add a name hint
    multi_practices = query_db(
        "SELECT ods_code, name, address_line1, address_line2, town, county, postcode "
        "FROM gp_practices WHERE postcode = 'B19 1HS' AND status = 'Active'"
    )
    if multi_practices:
        # Hint matching the second practice should sort it first
        hint_name = multi_practices[-1]["name"]
        test_cases.append({
            "id": 19,
            "type": "exact_match_with_hint",
            "description": "Name hint should reorder results — Birmingham",
            "input": {
                "postcode": "B19 1HS",
                "name_hint": hint_name,
                "address_hint": None,
            },
            "expected": {
                "match_count": len(multi_practices),
                "first_match_name": hint_name,
                "matches": multi_practices,
            },
        })

    # Another with address hint
    rg_practices = query_db(
        "SELECT ods_code, name, address_line1, address_line2, town, county, postcode "
        "FROM gp_practices WHERE postcode = 'RG12 1LH' AND status = 'Active'"
    )
    if rg_practices:
        test_cases.append({
            "id": 20,
            "type": "exact_match_with_hint",
            "description": "Name hint reorders — Bracknell (3 practices)",
            "input": {
                "postcode": "RG12 1LH",
                "name_hint": rg_practices[0]["name"],
                "address_hint": None,
            },
            "expected": {
                "match_count": len(rg_practices),
                "first_match_name": rg_practices[0]["name"],
                "matches": rg_practices,
            },
        })

    # =========================================================================
    # FALLBACK CASES (21-25): postcode not in DB, fall back to district
    # =========================================================================

    # For each fallback, we use a postcode that doesn't exist in the DB but
    # whose district does. We construct a fictional postcode in a real district.

    fallback_districts = [
        {
            "district": "CT18",
            "fake_postcode": "CT18 7ZZ",
            "description": "Kent — no exact match, 3 in district, hint matches one",
        },
        {
            "district": "SP6",
            "fake_postcode": "SP6 9ZZ",
            "description": "Hampshire — no exact match, 2 in district, hint matches one",
        },
        {
            "district": "BS3",
            "fake_postcode": "BS3 9ZZ",
            "description": "Bristol — no exact match, 3 in district, no hint",
        },
        {
            "district": "LS12",
            "fake_postcode": "LS12 9ZZ",
            "description": "Leeds — no exact match, 2 in district, no hint",
        },
    ]

    for i, fb in enumerate(fallback_districts, 21):
        # Get all practices in the district
        district_practices = query_db(
            "SELECT ods_code, name, address_line1, address_line2, town, county, postcode "
            "FROM gp_practices WHERE postcode_district = ? AND status = 'Active'",
            (fb["district"],),
        )

        # For cases 21-22, provide a name hint from one of the practices
        if i <= 22 and district_practices:
            hint_practice = district_practices[0]
            # Extract a distinctive word from the practice name for the hint
            name_words = [w for w in hint_practice["name"].split()
                          if len(w) > 3 and w.lower() not in
                          ("the", "surgery", "practice", "medical", "centre", "group")]
            hint = name_words[0] if name_words else hint_practice["name"]

            test_cases.append({
                "id": i,
                "type": "district_fallback_with_hint",
                "description": fb["description"],
                "input": {
                    "postcode": fb["fake_postcode"],
                    "name_hint": hint,
                    "address_hint": None,
                },
                "expected": {
                    "district": fb["district"],
                    "district_practice_count": len(district_practices),
                    "should_return_results": True,
                    "notes": f"Hint '{hint}' should help select from {len(district_practices)} candidates",
                },
            })
        else:
            # No hint — should return top 2 candidates or all if few
            test_cases.append({
                "id": i,
                "type": "district_fallback_no_hint",
                "description": fb["description"],
                "input": {
                    "postcode": fb["fake_postcode"],
                    "name_hint": None,
                    "address_hint": None,
                },
                "expected": {
                    "district": fb["district"],
                    "district_practice_count": len(district_practices),
                    "should_return_results": False,
                    "notes": "No hint = no fallback (lookup_gp requires hints for district fallback)",
                },
            })

    # Case 25: completely invalid postcode (no district exists)
    test_cases.append({
        "id": 25,
        "type": "no_match",
        "description": "Invalid postcode — no district exists in DB",
        "input": {
            "postcode": "ZZ99 9ZZ",
            "name_hint": None,
            "address_hint": None,
        },
        "expected": {
            "match_count": 0,
            "matches": [],
        },
    })

    # Write fixtures
    with open(FIXTURES_DIR / "test_cases.json", "w") as f:
        json.dump({
            "description": "NHS ODS GP practice lookup test cases",
            "data_source": "NHS Digital ODS data (Open Government Licence)",
            "total_cases": len(test_cases),
            "cases": test_cases,
        }, f, indent=2)

    print(f"Generated {len(test_cases)} test cases in {FIXTURES_DIR / 'test_cases.json'}")

    # Summary
    by_type = {}
    for tc in test_cases:
        by_type[tc["type"]] = by_type.get(tc["type"], 0) + 1
    for t, c in sorted(by_type.items()):
        print(f"  {t}: {c}")


if __name__ == "__main__":
    generate()
