#!/usr/bin/env python3
"""Compare Swift extraction output against Python extraction output.

Runs yiana-extract CLI on each OCR file, compares against existing
.addresses/ output field-by-field. Generates aggregate report (no PII).

Usage:
    python3 compare_extraction.py \
        --ocr-dir .ocr_results/PP/Clinical/ \
        --addr-dir .addresses/ \
        --swift-bin /path/to/yiana-extract \
        --db-path /path/to/nhs_lookup.db \
        --report-dir migration/validation_report/
"""

import argparse
import json
import os
import re
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path


# Python method name -> normalised name
METHOD_MAP = {
    "spire_form": "clearwater_form",
    "clearwater_form": "clearwater_form",
    "form": "form",
    "label": "label",
    "unstructured": "unstructured",
}


def normalise_postcode(pc):
    """Normalise UK postcode for comparison."""
    if not pc:
        return ""
    return pc.upper().strip().replace(" ", "")


def normalise_name(name):
    """Normalise name for comparison."""
    if not name:
        return ""
    return " ".join(name.lower().split())


def normalise_phone(phone):
    """Normalise phone number — digits only."""
    if not phone:
        return ""
    return re.sub(r"\D", "", phone)


def get_phones(patient):
    """Extract set of normalised phone numbers from patient dict."""
    phones = set()
    ph = patient.get("phones", {}) or {}
    for key in ("home", "work", "mobile"):
        val = ph.get(key)
        if val:
            n = normalise_phone(val)
            if n:
                phones.add(n)
    return phones


def compare_field(python_val, swift_val, normalise_fn=None):
    """Compare two field values. Returns category string."""
    if normalise_fn:
        pv = normalise_fn(python_val)
        sv = normalise_fn(swift_val)
    else:
        pv = python_val or ""
        sv = swift_val or ""

    if not pv and not sv:
        return "both_empty"
    if not pv and sv:
        return "swift_better"
    if pv and not sv:
        return "python_better"
    if pv == sv:
        return "match"
    return "different"


def compare_page(python_page, swift_page):
    """Compare two page extractions. Returns dict of field -> category."""
    results = {}

    pp = python_page.get("patient", {}) or {}
    sp = swift_page.get("patient", {}) or {}
    results["patient.full_name"] = compare_field(
        pp.get("full_name"), sp.get("full_name"), normalise_name
    )
    results["patient.date_of_birth"] = compare_field(
        pp.get("date_of_birth"), sp.get("date_of_birth")
    )
    results["patient.mrn"] = compare_field(
        pp.get("mrn"), sp.get("mrn")
    )

    # Phones: set comparison
    py_phones = get_phones(pp)
    sw_phones = get_phones(sp)
    if not py_phones and not sw_phones:
        results["patient.phones"] = "both_empty"
    elif py_phones == sw_phones:
        results["patient.phones"] = "match"
    elif not py_phones and sw_phones:
        results["patient.phones"] = "swift_better"
    elif py_phones and not sw_phones:
        results["patient.phones"] = "python_better"
    else:
        results["patient.phones"] = "different"

    pa = python_page.get("address", {}) or {}
    sa = swift_page.get("address", {}) or {}
    results["address.postcode"] = compare_field(
        pa.get("postcode"), sa.get("postcode"), normalise_postcode
    )
    results["address.line1"] = compare_field(
        pa.get("line1"), sa.get("line1"), normalise_name
    )
    results["address.city"] = compare_field(
        pa.get("city"), sa.get("city"), normalise_name
    )

    pg = python_page.get("gp", {}) or {}
    sg = swift_page.get("gp", {}) or {}
    results["gp.name"] = compare_field(
        pg.get("name"), sg.get("name"), normalise_name
    )
    results["gp.practice"] = compare_field(
        pg.get("practice"), sg.get("practice"), normalise_name
    )
    results["gp.postcode"] = compare_field(
        pg.get("postcode"), sg.get("postcode"), normalise_postcode
    )

    # Method comparison (normalised)
    py_method = METHOD_MAP.get(
        (python_page.get("extraction", {}) or {}).get("method", ""),
        (python_page.get("extraction", {}) or {}).get("method", ""),
    )
    sw_method = (swift_page.get("extraction", {}) or {}).get("method", "")
    results["extraction.method"] = compare_field(py_method, sw_method)

    # NHS candidates: compare ODS code sets
    py_candidates = set(
        c.get("ods_code", "") for c in (pg.get("nhs_candidates") or [])
    )
    sw_candidates = set(
        c.get("ods_code", "") for c in (sg.get("nhs_candidates") or [])
    )
    py_candidates.discard("")
    sw_candidates.discard("")
    if not py_candidates and not sw_candidates:
        results["nhs_candidates"] = "both_empty"
    elif py_candidates == sw_candidates:
        results["nhs_candidates"] = "match"
    elif not py_candidates and sw_candidates:
        results["nhs_candidates"] = "swift_better"
    elif py_candidates and not sw_candidates:
        results["nhs_candidates"] = "python_better"
    else:
        results["nhs_candidates"] = "different"

    return results


def classify_document(page_results):
    """Classify overall document comparison result."""
    # A document is "match" if all core fields match on all pages
    core_fields = ["patient.full_name", "patient.date_of_birth", "address.postcode"]
    all_match = True
    any_swift_better = False
    any_python_better = False

    for page_num, fields in page_results.items():
        for field in core_fields:
            cat = fields.get(field, "both_empty")
            if cat == "swift_better":
                any_swift_better = True
            elif cat == "python_better":
                any_python_better = True
            elif cat == "different":
                all_match = False

    if all_match and not any_swift_better and not any_python_better:
        return "match"
    if any_swift_better and not any_python_better:
        return "swift_better"
    if any_python_better and not any_swift_better:
        return "python_better"
    return "different"


def run_swift_extraction(ocr_path, swift_bin, db_path):
    """Run yiana-extract CLI on an OCR file. Returns parsed JSON or None."""
    try:
        with open(ocr_path) as f:
            ocr_data = f.read()
        cmd = [swift_bin]
        if db_path:
            cmd += ["--db-path", db_path]
        result = subprocess.run(
            cmd, input=ocr_data, capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            return None
        return json.loads(result.stdout)
    except (subprocess.TimeoutExpired, json.JSONDecodeError, OSError):
        return None


def main():
    parser = argparse.ArgumentParser(description="Compare Swift vs Python extraction")
    parser.add_argument("--ocr-dir", required=True)
    parser.add_argument("--addr-dir", required=True)
    parser.add_argument("--swift-bin", required=True)
    parser.add_argument("--db-path", default=None)
    parser.add_argument("--report-dir", required=True)
    parser.add_argument("--limit", type=int, default=0, help="Limit docs for testing")
    args = parser.parse_args()

    os.makedirs(args.report_dir, exist_ok=True)

    # Find matching OCR + addresses files
    ocr_files = {
        os.path.basename(f): f
        for f in Path(args.ocr_dir).glob("*.json")
    }
    addr_files = {
        os.path.basename(f): f
        for f in Path(args.addr_dir).glob("*.json")
    }
    common = sorted(set(ocr_files) & set(addr_files))
    if args.limit > 0:
        common = common[: args.limit]

    print(f"Comparing {len(common)} documents...")

    # Counters
    doc_categories = Counter()
    field_categories = defaultdict(Counter)
    method_confusion = Counter()  # (python_method, swift_method) pairs
    errors = 0
    total_pages_compared = 0
    swift_extra_pages = 0
    python_extra_pages = 0

    # Per-document details (kept in memory, written to local file on Devon)
    details_path = os.path.join(args.report_dir, "differences.jsonl")
    details_file = open(details_path, "w")

    for i, filename in enumerate(common):
        if (i + 1) % 100 == 0:
            print(f"  {i + 1}/{len(common)}...")

        # Load Python output
        try:
            with open(addr_files[filename]) as f:
                python_doc = json.load(f)
        except (json.JSONDecodeError, OSError):
            errors += 1
            continue

        # Run Swift extraction
        swift_doc = run_swift_extraction(
            str(ocr_files[filename]), args.swift_bin, args.db_path
        )
        if swift_doc is None:
            errors += 1
            continue

        # Build page maps (by page_number)
        python_pages = {
            p["page_number"]: p for p in python_doc.get("pages", [])
        }
        swift_pages = {
            p["page_number"]: p for p in swift_doc.get("pages", [])
        }

        all_page_nums = sorted(set(python_pages) | set(swift_pages))
        page_results = {}

        for pn in all_page_nums:
            py_page = python_pages.get(pn)
            sw_page = swift_pages.get(pn)

            if py_page and not sw_page:
                python_extra_pages += 1
                # Count all Python fields as python_better
                page_results[pn] = {
                    f: "python_better"
                    for f in [
                        "patient.full_name", "patient.date_of_birth",
                        "address.postcode", "extraction.method",
                    ]
                }
                for field, cat in page_results[pn].items():
                    field_categories[field][cat] += 1
                continue

            if sw_page and not py_page:
                swift_extra_pages += 1
                page_results[pn] = {
                    f: "swift_better"
                    for f in [
                        "patient.full_name", "patient.date_of_birth",
                        "address.postcode", "extraction.method",
                    ]
                }
                for field, cat in page_results[pn].items():
                    field_categories[field][cat] += 1
                continue

            # Both have this page — compare field by field
            total_pages_compared += 1
            fields = compare_page(py_page, sw_page)
            page_results[pn] = fields

            for field, cat in fields.items():
                field_categories[field][cat] += 1

            # Track method confusion
            py_method = METHOD_MAP.get(
                (py_page.get("extraction", {}) or {}).get("method", "none"),
                (py_page.get("extraction", {}) or {}).get("method", "none"),
            )
            sw_method = (sw_page.get("extraction", {}) or {}).get("method", "none")
            method_confusion[(py_method, sw_method)] += 1

            # Write differences (anonymised — use index not filename)
            for field, cat in fields.items():
                if cat not in ("match", "both_empty"):
                    details_file.write(
                        json.dumps({
                            "doc_index": i,
                            "page": pn,
                            "field": field,
                            "category": cat,
                        })
                        + "\n"
                    )

        doc_cat = classify_document(page_results)
        doc_categories[doc_cat] += 1

    details_file.close()

    # Write summary report
    total = len(common)
    summary_path = os.path.join(args.report_dir, "summary.txt")
    with open(summary_path, "w") as f:
        f.write(f"Extraction Comparison Report\n")
        f.write(f"{'=' * 40}\n\n")
        f.write(f"Documents compared: {total}\n")
        f.write(f"Errors (could not compare): {errors}\n")
        f.write(f"Pages compared (both have page): {total_pages_compared}\n")
        f.write(f"Swift extra pages (Swift found, Python didn't): {swift_extra_pages}\n")
        f.write(f"Python extra pages (Python found, Swift didn't): {python_extra_pages}\n\n")

        f.write(f"Document-level results:\n")
        for cat in ["match", "swift_better", "python_better", "different"]:
            count = doc_categories.get(cat, 0)
            pct = (count / total * 100) if total else 0
            f.write(f"  {cat}: {count} ({pct:.1f}%)\n")

        f.write(f"\nField-level breakdown:\n")
        all_fields = sorted(field_categories.keys())
        for field in all_fields:
            cats = field_categories[field]
            total_field = sum(cats.values())
            f.write(f"\n  {field} ({total_field} comparisons):\n")
            for cat in ["match", "both_empty", "swift_better", "python_better", "different"]:
                count = cats.get(cat, 0)
                pct = (count / total_field * 100) if total_field else 0
                if count > 0:
                    f.write(f"    {cat}: {count} ({pct:.1f}%)\n")

        f.write(f"\nMethod confusion matrix (Python -> Swift):\n")
        for (py_m, sw_m), count in sorted(
            method_confusion.items(), key=lambda x: -x[1]
        ):
            f.write(f"  {py_m} -> {sw_m}: {count}\n")

    print(f"\nDone. Report written to {summary_path}")
    print(f"Details written to {details_path}")

    # Print summary to console too
    with open(summary_path) as f:
        print(f.read())


if __name__ == "__main__":
    main()
