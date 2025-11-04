-- Migration: Add prime address system columns
-- Date: 2025-11-02
-- Description: Adds address_type, is_prime, and specialist_name columns for prime address management

-- Add columns to extracted_addresses table
ALTER TABLE extracted_addresses ADD COLUMN address_type TEXT CHECK(address_type IN ('patient', 'gp', 'optician', 'specialist')) DEFAULT 'patient';
ALTER TABLE extracted_addresses ADD COLUMN is_prime BOOLEAN DEFAULT 0;
ALTER TABLE extracted_addresses ADD COLUMN specialist_name TEXT;

-- Add columns to address_overrides table
ALTER TABLE address_overrides ADD COLUMN address_type TEXT CHECK(address_type IN ('patient', 'gp', 'optician', 'specialist')) DEFAULT 'patient';
ALTER TABLE address_overrides ADD COLUMN is_prime BOOLEAN DEFAULT 0;
ALTER TABLE address_overrides ADD COLUMN specialist_name TEXT;

-- Set default address types based on existing data
-- Addresses with GP information are classified as 'gp', others as 'patient'
UPDATE extracted_addresses
SET address_type = 'gp'
WHERE (gp_name IS NOT NULL AND gp_name != '')
   OR (gp_practice IS NOT NULL AND gp_practice != '');

UPDATE address_overrides
SET address_type = 'gp'
WHERE (gp_name IS NOT NULL AND gp_name != '')
   OR (gp_practice IS NOT NULL AND gp_practice != '');

-- Create index for efficient querying of prime addresses by type
CREATE INDEX IF NOT EXISTS idx_extracted_addresses_type_prime ON extracted_addresses(document_id, address_type, is_prime);
CREATE INDEX IF NOT EXISTS idx_address_overrides_type_prime ON address_overrides(document_id, address_type, is_prime);
