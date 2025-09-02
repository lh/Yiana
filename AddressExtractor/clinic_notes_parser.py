#!/usr/bin/env python3
"""
Clinic Notes Parser
Extracts patient information, GP details, and clinical content from structured clinic notes
"""

import re
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class PatientNote:
    """Parsed patient note from clinic"""
    spire_mrn: str
    patient_name: str
    gp_name: str
    optician_name: Optional[str]
    clinical_content: str
    date: Optional[str] = None
    
    def get_gpk_number(self) -> str:
        """Format MRN as GPK number"""
        return f"GPK{self.spire_mrn}"


class ClinicNotesParser:
    """Parse clinic notes in the specific format used"""
    
    def __init__(self):
        # Patterns for extracting information
        # MRN patterns - looking for 10-digit numbers
        self.mrn_patterns = [
            r'\b(\d{10})\b',  # Plain 10-digit number
            r'GPK(\d{10})',    # GPK prefix format
            r'MRN[:\s]*(\d{10})',  # MRN: format
        ]
        
        # GP patterns - various formats observed
        self.gp_patterns = [
            r'(?:GP|Doctor|Dr|DR)\s*[:\s]*([A-Za-z\s\-\'\.]+?)(?=\n|$|,)',
            r'Copy to[:\s]*(?:GP|Doctor|Dr)\s*([A-Za-z\s\-\'\.]+?)(?=\n|$|,)',
        ]
        
        # Optician patterns
        self.optician_patterns = [
            r'(?:Optician|Optometrist)[:\s]*([A-Za-z\s\-\'\.]+?)(?=\n|$|,)',
            r'Copy to[:\s]*(?:Optician|Optometrist)\s*([A-Za-z\s\-\'\.]+?)(?=\n|$|,)',
        ]
    
    def parse_single_note(self, text: str) -> Optional[PatientNote]:
        """
        Parse a single patient note section
        
        Expected format:
        0030730605
        Patricia Wheatley
        Doctor E Robinson
        
        Clinical content here...
        """
        
        lines = text.strip().split('\n')
        if len(lines) < 3:
            logger.warning("Note too short to parse")
            return None
        
        # Try to extract MRN from first few lines
        mrn = None
        mrn_line_idx = -1
        
        for idx, line in enumerate(lines[:3]):
            for pattern in self.mrn_patterns:
                match = re.search(pattern, line.strip())
                if match:
                    mrn = match.group(1) if '(' in pattern else match.group(0)
                    # Ensure it's 10 digits
                    if re.match(r'^\d{10}$', mrn):
                        mrn_line_idx = idx
                        break
            if mrn:
                break
        
        if not mrn:
            logger.warning("No valid MRN found in note")
            return None
        
        # Patient name is typically the line after MRN
        patient_name = None
        if mrn_line_idx < len(lines) - 1:
            patient_name = lines[mrn_line_idx + 1].strip()
            # Clean up the name
            patient_name = re.sub(r'^(Mr|Mrs|Ms|Miss|Dr|Master)\s+', '', patient_name, flags=re.IGNORECASE)
        
        if not patient_name:
            logger.warning(f"No patient name found for MRN {mrn}")
            return None
        
        # GP is typically the line after patient name
        gp_name = None
        if mrn_line_idx < len(lines) - 2:
            gp_line = lines[mrn_line_idx + 2].strip()
            
            # Try direct GP patterns
            for pattern in self.gp_patterns:
                match = re.search(pattern, gp_line, re.IGNORECASE)
                if match:
                    gp_name = match.group(1).strip()
                    break
            
            # If no pattern match, but line starts with Doctor/Dr, take the whole line
            if not gp_name:
                if re.match(r'^(Doctor|Dr|DR)\s+', gp_line, re.IGNORECASE):
                    gp_name = gp_line
        
        if not gp_name:
            logger.warning(f"No GP found for patient {patient_name}")
        
        # Look for optician (may not be present)
        optician_name = None
        for line in lines[mrn_line_idx:mrn_line_idx+5]:  # Check first few lines
            for pattern in self.optician_patterns:
                match = re.search(pattern, line, re.IGNORECASE)
                if match:
                    optician_name = match.group(1).strip()
                    break
            if optician_name:
                break
        
        # Clinical content starts after the header lines
        # Usually after a blank line or starting from line 4
        content_start = mrn_line_idx + 3
        
        # Skip any blank lines
        while content_start < len(lines) and not lines[content_start].strip():
            content_start += 1
        
        if content_start >= len(lines):
            logger.warning(f"No clinical content for patient {patient_name}")
            return None
        
        # Join remaining lines as clinical content
        clinical_content = '\n'.join(lines[content_start:]).strip()
        
        # Try to extract date from content
        date = None
        date_match = re.search(r'(\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4})', clinical_content)
        if date_match:
            date = date_match.group(1)
        
        return PatientNote(
            spire_mrn=mrn,
            patient_name=patient_name,
            gp_name=gp_name or "Unknown GP",
            optician_name=optician_name,
            clinical_content=clinical_content,
            date=date
        )
    
    def parse_batch_notes(self, text: str) -> List[PatientNote]:
        """
        Parse multiple patient notes from a single text block
        
        Notes are typically separated by:
        - Multiple newlines
        - Separator lines (---, ===, etc.)
        - Or clear MRN patterns
        """
        
        notes = []
        
        # Split by common separators
        sections = re.split(r'\n{3,}|(?:\n[-=]{3,}\n)', text)
        
        for section in sections:
            section = section.strip()
            if not section:
                continue
            
            # Check if this looks like it contains an MRN
            has_mrn = any(re.search(pattern, section) for pattern in self.mrn_patterns)
            
            if has_mrn:
                note = self.parse_single_note(section)
                if note:
                    notes.append(note)
                    logger.info(f"Parsed note for {note.patient_name} (MRN: {note.spire_mrn})")
        
        # If no sections found, try to parse as single note
        if not notes and text.strip():
            note = self.parse_single_note(text)
            if note:
                notes.append(note)
        
        return notes
    
    def parse_file(self, file_path: str) -> List[PatientNote]:
        """Parse clinic notes from a file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            return self.parse_batch_notes(content)
        
        except Exception as e:
            logger.error(f"Error parsing file {file_path}: {e}")
            return []
    
    def validate_mrn(self, mrn: str) -> bool:
        """Validate that MRN is in correct format"""
        # Should be exactly 10 digits
        return bool(re.match(r'^\d{10}$', mrn))
    
    def format_for_database(self, note: PatientNote) -> Dict:
        """Format parsed note for database insertion"""
        
        # Parse patient name if in "Last, First" format
        patient_name = note.patient_name
        first_name = None
        last_name = None
        
        if ',' in patient_name:
            last_name, first_name = [n.strip() for n in patient_name.split(',', 1)]
        else:
            parts = patient_name.strip().split()
            if len(parts) > 1:
                first_name = ' '.join(parts[:-1])
                last_name = parts[-1]
            else:
                last_name = patient_name
        
        return {
            'spire_mrn': note.spire_mrn,
            'full_name': patient_name,
            'first_name': first_name,
            'last_name': last_name,
            'gp_name': note.gp_name,
            'optician_name': note.optician_name,
            'clinical_content': note.clinical_content,
            'letter_date': note.date or datetime.now().strftime('%Y-%m-%d')
        }


def main():
    """Test the parser with sample data"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Parse clinic notes')
    parser.add_argument('file', nargs='?', help='File containing clinic notes')
    parser.add_argument('--test', action='store_true', help='Test with sample data')
    
    args = parser.parse_args()
    
    notes_parser = ClinicNotesParser()
    
    if args.test:
        # Test with sample data based on user's examples
        sample_notes = """
0030730605
Patricia Wheatley
Doctor E Robinson

Assessment and plan:
Patient seen for routine diabetic review. HbA1c 48 mmol/mol, improved from 52.
Blood pressure 128/78, well controlled on current medication.
Continue metformin 1g BD. Annual review in 12 months.
Diabetic retinal screening due - referred.

---

0030730606
John Smith
Dr A Patel
Optician: Mr B Jones

Follow-up post cataract surgery.
Vision 6/6 right eye, 6/9 left eye.
No signs of infection or inflammation.
Drops can be discontinued.
Routine follow-up in 6 months.

===

0030730607
Margaret Thompson
Doctor K Williams

New patient consultation for dry eyes.
Symptoms: burning, grittiness, worse in evenings.
Schirmer test: 4mm both eyes.
Started on preservative-free lubricants QDS.
Review in 4 weeks.
"""
        
        notes = notes_parser.parse_batch_notes(sample_notes)
        
        print(f"\n📋 Parsed {len(notes)} notes from test data:\n")
        for i, note in enumerate(notes, 1):
            print(f"{i}. Patient: {note.patient_name}")
            print(f"   MRN: {note.spire_mrn} ({note.get_gpk_number()})")
            print(f"   GP: {note.gp_name}")
            if note.optician_name:
                print(f"   Optician: {note.optician_name}")
            print(f"   Content preview: {note.clinical_content[:100]}...")
            print()
    
    elif args.file:
        notes = notes_parser.parse_file(args.file)
        
        if notes:
            print(f"\n📋 Parsed {len(notes)} notes from {args.file}:\n")
            for i, note in enumerate(notes, 1):
                print(f"{i}. {note.patient_name} (MRN: {note.spire_mrn})")
                print(f"   GP: {note.gp_name}")
                if note.optician_name:
                    print(f"   Optician: {note.optician_name}")
                
                # Format for database
                db_data = notes_parser.format_for_database(note)
                print(f"   DB format: {db_data['first_name']} {db_data['last_name']}")
                print()
        else:
            print(f"❌ No valid notes found in {args.file}")
    
    else:
        parser.print_help()
        print("\nExample usage:")
        print("  python clinic_notes_parser.py --test")
        print("  python clinic_notes_parser.py clinic_notes.txt")


if __name__ == "__main__":
    main()