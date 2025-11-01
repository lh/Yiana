-- Address Overrides Table
-- Stores user corrections while keeping original automated extractions
CREATE TABLE IF NOT EXISTS address_overrides (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id TEXT NOT NULL,
    page_number INTEGER,

    -- Reference to original extraction (NULL if user added new address)
    original_extraction_id INTEGER,

    -- User-corrected data (same structure as extracted_addresses)
    full_name TEXT,
    date_of_birth TEXT,
    address_line_1 TEXT,
    address_line_2 TEXT,
    city TEXT,
    county TEXT,
    postcode TEXT,
    country TEXT DEFAULT 'UK',
    phone_home TEXT,
    phone_work TEXT,
    phone_mobile TEXT,
    gp_name TEXT,
    gp_practice TEXT,
    gp_address TEXT,
    gp_postcode TEXT,
    gp_ods_code TEXT,
    gp_official_name TEXT,

    -- Override metadata
    overridden_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    override_reason TEXT CHECK(override_reason IN ('corrected', 'added', 'removed', 'false_positive')),
    override_notes TEXT,

    -- Training data
    is_training_candidate BOOLEAN DEFAULT 1,
    training_used BOOLEAN DEFAULT 0,

    FOREIGN KEY(original_extraction_id) REFERENCES extracted_addresses(id) ON DELETE SET NULL
);

-- Address Exclusions Table
-- Patterns for addresses to skip (e.g., recipient's own address)
CREATE TABLE IF NOT EXISTS address_exclusions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Pattern matching (SQL LIKE patterns, % = wildcard)
    full_name_pattern TEXT,
    address_pattern TEXT,
    postcode_pattern TEXT,

    -- Exclusion metadata
    exclusion_type TEXT CHECK(exclusion_type IN ('recipient', 'sender', 'clinic_address', 'other')),
    reason TEXT NOT NULL,
    enabled BOOLEAN DEFAULT 1,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_overrides_document ON address_overrides(document_id);
CREATE INDEX IF NOT EXISTS idx_overrides_original ON address_overrides(original_extraction_id);
CREATE INDEX IF NOT EXISTS idx_overrides_training ON address_overrides(is_training_candidate, training_used);
CREATE INDEX IF NOT EXISTS idx_exclusions_enabled ON address_exclusions(enabled);

-- Insert example exclusion (replace with user's actual info)
INSERT OR IGNORE INTO address_exclusions
    (full_name_pattern, exclusion_type, reason)
VALUES
    ('Rose %', 'recipient', 'My own address - I am the recipient'),
    ('Dr Rose %', 'recipient', 'My own address with title');

-- View for combined addresses (overrides take precedence)
CREATE VIEW IF NOT EXISTS addresses_with_overrides AS
SELECT
    COALESCE(ao.document_id, ea.document_id) as document_id,
    COALESCE(ao.page_number, ea.page_number) as page_number,
    COALESCE(ao.full_name, ea.full_name) as full_name,
    COALESCE(ao.date_of_birth, ea.date_of_birth) as date_of_birth,
    COALESCE(ao.address_line_1, ea.address_line_1) as address_line_1,
    COALESCE(ao.address_line_2, ea.address_line_2) as address_line_2,
    COALESCE(ao.city, ea.city) as city,
    COALESCE(ao.county, ea.county) as county,
    COALESCE(ao.postcode, ea.postcode) as postcode,
    COALESCE(ao.country, ea.country) as country,
    COALESCE(ao.phone_home, ea.phone_home) as phone_home,
    COALESCE(ao.phone_work, ea.phone_work) as phone_work,
    COALESCE(ao.phone_mobile, ea.phone_mobile) as phone_mobile,
    COALESCE(ao.gp_name, ea.gp_name) as gp_name,
    COALESCE(ao.gp_practice, ea.gp_practice) as gp_practice,
    COALESCE(ao.gp_address, ea.gp_address) as gp_address,
    COALESCE(ao.gp_postcode, ea.gp_postcode) as gp_postcode,
    ea.extraction_confidence,
    ea.extraction_method,
    CASE
        WHEN ao.id IS NOT NULL THEN 1
        ELSE 0
    END as is_overridden,
    ao.override_reason
FROM extracted_addresses ea
LEFT JOIN address_overrides ao ON ea.id = ao.original_extraction_id
WHERE ao.override_reason IS NULL OR ao.override_reason != 'removed';
