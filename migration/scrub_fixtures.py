#!/usr/bin/env python3
"""
Scrub PHI from extraction test fixtures.

Selects a representative sample of documents, copies both OCR JSON and
address JSON, replaces all PII with synthetic equivalents while preserving
structure, field types, and extraction method distribution.

Usage:
    python3 migration/scrub_fixtures.py --select   # pick 50 documents, copy raw
    python3 migration/scrub_fixtures.py --scrub     # anonymise the raw copies
    python3 migration/scrub_fixtures.py --verify    # check no real PII remains

The --select step writes raw (unscrubbed) files to migration/fixtures/_raw/.
The --scrub step reads from _raw/, writes scrubbed files to the final directories.
The _raw/ directory is gitignored and must be deleted after inspection.
"""

import argparse
import hashlib
import json
import os
import random
import re
import shutil
import string
import sys
from pathlib import Path

# --- Paths ---
ICLOUD_BASE = Path.home() / "Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents"
ADDRESSES_DIR = ICLOUD_BASE / ".addresses"
OCR_DIR = ICLOUD_BASE / ".ocr_results"

MIGRATION_DIR = Path(__file__).parent
RAW_DIR = MIGRATION_DIR / "fixtures" / "_raw"
EXTRACTION_DIR = MIGRATION_DIR / "fixtures" / "extraction"

# --- Synthetic data pools ---

FIRST_NAMES = [
    "Alice", "Bob", "Carol", "David", "Emma", "Frank", "Grace", "Henry",
    "Iris", "James", "Karen", "Leo", "Mary", "Noah", "Olivia", "Paul",
    "Quinn", "Rachel", "Simon", "Tara", "Uma", "Victor", "Wendy", "Xavier",
    "Yvonne", "Zach", "Amara", "Brent", "Clara", "Derek", "Elena", "Finn",
    "Gita", "Hugo", "Iona", "Jay", "Kira", "Luke", "Mira", "Neel",
    "Opal", "Peter", "Rosa", "Sean", "Tessa", "Uri", "Vera", "Will",
    "Xena", "Yusuf",
]

LAST_NAMES = [
    "Anderson", "Baker", "Clarke", "Davis", "Edwards", "Fisher", "Green",
    "Harris", "Irving", "Jones", "Knight", "Lewis", "Morgan", "Nelson",
    "Owen", "Parker", "Quinn", "Roberts", "Smith", "Taylor", "Underwood",
    "Vance", "Walker", "Young", "Zhao", "Ashworth", "Brennan", "Cooper",
    "Dixon", "Ellis", "Foster", "Grant", "Holmes", "Ingram", "Jacobs",
    "Keane", "Lloyd", "Mason", "Norris", "Palmer", "Reed", "Stone",
    "Turner", "Vaughan", "Ward", "Cross", "Blake", "Chase", "Drew", "Frost",
]

STREETS = [
    "Oak Lane", "High Street", "Church Road", "Mill Lane", "The Green",
    "Station Road", "Park Avenue", "Victoria Road", "Manor Way", "Kings Road",
    "Queens Drive", "Elm Close", "Cedar Way", "Birch Lane", "Maple Drive",
    "Willow Court", "Ash Grove", "Pine Road", "Beech Avenue", "Holly Lane",
]

TOWNS = [
    "Redhill", "Guildford", "Crawley", "Horsham", "Dorking",
    "Woking", "Epsom", "Reigate", "Leatherhead", "Farnham",
    "Tonbridge", "Maidstone", "Sevenoaks", "Tunbridge Wells", "Canterbury",
    "Oxford", "Reading", "Winchester", "Chichester", "Brighton",
]

COUNTIES = [
    "Surrey", "West Sussex", "East Sussex", "Kent", "Hampshire",
    "Oxfordshire", "Berkshire", "Buckinghamshire",
]

# Synthetic postcodes: valid format but not real addresses
POSTCODE_PREFIXES = [
    "AA1", "BB2", "CC3", "DD4", "EE5", "FF6", "GG7", "HH8",
    "JJ9", "KK1", "LL2", "MM3", "NN4", "PP5", "QQ6", "RR7",
]

PRACTICE_NAMES = [
    "Oakwood Medical Centre", "The Willows Surgery", "Riverside Health Centre",
    "Greenfield Medical Practice", "The Cedars Surgery", "Hillside Medical Centre",
    "Meadow Lane Surgery", "Parkview Medical Practice", "Brookside Health Centre",
    "Valley Medical Centre", "The Pines Surgery", "Lakeside Medical Practice",
]

DR_NAMES = [
    "Dr A Mitchell", "Dr B Cooper", "Dr C Patel", "Dr D Okafor",
    "Dr E Svensson", "Dr F Romero", "Dr G Tanaka", "Dr H Amara",
    "Dr J Kowalski", "Dr K Nguyen", "Dr L Fraser", "Dr M Santos",
]


class SyntheticMapper:
    """Deterministic mapping from real PII to synthetic equivalents.

    Uses a seeded hash so the same real value always maps to the same
    synthetic value within a document, but different documents get
    different mappings.
    """

    def __init__(self, seed: str):
        self.seed = seed
        self.name_map: dict[str, str] = {}
        self.address_map: dict[str, str] = {}
        self._rng = random.Random(hashlib.sha256(seed.encode()).hexdigest())
        self._used_first = set()
        self._used_last = set()
        self._used_streets = set()
        self._postcode_map: dict[str, str] = {}

    def _pick(self, pool: list[str], used: set[str]) -> str:
        available = [x for x in pool if x not in used]
        if not available:
            # Exhausted pool, allow reuse with suffix
            choice = self._rng.choice(pool)
            return choice + str(self._rng.randint(2, 9))
        choice = self._rng.choice(available)
        used.add(choice)
        return choice

    def map_name(self, real_name: str | None) -> str | None:
        if not real_name:
            return real_name
        if real_name in self.name_map:
            return self.name_map[real_name]
        first = self._pick(FIRST_NAMES, self._used_first)
        last = self._pick(LAST_NAMES, self._used_last)
        synthetic = f"{first} {last}"
        self.name_map[real_name] = synthetic
        return synthetic

    def map_firstname(self, real: str | None) -> str | None:
        if not real:
            return real
        if real in self.name_map:
            return self.name_map[real]
        synth = self._pick(FIRST_NAMES, self._used_first)
        self.name_map[real] = synth
        return synth

    def map_lastname(self, real: str | None) -> str | None:
        if not real:
            return real
        if real in self.name_map:
            return self.name_map[real]
        synth = self._pick(LAST_NAMES, self._used_last)
        self.name_map[real] = synth
        return synth

    def map_dob(self, real_dob: str | None) -> str | None:
        """Replace DOB with synthetic. Preserves format (DD/MM/YYYY or DD/MM/YY)."""
        if not real_dob:
            return real_dob
        if real_dob in self.name_map:
            return self.name_map[real_dob]
        day = self._rng.randint(1, 28)
        month = self._rng.randint(1, 12)
        year = self._rng.randint(1940, 2005)
        if len(real_dob) <= 8:  # DD/MM/YY
            synth = f"{day:02d}/{month:02d}/{year % 100:02d}"
        else:  # DD/MM/YYYY
            synth = f"{day:02d}/{month:02d}/{year}"
        self.name_map[real_dob] = synth
        return synth

    def map_phone(self, real_phone: str | None) -> str | None:
        if not real_phone:
            return real_phone
        if real_phone in self.name_map:
            return self.name_map[real_phone]
        if real_phone.startswith("07"):
            synth = f"07700{self._rng.randint(100000, 999999)}"
        else:
            synth = f"01234{self._rng.randint(100000, 999999)}"
        self.name_map[real_phone] = synth
        return synth

    def map_mrn(self, real_mrn: str | None) -> str | None:
        if not real_mrn:
            return real_mrn
        if real_mrn in self.name_map:
            return self.name_map[real_mrn]
        synth = "".join(self._rng.choices(string.digits, k=len(real_mrn)))
        self.name_map[real_mrn] = synth
        return synth

    def map_postcode(self, real_pc: str | None) -> str | None:
        if not real_pc:
            return real_pc
        if real_pc in self._postcode_map:
            return self._postcode_map[real_pc]
        prefix = self._rng.choice(POSTCODE_PREFIXES)
        suffix = f"{self._rng.randint(1, 9)}{self._rng.choice('ABCDEFGHJKLMNPRSTUVWXYZ')}{self._rng.choice('ABCDEFGHJKLMNPRSTUVWXYZ')}"
        synth = f"{prefix} {suffix}"
        self._postcode_map[real_pc] = synth
        return synth

    def map_address_line(self, real_line: str | None) -> str | None:
        if not real_line:
            return real_line
        if real_line in self.address_map:
            return self.address_map[real_line]
        num = self._rng.randint(1, 150)
        street = self._pick(STREETS, self._used_streets)
        synth = f"{num} {street}"
        self.address_map[real_line] = synth
        return synth

    def map_town(self, real_town: str | None) -> str | None:
        if not real_town:
            return real_town
        if real_town in self.name_map:
            return self.name_map[real_town]
        synth = self._rng.choice(TOWNS)
        self.name_map[real_town] = synth
        return synth

    def map_county(self, real_county: str | None) -> str | None:
        if not real_county:
            return real_county
        if real_county in self.name_map:
            return self.name_map[real_county]
        synth = self._rng.choice(COUNTIES)
        self.name_map[real_county] = synth
        return synth

    def map_gp_name(self, real: str | None) -> str | None:
        if not real:
            return real
        if real in self.name_map:
            return self.name_map[real]
        synth = self._rng.choice(DR_NAMES)
        self.name_map[real] = synth
        return synth

    def map_practice(self, real: str | None) -> str | None:
        if not real:
            return real
        if real in self.name_map:
            return self.name_map[real]
        synth = self._rng.choice(PRACTICE_NAMES).upper()
        self.name_map[real] = synth
        return synth

    def map_ods_code(self, real: str | None) -> str | None:
        if not real:
            return real
        if real in self.name_map:
            return self.name_map[real]
        letter = self._rng.choice("ABCDEFGHJKLMNP")
        num = self._rng.randint(10000, 99999)
        synth = f"{letter}{num}"
        self.name_map[real] = synth
        return synth


def scrub_address_page(page: dict, mapper: SyntheticMapper) -> dict:
    """Scrub a single page entry in an address JSON file."""
    scrubbed = dict(page)

    # Patient
    if "patient" in scrubbed and scrubbed["patient"]:
        p = dict(scrubbed["patient"])
        p["full_name"] = mapper.map_name(p.get("full_name"))
        p["date_of_birth"] = mapper.map_dob(p.get("date_of_birth"))
        p["mrn"] = mapper.map_mrn(p.get("mrn"))
        if "phones" in p and p["phones"]:
            phones = dict(p["phones"])
            phones["home"] = mapper.map_phone(phones.get("home"))
            phones["work"] = mapper.map_phone(phones.get("work"))
            phones["mobile"] = mapper.map_phone(phones.get("mobile"))
            p["phones"] = phones
        scrubbed["patient"] = p

    # Address
    if "address" in scrubbed and scrubbed["address"]:
        a = dict(scrubbed["address"])
        a["line_1"] = mapper.map_address_line(a.get("line_1"))
        a["line_2"] = mapper.map_address_line(a.get("line_2"))
        a["city"] = mapper.map_town(a.get("city"))
        a["county"] = mapper.map_county(a.get("county"))
        a["postcode"] = mapper.map_postcode(a.get("postcode"))
        if a.get("postcode_district"):
            # Derive from mapped postcode
            mapped_pc = a["postcode"]
            a["postcode_district"] = mapped_pc.split()[0] if mapped_pc else None
        scrubbed["address"] = a

    # GP
    if "gp" in scrubbed and scrubbed["gp"]:
        g = dict(scrubbed["gp"])
        g["name"] = mapper.map_gp_name(g.get("name"))
        g["practice"] = mapper.map_practice(g.get("practice"))
        g["address"] = mapper.map_address_line(g.get("address"))
        g["postcode"] = mapper.map_postcode(g.get("postcode"))
        g["ods_code"] = mapper.map_ods_code(g.get("ods_code"))
        g["official_name"] = mapper.map_practice(g.get("official_name"))
        if g.get("nhs_candidates"):
            scrubbed_candidates = []
            for cand in g["nhs_candidates"]:
                sc = dict(cand)
                sc["ods_code"] = mapper.map_ods_code(sc.get("ods_code"))
                sc["name"] = mapper.map_practice(sc.get("name"))
                sc["address_line1"] = mapper.map_address_line(sc.get("address_line1"))
                sc["address_line2"] = mapper.map_address_line(sc.get("address_line2"))
                sc["town"] = mapper.map_town(sc.get("town"))
                sc["postcode"] = mapper.map_postcode(sc.get("postcode"))
                scrubbed_candidates.append(sc)
            g["nhs_candidates"] = scrubbed_candidates
        scrubbed["gp"] = g

    # Specialist name
    if scrubbed.get("specialist_name"):
        scrubbed["specialist_name"] = mapper.map_name(scrubbed["specialist_name"])

    return scrubbed


def scrub_address_file(data: dict, mapper: SyntheticMapper) -> dict:
    """Scrub an entire address JSON file."""
    scrubbed = dict(data)

    # Scrub pages
    if "pages" in scrubbed:
        scrubbed["pages"] = [scrub_address_page(p, mapper) for p in scrubbed["pages"]]

    # Scrub overrides — same structure as pages (gp, patient, address sub-objects)
    # plus override-specific fields (override_date, override_reason, match_address_type)
    if "overrides" in scrubbed and scrubbed["overrides"]:
        scrubbed["overrides"] = [scrub_address_page(ov, mapper) for ov in scrubbed["overrides"]]

    # Scrub enriched data — nested patient/practitioners objects
    if "enriched" in scrubbed and scrubbed["enriched"]:
        e = dict(scrubbed["enriched"])
        # Patient sub-object
        if e.get("patient") and isinstance(e["patient"], dict):
            ep = dict(e["patient"])
            ep["full_name"] = mapper.map_name(ep.get("full_name"))
            ep["surname"] = mapper.map_lastname(ep.get("surname"))
            ep["firstname"] = mapper.map_firstname(ep.get("firstname"))
            ep["date_of_birth"] = mapper.map_dob(ep.get("date_of_birth"))
            e["patient"] = ep
        # Flat patient fields (older format)
        if e.get("patient_canonical"):
            e["patient_canonical"] = mapper.map_name(e["patient_canonical"])
        if e.get("practitioner_canonical"):
            e["practitioner_canonical"] = mapper.map_name(e["practitioner_canonical"])
        if e.get("patient_id"):
            e["patient_id"] = mapper.map_mrn(str(e["patient_id"]))
        if e.get("practitioner_id"):
            e["practitioner_id"] = mapper.map_mrn(str(e["practitioner_id"]))
        # Practitioners array
        if e.get("practitioners") and isinstance(e["practitioners"], list):
            scrubbed_pracs = []
            for prac in e["practitioners"]:
                sp = dict(prac)
                sp["name"] = mapper.map_gp_name(sp.get("name"))
                sp["practice"] = mapper.map_practice(sp.get("practice"))
                if sp.get("address"):
                    sp["address"] = mapper.map_address_line(sp.get("address"))
                if sp.get("postcode"):
                    sp["postcode"] = mapper.map_postcode(sp.get("postcode"))
                if sp.get("ods_code"):
                    sp["ods_code"] = mapper.map_ods_code(sp.get("ods_code"))
                scrubbed_pracs.append(sp)
            e["practitioners"] = scrubbed_pracs
        scrubbed["enriched"] = e

    return scrubbed


def scrub_ocr_text(text: str, mapper: SyntheticMapper) -> str:
    """Replace known PII patterns in OCR full text.

    This is necessarily imperfect — OCR text is free-form. We replace:
    - Names that we've already mapped (from address data)
    - UK postcodes
    - Phone numbers
    - Date patterns that look like DOBs
    """
    result = text

    # Replace all mapped names (longest first to avoid partial replacement)
    for real, synth in sorted(mapper.name_map.items(), key=lambda x: -len(x[0])):
        if real and len(real) > 2:  # Skip very short strings
            result = result.replace(real, synth)
            # Also try case variants
            result = result.replace(real.upper(), synth.upper())
            result = result.replace(real.title(), synth.title())

    # Replace mapped postcodes
    for real_pc, synth_pc in mapper._postcode_map.items():
        if real_pc:
            result = result.replace(real_pc, synth_pc)
            result = result.replace(real_pc.replace(" ", ""), synth_pc.replace(" ", ""))

    # Replace mapped addresses
    for real_addr, synth_addr in mapper.address_map.items():
        if real_addr and len(real_addr) > 3:
            result = result.replace(real_addr, synth_addr)

    # Replace any remaining UK phone numbers not already mapped
    result = re.sub(r'0\d{3,4}\s?\d{6,7}', lambda m: mapper.map_phone(m.group()), result)
    result = re.sub(r'07\d{3}\s?\d{6}', lambda m: mapper.map_phone(m.group()), result)

    return result


def scrub_ocr_file(data: dict, mapper: SyntheticMapper) -> dict:
    """Scrub OCR JSON — replace text content while preserving structure."""
    scrubbed = dict(data)

    if "pages" in scrubbed:
        scrubbed_pages = []
        for page in scrubbed["pages"]:
            sp = dict(page)
            # Scrub full page text
            if "text" in sp and sp["text"]:
                sp["text"] = scrub_ocr_text(sp["text"], mapper)
            # Scrub textBlocks
            if "textBlocks" in sp:
                scrubbed_blocks = []
                for block in sp["textBlocks"]:
                    sb = dict(block)
                    if "text" in sb and sb["text"]:
                        sb["text"] = scrub_ocr_text(sb["text"], mapper)
                    if "lines" in sb:
                        scrubbed_lines = []
                        for line in sb["lines"]:
                            sl = dict(line)
                            if "text" in sl and sl["text"]:
                                sl["text"] = scrub_ocr_text(sl["text"], mapper)
                            if "words" in sl:
                                scrubbed_words = []
                                for word in sl["words"]:
                                    sw = dict(word)
                                    if "text" in sw and sw["text"]:
                                        sw["text"] = scrub_ocr_text(sw["text"], mapper)
                                    scrubbed_words.append(sw)
                                sl["words"] = scrubbed_words
                            scrubbed_lines.append(sl)
                        sb["lines"] = scrubbed_lines
                    scrubbed_blocks.append(sb)
                sp["textBlocks"] = scrubbed_blocks
            scrubbed_pages.append(sp)
        scrubbed["pages"] = scrubbed_pages

    return scrubbed


def select_documents():
    """Select 50 representative documents and copy raw files."""
    if not ADDRESSES_DIR.exists():
        print(f"ERROR: addresses dir not found: {ADDRESSES_DIR}")
        sys.exit(1)

    # Categorise all documents by extraction method
    by_method: dict[str, list[str]] = {}
    has_overrides = []
    no_pages = []

    for f in sorted(ADDRESSES_DIR.iterdir()):
        if not f.name.endswith(".json"):
            continue
        with open(f) as fh:
            data = json.load(fh)
        doc_id = f.stem

        pages = data.get("pages", [])
        if not pages:
            no_pages.append(doc_id)
            continue

        if data.get("overrides"):
            has_overrides.append(doc_id)

        for page in pages:
            method = page.get("extraction", {}).get("method", "unknown")
            by_method.setdefault(method, []).append(doc_id)

    print("Distribution:")
    for method, docs in sorted(by_method.items()):
        unique = list(set(docs))
        print(f"  {method}: {len(unique)} documents ({len(docs)} pages)")
    print(f"  has_overrides: {len(has_overrides)}")
    print(f"  no_pages: {len(no_pages)}")

    # Select sample (target from plan: 10 clearwater, 15 form, 10 label, 10 unstructured, 5 edge)
    rng = random.Random(42)  # reproducible selection
    selected = set()

    # Clearwater forms: 10
    clearwater = list(set(by_method.get("clearwater_form", [])))
    rng.shuffle(clearwater)
    selected.update(clearwater[:10])

    # Form-based: 15 (or all if fewer)
    form = list(set(by_method.get("form", [])))
    rng.shuffle(form)
    selected.update(form[:15])

    # Label-based: 10
    label = list(set(by_method.get("label", [])))
    rng.shuffle(label)
    selected.update(label[:10])

    # Unstructured: all (only 5 exist)
    unstructured = list(set(by_method.get("unstructured", [])))
    selected.update(unstructured)

    # Edge cases: no pages + documents with overrides (up to 5 each)
    selected.update(no_pages[:4])
    # Add override documents not already selected
    override_extra = [d for d in has_overrides if d not in selected]
    rng.shuffle(override_extra)
    selected.update(override_extra[:6])

    print(f"\nSelected {len(selected)} documents")

    # Copy raw files
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    raw_addresses = RAW_DIR / "addresses"
    raw_ocr = RAW_DIR / "ocr"
    raw_addresses.mkdir(exist_ok=True)
    raw_ocr.mkdir(exist_ok=True)

    # Find OCR files — they're in subdirectories
    ocr_index = {}
    if OCR_DIR.exists():
        for ocr_file in OCR_DIR.rglob("*.json"):
            ocr_index[ocr_file.stem] = ocr_file

    copied_addr = 0
    copied_ocr = 0
    for doc_id in sorted(selected):
        # Address file
        addr_src = ADDRESSES_DIR / f"{doc_id}.json"
        if addr_src.exists():
            shutil.copy2(addr_src, raw_addresses / f"{doc_id}.json")
            copied_addr += 1

        # OCR file
        if doc_id in ocr_index:
            shutil.copy2(ocr_index[doc_id], raw_ocr / f"{doc_id}.json")
            copied_ocr += 1

    # Write manifest
    manifest = {
        "selected_documents": sorted(selected),
        "count": len(selected),
        "selection_seed": 42,
        "copied_addresses": copied_addr,
        "copied_ocr": copied_ocr,
    }
    with open(RAW_DIR / "manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"Copied {copied_addr} address files, {copied_ocr} OCR files to {RAW_DIR}")
    print(f"Manifest written to {RAW_DIR / 'manifest.json'}")
    print(f"\n>>> NOW: inspect {RAW_DIR} then run --scrub <<<")


def scrub_documents():
    """Read raw files, scrub PII, write to final fixture directories."""
    raw_addresses = RAW_DIR / "addresses"
    raw_ocr = RAW_DIR / "ocr"

    if not raw_addresses.exists():
        print("ERROR: run --select first")
        sys.exit(1)

    EXTRACTION_DIR.mkdir(parents=True, exist_ok=True)
    input_dir = EXTRACTION_DIR / "input_ocr"
    expected_dir = EXTRACTION_DIR / "expected_addresses"
    input_dir.mkdir(exist_ok=True)
    expected_dir.mkdir(exist_ok=True)

    manifest_path = RAW_DIR / "manifest.json"
    with open(manifest_path) as f:
        manifest = json.load(f)

    scrubbed_count = 0
    for doc_id in manifest["selected_documents"]:
        # Create mapper seeded per-document for consistency
        mapper = SyntheticMapper(seed=f"yiana-fixture-{doc_id}")

        # Scrub address file first (builds the name map)
        addr_raw = raw_addresses / f"{doc_id}.json"
        if addr_raw.exists():
            with open(addr_raw) as f:
                addr_data = json.load(f)

            # Generate synthetic document_id from original
            parts = doc_id.split("_")
            if len(parts) >= 3:
                synth_last = mapper.map_lastname(parts[0])
                synth_first = mapper.map_firstname(parts[1])
                synth_dob_part = parts[2]  # Keep DOB code format but replace
                day = mapper._rng.randint(1, 28)
                month = mapper._rng.randint(1, 12)
                year = mapper._rng.randint(40, 99)
                synth_dob_part = f"{day:02d}{month:02d}{year:02d}"
                synth_doc_id = f"{synth_last}_{synth_first}_{synth_dob_part}"
            else:
                synth_doc_id = f"TestDoc_{scrubbed_count:03d}"

            addr_data["document_id"] = synth_doc_id
            scrubbed_addr = scrub_address_file(addr_data, mapper)
            with open(expected_dir / f"{synth_doc_id}.json", "w") as f:
                json.dump(scrubbed_addr, f, indent=2)

            # Scrub OCR file (uses same mapper so name replacements are consistent)
            ocr_raw = raw_ocr / f"{doc_id}.json"
            if ocr_raw.exists():
                with open(ocr_raw) as f:
                    ocr_data = json.load(f)
                ocr_data["documentId"] = synth_doc_id
                scrubbed_ocr = scrub_ocr_file(ocr_data, mapper)
                with open(input_dir / f"{synth_doc_id}.json", "w") as f:
                    json.dump(scrubbed_ocr, f, indent=2)

            # Write mapping file (real doc_id → synthetic doc_id, for your inspection)
            # This file is gitignored
            mapping_file = RAW_DIR / "id_mapping.json"
            mapping = {}
            if mapping_file.exists():
                with open(mapping_file) as f:
                    mapping = json.load(f)
            mapping[doc_id] = synth_doc_id
            with open(mapping_file, "w") as f:
                json.dump(mapping, f, indent=2)

            scrubbed_count += 1

    print(f"Scrubbed {scrubbed_count} documents")
    print(f"  OCR inputs:        {input_dir}")
    print(f"  Expected addresses: {expected_dir}")
    print(f"  ID mapping:        {RAW_DIR / 'id_mapping.json'}")
    print(f"\n>>> INSPECT scrubbed files, then delete {RAW_DIR} <<<")


def verify_scrubbed():
    """Check scrubbed files for remaining real PII patterns."""
    input_dir = EXTRACTION_DIR / "input_ocr"
    expected_dir = EXTRACTION_DIR / "expected_addresses"

    if not expected_dir.exists():
        print("ERROR: run --scrub first")
        sys.exit(1)

    # Load the raw manifest to get original doc IDs
    manifest_path = RAW_DIR / "manifest.json"
    if not manifest_path.exists():
        print("WARNING: raw manifest not found — can only check format, not PII leakage")
        real_doc_ids = set()
    else:
        with open(manifest_path) as f:
            manifest = json.load(f)
        real_doc_ids = set(manifest["selected_documents"])

    issues = []

    def check_text(text: str, filepath: str, context: str):
        """Check a text string for potential PII leakage."""
        if not text:
            return
        # Check for real document IDs (which contain real names)
        for real_id in real_doc_ids:
            parts = real_id.split("_")
            for part in parts[:-1]:  # Skip DOB part
                if len(part) > 2 and part.lower() in text.lower():
                    issues.append(f"  {filepath} [{context}]: possible real name fragment '{part}'")

    # Check all scrubbed files
    for d in [input_dir, expected_dir]:
        for f in sorted(d.iterdir()):
            if not f.name.endswith(".json"):
                continue
            with open(f) as fh:
                content = fh.read()
            # Quick check: does any real doc ID appear in the file?
            for real_id in real_doc_ids:
                if real_id in content:
                    issues.append(f"  {f.name}: contains real document ID '{real_id}'")

    if issues:
        print(f"POTENTIAL ISSUES ({len(issues)}):")
        for issue in issues[:50]:
            print(issue)
        if len(issues) > 50:
            print(f"  ... and {len(issues) - 50} more")
    else:
        print("No obvious PII leakage detected in scrubbed files.")

    print(f"\nChecked {len(list(input_dir.glob('*.json')))} OCR files, "
          f"{len(list(expected_dir.glob('*.json')))} address files")
    print(">>> YOU must still personally inspect every file <<<")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Scrub PHI from test fixtures")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--select", action="store_true", help="Select 50 documents and copy raw")
    group.add_argument("--scrub", action="store_true", help="Anonymise raw copies")
    group.add_argument("--verify", action="store_true", help="Check for remaining PII")
    args = parser.parse_args()

    if args.select:
        select_documents()
    elif args.scrub:
        scrub_documents()
    elif args.verify:
        verify_scrubbed()
