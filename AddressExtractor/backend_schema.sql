-- Backend Address Database Schema
-- Entity-centric SQLite database for cross-document queries,
-- deduplication, and learning from corrections.
-- Lives on Devon (outside iCloud). Ingests from .addresses/*.json files.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- Documents: one row per JSON file
CREATE TABLE IF NOT EXISTS documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id TEXT UNIQUE NOT NULL,       -- filename stem e.g. "Kelly_Sidney_010575"
    json_hash TEXT NOT NULL,                -- SHA256 for change detection
    schema_version INTEGER,
    extracted_at TEXT,                       -- from JSON extracted_at
    page_count INTEGER,
    ingested_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT
);

-- Patients: deduplicated across documents
-- Dedup key: full_name_normalized + date_of_birth
CREATE TABLE IF NOT EXISTS patients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name TEXT NOT NULL,
    full_name_normalized TEXT NOT NULL,      -- lowercase, no titles, collapsed whitespace
    date_of_birth TEXT,                      -- as extracted (various formats)

    -- Best-known address (updated from most recent extraction)
    address_line_1 TEXT,
    address_line_2 TEXT,
    city TEXT,
    county TEXT,
    postcode TEXT,
    postcode_district TEXT,

    -- Best-known phone numbers
    phone_home TEXT,
    phone_work TEXT,
    phone_mobile TEXT,

    document_count INTEGER NOT NULL DEFAULT 1,
    first_seen_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    last_seen_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_patients_normalized ON patients(full_name_normalized, date_of_birth);
CREATE INDEX IF NOT EXISTS idx_patients_name ON patients(full_name);

-- Practitioners: GPs, opticians, specialists
-- Dedup key: ods_code (if available) OR full_name_normalized + type
CREATE TABLE IF NOT EXISTS practitioners (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL CHECK(type IN ('GP', 'Optician', 'Consultant', 'Other')),
    full_name TEXT,                          -- as extracted
    full_name_normalized TEXT,               -- lowercase, collapsed whitespace
    practice_name TEXT,
    ods_code TEXT,                           -- NHS ODS code if known
    official_name TEXT,                      -- canonical name from ODS lookup
    address TEXT,                            -- full address string
    postcode TEXT,

    document_count INTEGER NOT NULL DEFAULT 1,
    first_seen_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    last_seen_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_practitioners_normalized ON practitioners(full_name_normalized, type);
CREATE INDEX IF NOT EXISTS idx_practitioners_ods ON practitioners(ods_code);

-- Extractions: raw per-page extraction results
-- Preserves all original data verbatim
CREATE TABLE IF NOT EXISTS extractions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id TEXT NOT NULL REFERENCES documents(document_id),
    page_number INTEGER NOT NULL,
    address_type TEXT,                       -- 'patient', 'gp', 'optician', 'specialist'
    is_prime INTEGER,                        -- boolean

    -- Resolved entity FKs (NULL if no entity resolved)
    patient_id INTEGER REFERENCES patients(id),
    practitioner_id INTEGER REFERENCES practitioners(id),

    -- Raw patient fields
    patient_full_name TEXT,
    patient_date_of_birth TEXT,
    patient_phone_home TEXT,
    patient_phone_work TEXT,
    patient_phone_mobile TEXT,

    -- Raw address fields
    address_line_1 TEXT,
    address_line_2 TEXT,
    address_city TEXT,
    address_county TEXT,
    address_postcode TEXT,
    address_postcode_valid INTEGER,
    address_postcode_district TEXT,

    -- Raw GP fields
    gp_name TEXT,
    gp_practice TEXT,
    gp_address TEXT,
    gp_postcode TEXT,

    -- Raw extraction metadata
    extraction_method TEXT,
    extraction_confidence REAL,
    specialist_name TEXT,

    -- Override tracking
    has_override INTEGER NOT NULL DEFAULT 0,
    override_reason TEXT,
    override_date TEXT,

    UNIQUE(document_id, page_number, address_type)
);

CREATE INDEX IF NOT EXISTS idx_extractions_document ON extractions(document_id);
CREATE INDEX IF NOT EXISTS idx_extractions_patient ON extractions(patient_id);
CREATE INDEX IF NOT EXISTS idx_extractions_practitioner ON extractions(practitioner_id);

-- Patient-Document: which patients appear in which documents
CREATE TABLE IF NOT EXISTS patient_documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL REFERENCES patients(id),
    document_id TEXT NOT NULL REFERENCES documents(document_id),
    UNIQUE(patient_id, document_id)
);

CREATE INDEX IF NOT EXISTS idx_patient_documents_patient ON patient_documents(patient_id);
CREATE INDEX IF NOT EXISTS idx_patient_documents_document ON patient_documents(document_id);

-- Patient-Practitioner: which patients are linked to which practitioners
CREATE TABLE IF NOT EXISTS patient_practitioners (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL REFERENCES patients(id),
    practitioner_id INTEGER NOT NULL REFERENCES practitioners(id),
    relationship_type TEXT,                  -- 'GP', 'Optician', 'Consultant', etc.
    document_count INTEGER NOT NULL DEFAULT 1,
    first_seen_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    last_seen_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE(patient_id, practitioner_id, relationship_type)
);

CREATE INDEX IF NOT EXISTS idx_pp_patient ON patient_practitioners(patient_id);
CREATE INDEX IF NOT EXISTS idx_pp_practitioner ON patient_practitioners(practitioner_id);

-- Corrections: Phase 2 schema (created empty now)
-- Will hold override-derived training data for learning
CREATE TABLE IF NOT EXISTS corrections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    extraction_id INTEGER REFERENCES extractions(id),
    document_id TEXT NOT NULL,
    page_number INTEGER NOT NULL,
    field_name TEXT NOT NULL,                -- e.g. 'patient.full_name', 'address.postcode'
    original_value TEXT,
    corrected_value TEXT,
    override_reason TEXT,
    override_date TEXT,
    reviewed INTEGER NOT NULL DEFAULT 0,
    applied_to_rules INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_corrections_document ON corrections(document_id);
CREATE INDEX IF NOT EXISTS idx_corrections_field ON corrections(field_name);

-- Name aliases: Phase 2 schema (created empty now)
-- Maps variant names to canonical forms
CREATE TABLE IF NOT EXISTS name_aliases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    alias TEXT NOT NULL,                     -- the variant form
    canonical TEXT NOT NULL,                 -- the preferred form
    entity_type TEXT NOT NULL CHECK(entity_type IN ('patient', 'practitioner')),
    source TEXT,                             -- 'manual', 'correction', 'learned'
    confidence REAL DEFAULT 1.0,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE(alias, entity_type)
);

CREATE INDEX IF NOT EXISTS idx_name_aliases_alias ON name_aliases(alias, entity_type);
