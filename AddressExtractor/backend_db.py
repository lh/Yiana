#!/usr/bin/env python3
"""
Backend Address Database — Entity-centric SQLite ingestion from .addresses/*.json files.

Reads per-document JSON files (iCloud sync layer), deduplicates patients and
practitioners, and populates a local SQLite database for cross-document queries.

Zero dependencies beyond Python stdlib. Idempotent (hash-based change detection).

Usage:
    python backend_db.py --ingest
    python backend_db.py --stats
    python backend_db.py --merge-candidates
"""

import argparse
import hashlib
import json
import logging
import os
import re
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

logger = logging.getLogger(__name__)

# Default paths
DEFAULT_ADDRESSES_DIR = os.path.expanduser(
    "~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/.addresses"
)
DEFAULT_DB_PATH = "./addresses_backend.db"

# Titles to strip during name normalization
TITLE_PATTERNS = re.compile(
    r"^(mr|mrs|ms|miss|dr|prof|professor|sir|dame|lord|lady|rev|reverend)\b\.?\s*",
    re.IGNORECASE,
)


def normalize_name(name: str) -> str:
    """Normalize a name for deduplication.

    - Lowercase
    - Strip common titles (Mr/Mrs/Dr/etc)
    - Collapse whitespace
    - Remove non-alpha characters except hyphens, apostrophes, spaces
    """
    if not name:
        return ""
    n = name.lower().strip()
    # Strip titles
    n = TITLE_PATTERNS.sub("", n)
    # Remove non-alpha except hyphens, apostrophes, spaces
    n = re.sub(r"[^a-z\s\-']", "", n)
    # Collapse whitespace
    n = re.sub(r"\s+", " ", n).strip()
    return n


def file_hash(path: Path) -> str:
    """Compute SHA256 of a file."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


class BackendDatabase:
    """Entity-centric backend database for address data."""

    def __init__(self, db_path: str = DEFAULT_DB_PATH):
        self.db_path = db_path
        self.conn = None

    def connect(self):
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("PRAGMA journal_mode = WAL")
        self.conn.execute("PRAGMA foreign_keys = ON")

    def close(self):
        if self.conn:
            self.conn.close()
            self.conn = None

    def init_schema(self):
        """Create tables from backend_schema.sql."""
        schema_path = Path(__file__).parent / "backend_schema.sql"
        with open(schema_path) as f:
            schema_sql = f.read()
        self.conn.executescript(schema_sql)
        logger.info("Schema initialized")

    # ------------------------------------------------------------------
    # Ingestion
    # ------------------------------------------------------------------

    def ingest_directory(self, addresses_dir: str = DEFAULT_ADDRESSES_DIR):
        """Ingest all JSON files from the addresses directory."""
        addresses_path = Path(addresses_dir)
        if not addresses_path.is_dir():
            logger.error(f"Addresses directory not found: {addresses_dir}")
            sys.exit(1)

        json_files = sorted(addresses_path.glob("*.json"))
        logger.info(f"Found {len(json_files)} JSON files in {addresses_dir}")

        stats = {"processed": 0, "skipped": 0, "errors": 0}

        for json_path in json_files:
            try:
                if self._ingest_file(json_path):
                    stats["processed"] += 1
                else:
                    stats["skipped"] += 1
            except Exception as e:
                stats["errors"] += 1
                logger.error(f"Error processing {json_path.name}: {e}")

        logger.info(
            f"Ingestion complete: {stats['processed']} processed, "
            f"{stats['skipped']} skipped (unchanged), {stats['errors']} errors"
        )
        return stats

    def _ingest_file(self, json_path: Path) -> bool:
        """Ingest a single JSON file. Returns True if processed, False if skipped."""
        current_hash = file_hash(json_path)
        document_id = json_path.stem

        # Check if document exists with same hash
        row = self.conn.execute(
            "SELECT json_hash FROM documents WHERE document_id = ?", (document_id,)
        ).fetchone()

        if row and row["json_hash"] == current_hash:
            return False  # unchanged

        # Parse JSON
        with open(json_path) as f:
            data = json.load(f)

        # Validate minimal structure
        if "pages" not in data:
            logger.warning(f"No pages array in {json_path.name}, skipping")
            return False

        cursor = self.conn.cursor()

        try:
            # Begin transaction
            cursor.execute("BEGIN")

            # Upsert document
            now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")
            cursor.execute(
                """
                INSERT INTO documents (document_id, json_hash, schema_version,
                                       extracted_at, page_count, ingested_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(document_id) DO UPDATE SET
                    json_hash = excluded.json_hash,
                    schema_version = excluded.schema_version,
                    extracted_at = excluded.extracted_at,
                    page_count = excluded.page_count,
                    updated_at = excluded.updated_at
                """,
                (
                    document_id,
                    current_hash,
                    data.get("schema_version"),
                    data.get("extracted_at"),
                    data.get("page_count"),
                    now,
                    now,
                ),
            )

            # Delete old extractions and links for this document (simpler than diffing)
            old_extraction_ids = [
                r["id"]
                for r in cursor.execute(
                    "SELECT id FROM extractions WHERE document_id = ?", (document_id,)
                ).fetchall()
            ]
            cursor.execute(
                "DELETE FROM extractions WHERE document_id = ?", (document_id,)
            )
            cursor.execute(
                "DELETE FROM patient_documents WHERE document_id = ?", (document_id,)
            )
            # Note: we don't delete patient_practitioners here — those accumulate across
            # documents and are rebuilt via document_count logic

            # Build override map: (page_number, match_address_type) -> override
            override_map = {}
            for override in data.get("overrides", []):
                key = (override.get("page_number"), override.get("match_address_type"))
                # Most recent override wins (by override_date)
                existing = override_map.get(key)
                if existing is None:
                    override_map[key] = override
                else:
                    existing_date = existing.get("override_date", "")
                    new_date = override.get("override_date", "")
                    if new_date > existing_date:
                        override_map[key] = override

            # Track entities seen in this document for M2M linking
            seen_patients = set()
            seen_practitioners = set()  # (practitioner_id, relationship_type)
            page_patients = {}    # page_number -> set of patient_ids
            page_practitioners = {}  # page_number -> set of (practitioner_id, rel_type)
            seen_patient_practitioner_pairs = set()

            for page in data["pages"]:
                page_number = page.get("page_number")
                address_type = page.get("address_type", "patient")

                # Apply override if present
                override_key = (page_number, address_type)
                override = override_map.get(override_key)
                has_override = override is not None

                # Effective values: override fields replace page fields entirely
                patient = (override.get("patient") if override and override.get("patient") else page.get("patient")) or {}
                address = (override.get("address") if override and override.get("address") else page.get("address")) or {}
                gp = (override.get("gp") if override and override.get("gp") else page.get("gp")) or {}
                eff_address_type = (override.get("address_type") if override else None) or address_type
                eff_is_prime = (override.get("is_prime") if override else None)
                if eff_is_prime is None:
                    eff_is_prime = page.get("is_prime")
                eff_specialist = (override.get("specialist_name") if override else None) or page.get("specialist_name")

                extraction = page.get("extraction") or {}
                phones = patient.get("phones") or {}

                # Resolve patient entity
                patient_id = None
                patient_name = patient.get("full_name")
                if patient_name and patient_name.strip():
                    patient_id = self._resolve_patient(
                        cursor,
                        full_name=patient_name,
                        date_of_birth=patient.get("date_of_birth"),
                        address=address,
                        phones=phones,
                    )
                    if patient_id:
                        seen_patients.add(patient_id)

                # Resolve practitioner entity (from GP data)
                practitioner_id = None
                gp_name = gp.get("name")
                gp_practice = gp.get("practice")
                if gp_name and gp_name.strip():
                    practitioner_id = self._resolve_practitioner(
                        cursor,
                        full_name=gp_name,
                        practice_name=gp_practice,
                        address=gp.get("address"),
                        postcode=gp.get("postcode"),
                        prac_type="GP",
                    )

                # If address_type indicates a specialist, also resolve that
                if eff_address_type == "specialist" and eff_specialist:
                    # The specialist is the practitioner for this extraction
                    practitioner_id = self._resolve_practitioner(
                        cursor,
                        full_name=eff_specialist,
                        practice_name=None,
                        address=None,
                        postcode=None,
                        prac_type="Consultant",
                    )

                # Track page-level entities for cross-row linking
                if patient_id:
                    page_patients.setdefault(page_number, set()).add(patient_id)
                if practitioner_id:
                    rel_type = "Consultant" if eff_address_type == "specialist" else "GP"
                    page_practitioners.setdefault(page_number, set()).add((practitioner_id, rel_type))
                    seen_practitioners.add((practitioner_id, rel_type))

                # Insert extraction record
                cursor.execute(
                    """
                    INSERT INTO extractions (
                        document_id, page_number, address_type, is_prime,
                        patient_id, practitioner_id,
                        patient_full_name, patient_date_of_birth,
                        patient_phone_home, patient_phone_work, patient_phone_mobile,
                        address_line_1, address_line_2, address_city, address_county,
                        address_postcode, address_postcode_valid, address_postcode_district,
                        gp_name, gp_practice, gp_address, gp_postcode,
                        extraction_method, extraction_confidence, specialist_name,
                        has_override, override_reason, override_date
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(document_id, page_number, address_type) DO UPDATE SET
                        is_prime = excluded.is_prime,
                        patient_id = excluded.patient_id,
                        practitioner_id = excluded.practitioner_id,
                        patient_full_name = excluded.patient_full_name,
                        patient_date_of_birth = excluded.patient_date_of_birth,
                        patient_phone_home = excluded.patient_phone_home,
                        patient_phone_work = excluded.patient_phone_work,
                        patient_phone_mobile = excluded.patient_phone_mobile,
                        address_line_1 = excluded.address_line_1,
                        address_line_2 = excluded.address_line_2,
                        address_city = excluded.address_city,
                        address_county = excluded.address_county,
                        address_postcode = excluded.address_postcode,
                        address_postcode_valid = excluded.address_postcode_valid,
                        address_postcode_district = excluded.address_postcode_district,
                        gp_name = excluded.gp_name,
                        gp_practice = excluded.gp_practice,
                        gp_address = excluded.gp_address,
                        gp_postcode = excluded.gp_postcode,
                        extraction_method = excluded.extraction_method,
                        extraction_confidence = excluded.extraction_confidence,
                        specialist_name = excluded.specialist_name,
                        has_override = excluded.has_override,
                        override_reason = excluded.override_reason,
                        override_date = excluded.override_date
                    """,
                    (
                        document_id,
                        page_number,
                        eff_address_type,
                        1 if eff_is_prime else 0 if eff_is_prime is not None else None,
                        patient_id,
                        practitioner_id,
                        patient.get("full_name"),
                        patient.get("date_of_birth"),
                        phones.get("home"),
                        phones.get("work"),
                        phones.get("mobile"),
                        address.get("line_1"),
                        address.get("line_2"),
                        address.get("city"),
                        address.get("county"),
                        address.get("postcode"),
                        1 if address.get("postcode_valid") else 0 if address.get("postcode_valid") is not None else None,
                        address.get("postcode_district"),
                        gp.get("name"),
                        gp.get("practice"),
                        gp.get("address"),
                        gp.get("postcode"),
                        extraction.get("method"),
                        extraction.get("confidence"),
                        eff_specialist,
                        1 if has_override else 0,
                        override.get("override_reason") if override else None,
                        override.get("override_date") if override else None,
                    ),
                )

            # Cross-row linking: connect patients and practitioners
            # Strategy 1: link entities sharing the same page_number
            for pg, pids in page_patients.items():
                for pid in pids:
                    for prac_id, rel_type in page_practitioners.get(pg, set()):
                        pair_key = (pid, prac_id, rel_type)
                        if pair_key not in seen_patient_practitioner_pairs:
                            seen_patient_practitioner_pairs.add(pair_key)
                            self._link_patient_practitioner(cursor, pid, prac_id, rel_type)

            # Strategy 2: for single-patient documents, link to all practitioners
            if len(seen_patients) == 1:
                sole_patient = next(iter(seen_patients))
                for prac_id, rel_type in seen_practitioners:
                    pair_key = (sole_patient, prac_id, rel_type)
                    if pair_key not in seen_patient_practitioner_pairs:
                        seen_patient_practitioner_pairs.add(pair_key)
                        self._link_patient_practitioner(cursor, sole_patient, prac_id, rel_type)

            # Link patients <-> document
            for pid in seen_patients:
                cursor.execute(
                    """
                    INSERT INTO patient_documents (patient_id, document_id)
                    VALUES (?, ?)
                    ON CONFLICT(patient_id, document_id) DO NOTHING
                    """,
                    (pid, document_id),
                )

            self.conn.commit()
            return True

        except Exception:
            self.conn.rollback()
            raise

    # ------------------------------------------------------------------
    # Entity resolution
    # ------------------------------------------------------------------

    def _resolve_patient(
        self, cursor, full_name: str, date_of_birth: str, address: dict, phones: dict
    ) -> int | None:
        """Find or create a patient entity. Returns patient_id or None."""
        name_norm = normalize_name(full_name)
        if not name_norm:
            return None

        now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")

        if date_of_birth and date_of_birth.strip():
            # Exact match on (name_norm, dob)
            row = cursor.execute(
                "SELECT id FROM patients WHERE full_name_normalized = ? AND date_of_birth = ?",
                (name_norm, date_of_birth),
            ).fetchone()
        else:
            # Match only if exactly one patient with that name_norm exists
            rows = cursor.execute(
                "SELECT id FROM patients WHERE full_name_normalized = ?",
                (name_norm,),
            ).fetchall()
            row = rows[0] if len(rows) == 1 else None

        if row:
            patient_id = row["id"]
            # Update with any new data
            updates = []
            params = []

            # Update address if extraction has data
            for field, json_key in [
                ("address_line_1", "line_1"),
                ("address_line_2", "line_2"),
                ("city", "city"),
                ("county", "county"),
                ("postcode", "postcode"),
                ("postcode_district", "postcode_district"),
            ]:
                val = address.get(json_key)
                if val and val.strip():
                    updates.append(f"{field} = ?")
                    params.append(val)

            # Update phones
            for field, json_key in [
                ("phone_home", "home"),
                ("phone_work", "work"),
                ("phone_mobile", "mobile"),
            ]:
                val = phones.get(json_key)
                if val and val.strip():
                    updates.append(f"{field} = ?")
                    params.append(val)

            # Always bump count and last_seen
            updates.append("document_count = document_count + 1")
            updates.append("last_seen_at = ?")
            params.append(now)

            if updates:
                params.append(patient_id)
                cursor.execute(
                    f"UPDATE patients SET {', '.join(updates)} WHERE id = ?", params
                )

            return patient_id

        else:
            # Insert new patient
            cursor.execute(
                """
                INSERT INTO patients (
                    full_name, full_name_normalized, date_of_birth,
                    address_line_1, address_line_2, city, county, postcode, postcode_district,
                    phone_home, phone_work, phone_mobile,
                    document_count, first_seen_at, last_seen_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
                """,
                (
                    full_name.strip(),
                    name_norm,
                    date_of_birth if date_of_birth and date_of_birth.strip() else None,
                    address.get("line_1"),
                    address.get("line_2"),
                    address.get("city"),
                    address.get("county"),
                    address.get("postcode"),
                    address.get("postcode_district"),
                    phones.get("home"),
                    phones.get("work"),
                    phones.get("mobile"),
                    now,
                    now,
                ),
            )
            return cursor.lastrowid

    def _resolve_practitioner(
        self,
        cursor,
        full_name: str,
        practice_name: str | None,
        address: str | None,
        postcode: str | None,
        prac_type: str = "GP",
    ) -> int | None:
        """Find or create a practitioner entity. Returns practitioner_id or None."""
        name_norm = normalize_name(full_name)
        if not name_norm:
            return None

        now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")

        # Look up by normalized name + type
        row = cursor.execute(
            "SELECT id FROM practitioners WHERE full_name_normalized = ? AND type = ?",
            (name_norm, prac_type),
        ).fetchone()

        if row:
            practitioner_id = row["id"]
            # Update with any new data
            updates = []
            params = []
            if practice_name and practice_name.strip():
                updates.append("practice_name = ?")
                params.append(practice_name)
            if address and address.strip():
                updates.append("address = ?")
                params.append(address)
            if postcode and postcode.strip():
                updates.append("postcode = ?")
                params.append(postcode)

            updates.append("document_count = document_count + 1")
            updates.append("last_seen_at = ?")
            params.append(now)

            params.append(practitioner_id)
            cursor.execute(
                f"UPDATE practitioners SET {', '.join(updates)} WHERE id = ?", params
            )

            return practitioner_id

        else:
            cursor.execute(
                """
                INSERT INTO practitioners (
                    type, full_name, full_name_normalized, practice_name,
                    address, postcode, document_count, first_seen_at, last_seen_at
                ) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
                """,
                (
                    prac_type,
                    full_name.strip(),
                    name_norm,
                    practice_name,
                    address,
                    postcode,
                    now,
                    now,
                ),
            )
            return cursor.lastrowid

    def _link_patient_practitioner(
        self, cursor, patient_id: int, practitioner_id: int, relationship_type: str
    ):
        """Create or update a patient-practitioner link."""
        now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")
        cursor.execute(
            """
            INSERT INTO patient_practitioners (
                patient_id, practitioner_id, relationship_type,
                document_count, first_seen_at, last_seen_at
            ) VALUES (?, ?, ?, 1, ?, ?)
            ON CONFLICT(patient_id, practitioner_id, relationship_type) DO UPDATE SET
                document_count = patient_practitioners.document_count + 1,
                last_seen_at = excluded.last_seen_at
            """,
            (patient_id, practitioner_id, relationship_type, now, now),
        )

    # ------------------------------------------------------------------
    # Reporting
    # ------------------------------------------------------------------

    def get_stats(self) -> dict:
        """Get database statistics."""
        stats = {}
        for label, query in [
            ("documents", "SELECT COUNT(*) FROM documents"),
            ("extractions", "SELECT COUNT(*) FROM extractions"),
            ("patients", "SELECT COUNT(*) FROM patients"),
            ("practitioners", "SELECT COUNT(*) FROM practitioners"),
            ("patient_document_links", "SELECT COUNT(*) FROM patient_documents"),
            ("patient_practitioner_links", "SELECT COUNT(*) FROM patient_practitioners"),
            ("corrections", "SELECT COUNT(*) FROM corrections"),
            ("name_aliases", "SELECT COUNT(*) FROM name_aliases"),
        ]:
            stats[label] = self.conn.execute(query).fetchone()[0]

        # Practitioner breakdown by type
        rows = self.conn.execute(
            "SELECT type, COUNT(*) as cnt FROM practitioners GROUP BY type ORDER BY cnt DESC"
        ).fetchall()
        stats["practitioners_by_type"] = {r["type"]: r["cnt"] for r in rows}

        # Extractions with overrides
        stats["extractions_with_overrides"] = self.conn.execute(
            "SELECT COUNT(*) FROM extractions WHERE has_override = 1"
        ).fetchone()[0]

        # Patients appearing in multiple documents
        stats["patients_multi_doc"] = self.conn.execute(
            "SELECT COUNT(*) FROM patients WHERE document_count > 1"
        ).fetchone()[0]

        return stats

    def print_stats(self):
        """Print formatted statistics."""
        stats = self.get_stats()
        print("\nBackend Database Statistics")
        print("=" * 45)
        print(f"  Documents:                    {stats['documents']:>6}")
        print(f"  Extractions:                  {stats['extractions']:>6}")
        print(f"    with overrides:             {stats['extractions_with_overrides']:>6}")
        print(f"  Patients (deduplicated):      {stats['patients']:>6}")
        print(f"    in multiple documents:      {stats['patients_multi_doc']:>6}")
        print(f"  Practitioners:                {stats['practitioners']:>6}")
        for ptype, count in stats.get("practitioners_by_type", {}).items():
            print(f"    {ptype}:{'':>{22 - len(ptype)}}{count:>6}")
        print(f"  Patient-Document links:       {stats['patient_document_links']:>6}")
        print(f"  Patient-Practitioner links:   {stats['patient_practitioner_links']:>6}")
        print(f"  Corrections (Phase 2):        {stats['corrections']:>6}")
        print(f"  Name aliases (Phase 2):       {stats['name_aliases']:>6}")

    def print_merge_candidates(self, limit: int = 30):
        """Show potential patient duplicates for manual review."""
        # Find patients with the same normalized name but different DOBs (or NULL DOBs)
        rows = self.conn.execute(
            """
            SELECT full_name_normalized, COUNT(*) as cnt,
                   GROUP_CONCAT(id || ':' || full_name || ':' || COALESCE(date_of_birth, '?'), ' | ') as entries
            FROM patients
            GROUP BY full_name_normalized
            HAVING cnt > 1
            ORDER BY cnt DESC
            LIMIT ?
            """,
            (limit,),
        ).fetchall()

        if not rows:
            print("\nNo merge candidates found (good deduplication).")
            return

        print(f"\nPotential Patient Duplicates ({len(rows)} groups)")
        print("=" * 80)
        for row in rows:
            print(f"\n  [{row['cnt']} records] {row['full_name_normalized']}")
            for entry in row["entries"].split(" | "):
                parts = entry.split(":", 2)
                if len(parts) == 3:
                    pid, name, dob = parts
                    print(f"    ID {pid}: {name} (DOB: {dob})")

    def print_top_practitioners(self, limit: int = 20):
        """Show practitioners with highest document counts."""
        rows = self.conn.execute(
            """
            SELECT pr.full_name, pr.type, pr.practice_name, pr.postcode, pr.document_count
            FROM practitioners pr
            ORDER BY pr.document_count DESC
            LIMIT ?
            """,
            (limit,),
        ).fetchall()

        print(f"\nTop {limit} Practitioners by Document Count")
        print("=" * 80)
        for r in rows:
            practice = f" ({r['practice_name']})" if r["practice_name"] else ""
            postcode = f" [{r['postcode']}]" if r["postcode"] else ""
            print(
                f"  {r['document_count']:>4}x  {r['type']:<12} {r['full_name']}{practice}{postcode}"
            )

    def print_top_patient_practitioner_links(self, limit: int = 10):
        """Show most-attested patient-practitioner relationships."""
        rows = self.conn.execute(
            """
            SELECT p.full_name as patient, pr.full_name as practitioner,
                   pp.relationship_type, pp.document_count
            FROM patient_practitioners pp
            JOIN patients p ON pp.patient_id = p.id
            JOIN practitioners pr ON pp.practitioner_id = pr.id
            ORDER BY pp.document_count DESC
            LIMIT ?
            """,
            (limit,),
        ).fetchall()

        print(f"\nTop {limit} Patient-Practitioner Links")
        print("=" * 80)
        for r in rows:
            print(
                f"  {r['document_count']:>3}x  {r['patient']:<30} -> {r['practitioner']} ({r['relationship_type']})"
            )


def main():
    parser = argparse.ArgumentParser(
        description="Backend Address Database — ingest .addresses/*.json into SQLite"
    )
    parser.add_argument(
        "--ingest",
        action="store_true",
        help="Ingest all JSON files (default action if no flags given)",
    )
    parser.add_argument(
        "--stats", action="store_true", help="Show database statistics"
    )
    parser.add_argument(
        "--merge-candidates",
        action="store_true",
        help="Show potential patient duplicates",
    )
    parser.add_argument(
        "--top-practitioners",
        action="store_true",
        help="Show top practitioners by document count",
    )
    parser.add_argument(
        "--top-links",
        action="store_true",
        help="Show most-attested patient-practitioner links",
    )
    parser.add_argument(
        "--addresses-dir",
        default=DEFAULT_ADDRESSES_DIR,
        help=f"Path to .addresses/ directory (default: {DEFAULT_ADDRESSES_DIR})",
    )
    parser.add_argument(
        "--db-path",
        default=DEFAULT_DB_PATH,
        help=f"Path to SQLite database (default: {DEFAULT_DB_PATH})",
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Verbose logging"
    )

    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)-8s %(message)s",
        datefmt="%H:%M:%S",
    )

    db = BackendDatabase(args.db_path)
    db.connect()
    db.init_schema()

    try:
        if args.stats:
            db.print_stats()
        elif args.merge_candidates:
            db.print_merge_candidates()
        elif args.top_practitioners:
            db.print_top_practitioners()
        elif args.top_links:
            db.print_top_patient_practitioner_links()
        else:
            # Default: ingest
            db.ingest_directory(args.addresses_dir)
            db.print_stats()
    finally:
        db.close()


if __name__ == "__main__":
    main()
