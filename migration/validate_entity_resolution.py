#!/usr/bin/env python3
"""
Validate entity resolution by running backend_db.py against synthetic fixtures.

Creates a temporary SQLite DB, ingests the synthetic address files,
then queries the DB and compares against expected.json.

Usage:
    python3 migration/validate_entity_resolution.py
    python3 migration/validate_entity_resolution.py --verbose
    python3 migration/validate_entity_resolution.py --scenario 15
"""

import argparse
import json
import os
import sqlite3
import sys
import tempfile
from pathlib import Path

# Add AddressExtractor to path
sys.path.insert(0, str(Path(__file__).parent.parent / "AddressExtractor"))

from backend_db import BackendDatabase

FIXTURES_DIR = Path(__file__).parent / "fixtures" / "entity"
ADDRESSES_DIR = FIXTURES_DIR / "addresses"
EXPECTED_PATH = FIXTURES_DIR / "expected.json"


def run_ingestion(db_path: str) -> BackendDatabase:
    """Ingest all synthetic address files into a fresh DB."""
    db = BackendDatabase(db_path=db_path)
    db.connect()
    db.init_schema()
    db.ingest_directory(addresses_dir=str(ADDRESSES_DIR))
    return db


def query_patients(db_path: str) -> list[dict]:
    """Get all patients from DB."""
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT id, full_name, full_name_normalized, date_of_birth, "
            "document_count FROM patients ORDER BY id"
        ).fetchall()
    return [dict(r) for r in rows]


def query_practitioners(db_path: str) -> list[dict]:
    """Get all practitioners from DB."""
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT id, full_name, full_name_normalized, type, practice_name, "
            "document_count FROM practitioners ORDER BY id"
        ).fetchall()
    return [dict(r) for r in rows]


def query_patient_documents(db_path: str) -> list[dict]:
    """Get patient-document links."""
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT pd.patient_id, pd.document_id, p.full_name_normalized "
            "FROM patient_documents pd "
            "JOIN patients p ON p.id = pd.patient_id "
            "ORDER BY pd.patient_id, pd.document_id"
        ).fetchall()
    return [dict(r) for r in rows]


def query_patient_practitioners(db_path: str) -> list[dict]:
    """Get patient-practitioner links."""
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT pp.patient_id, pp.practitioner_id, pp.relationship_type, "
            "pp.document_count, p.full_name_normalized as patient_name, "
            "pr.full_name_normalized as practitioner_name "
            "FROM patient_practitioners pp "
            "JOIN patients p ON p.id = pp.patient_id "
            "JOIN practitioners pr ON pr.id = pp.practitioner_id "
            "ORDER BY pp.patient_id, pp.practitioner_id"
        ).fetchall()
    return [dict(r) for r in rows]


def query_documents(db_path: str) -> list[dict]:
    """Get all documents."""
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT document_id, page_count FROM documents ORDER BY document_id"
        ).fetchall()
    return [dict(r) for r in rows]


def query_extractions(db_path: str) -> list[dict]:
    """Get all extractions with entity FKs."""
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT document_id, page_number, patient_id, practitioner_id "
            "FROM extractions ORDER BY document_id, page_number"
        ).fetchall()
    return [dict(r) for r in rows]


def get_scenario_entities(
    scenario: dict,
    patients: list[dict],
    practitioners: list[dict],
    pat_docs: list[dict],
    pat_pracs: list[dict],
    documents: list[dict],
    extractions: list[dict],
) -> dict:
    """Extract entities relevant to a scenario's files."""
    # Map filenames to document_ids (strip .json)
    scenario_doc_ids = set()
    for f in scenario["files"]:
        doc_id = f.replace(".json", "")
        scenario_doc_ids.add(doc_id)

    # Find patients linked to these documents
    scenario_patient_ids = set()
    for pd in pat_docs:
        if pd["document_id"] in scenario_doc_ids:
            scenario_patient_ids.add(pd["patient_id"])

    # Also find patients from extractions (covers cases where
    # patient_documents might not have an entry)
    for ext in extractions:
        if ext["document_id"] in scenario_doc_ids and ext["patient_id"]:
            scenario_patient_ids.add(ext["patient_id"])

    scenario_patients = [p for p in patients if p["id"] in scenario_patient_ids]

    # Find practitioners linked to scenario patients via patient_practitioners
    scenario_prac_ids = set()
    for pp in pat_pracs:
        if pp["patient_id"] in scenario_patient_ids:
            scenario_prac_ids.add(pp["practitioner_id"])

    # Also find practitioners directly from extractions for these documents
    # (they may not be linked to patients if no patient was resolved)
    for ext in extractions:
        if ext["document_id"] in scenario_doc_ids and ext["practitioner_id"]:
            scenario_prac_ids.add(ext["practitioner_id"])

    scenario_practitioners = [p for p in practitioners if p["id"] in scenario_prac_ids]

    # Count links for this scenario
    scenario_links = [
        pp for pp in pat_pracs if pp["patient_id"] in scenario_patient_ids
    ]

    return {
        "patients": scenario_patients,
        "practitioners": scenario_practitioners,
        "links": scenario_links,
    }


def validate_scenario(
    scenario: dict, db_path: str, patients: list, practitioners: list,
    pat_docs: list, pat_pracs: list, documents: list, extractions: list,
    verbose: bool,
) -> list[str]:
    """Validate a single scenario. Returns list of issues."""
    issues = []

    entities = get_scenario_entities(
        scenario, patients, practitioners, pat_docs, pat_pracs, documents,
        extractions,
    )

    # Check patient count
    expected_patients = scenario.get("expected_patients", 0)
    actual_patients = len(entities["patients"])
    if actual_patients != expected_patients:
        issues.append(
            f"patients: expected={expected_patients}, got={actual_patients}"
        )
        if verbose:
            for p in entities["patients"]:
                issues.append(f"  patient: {p['full_name_normalized']} (dob={p.get('date_of_birth')})")

    # Check patient names if specified
    if "expected_patient_names" in scenario:
        actual_names = sorted(p["full_name_normalized"] for p in entities["patients"])
        expected_names = sorted(scenario["expected_patient_names"])
        if actual_names != expected_names:
            issues.append(
                f"patient names: expected={expected_names}, got={actual_names}"
            )

    # Check patient document counts if specified
    if "expected_patient_doc_count" in scenario:
        for name, expected_count in scenario["expected_patient_doc_count"].items():
            matching = [p for p in entities["patients"] if p["full_name_normalized"] == name]
            if matching:
                actual_count = matching[0]["document_count"]
                if actual_count != expected_count:
                    issues.append(
                        f"patient '{name}' doc_count: expected={expected_count}, got={actual_count}"
                    )
            elif expected_count > 0:
                issues.append(f"patient '{name}' not found (expected doc_count={expected_count})")

    # Check practitioner count
    expected_pracs = scenario.get("expected_practitioners", 0)
    actual_pracs = len(entities["practitioners"])
    if actual_pracs != expected_pracs:
        issues.append(
            f"practitioners: expected={expected_pracs}, got={actual_pracs}"
        )
        if verbose:
            for p in entities["practitioners"]:
                issues.append(f"  practitioner: {p['full_name_normalized']} ({p['type']})")

    # Check practitioner names if specified
    if "expected_practitioner_names" in scenario:
        actual_prac_names = sorted(p["full_name_normalized"] for p in entities["practitioners"])
        expected_prac_names = sorted(scenario["expected_practitioner_names"])
        if actual_prac_names != expected_prac_names:
            issues.append(
                f"practitioner names: expected={expected_prac_names}, got={actual_prac_names}"
            )

    # Check link count
    expected_links = scenario.get("expected_links", 0)
    actual_links = len(entities["links"])
    if actual_links != expected_links:
        issues.append(
            f"links: expected={expected_links}, got={actual_links}"
        )
        if verbose:
            for link in entities["links"]:
                issues.append(
                    f"  link: {link['patient_name']} -> {link['practitioner_name']} "
                    f"({link['relationship_type']}, doc_count={link['document_count']})"
                )

    return issues


def main():
    parser = argparse.ArgumentParser(description="Validate entity resolution")
    parser.add_argument("--verbose", "-v", action="store_true")
    parser.add_argument("--scenario", type=int, help="Run single scenario by ID")
    args = parser.parse_args()

    if not EXPECTED_PATH.exists():
        print(f"ERROR: {EXPECTED_PATH} not found. Run generate_entity_fixtures.py first.")
        sys.exit(1)

    with open(EXPECTED_PATH) as f:
        expected = json.load(f)

    # Create temp DB and ingest
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as tmp:
        db_path = tmp.name

    try:
        print(f"Ingesting {expected['total_files']} files into {db_path}...")
        db = run_ingestion(db_path)

        # Query all entities
        patients = query_patients(db_path)
        practitioners = query_practitioners(db_path)
        pat_docs = query_patient_documents(db_path)
        pat_pracs = query_patient_practitioners(db_path)
        documents = query_documents(db_path)
        extractions = query_extractions(db_path)

        if args.verbose:
            print(f"\nDB contents:")
            print(f"  Patients: {len(patients)}")
            print(f"  Practitioners: {len(practitioners)}")
            print(f"  Patient-Document links: {len(pat_docs)}")
            print(f"  Patient-Practitioner links: {len(pat_pracs)}")
            print(f"  Documents: {len(documents)}")

        # Validate scenarios
        scenarios = expected["scenarios"]
        if args.scenario:
            scenarios = [s for s in scenarios if s["id"] == args.scenario]
            if not scenarios:
                print(f"ERROR: scenario {args.scenario} not found")
                sys.exit(1)

        passed = 0
        failed = 0
        all_issues = []

        for scenario in scenarios:
            issues = validate_scenario(
                scenario, db_path, patients, practitioners,
                pat_docs, pat_pracs, documents, extractions, args.verbose
            )
            if issues:
                failed += 1
                for issue in issues:
                    all_issues.append(f"[{scenario['id']}] {scenario['name']}: {issue}")
            else:
                passed += 1

        # Summary
        print(f"\n{'='*60}")
        print(f"ENTITY RESOLUTION VALIDATION RESULTS")
        print(f"{'='*60}")
        print(f"Scenarios: {passed}/{passed + failed} passed")

        if all_issues:
            print(f"\nISSUES ({len(all_issues)}):")
            for issue in all_issues:
                print(f"  {issue}")
            print(f"\n{'='*60}")
            print("FAIL")
            sys.exit(1)
        else:
            print(f"\n{'='*60}")
            print("PASS")
            sys.exit(0)

    finally:
        os.unlink(db_path)


if __name__ == "__main__":
    main()
