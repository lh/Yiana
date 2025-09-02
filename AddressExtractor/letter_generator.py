#!/usr/bin/env python3
"""
Letter Generator
Generates LaTeX letters from parsed clinic notes and database information
Produces PDFs ready for C5 window envelopes
"""

import os
import subprocess
import shutil
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import logging
import re
import tempfile

from letter_system_db_simple import SimpleLetterDatabase
from clinic_notes_parser import PatientNote

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class LetterGenerator:
    """Generate LaTeX letters and PDFs for medical correspondence"""
    
    def __init__(self, 
                 db_path: str = "letter_addresses.db",
                 template_path: str = "letter_template_simple.tex",  # Use simple template
                 output_dir: str = "letters",
                 consultant_details: Optional[Dict] = None):
        
        self.db = SimpleLetterDatabase(db_path)
        self.template_path = Path(template_path)
        self.output_dir = Path(output_dir)
        
        # Create output directories
        self.print_me_dir = self.output_dir / "print-me"
        self.printed_dir = self.output_dir / "printed"
        self.print_me_dir.mkdir(parents=True, exist_ok=True)
        self.printed_dir.mkdir(parents=True, exist_ok=True)
        
        # Default consultant details (can be overridden)
        self.consultant = consultant_details or {
            'name': 'Mr R Smith',
            'title': 'Consultant Ophthalmologist',
            'qualifications': 'FRCOphth'
        }
        
        # Load template
        if not self.template_path.exists():
            raise FileNotFoundError(f"Template not found: {self.template_path}")
        
        with open(self.template_path, 'r') as f:
            self.template = f.read()
    
    def generate_letter(self, 
                       note: PatientNote,
                       recipient: str = 'patient',
                       copy_to: Optional[List[str]] = None) -> Optional[str]:
        """
        Generate a letter from a parsed note
        
        Args:
            note: Parsed patient note
            recipient: 'patient' or 'gp' 
            copy_to: List of additional recipients
            
        Returns:
            Path to generated PDF or None if failed
        """
        
        # Get patient data
        patient = self.db.get_patient(note.spire_mrn)
        if not patient:
            logger.error(f"Patient {note.spire_mrn} not in database")
            return None
        
        # Check if patient has address
        if recipient == 'patient' and not patient.get('address_line_1'):
            logger.warning(f"No address for patient {patient['full_name']}")
            self.db.flag_missing_address(note.spire_mrn, patient['full_name'])
            return None
        
        # Get GP data if needed
        gp_data = None
        if recipient == 'gp' or (copy_to and note.gp_name in copy_to):
            gp_data = self.db.get_practitioner(note.gp_name) if note.gp_name else None
            if not gp_data or not gp_data.get('address_line_1'):
                logger.warning(f"No address for GP {note.gp_name}")
                return None
        
        # Prepare template variables
        variables = self._prepare_variables(patient, note, recipient, gp_data, copy_to)
        
        # Generate LaTeX
        latex_content = self._fill_template(variables)
        
        # Create temporary directory for LaTeX compilation
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            
            # Write LaTeX file
            tex_file = temp_path / f"{note.spire_mrn}_{recipient}.tex"
            with open(tex_file, 'w') as f:
                f.write(latex_content)
            
            # Compile to PDF
            pdf_path = self._compile_latex(tex_file, temp_path)
            
            if pdf_path and pdf_path.exists():
                # Move to print-me folder
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                final_name = f"{note.spire_mrn}_{patient['full_name'].replace(' ', '_')}_{recipient}_{timestamp}.pdf"
                final_path = self.print_me_dir / final_name
                
                shutil.copy2(pdf_path, final_path)
                logger.info(f"Generated letter: {final_path}")
                
                # Log in database
                recipients = recipient.title()
                if copy_to:
                    recipients += f", {', '.join(copy_to)}"
                
                self.db.log_letter(
                    spire_mrn=note.spire_mrn,
                    patient_name=patient['full_name'],
                    letter_date=note.date or datetime.now().strftime('%Y-%m-%d'),
                    recipients=recipients
                )
                
                return str(final_path)
            else:
                logger.error("PDF compilation failed")
                return None
    
    def _prepare_variables(self, patient: Dict, note: PatientNote, 
                          recipient: str, gp_data: Optional[Dict],
                          copy_to: Optional[List[str]]) -> Dict:
        """Prepare template variables for improved template"""
        
        # Format patient's full address for Re: line
        patient_addr_parts = []
        if patient.get('address_line_1'):
            patient_addr_parts.append(patient['address_line_1'])
        if patient.get('address_line_2'):
            patient_addr_parts.append(patient['address_line_2'])
        if patient.get('city'):
            patient_addr_parts.append(patient['city'])
        if patient.get('postcode'):
            patient_addr_parts.append(patient['postcode'])
        patient_full_address = ' '.join(patient_addr_parts)
        
        # Format patient phone numbers
        phone_parts = []
        if patient.get('phone'):
            phone_parts.append(f"Home: {patient['phone']}")
        if patient.get('phone_mobile'):
            phone_parts.append(f"Mobile: {patient['phone_mobile']}")
        patient_phones = '. '.join(phone_parts) if phone_parts else ''
        
        # Determine recipient details for envelope window
        if recipient == 'patient':
            recipient_name = patient.get('full_name', '')
            recipient_addr1 = patient.get('address_line_1', '')
            recipient_addr2 = patient.get('address_line_2', '') + '\\\\' if patient.get('address_line_2') else ''
            recipient_city = patient.get('city', '')
            recipient_postcode = patient.get('postcode', '')
            # Use title and surname for proper salutation
            if patient.get('title') and patient.get('full_name'):
                surname = patient.get('full_name', '').split()[-1]
                salutation = f"{patient.get('title')} {surname}"
            else:
                salutation = patient.get('full_name', '').split()[-1] if patient.get('full_name') else 'Patient'
        else:  # GP
            if gp_data:
                recipient_name = gp_data.get('full_name', gp_data.get('name_as_written', ''))
                recipient_addr1 = gp_data.get('practice_name', '') or gp_data.get('address_line_1', '')
                recipient_addr2 = (gp_data.get('address_line_1', '') if gp_data.get('practice_name') 
                                  else gp_data.get('address_line_2', ''))
                recipient_addr2 = recipient_addr2 + '\\\\' if recipient_addr2 else ''
                recipient_city = gp_data.get('city', '')
                recipient_postcode = gp_data.get('postcode', '')
                salutation = gp_data.get('salutation', f"Dr {gp_data.get('name_as_written', 'Doctor')}")
            else:
                recipient_name = note.gp_name or 'GP'
                recipient_addr1 = ''
                recipient_addr2 = ''
                recipient_city = ''
                recipient_postcode = ''
                salutation = note.gp_name or 'Doctor'
        
        variables = {
            # Practice/Hospital details for header
            'PRACTICE_NAME': 'Private Practice',
            'PRACTICE_ADDRESS_1': 'Gatwick Park Hospital',
            'PRACTICE_ADDRESS_2': 'Povey Cross Road',
            'PRACTICE_CITY': 'Horley, Surrey',
            'PRACTICE_POSTCODE': 'RH6 0BB',
            'PRACTICE_PHONE': '0207 8849411',
            'HOSPITAL_LOCATION': 'Gatwick Park Hospital.',
            
            # Patient details for Re: line (all in bold)
            'PATIENT_NAME': patient.get('full_name', ''),
            'PATIENT_DOB': patient.get('date_of_birth', 'DOB not available'),
            'SPIRE_MRN': note.spire_mrn,  # Just the number, not GPK prefix
            'PATIENT_FULL_ADDRESS': patient_full_address,
            'PATIENT_PHONES': patient_phones,
            
            # Recipient details for envelope window
            'RECIPIENT_NAME': recipient_name,
            'RECIPIENT_ADDRESS_1': recipient_addr1,
            'RECIPIENT_ADDRESS_2': recipient_addr2,
            'RECIPIENT_CITY': recipient_city,
            'RECIPIENT_POSTCODE': recipient_postcode,
            
            # Letter content
            'SALUTATION': salutation,
            'LETTER_DATE': self._format_date(note.date),
            'CLINICAL_CONTENT': self._escape_latex(note.clinical_content),
            'CLOSING': 'With best wishes' if recipient == 'patient' else 'Yours sincerely',
            
            # Consultant details
            'CONSULTANT_NAME': self.consultant['name'],
            'CONSULTANT_TITLE': self.consultant['title'],
            'CONSULTANT_QUALS': self.consultant['qualifications'],
            
            # Copy list
            'COPY_LIST': ''
        }
        
        # Format copy list if present
        if copy_to:
            copy_lines = []
            for recipient_cc in copy_to:
                # Try to get full details for each CC recipient
                if 'GP' in recipient_cc or 'Dr' in recipient_cc or 'Doctor' in recipient_cc:
                    cc_gp = self.db.get_practitioner(recipient_cc)
                    if cc_gp and cc_gp.get('practice_name'):
                        cc_addr_parts = [cc_gp.get('practice_name', '')]
                        if cc_gp.get('address_line_1'):
                            cc_addr_parts.append(cc_gp['address_line_1'])
                        if cc_gp.get('postcode'):
                            cc_addr_parts.append(cc_gp['postcode'])
                        copy_lines.append(f"Cc: {recipient_cc} {' '.join(cc_addr_parts)}.")
                    else:
                        copy_lines.append(f"Cc: {recipient_cc}")
                else:
                    copy_lines.append(f"Cc: {recipient_cc}")
            
            variables['COPY_LIST'] = '\\\\'.join(copy_lines) if copy_lines else ''
        
        # Format GP in copy list when letter is to patient
        if recipient == 'patient' and note.gp_name and note.gp_name != "Unknown GP":
            if gp_data and gp_data.get('practice_name'):
                gp_addr_parts = [gp_data.get('practice_name', '')]
                if gp_data.get('address_line_1'):
                    gp_addr_parts.append(gp_data['address_line_1'])
                if gp_data.get('postcode'):
                    gp_addr_parts.append(gp_data['postcode'])
                gp_cc = f"Cc: {note.gp_name} {' '.join(gp_addr_parts)}."
            else:
                gp_cc = f"Cc: {note.gp_name}"
            
            if variables['COPY_LIST']:
                variables['COPY_LIST'] = gp_cc + '\\\\' + variables['COPY_LIST']
            else:
                variables['COPY_LIST'] = gp_cc
        
        return variables
    
    def _fill_template(self, variables: Dict) -> str:
        """Fill template with variables"""
        content = self.template
        
        # Replace placeholders
        for key, value in variables.items():
            placeholder = f"<{key}>"
            content = content.replace(placeholder, str(value) if value else '')
        
        return content
    
    def _escape_latex(self, text: str) -> str:
        """Escape special LaTeX characters"""
        if not text:
            return ''
        
        # Characters that need escaping
        replacements = {
            '\\': r'\textbackslash{}',
            '{': r'\{',
            '}': r'\}',
            '$': r'\$',
            '&': r'\&',
            '%': r'\%',
            '#': r'\#',
            '_': r'\_',
            '~': r'\textasciitilde{}',
            '^': r'\textasciicircum{}',
        }
        
        # Apply replacements
        for char, replacement in replacements.items():
            text = text.replace(char, replacement)
        
        # Convert line breaks to LaTeX
        text = text.replace('\n\n', r'\\[10pt]')  # Paragraph breaks
        text = text.replace('\n', r'\\')  # Line breaks
        
        return text
    
    def _format_date(self, date_str: Optional[str]) -> str:
        """Format date for letter"""
        if not date_str:
            return datetime.now().strftime('%d %B %Y')
        
        # Try to parse various date formats
        for fmt in ['%d/%m/%Y', '%d-%m-%Y', '%Y-%m-%d', '%d/%m/%y']:
            try:
                dt = datetime.strptime(date_str, fmt)
                return dt.strftime('%d %B %Y')
            except ValueError:
                continue
        
        # Return as-is if can't parse
        return date_str
    
    def _compile_latex(self, tex_file: Path, working_dir: Path) -> Optional[Path]:
        """Compile LaTeX to PDF using lualatex"""
        
        # Expected PDF output
        pdf_file = tex_file.with_suffix('.pdf')
        
        try:
            # Run lualatex (twice for references)
            for _ in range(2):
                result = subprocess.run(
                    ['lualatex', '-interaction=nonstopmode', tex_file.name],
                    cwd=working_dir,
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                if result.returncode != 0:
                    logger.error(f"LaTeX compilation failed: {result.stderr}")
                    # Try to extract meaningful error
                    for line in result.stdout.split('\n'):
                        if 'Error' in line or '!' in line:
                            logger.error(f"LaTeX error: {line}")
                    return None
            
            if pdf_file.exists():
                return pdf_file
            else:
                logger.error("PDF file not created")
                return None
                
        except subprocess.TimeoutExpired:
            logger.error("LaTeX compilation timed out")
            return None
        except FileNotFoundError:
            logger.error("lualatex not found. Please install LaTeX (e.g., MacTeX on macOS)")
            return None
        except Exception as e:
            logger.error(f"Compilation error: {e}")
            return None
    
    def batch_generate(self, notes: List[PatientNote]) -> Dict:
        """Generate letters for multiple notes"""
        
        stats = {
            'total': len(notes),
            'patient_letters': 0,
            'gp_letters': 0,
            'failed': 0
        }
        
        for note in notes:
            # Generate patient letter
            if self.generate_letter(note, 'patient'):
                stats['patient_letters'] += 1
            else:
                stats['failed'] += 1
            
            # Generate GP letter if GP specified
            if note.gp_name and note.gp_name != "Unknown GP":
                copy_list = []
                if note.optician_name:
                    copy_list.append(note.optician_name)
                
                if self.generate_letter(note, 'gp', copy_to=copy_list):
                    stats['gp_letters'] += 1
        
        return stats
    
    def move_to_printed(self, pdf_path: str) -> bool:
        """Move a letter from print-me to printed folder"""
        
        source = Path(pdf_path)
        if not source.exists():
            logger.error(f"File not found: {pdf_path}")
            return False
        
        dest = self.printed_dir / source.name
        
        try:
            shutil.move(str(source), str(dest))
            logger.info(f"Moved to printed: {dest.name}")
            return True
        except Exception as e:
            logger.error(f"Failed to move file: {e}")
            return False


def main():
    """Test letter generation"""
    import argparse
    from clinic_notes_parser import ClinicNotesParser
    
    parser = argparse.ArgumentParser(description='Generate medical letters')
    parser.add_argument('--notes', help='Clinic notes file to process')
    parser.add_argument('--test', action='store_true', help='Generate test letter')
    parser.add_argument('--list-ready', action='store_true', 
                       help='List letters ready to print')
    parser.add_argument('--mark-printed', help='Move letter to printed folder')
    
    args = parser.parse_args()
    
    generator = LetterGenerator()
    
    if args.test:
        # Create test note
        test_note = PatientNote(
            spire_mrn='0030730605',
            patient_name='Test Patient',
            gp_name='Dr E Robinson',
            optician_name=None,
            clinical_content="""Thank you for attending today's consultation.

Your examination showed:
- Visual acuity: 6/6 right eye, 6/9 left eye
- Intraocular pressures: Normal
- Fundoscopy: Healthy appearance

I recommend:
1. Continue current eye drops
2. Regular monitoring every 6 months
3. Report any changes in vision

Please make a follow-up appointment for 6 months.""",
            date='15/01/2024'
        )
        
        # First, ensure test patient exists in database
        generator.db.save_patient(
            '0030730605',
            'Test Patient',
            sex='M',
            address_line_1='123 Test Street',
            city='London',
            postcode='SW1A 1AA'
        )
        
        # Generate letter
        pdf_path = generator.generate_letter(test_note, 'patient')
        if pdf_path:
            print(f"✅ Test letter generated: {pdf_path}")
            print(f"   Check the print-me folder")
        else:
            print("❌ Failed to generate test letter")
            print("   Make sure pdflatex is installed (e.g., MacTeX)")
    
    elif args.notes:
        # Process real notes
        parser = ClinicNotesParser()
        notes = parser.parse_file(args.notes)
        
        if notes:
            print(f"Found {len(notes)} notes to process")
            stats = generator.batch_generate(notes)
            
            print(f"\n📊 Generation Summary:")
            print(f"   Patient letters: {stats['patient_letters']}")
            print(f"   GP letters: {stats['gp_letters']}")
            print(f"   Failed: {stats['failed']}")
        else:
            print("No valid notes found")
    
    elif args.list_ready:
        # List files ready to print
        print_me_files = list(generator.print_me_dir.glob("*.pdf"))
        
        if print_me_files:
            print(f"\n📄 Letters ready to print ({len(print_me_files)}):")
            for pdf in sorted(print_me_files):
                print(f"   {pdf.name}")
        else:
            print("No letters waiting to be printed")
    
    elif args.mark_printed:
        # Move to printed
        if generator.move_to_printed(args.mark_printed):
            print("✅ Moved to printed folder")
        else:
            print("❌ Failed to move file")
    
    else:
        parser.print_help()
        print("\nExamples:")
        print("  python letter_generator.py --test")
        print("  python letter_generator.py --notes clinic_notes.txt")
        print("  python letter_generator.py --list-ready")


if __name__ == "__main__":
    main()