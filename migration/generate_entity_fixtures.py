#!/usr/bin/env python3
"""
Generate fully synthetic entity resolution test fixtures.

Creates .addresses/*.json files and an expected.json that describes
what backend_db.py should produce when ingesting them.

All data is invented — no real names, addresses, or identifiers.
"""

import json
from pathlib import Path

FIXTURES_DIR = Path(__file__).parent / "fixtures" / "entity"
ADDRESSES_DIR = FIXTURES_DIR / "addresses"


def make_address_file(
    document_id: str,
    pages: list[dict],
    overrides: list[dict] | None = None,
) -> dict:
    """Create a .addresses/*.json structure."""
    return {
        "schema_version": 1,
        "document_id": document_id,
        "extracted_at": "2026-03-16T12:00:00.000000",
        "page_count": len(pages),
        "pages": pages,
        "overrides": overrides or [],
    }


def make_page(
    page_number: int = 1,
    patient_name: str | None = None,
    dob: str | None = None,
    mrn: str | None = None,
    phone_home: str | None = None,
    phone_mobile: str | None = None,
    addr_1: str | None = None,
    addr_2: str | None = None,
    city: str | None = None,
    county: str | None = None,
    postcode: str | None = None,
    gp_name: str | None = None,
    gp_practice: str | None = None,
    gp_address: str | None = None,
    gp_postcode: str | None = None,
    gp_ods_code: str | None = None,
    gp_official_name: str | None = None,
    method: str = "label",
    confidence: float = 0.7,
    address_type: str = "patient",
    specialist_name: str | None = None,
) -> dict:
    return {
        "page_number": page_number,
        "patient": {
            "full_name": patient_name,
            "date_of_birth": dob,
            "phones": {
                "home": phone_home,
                "work": None,
                "mobile": phone_mobile,
            },
            "mrn": mrn,
        },
        "address": {
            "line_1": addr_1,
            "line_2": addr_2,
            "city": city,
            "county": county,
            "postcode": postcode,
            "postcode_valid": None,
            "postcode_district": None,
        },
        "gp": {
            "name": gp_name,
            "practice": gp_practice,
            "address": gp_address,
            "postcode": gp_postcode,
            "ods_code": gp_ods_code,
            "official_name": gp_official_name,
            "nhs_candidates": None,
        },
        "extraction": {
            "method": method,
            "confidence": confidence,
        },
        "address_type": address_type,
        "is_prime": None,
        "specialist_name": specialist_name,
    }


def generate_all():
    ADDRESSES_DIR.mkdir(parents=True, exist_ok=True)

    # Clean previous fixtures
    for f in ADDRESSES_DIR.glob("*.json"):
        f.unlink()

    files = {}  # filename -> data

    # =========================================================================
    # SCENARIOS 1-10: Exact-match patient dedup
    # Same Surname_Firstname_DDMMYY appearing in 2 documents each.
    # backend_db uses filename to create patient entity; same filename = same patient.
    # =========================================================================

    # Scenario 1: Basic exact match — same patient, two documents, same GP
    files["Archer_Tom_150380.json"] = make_address_file("Archer_Tom_150380", [
        make_page(1, "Tom Archer", "15/03/1980", addr_1="10 Elm Road",
                  city="Millbrook", postcode="ZZ1 1AA",
                  gp_name="Dr Hall", gp_practice="Millbrook Surgery"),
    ])
    files["Archer_Tom_150380_letter.json"] = make_address_file("Archer_Tom_150380_letter", [
        make_page(1, "Tom Archer", "15/03/1980", addr_1="10 Elm Road",
                  city="Millbrook", postcode="ZZ1 1AA",
                  gp_name="Dr Hall", gp_practice="Millbrook Surgery"),
    ])

    # Scenario 2: Same patient, different address (moved house)
    files["Barton_Emma_220595.json"] = make_address_file("Barton_Emma_220595", [
        make_page(1, "Emma Barton", "22/05/1995", addr_1="5 Oak Lane",
                  city="Ashford", postcode="ZZ2 2BB",
                  gp_name="Dr Patel", gp_practice="Ashford Medical Centre"),
    ])
    files["Barton_Emma_220595_ref.json"] = make_address_file("Barton_Emma_220595_ref", [
        make_page(1, "Emma Barton", "22/05/1995", addr_1="42 Pine Close",
                  city="Ashford", postcode="ZZ2 3CC",
                  gp_name="Dr Patel", gp_practice="Ashford Medical Centre"),
    ])

    # Scenario 3: Same patient, different GP (changed practice)
    files["Clarke_James_100172.json"] = make_address_file("Clarke_James_100172", [
        make_page(1, "James Clarke", "10/01/1972", postcode="ZZ3 4DD",
                  gp_name="Dr Ahmed", gp_practice="Riverside Surgery"),
    ])
    files["Clarke_James_100172_2.json"] = make_address_file("Clarke_James_100172_2", [
        make_page(1, "James Clarke", "10/01/1972", postcode="ZZ3 4DD",
                  gp_name="Dr Lopez", gp_practice="Hilltop Medical Centre"),
    ])

    # Scenario 4: Same patient, three documents
    files["Doyle_Sarah_030488.json"] = make_address_file("Doyle_Sarah_030488", [
        make_page(1, "Sarah Doyle", "03/04/1988", postcode="ZZ4 5EE",
                  gp_name="Dr Osei", gp_practice="Valley Practice"),
    ])
    files["Doyle_Sarah_030488_scan.json"] = make_address_file("Doyle_Sarah_030488_scan", [
        make_page(1, "Sarah Doyle", "03/04/1988", postcode="ZZ4 5EE",
                  gp_name="Dr Osei", gp_practice="Valley Practice"),
    ])
    files["Doyle_Sarah_030488_ref.json"] = make_address_file("Doyle_Sarah_030488_ref", [
        make_page(1, "Sarah Doyle", "03/04/1988", postcode="ZZ4 5EE",
                  gp_name="Dr Osei", gp_practice="Valley Practice"),
    ])

    # Scenario 5: Same patient, OCR name slightly different but filename matches
    files["Evans_Mark_180267.json"] = make_address_file("Evans_Mark_180267", [
        make_page(1, "Mark Evans", "18/02/1967", postcode="ZZ5 6FF",
                  gp_name="Dr Novak", gp_practice="Elm Surgery"),
    ])
    files["Evans_Mark_180267_copy.json"] = make_address_file("Evans_Mark_180267_copy", [
        make_page(1, "M Evans", "18/02/1967", postcode="ZZ5 6FF",
                  gp_name="Dr Novak", gp_practice="Elm Surgery"),
    ])

    # Scenario 6: Same patient, multi-page documents
    files["Ford_Lily_091199.json"] = make_address_file("Ford_Lily_091199", [
        make_page(1, "Lily Ford", "09/11/1999", postcode="ZZ6 7GG",
                  gp_name="Dr Singh", gp_practice="Heath Surgery"),
        make_page(2, "Lily Ford", "09/11/1999", postcode="ZZ6 7GG"),
    ])
    files["Ford_Lily_091199_letter.json"] = make_address_file("Ford_Lily_091199_letter", [
        make_page(1, "Lily Ford", "09/11/1999", postcode="ZZ6 7GG",
                  gp_name="Dr Singh", gp_practice="Heath Surgery"),
    ])

    # Scenario 7: Same patient, one doc has specialist
    # specialist_name only creates a Consultant entity when address_type="specialist"
    files["Grant_Noah_250855.json"] = make_address_file("Grant_Noah_250855", [
        make_page(1, "Noah Grant", "25/08/1955", postcode="ZZ7 8HH",
                  gp_name="Dr Wei", gp_practice="Lakeside Practice"),
    ])
    files["Grant_Noah_250855_ref.json"] = make_address_file("Grant_Noah_250855_ref", [
        make_page(1, "Noah Grant", "25/08/1955", postcode="ZZ7 8HH",
                  gp_name="Dr Wei", gp_practice="Lakeside Practice"),
        make_page(2, "Noah Grant", "25/08/1955", postcode="ZZ7 8HH",
                  address_type="specialist", specialist_name="Mr Bennett"),
    ])

    # Scenario 8: Same patient, one doc has phone, other doesn't
    files["Hart_Zoe_120304.json"] = make_address_file("Hart_Zoe_120304", [
        make_page(1, "Zoe Hart", "12/03/2004", postcode="ZZ8 1KK",
                  phone_mobile="07700111222",
                  gp_name="Dr Kim", gp_practice="Cedar Surgery"),
    ])
    files["Hart_Zoe_120304_2.json"] = make_address_file("Hart_Zoe_120304_2", [
        make_page(1, "Zoe Hart", "12/03/2004", postcode="ZZ8 1KK",
                  gp_name="Dr Kim", gp_practice="Cedar Surgery"),
    ])

    # Scenario 9: Same patient, different extraction methods
    files["Irwin_Ben_070746.json"] = make_address_file("Irwin_Ben_070746", [
        make_page(1, "Ben Irwin", "07/07/1946", postcode="ZZ9 2LL",
                  method="clearwater_form", confidence=0.9,
                  gp_name="Dr Russo", gp_practice="Oak Medical Centre"),
    ])
    files["Irwin_Ben_070746_scan.json"] = make_address_file("Irwin_Ben_070746_scan", [
        make_page(1, "Ben Irwin", "07/07/1946", postcode="ZZ9 2LL",
                  method="form", confidence=0.8,
                  gp_name="Dr Russo", gp_practice="Oak Medical Centre"),
    ])

    # Scenario 10: Same patient, one doc empty (no pages)
    files["Jones_Amy_010190.json"] = make_address_file("Jones_Amy_010190", [
        make_page(1, "Amy Jones", "01/01/1990", postcode="ZZ1 3MM",
                  gp_name="Dr Fox", gp_practice="Bridge Surgery"),
    ])
    files["Jones_Amy_010190_empty.json"] = make_address_file("Jones_Amy_010190_empty", [])

    # =========================================================================
    # SCENARIOS 11-15: Near-match name normalization
    # Tests that normalize_name() correctly handles titles, case, whitespace.
    # Note: backend_db resolves by FILENAME, not OCR name. So near-match
    # only matters if the filenames produce the same normalized name + DOB.
    # =========================================================================

    # Scenario 11: Title prefix in OCR name (filename is clean)
    # Both files have same filename root — same patient.
    # OCR names differ ("Dr Knox" vs "Knox") but filename governs.
    files["Knox_Peter_200660.json"] = make_address_file("Knox_Peter_200660", [
        make_page(1, "Dr Peter Knox", "20/06/1960", postcode="YY1 1AA",
                  gp_name="Dr Burns", gp_practice="North Surgery"),
    ])
    files["Knox_Peter_200660_ref.json"] = make_address_file("Knox_Peter_200660_ref", [
        make_page(1, "Peter Knox", "20/06/1960", postcode="YY1 1AA",
                  gp_name="Dr Burns", gp_practice="North Surgery"),
    ])

    # Scenario 12: Case difference in OCR name (filename identical)
    files["Lane_Rosa_151075.json"] = make_address_file("Lane_Rosa_151075", [
        make_page(1, "ROSA LANE", "15/10/1975", postcode="YY2 2BB",
                  gp_name="Dr Shah", gp_practice="South Surgery"),
    ])
    files["Lane_Rosa_151075_2.json"] = make_address_file("Lane_Rosa_151075_2", [
        make_page(1, "rosa lane", "15/10/1975", postcode="YY2 2BB",
                  gp_name="Dr Shah", gp_practice="South Surgery"),
    ])

    # Scenario 13: Hyphenated surname in filename
    files["Melo-Cruz_Ana_080392.json"] = make_address_file("Melo-Cruz_Ana_080392", [
        make_page(1, "Ana Melo-Cruz", "08/03/1992", postcode="YY3 3CC",
                  gp_name="Dr Chung", gp_practice="East Surgery"),
    ])
    files["Melo-Cruz_Ana_080392_ref.json"] = make_address_file("Melo-Cruz_Ana_080392_ref", [
        make_page(1, "Ana Melo-Cruz", "08/03/1992", postcode="YY3 3CC",
                  gp_name="Dr Chung", gp_practice="East Surgery"),
    ])

    # Scenario 14: Apostrophe in surname
    files["O'Brien_Sean_290185.json"] = make_address_file("O'Brien_Sean_290185", [
        make_page(1, "Sean O'Brien", "29/01/1985", postcode="YY4 4DD",
                  gp_name="Dr Yilmaz", gp_practice="West Surgery"),
    ])
    files["O'Brien_Sean_290185_2.json"] = make_address_file("O'Brien_Sean_290185_2", [
        make_page(1, "Sean O'Brien", "29/01/1985", postcode="YY4 4DD",
                  gp_name="Dr Yilmaz", gp_practice="West Surgery"),
    ])

    # Scenario 15: Two genuinely different patients with similar names
    # Different DOB in filename = different entities
    files["Nash_Kate_120590.json"] = make_address_file("Nash_Kate_120590", [
        make_page(1, "Kate Nash", "12/05/1990", postcode="YY5 5EE",
                  gp_name="Dr Gupta", gp_practice="Park Surgery"),
    ])
    files["Nash_Kate_040302.json"] = make_address_file("Nash_Kate_040302", [
        make_page(1, "Kate Nash", "04/03/2002", postcode="YY5 6FF",
                  gp_name="Dr Gupta", gp_practice="Park Surgery"),
    ])

    # =========================================================================
    # SCENARIOS 16-20: Practitioner dedup
    # Same GP appears across documents with different formatting.
    # Dedup key: (normalize_name(full_name), type)
    # =========================================================================

    # Scenario 16: Same GP, different practice address formatting
    files["Palmer_Jo_100870.json"] = make_address_file("Palmer_Jo_100870", [
        make_page(1, "Jo Palmer", "10/08/1970", postcode="XX1 1AA",
                  gp_name="Dr Fisher", gp_practice="Birch Lane Surgery",
                  gp_address="1 Birch Lane, Milltown", gp_postcode="XX1 9ZZ"),
    ])
    files["Quinn_Dan_050682.json"] = make_address_file("Quinn_Dan_050682", [
        make_page(1, "Dan Quinn", "05/06/1982", postcode="XX2 2BB",
                  gp_name="Dr Fisher", gp_practice="BIRCH LANE SURGERY",
                  gp_address="1 BIRCH LANE, MILLTOWN", gp_postcode="XX1 9ZZ"),
    ])

    # Scenario 17: Same GP, title variants ("Dr" vs "Dr.")
    # normalize_name strips "dr" but NOT "doctor" (not in title list)
    files["Reed_Ava_230793.json"] = make_address_file("Reed_Ava_230793", [
        make_page(1, "Ava Reed", "23/07/1993", postcode="XX3 3CC",
                  gp_name="Dr Martinez", gp_practice="Pine Surgery"),
    ])
    files["Stone_Leo_140561.json"] = make_address_file("Stone_Leo_140561", [
        make_page(1, "Leo Stone", "14/05/1961", postcode="XX4 4DD",
                  gp_name="Dr. Martinez", gp_practice="Pine Surgery"),
    ])

    # Scenario 18: Same GP, case difference
    files["Trent_Mia_011188.json"] = make_address_file("Trent_Mia_011188", [
        make_page(1, "Mia Trent", "01/11/1988", postcode="XX5 5EE",
                  gp_name="Dr KEANE", gp_practice="Maple Surgery"),
    ])
    files["Upton_Raj_160274.json"] = make_address_file("Upton_Raj_160274", [
        make_page(1, "Raj Upton", "16/02/1974", postcode="XX6 6FF",
                  gp_name="Dr Keane", gp_practice="Maple Surgery"),
    ])

    # Scenario 19: Two genuinely different GPs with different names
    files["Voss_Kim_090401.json"] = make_address_file("Voss_Kim_090401", [
        make_page(1, "Kim Voss", "09/04/2001", postcode="XX7 7GG",
                  gp_name="Dr Moss", gp_practice="Fern Surgery"),
    ])
    files["Ward_Sam_281196.json"] = make_address_file("Ward_Sam_281196", [
        make_page(1, "Sam Ward", "28/11/1996", postcode="XX8 8HH",
                  gp_name="Dr Lake", gp_practice="Brook Surgery"),
    ])

    # Scenario 20: Same GP appears as specialist in one doc
    # Different type = different entity (GP vs Consultant)
    files["Yates_Eve_170883.json"] = make_address_file("Yates_Eve_170883", [
        make_page(1, "Eve Yates", "17/08/1983", postcode="XX9 9JJ",
                  gp_name="Dr Finch", gp_practice="Holly Surgery"),
    ])
    files["Zane_Max_050777.json"] = make_address_file("Zane_Max_050777", [
        make_page(1, "Max Zane", "05/07/1977", postcode="XX1 2KK",
                  address_type="specialist", specialist_name="Mr Finch"),
    ])

    # =========================================================================
    # SCENARIOS 21-25: ODS code
    # ODS code exists in schema but _resolve_practitioner() does NOT use it.
    # These tests document this current behaviour.
    # =========================================================================

    # Scenario 21: Same ODS code, same GP name — should dedup (by name)
    files["Abel_Jan_010170.json"] = make_address_file("Abel_Jan_010170", [
        make_page(1, "Jan Abel", "01/01/1970", postcode="WW1 1AA",
                  gp_name="Dr Bloom", gp_practice="Rose Surgery",
                  gp_ods_code="A12345"),
    ])
    files["Bell_Sue_020280.json"] = make_address_file("Bell_Sue_020280", [
        make_page(1, "Sue Bell", "02/02/1980", postcode="WW2 2BB",
                  gp_name="Dr Bloom", gp_practice="Rose Surgery",
                  gp_ods_code="A12345"),
    ])

    # Scenario 22: Same ODS code, different GP name — creates 2 entities
    # (because ODS code is not used for matching)
    files["Cole_Tim_030390.json"] = make_address_file("Cole_Tim_030390", [
        make_page(1, "Tim Cole", "03/03/1990", postcode="WW3 3CC",
                  gp_name="Dr Fry", gp_practice="Daisy Surgery",
                  gp_ods_code="B67890"),
    ])
    files["Drew_Liz_040400.json"] = make_address_file("Drew_Liz_040400", [
        make_page(1, "Liz Drew", "04/04/2000", postcode="WW4 4DD",
                  gp_name="Dr Ash", gp_practice="Daisy Surgery",
                  gp_ods_code="B67890"),
    ])

    # Scenario 23: Different ODS code, same GP name — deduplicates (by name)
    files["Egan_Roy_050565.json"] = make_address_file("Egan_Roy_050565", [
        make_page(1, "Roy Egan", "05/05/1965", postcode="WW5 5EE",
                  gp_name="Dr Clay", gp_practice="Iris Surgery",
                  gp_ods_code="C11111"),
    ])
    files["Fenn_Joy_060675.json"] = make_address_file("Fenn_Joy_060675", [
        make_page(1, "Joy Fenn", "06/06/1975", postcode="WW6 6FF",
                  gp_name="Dr Clay", gp_practice="Iris Medical Centre",
                  gp_ods_code="D22222"),
    ])

    # Scenario 24: ODS code present but GP name empty — no entity created
    files["Glen_Ada_070785.json"] = make_address_file("Glen_Ada_070785", [
        make_page(1, "Ada Glen", "07/07/1985", postcode="WW7 7GG",
                  gp_name="", gp_practice="Lily Surgery",
                  gp_ods_code="E33333"),
    ])

    # Scenario 25: ODS code present, GP name present, official_name differs
    files["Hale_Bob_080895.json"] = make_address_file("Hale_Bob_080895", [
        make_page(1, "Bob Hale", "08/08/1995", postcode="WW8 8HH",
                  gp_name="Dr Thorn", gp_practice="Poppy Surgery",
                  gp_ods_code="F44444", gp_official_name="POPPY MEDICAL CENTRE"),
    ])

    # =========================================================================
    # SCENARIOS 26-30: Edge cases
    # =========================================================================

    # Scenario 26: Missing DOB in filename (only 2 parts)
    files["Irvine_Meg.json"] = make_address_file("Irvine_Meg", [
        make_page(1, "Meg Irvine", None, postcode="VV1 1AA",
                  gp_name="Dr Park", gp_practice="Fern Lane Surgery"),
    ])

    # Scenario 27: Malformed filename (no underscore separator)
    files["JohnSmith.json"] = make_address_file("JohnSmith", [
        make_page(1, "John Smith", "01/06/1950", postcode="VV2 2BB",
                  gp_name="Dr Hill", gp_practice="Dale Surgery"),
    ])

    # Scenario 28: Filename with extra parts (suffix after DOB)
    files["Kent_Lyn_120380_copy1.json"] = make_address_file("Kent_Lyn_120380_copy1", [
        make_page(1, "Lyn Kent", "12/03/1980", postcode="VV3 3CC",
                  gp_name="Dr Vale", gp_practice="Stream Surgery"),
    ])
    files["Kent_Lyn_120380_dna.json"] = make_address_file("Kent_Lyn_120380_dna", [
        make_page(1, "Lyn Kent", "12/03/1980", postcode="VV3 3CC",
                  gp_name="Dr Vale", gp_practice="Stream Surgery"),
    ])

    # Scenario 29: Empty pages array
    files["Lowe_Ned_010101.json"] = make_address_file("Lowe_Ned_010101", [])

    # Scenario 30: Name with numbers (OCR noise) — should still parse filename
    files["Moss_Ali_150595.json"] = make_address_file("Moss_Ali_150595", [
        make_page(1, "Ali M0ss", "15/05/1995", postcode="VV5 5EE",
                  gp_name="Dr Stone", gp_practice="Cliff Surgery"),
    ])

    # =========================================================================
    # Write all files
    # =========================================================================
    for filename, data in sorted(files.items()):
        with open(ADDRESSES_DIR / filename, "w") as f:
            json.dump(data, f, indent=2)

    print(f"Generated {len(files)} address files in {ADDRESSES_DIR}")

    # =========================================================================
    # Expected outcomes
    # =========================================================================
    expected = {
        "description": "Expected entity resolution outcomes from backend_db.py ingestion",
        "total_files": len(files),
        "scenarios": [
            # --- Exact-match dedup (1-10) ---
            {
                "id": 1,
                "name": "basic_exact_match",
                "files": ["Archer_Tom_150380.json", "Archer_Tom_150380_letter.json"],
                "expected_patients": 1,
                "expected_patient_names": ["tom archer"],
                "expected_patient_doc_count": {"tom archer": 2},
                "expected_practitioners": 1,
                "expected_practitioner_names": ["hall"],
                "expected_links": 1,
                "notes": "Same filename root = same patient entity",
            },
            {
                "id": 2,
                "name": "same_patient_different_address",
                "files": ["Barton_Emma_220595.json", "Barton_Emma_220595_ref.json"],
                "expected_patients": 1,
                "expected_patient_names": ["emma barton"],
                "expected_patient_doc_count": {"emma barton": 2},
                "expected_practitioners": 1,
                "expected_links": 1,
                "notes": "Address update on second ingestion",
            },
            {
                "id": 3,
                "name": "same_patient_different_gp",
                "files": ["Clarke_James_100172.json", "Clarke_James_100172_2.json"],
                "expected_patients": 1,
                "expected_practitioners": 2,
                "expected_practitioner_names": ["ahmed", "lopez"],
                "expected_links": 2,
                "notes": "Patient linked to both GPs",
            },
            {
                "id": 4,
                "name": "same_patient_three_docs",
                "files": ["Doyle_Sarah_030488.json", "Doyle_Sarah_030488_scan.json",
                          "Doyle_Sarah_030488_ref.json"],
                "expected_patients": 1,
                "expected_patient_doc_count": {"sarah doyle": 3},
                "expected_practitioners": 1,
                "expected_practitioner_names": ["osei"],
                "expected_links": 1,
                "notes": "document_count should be 3",
            },
            {
                "id": 5,
                "name": "same_patient_ocr_name_differs",
                "files": ["Evans_Mark_180267.json", "Evans_Mark_180267_copy.json"],
                "expected_patients": 1,
                "expected_patient_names": ["mark evans"],
                "expected_practitioners": 1,
                "expected_links": 1,
                "notes": "OCR says 'M Evans' but filename governs identity",
            },
            {
                "id": 6,
                "name": "same_patient_multipage",
                "files": ["Ford_Lily_091199.json", "Ford_Lily_091199_letter.json"],
                "expected_patients": 1,
                "expected_practitioners": 1,
                "expected_links": 1,
                "notes": "Multi-page doc, same patient on all pages",
            },
            {
                "id": 7,
                "name": "same_patient_with_specialist",
                "files": ["Grant_Noah_250855.json", "Grant_Noah_250855_ref.json"],
                "expected_patients": 1,
                "expected_practitioners": 2,
                "expected_practitioner_names": ["wei", "bennett"],
                "expected_links": 2,
                "notes": "GP + specialist = 2 practitioners, both linked to patient",
            },
            {
                "id": 8,
                "name": "same_patient_phone_update",
                "files": ["Hart_Zoe_120304.json", "Hart_Zoe_120304_2.json"],
                "expected_patients": 1,
                "expected_practitioners": 1,
                "expected_links": 1,
                "notes": "Phone from first doc should persist",
            },
            {
                "id": 9,
                "name": "same_patient_different_methods",
                "files": ["Irwin_Ben_070746.json", "Irwin_Ben_070746_scan.json"],
                "expected_patients": 1,
                "expected_practitioners": 1,
                "expected_links": 1,
                "notes": "Extraction method differs but entity resolution is the same",
            },
            {
                "id": 10,
                "name": "same_patient_one_empty",
                "files": ["Jones_Amy_010190.json", "Jones_Amy_010190_empty.json"],
                "expected_patients": 1,
                "expected_patient_doc_count": {"amy jones": 2},
                "expected_practitioners": 1,
                "expected_links": 1,
                "notes": "Empty doc still links filename patient to document",
            },
            # --- Near-match names (11-15) ---
            {
                "id": 11,
                "name": "title_in_ocr_name",
                "files": ["Knox_Peter_200660.json", "Knox_Peter_200660_ref.json"],
                "expected_patients": 1,
                "expected_patient_names": ["peter knox"],
                "expected_practitioners": 1,
                "expected_links": 1,
                "notes": "OCR 'Dr Peter Knox' vs 'Peter Knox', filename governs",
            },
            {
                "id": 12,
                "name": "case_difference_ocr",
                "files": ["Lane_Rosa_151075.json", "Lane_Rosa_151075_2.json"],
                "expected_patients": 1,
                "expected_patient_names": ["rosa lane"],
                "expected_practitioners": 1,
                "expected_links": 1,
                "notes": "OCR 'ROSA LANE' vs 'rosa lane', filename governs",
            },
            {
                "id": 13,
                "name": "hyphenated_surname",
                "files": ["Melo-Cruz_Ana_080392.json", "Melo-Cruz_Ana_080392_ref.json"],
                "expected_patients": 1,
                "expected_patient_names": ["ana melo-cruz"],
                "expected_practitioners": 1,
                "expected_links": 1,
                "notes": "Hyphen preserved in normalized name",
            },
            {
                "id": 14,
                "name": "apostrophe_surname",
                "files": ["O'Brien_Sean_290185.json", "O'Brien_Sean_290185_2.json"],
                "expected_patients": 1,
                "expected_patient_names": ["sean o'brien"],
                "expected_practitioners": 1,
                "expected_links": 1,
                "notes": "Apostrophe preserved in normalized name",
            },
            {
                "id": 15,
                "name": "same_name_different_dob",
                "files": ["Nash_Kate_120590.json", "Nash_Kate_040302.json"],
                "expected_patients": 2,
                "expected_patient_names": ["kate nash", "kate nash"],
                "expected_practitioners": 1,
                "expected_practitioner_names": ["gupta"],
                "expected_links": 2,
                "notes": "Same name but different DOB = 2 separate patients",
            },
            # --- Practitioner dedup (16-20) ---
            {
                "id": 16,
                "name": "gp_address_formatting",
                "files": ["Palmer_Jo_100870.json", "Quinn_Dan_050682.json"],
                "expected_patients": 2,
                "expected_practitioners": 1,
                "expected_practitioner_names": ["fisher"],
                "expected_links": 2,
                "notes": "Dr Fisher appears in both, different case in address",
            },
            {
                "id": 17,
                "name": "gp_title_variant",
                "files": ["Reed_Ava_230793.json", "Stone_Leo_140561.json"],
                "expected_patients": 2,
                "expected_practitioners": 1,
                "expected_practitioner_names": ["martinez"],
                "expected_links": 2,
                "notes": "'Dr Martinez' vs 'Dr. Martinez' both strip to 'martinez'",
            },
            {
                "id": 18,
                "name": "gp_case_difference",
                "files": ["Trent_Mia_011188.json", "Upton_Raj_160274.json"],
                "expected_patients": 2,
                "expected_practitioners": 1,
                "expected_practitioner_names": ["keane"],
                "expected_links": 2,
                "notes": "'Dr KEANE' vs 'Dr Keane' normalize to same",
            },
            {
                "id": 19,
                "name": "two_different_gps",
                "files": ["Voss_Kim_090401.json", "Ward_Sam_281196.json"],
                "expected_patients": 2,
                "expected_practitioners": 2,
                "expected_practitioner_names": ["moss", "lake"],
                "expected_links": 2,
                "notes": "Different GPs = different entities",
            },
            {
                "id": 20,
                "name": "gp_vs_specialist_same_name",
                "files": ["Yates_Eve_170883.json", "Zane_Max_050777.json"],
                "expected_patients": 2,
                "expected_practitioners": 2,
                "expected_practitioner_names": ["finch", "finch"],
                "expected_links": 2,
                "notes": "Dr Finch (GP) and Mr Finch (Consultant) are separate entities",
            },
            # --- ODS code (21-25) ---
            {
                "id": 21,
                "name": "same_ods_same_name",
                "files": ["Abel_Jan_010170.json", "Bell_Sue_020280.json"],
                "expected_patients": 2,
                "expected_practitioners": 1,
                "expected_practitioner_names": ["bloom"],
                "expected_links": 2,
                "notes": "Deduplicates by name (ODS code not used for matching)",
            },
            {
                "id": 22,
                "name": "same_ods_different_name",
                "files": ["Cole_Tim_030390.json", "Drew_Liz_040400.json"],
                "expected_patients": 2,
                "expected_practitioners": 2,
                "expected_practitioner_names": ["fry", "ash"],
                "expected_links": 2,
                "notes": "Same ODS code but different names = 2 entities (ODS not used)",
            },
            {
                "id": 23,
                "name": "different_ods_same_name",
                "files": ["Egan_Roy_050565.json", "Fenn_Joy_060675.json"],
                "expected_patients": 2,
                "expected_practitioners": 1,
                "expected_practitioner_names": ["clay"],
                "expected_links": 2,
                "notes": "Different ODS codes but same name = 1 entity (ODS not used)",
            },
            {
                "id": 24,
                "name": "ods_but_empty_gp_name",
                "files": ["Glen_Ada_070785.json"],
                "expected_patients": 1,
                "expected_practitioners": 0,
                "expected_links": 0,
                "notes": "No GP entity created when name is empty (ODS alone insufficient)",
            },
            {
                "id": 25,
                "name": "ods_with_official_name",
                "files": ["Hale_Bob_080895.json"],
                "expected_patients": 1,
                "expected_practitioners": 1,
                "expected_practitioner_names": ["thorn"],
                "expected_links": 1,
                "notes": "Official name stored but entity resolved by GP name",
            },
            # --- Edge cases (26-30) ---
            {
                "id": 26,
                "name": "missing_dob_in_filename",
                "files": ["Irvine_Meg.json"],
                "expected_patients": 0,
                "expected_practitioners": 1,
                "expected_links": 0,
                "notes": "No patient entity created — filename has no DOB part",
            },
            {
                "id": 27,
                "name": "malformed_filename",
                "files": ["JohnSmith.json"],
                "expected_patients": 0,
                "expected_practitioners": 1,
                "expected_links": 0,
                "notes": "No underscore = unparseable filename, no patient entity",
            },
            {
                "id": 28,
                "name": "filename_with_suffix",
                "files": ["Kent_Lyn_120380_copy1.json", "Kent_Lyn_120380_dna.json"],
                "expected_patients": 1,
                "expected_patient_names": ["lyn kent"],
                "expected_practitioners": 1,
                "expected_links": 1,
                "notes": "Suffix after DOB ignored, same patient resolved",
            },
            {
                "id": 29,
                "name": "empty_pages",
                "files": ["Lowe_Ned_010101.json"],
                "expected_patients": 1,
                "expected_patient_names": ["ned lowe"],
                "expected_practitioners": 0,
                "expected_links": 0,
                "notes": "Empty pages but valid filename still creates patient entity",
            },
            {
                "id": 30,
                "name": "ocr_noise_in_name",
                "files": ["Moss_Ali_150595.json"],
                "expected_patients": 1,
                "expected_patient_names": ["ali moss"],
                "expected_practitioners": 1,
                "expected_links": 1,
                "notes": "OCR says 'Ali M0ss' but filename governs patient identity",
            },
        ],
        "totals": {
            "expected_total_patients": 30,
            "expected_total_practitioners": 24,
            "expected_total_documents": len(files),
            "notes": [
                "Patient count: 10 dedup pairs + 2 (scenario 15) + 2 each for scenarios 16-20 "
                "+ 2 each for 21-23 + 1 each for 24-25 + 0 for 26-27 + 1 for 28 + 0 for 29 + 1 for 30",
                "Practitioner count includes GPs and specialists",
                "ODS code is NOT used for practitioner matching in current code",
            ],
        },
    }

    with open(FIXTURES_DIR / "expected.json", "w") as f:
        json.dump(expected, f, indent=2)

    print(f"Expected outcomes written to {FIXTURES_DIR / 'expected.json'}")


if __name__ == "__main__":
    generate_all()
