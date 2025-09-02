#!/usr/bin/env python3
"""
Specialized extractor for Spire Healthcare Registration Forms
These forms have a very consistent structure
"""

import re
from typing import Dict, Optional
import logging

logger = logging.getLogger(__name__)


class SpireFormExtractor:
    """Extract data from Spire Healthcare Registration Forms"""
    
    def extract(self, text: str) -> Optional[Dict]:
        """Extract address data from Spire form"""
        
        result = {}
        
        # Check if this is a Spire form
        if "Spire Healthcare" not in text or "Registration Form" not in text:
            return None
        
        logger.info("Detected Spire Healthcare Registration Form")
        
        # Extract Patient Name
        # In OCR output, the actual name appears after the address fields
        # Two patterns:
        # 1. Name followed by "Date of birth" label
        # 2. Name followed directly by date (no label)
        name_patterns = [
            # Pattern 1: Name before "Date of birth" label
            r'([A-Z][a-z]+,\s*[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s*\n\s*Date of birth',
            # Pattern 2: Name followed directly by date
            r'([A-Z][a-z]+,\s*[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s*\n\s*(\d{1,2}[./]\d{1,2}[./]\d{4})',
        ]
        
        for pattern in name_patterns:
            name_match = re.search(pattern, text, re.IGNORECASE)
            if name_match:
                name = name_match.group(1).strip()
                # Format: "Surname, Firstname" -> "Firstname Surname"
                if ',' in name:
                    parts = name.split(',', 1)
                    result['full_name'] = f"{parts[1].strip()} {parts[0].strip()}"
                else:
                    result['full_name'] = name
                
                # If pattern 2, also extract DOB from the match
                if len(name_match.groups()) > 1 and name_match.group(2):
                    dob = name_match.group(2)
                    result['date_of_birth'] = dob.replace('.', '/')
                break
        
        # Extract Date of Birth (if not already extracted)
        if not result.get('date_of_birth'):
            # Multiple patterns for DOB location
            dob_patterns = [
                # Pattern 1: "Date of birth" label followed by date
                r'Date of birth\s*\n?\s*(\d{1,2}[./]\d{1,2}[./]\d{4})',
                # Pattern 2: Date appears in same row as "Date of birth" (table format)
                r'Date of birth\s+(\d{1,2}[./]\d{1,2}[./]\d{4})',
                # Pattern 3: Any date format that looks like DOB (DD.MM.YYYY or DD/MM/YYYY)
                r'\b(\d{1,2}[./]\d{1,2}[./]19\d{2})\b',  # Birth years likely 1900s
            ]
            
            for pattern in dob_patterns:
                dob_match = re.search(pattern, text, re.IGNORECASE)
                if dob_match:
                    dob = dob_match.group(1)
                    # Normalize to DD/MM/YYYY format
                    result['date_of_birth'] = dob.replace('.', '/')
                    break
        
        # Extract Address components
        # In the OCR, structure is: "Patient name" label, then address lines, then town, county, then actual name
        # Look for address between "Patient name" label and the county name
        addr_pattern = r'Patient name\s*\n(.*?)(?:West Sussex|Surrey|Sussex|Kent|Essex|Berkshire)'
        addr_match = re.search(addr_pattern, text, re.IGNORECASE | re.DOTALL)
        if addr_match:
            addr_block = addr_match.group(1)
            lines = [l.strip() for l in addr_block.split('\n') if l.strip()]
            
            # First 2 lines are typically address
            if len(lines) >= 1:
                result['address_line_1'] = lines[0]
            if len(lines) >= 2:
                result['address_line_2'] = lines[1]
            if len(lines) >= 3:
                # Third line is often the town
                result['city'] = lines[2]
        
        # Alternative: Extract using labels if above didn't work
        if not result.get('city'):
            # Look for actual values in sequence after "Town"
            town_pattern = r'Town\s*\n\s*([^\n]+)(?:\s*\n\s*([^\n]+))?'
            town_match = re.search(town_pattern, text, re.IGNORECASE)
            if town_match:
                # The actual town often appears in the next non-label line
                town_text = town_match.group(1).strip()
                # Skip if it's another label
                if town_text and town_text.lower() not in ['county', 'postcode', 'address', 'town']:
                    result['city'] = town_text
                # Try the second match group if first is a label
                elif town_match.group(2):
                    town_text = town_match.group(2).strip()
                    if town_text and town_text.lower() not in ['county', 'postcode', 'address']:
                        result['city'] = town_text
        
        # Extract city from address lines if needed
        if not result.get('city') or result.get('city').lower() == 'town':
            # Check if address_line_2 contains town info (e.g., "Partridge Green, Horsham")
            if result.get('address_line_2') and ',' in result['address_line_2']:
                parts = result['address_line_2'].split(',')
                # Last part is likely the town
                result['city'] = parts[-1].strip()
                # Keep the full address_line_2 as is for completeness
                # Or split it if you prefer
                # result['address_line_2'] = parts[0].strip()
        
        # Look for county (often appears as "West Sussex", "Surrey", etc.)
        counties = ['Sussex', 'Surrey', 'Kent', 'Hampshire', 'London', 'Essex', 'Berkshire']
        for county in counties:
            if county in text:
                # Find the full county name (e.g., "West Sussex")
                pattern = r'((?:North|South|East|West|Greater)?\s*' + county + ')'
                county_match = re.search(pattern, text, re.IGNORECASE)
                if county_match:
                    result['county'] = county_match.group(1).strip()
                    break
        
        # Extract Postcode
        # UK postcode pattern
        postcode_pattern = r'(?:Postcode\s*\n?\s*)?([A-Z]{1,2}\d{1,2}[A-Z]?\s*\d[A-Z]{2})'
        postcode_matches = re.findall(postcode_pattern, text.upper())
        if postcode_matches:
            # Take the first valid-looking postcode
            for pc in postcode_matches:
                # Validate it's a proper UK postcode format
                if re.match(r'^[A-Z]{1,2}\d{1,2}[A-Z]?\s*\d[A-Z]{2}$', pc):
                    result['postcode'] = pc
                    break
        
        # Extract Phone Numbers
        # IMPORTANT: Only extract PATIENT phones, not emergency contact phones
        # Patient phones appear after "Tel no" labels but BEFORE "Next of kin" section
        
        # Find where emergency contact section starts to avoid those phones
        emergency_start = text.find('Next of kin')
        if emergency_start == -1:
            emergency_start = text.find('Emergency contact')
        if emergency_start == -1:
            emergency_start = text.find('Telephone no. day')  # Emergency section marker
        
        # Get patient section only
        patient_text = text[:emergency_start] if emergency_start > 0 else text
        
        # Look for patient phone numbers in the patient section
        # Phones often appear between "Tel no" labels and "Employer" or after "Age"
        
        # Pattern 1: Look for phones after the Tel no labels
        phone_patterns = [
            # Phones after Age label (common pattern)
            (r'Age\s*\n\s*(\d{5}\s*\d{6}|\d{11})\s*\n\s*(\d{5}\s*\d{6}|\d{11})?', 'after_age'),
            # Phones after Tel no labels
            (r'Tel no[.,]?\s*mobil[el].*?\n(.*?)(?:Sex|Nationality|Employer)', 'after_tel'),
            # Any phones in patient section not near emergency labels
            (r'(\d{5}\s*\d{6}|\d{11})(?:.*?)(\d{5}\s*\d{6}|\d{11})?', 'any_patient'),
        ]
        
        for pattern, method in phone_patterns:
            phone_match = re.search(pattern, patient_text, re.IGNORECASE | re.DOTALL)
            if phone_match:
                # Extract found phones
                found_phones = []
                for group in phone_match.groups():
                    if group and re.match(r'\d{5}\s*\d{6}|\d{11}', group):
                        found_phones.append(re.sub(r'\s+', '', group))
                
                # Assign to appropriate fields
                for phone in found_phones:
                    if phone.startswith('07') and not result.get('phone_mobile'):
                        result['phone_mobile'] = phone
                    elif not result.get('phone_home'):
                        result['phone_home'] = phone
                    elif not result.get('phone_work'):
                        result['phone_work'] = phone
                
                # If we found phones, stop looking
                if result.get('phone_home') or result.get('phone_mobile'):
                    break
        
        # Note: We deliberately SKIP emergency contact phones (Telephone no. day/night)
        # as requested - these belong to next of kin, not the patient
        
        # Extract GP Details
        # In Spire forms, GP info appears as: "Doctor NAME" followed by practice details
        # Pattern 1: Look for "Doctor" or "Dr" followed by name (handle OCR variations)
        doctor_patterns = [
            r'(?:Doctor|Dr|Dostor)\s+([A-Z][A-Z]+)',  # Single word name
            r'(?:Doctor|Dr|Dostor)\s+([A-Z][a-z]+)',  # Properly cased name
        ]
        
        for pattern in doctor_patterns:
            doctor_match = re.search(pattern, text)
            if doctor_match:
                gp_name = doctor_match.group(1)
                # Clean up the name - remove any non-letter characters and title case it
                gp_name = re.sub(r'[^A-Za-z]', '', gp_name)
                result['gp_name'] = f"Dr {gp_name.title()}"
                break
        
        # Pattern 2: After GP label and Address label, find practice details
        # The structure is: GP \n Address \n [other labels] \n Doctor NAME \n PRACTICE NAME \n ADDRESS
        gp_section = re.search(r'GP\s*\n.*?Address.*?\n(.*?)(?:Account|Medical|Reason)', text, re.IGNORECASE | re.DOTALL)
        if gp_section:
            gp_text = gp_section.group(1)
            lines = [l.strip() for l in gp_text.split('\n') if l.strip()]
            
            # Find practice info (usually appears after Doctor name)
            practice_started = False
            practice_lines = []
            
            for line in lines:
                if 'doctor' in line.lower() or 'dr ' in line.lower():
                    practice_started = True
                    continue
                elif practice_started and line and not any(skip in line.lower() for skip in 
                    ['specialist', 'date', 'symptoms', 'consulted', 'reason', 'age', 'tel']):
                    practice_lines.append(line)
                    if len(practice_lines) >= 4:  # Limit to practice name + 3 address lines
                        break
            
            if practice_lines:
                # First line after doctor is usually practice/surgery name
                result['gp_practice'] = practice_lines[0]
                
                # Next lines are address
                if len(practice_lines) > 1:
                    # Join address lines, excluding postcode for separate field
                    address_parts = []
                    for line in practice_lines[1:]:
                        # Check if this line is a postcode
                        pc_match = re.search(r'^([A-Z]{1,2}\d{1,2}[A-Z]?\s*\d[A-Z]{2})$', line.upper())
                        if pc_match:
                            result['gp_postcode'] = pc_match.group(1)
                        else:
                            address_parts.append(line)
                    
                    if address_parts:
                        result['gp_address'] = ', '.join(address_parts)
        
        # Set extraction metadata
        result['extraction_method'] = 'spire_form'
        result['extraction_confidence'] = 0.9  # High confidence for structured forms
        
        # Validate we have minimum required fields
        if result.get('full_name') and result.get('postcode'):
            logger.info(f"Extracted: {result.get('full_name')} - {result.get('postcode')}")
            return result
        
        return None


def extract_from_spire_form(text: str) -> Optional[Dict]:
    """Convenience function to extract from Spire form"""
    extractor = SpireFormExtractor()
    return extractor.extract(text)


if __name__ == "__main__":
    # Test with sample Spire form text
    sample = """
    Spire Healthcare
    Registration Form
    
    Patient name
    Piper, Elizabeth Helenah
    
    Date of birth
    07.10.1933
    
    Address
    The Warren, Rufwood
    Crawley Down
    
    Town
    Crawley
    
    County
    West Sussex
    
    Postcode
    RH10 4HD
    """
    
    result = extract_from_spire_form(sample)
    if result:
        print("Extracted from Spire form:")
        for key, value in result.items():
            print(f"  {key}: {value}")
    else:
        print("Failed to extract")