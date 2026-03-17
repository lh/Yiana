#!/usr/bin/env python3
"""
Validate NHS lookup against test fixtures.

Runs each test case through the NHSLookup class and compares
results against expected outcomes.

Usage:
    python3 migration/validate_nhs_lookup.py
    python3 migration/validate_nhs_lookup.py --verbose
    python3 migration/validate_nhs_lookup.py --case 21
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "AddressExtractor"))

from extraction_service import NHSLookup

FIXTURES_DIR = Path(__file__).parent / "fixtures" / "nhs_lookup"
DB_PATH = Path(__file__).parent.parent / "AddressExtractor" / "nhs_lookup.db"


def validate_case(case: dict, lookup: NHSLookup, verbose: bool) -> list[str]:
    """Validate a single test case. Returns list of issues."""
    issues = []
    inp = case["input"]
    expected = case["expected"]
    case_type = case["type"]

    results = lookup.lookup_gp(
        postcode=inp["postcode"],
        name_hint=inp.get("name_hint"),
        address_hint=inp.get("address_hint"),
    )

    if case_type in ("exact_match", "exact_match_multiple", "no_match"):
        exp_count = expected["match_count"]
        if len(results) != exp_count:
            issues.append(f"match_count: expected={exp_count}, got={len(results)}")

        # Check ODS codes match
        if "matches" in expected:
            exp_codes = sorted(m["ods_code"] for m in expected["matches"])
            got_codes = sorted(m["ods_code"] for m in results)
            if exp_codes != got_codes:
                issues.append(f"ods_codes: expected={exp_codes}, got={got_codes}")

    elif case_type == "exact_match_with_hint":
        exp_count = expected["match_count"]
        if len(results) != exp_count:
            issues.append(f"match_count: expected={exp_count}, got={len(results)}")

        # First result should match the hinted name
        if results and "first_match_name" in expected:
            exp_first = expected["first_match_name"].lower()
            got_first = results[0]["name"].lower()
            if exp_first != got_first:
                issues.append(f"first_match: expected='{expected['first_match_name']}', got='{results[0]['name']}'")

    elif case_type == "district_fallback_with_hint":
        should_return = expected.get("should_return_results", True)
        if should_return and not results:
            issues.append("expected results from district fallback but got none")
        if verbose and results:
            for r in results:
                issues.append(f"  fallback result: {r['name']} ({r['ods_code']}, {r['postcode']})")

    elif case_type == "district_fallback_no_hint":
        should_return = expected.get("should_return_results", False)
        if should_return and not results:
            issues.append("expected results but got none")
        elif not should_return and results:
            # This is informational — no hint means no fallback in current code
            if verbose:
                issues.append(f"  NOTE: got {len(results)} results without hint (unexpected)")

    return issues


def main():
    parser = argparse.ArgumentParser(description="Validate NHS lookup")
    parser.add_argument("--verbose", "-v", action="store_true")
    parser.add_argument("--case", type=int, help="Run single case by ID")
    args = parser.parse_args()

    cases_path = FIXTURES_DIR / "test_cases.json"
    if not cases_path.exists():
        print(f"ERROR: {cases_path} not found. Run generate_nhs_lookup_fixtures.py first.")
        sys.exit(1)

    with open(cases_path) as f:
        data = json.load(f)

    lookup = NHSLookup(db_path=str(DB_PATH))
    if not lookup.available:
        print(f"ERROR: nhs_lookup.db not found at {DB_PATH}")
        sys.exit(1)

    cases = data["cases"]
    if args.case:
        cases = [c for c in cases if c["id"] == args.case]
        if not cases:
            print(f"ERROR: case {args.case} not found")
            sys.exit(1)

    passed = 0
    failed = 0
    all_issues = []

    for case in cases:
        issues = validate_case(case, lookup, args.verbose)
        # Filter out verbose-only info lines (starting with "  ")
        real_issues = [i for i in issues if not i.startswith("  ")]
        info_lines = [i for i in issues if i.startswith("  ")]

        if real_issues:
            failed += 1
            for issue in real_issues:
                all_issues.append(f"[{case['id']}] {case['type']}: {issue}")
        else:
            passed += 1

        if args.verbose and info_lines:
            for line in info_lines:
                all_issues.append(f"[{case['id']}] {case['type']}:{line}")

    print(f"\n{'='*60}")
    print(f"NHS LOOKUP VALIDATION RESULTS")
    print(f"{'='*60}")
    print(f"Cases: {passed}/{passed + failed} passed")

    if all_issues:
        real = [i for i in all_issues if "NOTE:" not in i and "fallback result:" not in i]
        info = [i for i in all_issues if "NOTE:" in i or "fallback result:" in i]

        if real:
            print(f"\nISSUES ({len(real)}):")
            for issue in real:
                print(f"  {issue}")
        if info:
            print(f"\nINFO:")
            for line in info:
                print(f"  {line}")

    if any(not i.startswith("  ") and "NOTE:" not in i and "fallback result:" not in i
           for i in all_issues):
        print(f"\n{'='*60}")
        print("FAIL")
        sys.exit(1)
    else:
        print(f"\n{'='*60}")
        print("PASS")
        sys.exit(0)


if __name__ == "__main__":
    main()
