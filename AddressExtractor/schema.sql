-- Unified Address Database Schema
-- Used by both Python extraction service and Swift iOS/macOS app
-- Version: 2.0 (with address types and user overrides)

-- Main table for extracted addresses
CREATE TABLE IF NOT EXISTS extracted_addresses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id TEXT NOT NULL,
    page_number INTEGER,

    -- Person/Entity Information
    full_name TEXT,
    date_of_birth TEXT,

    -- Address
    address_line_1 TEXT,
    address_line_2 TEXT,
    city TEXT,
    county TEXT,
    postcode TEXT,
    country TEXT DEFAULT 'UK',

    -- Contact Details
    phone_home TEXT,
    phone_work TEXT,
    phone_mobile TEXT,

    -- GP Information (populated when address_type = 'gp')
    gp_name TEXT,
    gp_practice TEXT,
    gp_address TEXT,
    gp_postcode TEXT,
    gp_ods_code TEXT,
    gp_official_name TEXT,

    -- Extraction Metadata
    extraction_confidence REAL,
    extraction_method TEXT,
    extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Validation
    postcode_valid BOOLEAN,
    postcode_district TEXT,

    -- Raw Data
    raw_text TEXT,
    ocr_json TEXT,

    -- Address Type System
    address_type TEXT DEFAULT 'patient',  -- 'patient', 'gp', 'optician', 'specialist', or custom
    is_prime BOOLEAN DEFAULT 0,           -- marks primary address of this type per document
    specialist_name TEXT                  -- name/label when address_type requires subtype
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_extracted_addresses_document_id
    ON extracted_addresses(document_id);
CREATE INDEX IF NOT EXISTS idx_extracted_addresses_type_prime
    ON extracted_addresses(document_id, address_type, is_prime);

-- User overrides table (for corrections made in Swift app)
CREATE TABLE IF NOT EXISTS address_overrides (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    original_id INTEGER NOT NULL,
    document_id TEXT NOT NULL,
    page_number INTEGER,

    -- Overridden fields (all nullable - only non-null values override)
    full_name TEXT,
    date_of_birth TEXT,
    address_line_1 TEXT,
    address_line_2 TEXT,
    city TEXT,
    county TEXT,
    postcode TEXT,
    country TEXT,
    phone_home TEXT,
    phone_work TEXT,
    phone_mobile TEXT,
    gp_name TEXT,
    gp_practice TEXT,
    gp_address TEXT,
    gp_postcode TEXT,
    gp_ods_code TEXT,
    gp_official_name TEXT,
    extraction_confidence REAL,
    extraction_method TEXT,
    extracted_at TEXT,
    postcode_valid BOOLEAN,
    postcode_district TEXT,
    raw_text TEXT,
    ocr_json TEXT,
    address_type TEXT,
    is_prime BOOLEAN,
    specialist_name TEXT,

    -- Override metadata
    override_reason TEXT NOT NULL,  -- 'corrected', 'added', 'removed', 'false_positive'
    override_date TEXT NOT NULL,

    FOREIGN KEY (original_id) REFERENCES extracted_addresses(id)
);

CREATE INDEX IF NOT EXISTS idx_address_overrides_original_id
    ON address_overrides(original_id);
CREATE INDEX IF NOT EXISTS idx_address_overrides_document_id
    ON address_overrides(document_id);

-- Address exclusion patterns (to filter out unwanted extractions)
CREATE TABLE IF NOT EXISTS address_exclusions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name_pattern TEXT,      -- SQL LIKE pattern for name
    address_pattern TEXT,        -- SQL LIKE pattern for address
    postcode_pattern TEXT,       -- SQL LIKE pattern for postcode
    exclusion_type TEXT NOT NULL, -- 'hospital', 'business', 'self', etc.
    enabled BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- GP Practices lookup table
CREATE TABLE IF NOT EXISTS gp_practices (
    id INTEGER PRIMARY KEY,
    internal_name TEXT UNIQUE,   -- Name as extracted from forms
    ods_code TEXT UNIQUE,        -- NHS ODS code
    official_name TEXT,          -- Official NHS name
    address_line1 TEXT,
    address_line2 TEXT,
    address_city TEXT,
    address_county TEXT,
    address_postcode TEXT,
    phone TEXT,
    fax TEXT,
    website TEXT,
    status TEXT,
    last_checked TIMESTAMP,
    raw_fhir_data TEXT
);

-- Manual GP practice data (for practices not in NHS directory)
CREATE TABLE IF NOT EXISTS gp_practices_manual (
    id INTEGER PRIMARY KEY,
    internal_name TEXT UNIQUE,
    official_name TEXT,
    address_line1 TEXT,
    address_line2 TEXT,
    address_city TEXT,
    address_county TEXT,
    address_postcode TEXT,
    phone TEXT,
    gp_names TEXT,               -- JSON list of GP names
    notes TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- GP sync log
CREATE TABLE IF NOT EXISTS gp_sync_log (
    id INTEGER PRIMARY KEY,
    timestamp TIMESTAMP,
    practice_name TEXT,
    result TEXT,
    error TEXT
);
