#!/usr/bin/env python3
"""
Address Extraction Service for Yiana
Processes OCR output to extract UK addresses, names, and DOB
"""

import json
import re
import sqlite3
import os
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class AddressExtractor:
    """Extract addresses from OCR text using pattern matching and heuristics"""
    
    # UK postcode pattern
    UK_POSTCODE_PATTERN = r'[A-Z]{1,2}[0-9][0-9A-Z]?\s*[0-9][A-Z]{2}'
    
    # Date patterns
    DATE_PATTERNS = [
        r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}',  # DD/MM/YYYY or DD-MM-YYYY
        r'\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4}',
        r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{2,4}',
    ]
    
    # Common address keywords
    ADDRESS_KEYWORDS = [
        'address', 'addr', 'residence', 'street', 'road', 'lane', 'avenue',
        'close', 'drive', 'way', 'place', 'court', 'house', 'flat'
    ]
    
    # Form field indicators
    FORM_FIELDS = {
        'name': ['name', 'full name', 'patient name', 'client name'],
        'dob': ['date of birth', 'dob', 'birth date', 'born'],
        'address': ['address', 'addr', 'residence', 'postal address']
    }
    
    def __init__(self, db_path: str = "addresses.db"):
        self.db_path = db_path
        self.init_database()
        
    def init_database(self):
        """Initialize the SQLite database"""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute('''
                CREATE TABLE IF NOT EXISTS extracted_addresses (
                    id INTEGER PRIMARY KEY,
                    document_id TEXT NOT NULL,
                    page_number INTEGER,
                    
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
                    phone_day TEXT,
                    phone_night TEXT,
                    
                    gp_name TEXT,
                    gp_practice TEXT,
                    gp_address TEXT,
                    gp_postcode TEXT,
                    
                    extraction_confidence REAL,
                    extraction_method TEXT,
                    extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    
                    postcode_valid BOOLEAN,
                    postcode_district TEXT,
                    
                    raw_text TEXT,
                    ocr_json TEXT
                )
            ''')
            conn.commit()
    
    def extract_from_ocr_json(self, ocr_json_path: str, document_id: str) -> List[Dict]:
        """Extract addresses from OCR JSON file"""
        with open(ocr_json_path, 'r') as f:
            ocr_data = json.load(f)
        
        results = []
        for page in ocr_data.get('pages', []):
            page_num = page.get('pageNumber', 1)
            text = page.get('text', '')
            
            # Try different extraction methods
            result = None
            
            # Method 0: Spire Healthcare form (highest priority)
            if "Spire Healthcare" in text:
                from spire_form_extractor import extract_from_spire_form
                result = extract_from_spire_form(text)
                if result:
                    result['extraction_method'] = 'spire_form'
            
            # Method 1: Form-based extraction
            if not result:
                result = self.extract_from_form(text, page_num)
                if result:
                    result['extraction_method'] = 'form'
            
            # Method 2: Label-based extraction
            if not result:
                result = self.extract_from_label(text, page_num)
                if result:
                    result['extraction_method'] = 'label'
            
            # Method 3: Unstructured extraction
            if not result:
                result = self.extract_unstructured(text, page_num)
                if result:
                    result['extraction_method'] = 'unstructured'
            
            if result:
                result['document_id'] = document_id
                result['page_number'] = page_num
                result['raw_text'] = text[:1000]  # Store first 1000 chars
                result['ocr_json'] = json.dumps(page)[:2000]
                results.append(result)
        
        return results
    
    def extract_from_form(self, text: str, page_num: int) -> Optional[Dict]:
        """Extract from form-like structure (field: value)"""
        lines = text.split('\n')
        result = {}
        
        for i, line in enumerate(lines):
            line_lower = line.lower()
            
            # Look for name field
            for name_key in self.FORM_FIELDS['name']:
                if name_key in line_lower:
                    # Value might be on same line after colon or on next line
                    if ':' in line:
                        value = line.split(':', 1)[1].strip()
                        if value and not any(k in value.lower() for k in ['date', 'address']):
                            result['full_name'] = self.clean_name(value)
                    elif i + 1 < len(lines):
                        next_line = lines[i + 1].strip()
                        if next_line and not ':' in next_line:
                            result['full_name'] = self.clean_name(next_line)
            
            # Look for DOB field
            for dob_key in self.FORM_FIELDS['dob']:
                if dob_key in line_lower:
                    # Extract date from this or next line
                    date = self.extract_date_from_context(line, lines[i:i+2])
                    if date:
                        result['date_of_birth'] = date
            
            # Look for address field
            for addr_key in self.FORM_FIELDS['address']:
                if addr_key in line_lower:
                    # Extract address from following lines
                    addr = self.extract_address_block(lines[i:i+6])
                    if addr:
                        result.update(addr)
        
        # Must have at least name and address to be valid
        if result.get('full_name') and result.get('postcode'):
            result['extraction_confidence'] = 0.8
            return result
        
        return None
    
    def extract_from_label(self, text: str, page_num: int) -> Optional[Dict]:
        """Extract from address label format"""
        lines = [l.strip() for l in text.split('\n') if l.strip()]
        
        # Look for a block with name and postcode
        for i in range(len(lines) - 3):
            block = lines[i:i+6]
            
            # Check if this block contains a postcode
            postcode = None
            postcode_line = -1
            for j, line in enumerate(block):
                pc = self.extract_postcode(line)
                if pc:
                    postcode = pc
                    postcode_line = j
                    break
            
            if postcode:
                # Assume first line is name
                result = {
                    'full_name': self.clean_name(block[0]),
                    'postcode': postcode,
                    'extraction_confidence': 0.7
                }
                
                # Address lines are between name and postcode
                if postcode_line > 1:
                    addr_lines = block[1:postcode_line]
                    if addr_lines:
                        result['address_line_1'] = addr_lines[0]
                        if len(addr_lines) > 1:
                            result['address_line_2'] = addr_lines[1]
                        
                        # Last line before postcode often has city
                        last_addr = block[postcode_line - 1]
                        result['city'] = self.extract_city(last_addr)
                
                # Look for DOB nearby
                dob = self.find_date_near_name(text, result['full_name'])
                if dob:
                    result['date_of_birth'] = dob
                
                return result
        
        return None
    
    def extract_unstructured(self, text: str, page_num: int) -> Optional[Dict]:
        """Extract from unstructured text using patterns"""
        result = {}
        
        # Find postcode first as anchor
        postcode = self.extract_postcode(text)
        if not postcode:
            return None
        
        result['postcode'] = postcode
        
        # Find name (look for Title + First + Last pattern)
        name = self.extract_name_pattern(text)
        if name:
            result['full_name'] = name
        
        # Find date
        date = self.extract_any_date(text)
        if date:
            result['date_of_birth'] = date
        
        # Extract address around postcode
        addr = self.extract_address_around_postcode(text, postcode)
        if addr:
            result.update(addr)
        
        if result.get('full_name'):
            result['extraction_confidence'] = 0.5
            return result
        
        return None
    
    def extract_postcode(self, text: str) -> Optional[str]:
        """Extract UK postcode from text"""
        match = re.search(self.UK_POSTCODE_PATTERN, text.upper())
        if match:
            return match.group(0).strip()
        return None
    
    def extract_date_from_context(self, line: str, context_lines: List[str]) -> Optional[str]:
        """Extract date from line or context"""
        search_text = ' '.join(context_lines)
        for pattern in self.DATE_PATTERNS:
            match = re.search(pattern, search_text, re.IGNORECASE)
            if match:
                return match.group(0)
        return None
    
    def extract_any_date(self, text: str) -> Optional[str]:
        """Extract any date from text"""
        for pattern in self.DATE_PATTERNS:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(0)
        return None
    
    def extract_address_block(self, lines: List[str]) -> Optional[Dict]:
        """Extract address from a block of lines"""
        result = {}
        addr_lines = []
        
        for line in lines:
            line = line.strip()
            if not line or ':' in line:
                continue
                
            # Check for postcode
            pc = self.extract_postcode(line)
            if pc:
                result['postcode'] = pc
                # Line might also contain city
                city = line.replace(pc, '').strip()
                if city:
                    result['city'] = city
            else:
                addr_lines.append(line)
        
        if addr_lines and result.get('postcode'):
            result['address_line_1'] = addr_lines[0]
            if len(addr_lines) > 1:
                result['address_line_2'] = addr_lines[1]
            if len(addr_lines) > 2 and not result.get('city'):
                result['city'] = addr_lines[2]
        
        return result if result.get('postcode') else None
    
    def extract_address_around_postcode(self, text: str, postcode: str) -> Dict:
        """Extract address lines around a postcode"""
        lines = text.split('\n')
        result = {'postcode': postcode}
        
        # Find line with postcode
        for i, line in enumerate(lines):
            if postcode in line.upper():
                # Get surrounding lines
                start = max(0, i - 3)
                end = min(len(lines), i + 2)
                
                addr_lines = []
                for j in range(start, i):
                    line_clean = lines[j].strip()
                    if line_clean and ':' not in line_clean:
                        addr_lines.append(line_clean)
                
                if addr_lines:
                    result['address_line_1'] = addr_lines[-1]  # Closest to postcode
                    if len(addr_lines) > 1:
                        result['address_line_2'] = addr_lines[-2]
                
                # City often on same line as postcode
                city = lines[i].replace(postcode, '').strip()
                if city:
                    result['city'] = city
                
                break
        
        return result
    
    def extract_name_pattern(self, text: str) -> Optional[str]:
        """Extract name using common patterns"""
        # Look for Mr/Mrs/Ms/Dr followed by names
        pattern = r'(Mr|Mrs|Ms|Dr|Prof)\.?\s+[A-Z][a-z]+\s+[A-Z][a-z]+'
        match = re.search(pattern, text)
        if match:
            return match.group(0)
        
        # Look for "Name:" pattern
        pattern = r'Name:?\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)'
        match = re.search(pattern, text)
        if match:
            return match.group(1)
        
        return None
    
    def find_date_near_name(self, text: str, name: str) -> Optional[str]:
        """Find date near a name (likely DOB)"""
        if not name:
            return None
            
        # Get text around name
        idx = text.find(name)
        if idx >= 0:
            context = text[max(0, idx-100):idx+100]
            return self.extract_any_date(context)
        
        return None
    
    def clean_name(self, name: str) -> str:
        """Clean and validate name"""
        # Remove common non-name elements
        name = re.sub(r'[^a-zA-Z\s\-\']', '', name)
        name = ' '.join(name.split())  # Normalize whitespace
        
        # Title case
        return name.title() if name else ''
    
    def extract_city(self, text: str) -> str:
        """Extract city name from text"""
        # Remove postcode if present
        text = re.sub(self.UK_POSTCODE_PATTERN, '', text.upper()).strip()
        
        # Common UK cities/towns (extend this list)
        cities = ['LONDON', 'MANCHESTER', 'BIRMINGHAM', 'LEEDS', 'GLASGOW', 
                 'REDHILL', 'REIGATE', 'HORLEY', 'BANSTEAD', 'CRAWLEY', 'BRIGHTON']
        
        for city in cities:
            if city in text.upper():
                return city.title()
        
        # Return cleaned text as potential city
        return text.title() if text else ''
    
    def validate_postcode(self, postcode: str) -> Tuple[bool, str]:
        """Validate UK postcode and extract district"""
        if not postcode:
            return False, ''
        
        # Basic UK postcode validation
        pattern = r'^[A-Z]{1,2}[0-9][0-9A-Z]?\s*[0-9][A-Z]{2}$'
        if re.match(pattern, postcode.upper()):
            # Extract district (outward code)
            parts = postcode.upper().split()
            if parts:
                return True, parts[0]
        
        return False, ''
    
    def should_exclude_address(self, result: Dict) -> bool:
        """Check if address matches any exclusion pattern"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute("""
                SELECT full_name_pattern, address_pattern, postcode_pattern, exclusion_type
                FROM address_exclusions
                WHERE enabled = 1
            """)

            exclusions = cursor.fetchall()

        for name_pat, addr_pat, post_pat, ex_type in exclusions:
            # Check name pattern
            if name_pat and result.get('full_name'):
                # Convert SQL LIKE pattern to Python: % -> .*
                regex_pattern = name_pat.replace('%', '.*').replace('_', '.')
                if re.match(regex_pattern, result['full_name'], re.IGNORECASE):
                    logger.info(f"Excluded {result.get('full_name')} - matches {name_pat} ({ex_type})")
                    return True

            # Check address pattern
            if addr_pat:
                address_text = ' '.join(filter(None, [
                    result.get('address_line_1', ''),
                    result.get('address_line_2', ''),
                    result.get('city', ''),
                    result.get('gp_address', '')
                ]))
                if address_text:
                    regex_pattern = addr_pat.replace('%', '.*').replace('_', '.')
                    if re.search(regex_pattern, address_text, re.IGNORECASE):
                        logger.info(f"Excluded address matching {addr_pat} ({ex_type})")
                        return True

            # Check postcode pattern
            if post_pat and result.get('postcode'):
                postcode = result['postcode'].replace(' ', '')
                pattern_no_space = post_pat.replace(' ', '')
                regex_pattern = pattern_no_space.replace('%', '.*').replace('_', '.')
                if re.match(regex_pattern, postcode, re.IGNORECASE):
                    logger.info(f"Excluded postcode {result.get('postcode')} - matches {post_pat} ({ex_type})")
                    return True

        return False

    def save_to_database(self, results: List[Dict]):
        """Save extracted addresses to database (with exclusion filtering)

        Creates separate records for patient and GP data
        """
        if not results:
            return

        saved_count = 0
        excluded_count = 0

        with sqlite3.connect(self.db_path) as conn:
            for result in results:
                # Check exclusions first
                if self.should_exclude_address(result):
                    excluded_count += 1
                    continue

                # Split into separate patient and GP records
                records_to_insert = []

                # Patient record fields
                patient_fields = ['full_name', 'date_of_birth', 'address_line_1', 'address_line_2',
                                'city', 'county', 'postcode', 'country', 'phone_home', 'phone_work',
                                'phone_mobile', 'phone_day', 'phone_night']

                # GP record fields
                gp_fields = ['gp_name', 'gp_practice', 'gp_address', 'gp_postcode']

                # Common fields for both
                common_fields = ['document_id', 'page_number', 'extraction_confidence',
                               'extraction_method', 'raw_text', 'ocr_json']

                # Check if we have patient data
                has_patient_data = any(result.get(field) for field in patient_fields)

                # Check if we have GP data
                has_gp_data = any(result.get(field) for field in gp_fields)

                # Create patient record if patient data exists
                if has_patient_data:
                    patient_record = {field: result.get(field) for field in common_fields + patient_fields}
                    patient_record['address_type'] = 'patient'
                    patient_record['is_prime'] = 0

                    # Validate patient postcode
                    if patient_record.get('postcode'):
                        valid, district = self.validate_postcode(patient_record['postcode'])
                        patient_record['postcode_valid'] = valid
                        patient_record['postcode_district'] = district

                    records_to_insert.append(patient_record)

                # Create GP record if GP data exists
                if has_gp_data:
                    gp_record = {field: result.get(field) for field in common_fields + gp_fields}
                    gp_record['address_type'] = 'gp'
                    gp_record['is_prime'] = 0

                    # Validate GP postcode
                    if gp_record.get('gp_postcode'):
                        valid, district = self.validate_postcode(gp_record['gp_postcode'])
                        gp_record['postcode_valid'] = valid
                        gp_record['postcode_district'] = district

                    records_to_insert.append(gp_record)

                # Insert all records
                for record in records_to_insert:
                    # Remove None values
                    record = {k: v for k, v in record.items() if v is not None}

                    columns = list(record.keys())
                    values = list(record.values())

                    query = f'''
                        INSERT INTO extracted_addresses ({','.join(columns)})
                        VALUES ({','.join(['?' for _ in columns])})
                    '''

                    conn.execute(query, values)
                    saved_count += 1

            conn.commit()
            if saved_count > 0:
                logger.info(f"Saved {saved_count} address records to database")
            if excluded_count > 0:
                logger.info(f"Excluded {excluded_count} addresses (matched exclusion patterns)")


def main():
    """Main entry point for testing"""
    import sys
    
    if len(sys.argv) < 3:
        print("Usage: python address_extractor.py <ocr_json_file> <document_id>")
        sys.exit(1)
    
    ocr_file = sys.argv[1]
    doc_id = sys.argv[2]

    # Use DB_PATH environment variable if set
    db_path = os.environ.get("DB_PATH", "addresses.db")
    extractor = AddressExtractor(db_path)
    results = extractor.extract_from_ocr_json(ocr_file, doc_id)
    
    if results:
        print(f"Extracted {len(results)} addresses:")
        for r in results:
            print(f"  Page {r['page_number']}:")
            print(f"    Name: {r.get('full_name', 'N/A')}")
            print(f"    DOB: {r.get('date_of_birth', 'N/A')}")
            print(f"    Address: {r.get('address_line_1', 'N/A')}")
            print(f"    Postcode: {r.get('postcode', 'N/A')}")
            print(f"    Method: {r.get('extraction_method', 'N/A')}")
            print(f"    Confidence: {r.get('extraction_confidence', 0)}")
        
        extractor.save_to_database(results)
    else:
        print("No addresses found")


if __name__ == "__main__":
    main()
