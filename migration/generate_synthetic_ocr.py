#!/usr/bin/env python3
"""
Generate synthetic OCR JSON inputs that match the scrubbed expected address outputs.

Reads each expected address file, extracts the extraction method and data,
then generates OCR text that would trigger the correct extractor path.

The generated OCR text is synthetic — no real data is used.
"""

import json
import os
import random
import sys
from pathlib import Path

EXTRACTION_DIR = Path(__file__).parent / "fixtures" / "extraction"
EXPECTED_DIR = EXTRACTION_DIR / "expected_addresses"
INPUT_DIR = EXTRACTION_DIR / "input_ocr"


def make_ocr_page(page_number: int, text: str, confidence: float = 0.85) -> dict:
    """Create an OCR page in the format YianaOCRService produces."""
    # Build textBlocks from lines
    blocks = []
    y = 0.05
    for line in text.split("\n"):
        if not line.strip():
            y += 0.02
            continue
        blocks.append({
            "boundingBox": {"x": 0.08, "y": y, "width": 0.8, "height": 0.025},
            "confidence": confidence,
            "text": line.strip(),
            "lines": [{
                "boundingBox": {"x": 0.08, "y": y, "width": 0.8, "height": 0.025},
                "text": line.strip(),
                "words": [{
                    "boundingBox": {"x": 0.08, "y": y, "width": 0.15, "height": 0.025},
                    "confidence": confidence,
                    "text": w,
                } for w in line.strip().split()]
            }]
        })
        y += 0.03
    return {
        "pageNumber": page_number,
        "confidence": confidence,
        "text": text,
        "textBlocks": blocks,
    }


def generate_clearwater_form_text(page: dict) -> str:
    """Generate OCR text that triggers the Clearwater form extractor."""
    patient = page.get("patient", {})
    address = page.get("address", {})
    gp = page.get("gp", {})

    full_name = patient.get("full_name", "Test Patient")
    # Clearwater forms use "Surname, Firstname" format
    name_parts = full_name.split(" ", 1)
    if len(name_parts) == 2:
        form_name = f"{name_parts[1]}, {name_parts[0]}"
    else:
        form_name = full_name

    dob = patient.get("date_of_birth", "01/01/1970")
    # Convert DD/MM/YYYY to DD.MM.YYYY for Clearwater forms
    dob_dotted = dob.replace("/", ".") if dob else "01.01.1970"

    mrn = patient.get("mrn", "12345678")
    postcode = address.get("postcode", "AA1 1AA")
    addr_1 = address.get("line_1", "1 Test Street")
    city = address.get("city", "Testtown")
    county = address.get("county", "Surrey")

    phone_home = (patient.get("phones") or {}).get("home", "")
    phone_mobile = (patient.get("phones") or {}).get("mobile", "")

    gp_name = gp.get("name", "")
    gp_practice = gp.get("practice", "")
    gp_address = gp.get("address", "")
    gp_postcode = gp.get("postcode", "")

    # Build Clearwater registration form layout
    lines = [
        "se",
        "Clearwater Medical",
        "STRICTLY PRIVATE AND CONFIDENTIAL",
        "Registration Form",
        "",
        f"Patient_ {mrn}" if mrn else "Patient",
        "PLEASE READ AND COMPLETE BOTH PAGES OF THIS FORM AND AMEND ANY INCORRECT INFORMATION",
        "",
        "Patient name",
        addr_1 or "",
        city or "",
        "",
        "Town",
        "County",
        "Postcode",
        "",
        "Address",
        "Town",
        "County",
        "Postcode",
        "",
        f"{form_name}",
        f"Date of birth",
        f"{dob_dotted}",
        "",
        "Age",
        "Tel no. work",
        "Tel no. home",
        "Tel no, mobile",
    ]

    if phone_home:
        lines.append(phone_home)
    if phone_mobile:
        lines.append(phone_mobile)

    lines.extend([
        "",
        county if county else "Surrey",
        postcode,
        "",
        "Sex",
        "Nationality",
        "Employer or company or school",
        "",
        "Specialist name for this episode of care",
        "",
        "Your referral details",
        "GP",
        "Address",
    ])

    if gp_name:
        lines.append(gp_name.replace("Dr ", "Doctor "))
    if gp_practice:
        lines.append(gp_practice)
    if gp_address:
        lines.append(gp_address)
    if gp_postcode:
        lines.append(gp_postcode)

    lines.extend([
        "",
        "Account Settlement",
        "Medical Insurer's name",
        "",
        "Next of kin",
        "Name",
        "Relationship to you",
        "Address",
        "Synthetic Relative",
        "Spouse",
        "1 Fake Lane",
        "Faketown",
        "AA1 1ZZ",
        "",
        "Emergency contact",
        "Telephone no. day",
        "Telephone no. night",
        "01234000000",
    ])

    return "\n".join(lines)


def generate_form_text(page: dict) -> str:
    """Generate OCR text that triggers the form-based extractor."""
    patient = page.get("patient", {})
    address = page.get("address", {})
    gp = page.get("gp", {})

    full_name = patient.get("full_name", "Test Patient")
    dob = patient.get("date_of_birth", "")
    postcode = address.get("postcode", "AA1 1AA")
    addr_1 = address.get("line_1", "1 Test Street")
    addr_2 = address.get("line_2", "")
    city = address.get("city", "Testtown")
    county = address.get("county", "")

    lines = [
        "Clinical Correspondence",
        "",
        f"Patient name: {full_name}",
    ]

    if dob:
        lines.append(f"Date of birth: {dob}")

    lines.extend([
        "",
        f"Address: {addr_1}",
    ])
    if addr_2:
        lines.append(addr_2)
    if city:
        lines.append(city)
    if county:
        lines.append(county)
    lines.append(postcode)

    lines.append("")

    if gp.get("name"):
        lines.append(f"GP: {gp['name']}")
    if gp.get("practice"):
        lines.append(f"Practice: {gp['practice']}")
    if gp.get("address"):
        lines.append(f"Address: {gp['address']}")

    lines.extend([
        "",
        "Dear Colleague,",
        "",
        "Thank you for referring this patient.",
        "Yours sincerely,",
        "",
        "Consultant Surgeon",
    ])

    return "\n".join(lines)


def generate_label_text(page: dict) -> str:
    """Generate OCR text that triggers the label-based extractor."""
    patient = page.get("patient", {})
    address = page.get("address", {})

    full_name = patient.get("full_name", "Test Patient")
    dob = patient.get("date_of_birth", "")
    postcode = address.get("postcode", "AA1 1AA")
    addr_1 = address.get("line_1", "1 Test Street")
    addr_2 = address.get("line_2", "")
    city = address.get("city", "Testtown")

    # Label format: name on first line, address below, postcode at end
    lines = [
        full_name or "Unknown",
        addr_1 or "1 Unknown Street",
    ]
    if addr_2:
        lines.append(addr_2)
    if city:
        lines.append(city)
    lines.append(postcode or "AA1 1AA")

    if dob:
        lines.append("")
        lines.append(f"DOB: {dob}")

    return "\n".join(lines)


def generate_unstructured_text(page: dict) -> str:
    """Generate OCR text that triggers the unstructured extractor."""
    patient = page.get("patient", {})
    address = page.get("address", {})

    full_name = patient.get("full_name", "Test Patient")
    postcode = address.get("postcode", "AA1 1AA")
    addr_1 = address.get("line_1", "1 Test Street")
    dob = patient.get("date_of_birth", "")

    # Unstructured: text with postcode and name scattered in prose
    lines = [
        "Private and Confidential",
        "",
        f"This letter concerns Mr {full_name or 'Unknown'} who attended clinic on",
        "Monday for review of ongoing symptoms.",
        "",
        "The patient resides at",
        addr_1 or "1 Unknown Street",
        postcode or "AA1 1AA",
        "",
    ]

    if dob:
        lines.append(f"Date of birth {dob}")
        lines.append("")

    lines.extend([
        "Further follow-up in 6 weeks.",
        "With best wishes,",
        "Consultant",
    ])

    return "\n".join(lines)


GENERATORS = {
    "clearwater_form": generate_clearwater_form_text,
    "form": generate_form_text,
    "label": generate_label_text,
    "unstructured": generate_unstructured_text,
}


def generate_all():
    if not EXPECTED_DIR.exists():
        print(f"ERROR: expected addresses not found: {EXPECTED_DIR}")
        sys.exit(1)

    INPUT_DIR.mkdir(parents=True, exist_ok=True)

    generated = 0
    skipped = 0

    for f in sorted(EXPECTED_DIR.iterdir()):
        if not f.name.endswith(".json"):
            continue

        with open(f) as fh:
            addr_data = json.load(fh)

        doc_id = addr_data.get("document_id", f.stem)
        pages = addr_data.get("pages", [])

        if not pages:
            # Empty document — create minimal OCR with no extractable content
            ocr_doc = {
                "documentId": doc_id,
                "confidence": 0.5,
                "engineVersion": "1.0.0",
                "id": f"SYNTH-{doc_id}",
                "metadata": {
                    "detectedLanguages": ["en-US"],
                    "options": {
                        "recognitionLevel": "accurate",
                        "useLanguageCorrection": True,
                        "languages": ["en-US"],
                    },
                    "pageCount": 1,
                    "processingTime": 0.5,
                    "warnings": [],
                },
                "processedAt": "2026-03-16T00:00:00Z",
                "pages": [make_ocr_page(1, "This page contains no extractable addresses.", 0.5)],
            }
            with open(INPUT_DIR / f"{doc_id}.json", "w") as out:
                json.dump(ocr_doc, out, indent=2)
            generated += 1
            continue

        ocr_pages = []
        for page in pages:
            method = page.get("extraction", {}).get("method", "label")
            page_num = page.get("page_number", 1)

            generator = GENERATORS.get(method, generate_label_text)
            text = generator(page)
            ocr_pages.append(make_ocr_page(page_num, text))

        ocr_doc = {
            "documentId": doc_id,
            "confidence": 0.85,
            "engineVersion": "1.0.0",
            "id": f"SYNTH-{doc_id}",
            "metadata": {
                "detectedLanguages": ["en-US"],
                "options": {
                    "recognitionLevel": "accurate",
                    "useLanguageCorrection": True,
                    "languages": ["en-US"],
                },
                "pageCount": len(ocr_pages),
                "processingTime": 1.2,
                "warnings": [],
            },
            "processedAt": "2026-03-16T00:00:00Z",
            "pages": ocr_pages,
        }

        with open(INPUT_DIR / f"{doc_id}.json", "w") as out:
            json.dump(ocr_doc, out, indent=2)
        generated += 1

    print(f"Generated {generated} synthetic OCR files in {INPUT_DIR}")


if __name__ == "__main__":
    generate_all()
