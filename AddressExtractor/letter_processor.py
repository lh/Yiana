#!/usr/bin/env python3
"""
Letter Processor with Title Support
Uses the improved clinic notes parser with title extraction
"""

import argparse
import logging
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime

from clinic_notes_parser_improved import ImprovedClinicNotesParser, PatientNote
from letter_generator_improved import ImprovedLetterGenerator
from letter_system_db_simple import SimpleLetterDatabase

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class LetterProcessor:
    """Process clinic notes with title extraction and generate letters"""
    
    def __init__(self, db_path: str = "letter_addresses.db", consultant_details: Optional[Dict] = None):
        self.parser = ImprovedClinicNotesParser()
        self.db = SimpleLetterDatabase(db_path)
        
        # Default consultant details
        default_consultant = {
            'name': 'Mr Luke Herbert',
            'title': 'Consultant Ophthalmologist',
            'qualifications': 'FRCOphth'
        }
        
        self.generator = ImprovedLetterGenerator(
            db_path=db_path,
            consultant_details=consultant_details or default_consultant
        )
    
    def process_notes_file(self, file_path: str, generate_letters: bool = True) -> Dict:
        """
        Process a clinic notes file, extract titles, save to database, and optionally generate letters
        
        Args:
            file_path: Path to clinic notes file
            generate_letters: Whether to generate letters after parsing
            
        Returns:
            Statistics dictionary
        """
        
        logger.info(f"Processing notes file: {file_path}")
        
        # Parse notes with title extraction
        notes = self.parser.parse_file(file_path)
        
        if not notes:
            logger.warning("No valid notes found in file")
            return {'parsed': 0, 'saved': 0, 'letters_generated': 0}
        
        stats = {
            'parsed': len(notes),
            'saved': 0,
            'letters_generated': 0,
            'missing_addresses': 0,
            'titles_extracted': 0
        }
        
        # Process each note
        for note in notes:
            # Format for database with title
            db_data = self.parser.format_for_database(note)
            
            # Count titles extracted
            if db_data.get('title'):
                stats['titles_extracted'] += 1
                logger.info(f"Title extracted: {db_data['title']} {db_data['full_name']}")
            
            # Save patient to database with title
            try:
                self.db.save_patient(
                    spire_mrn=db_data['spire_mrn'],
                    full_name=db_data['full_name'],
                    title=db_data.get('title'),
                    first_name=db_data.get('first_name'),
                    last_name=db_data.get('last_name')
                )
                stats['saved'] += 1
                
                # Save GP if present
                if note.gp_name and note.gp_name != "Unknown GP":
                    self.db.save_practitioner(
                        name_as_written=note.gp_name,
                        prac_type='GP'
                    )
                
                # Save optician if present
                if note.optician_name:
                    self.db.save_practitioner(
                        name_as_written=note.optician_name,
                        prac_type='Optician'
                    )
                
            except Exception as e:
                logger.error(f"Failed to save patient {db_data['spire_mrn']}: {e}")
        
        # Generate letters if requested
        if generate_letters and stats['saved'] > 0:
            logger.info("Generating letters...")
            letter_stats = self.generator.batch_generate(notes)
            stats['letters_generated'] = letter_stats.get('patient_letters', 0) + letter_stats.get('gp_letters', 0)
            stats['missing_addresses'] = letter_stats.get('failed', 0)
        
        return stats
    
    def test_with_sample_data(self):
        """Test the processor with sample data including titles"""
        
        sample_notes = """
0030730605
Mrs Patricia Wheatley
Doctor E Robinson

Assessment and plan:
Patient seen for routine diabetic review. HbA1c 48 mmol/mol, improved from 52.
Blood pressure 128/78, well controlled on current medication.
Continue metformin 1g BD. Annual review in 12 months.

---

0030730606
Mr John Smith
Dr A Patel
Optician: Mr B Jones

Follow-up post cataract surgery.
Vision 6/6 right eye, 6/9 left eye.
No signs of infection or inflammation.

===

0030730607
Ms Margaret Thompson
Doctor K Williams

New patient consultation for dry eyes.
Symptoms: burning, grittiness, worse in evenings.

---

0015797750
Mrs Catherine Farley
Dr D Holwell

It was a pleasure to meet you in clinic for the first time today. You came to see me because your optician thought the lens capsule had become thickened in the left eye and you might benefit from a YAG capsulotomy. In fact, the lens implant in your left eye has become cloudy. This is bothering you significantly, and after a discussion about the risks and benefits of surgery you have decided you would like to have the lens exchange.

Your vision today measured 6/12 in the left eye with the cloudy lens implant. The lens has developed opacification, which is causing the reduced vision and visual symptoms you are experiencing.

I will arrange lens exchange surgery for your left eye. However, this is a more complex procedure than standard cataract surgery as I need to remove your existing lens implant and replace it with a new one. I will wait for your old measurement details so I can calculate the correct power for your new lens implant.
"""
        
        # Create a temporary file with the sample data
        temp_file = Path("temp_test_notes.txt")
        with open(temp_file, 'w') as f:
            f.write(sample_notes)
        
        # Process the notes
        stats = self.process_notes_file(str(temp_file), generate_letters=False)
        
        # Clean up
        temp_file.unlink()
        
        # Display results
        print("\n📊 Test Results:")
        print(f"   Notes parsed: {stats['parsed']}")
        print(f"   Titles extracted: {stats['titles_extracted']}")
        print(f"   Patients saved: {stats['saved']}")
        
        # Show extracted titles
        print("\n📋 Extracted Titles:")
        notes = self.parser.parse_batch_notes(sample_notes)
        for note in notes:
            print(f"   {note.patient_title or '(no title)'} {note.patient_name} - MRN: {note.spire_mrn}")
        
        return stats


def main():
    """Command-line interface for the letter processor"""
    
    parser = argparse.ArgumentParser(description='Process clinic notes with title extraction')
    parser.add_argument('file', nargs='?', help='Clinic notes file to process')
    parser.add_argument('--test', action='store_true', help='Run test with sample data')
    parser.add_argument('--no-letters', action='store_true', help='Parse only, do not generate letters')
    parser.add_argument('--consultant-name', help='Consultant name (default: Mr Luke Herbert)')
    parser.add_argument('--consultant-title', help='Consultant title (default: Consultant Ophthalmologist)')
    parser.add_argument('--consultant-quals', help='Consultant qualifications (default: FRCOphth)')
    
    args = parser.parse_args()
    
    # Set up consultant details if provided
    consultant_details = None
    if any([args.consultant_name, args.consultant_title, args.consultant_quals]):
        consultant_details = {
            'name': args.consultant_name or 'Mr Luke Herbert',
            'title': args.consultant_title or 'Consultant Ophthalmologist',
            'qualifications': args.consultant_quals or 'FRCOphth'
        }
    
    # Create processor
    processor = LetterProcessor(consultant_details=consultant_details)
    
    if args.test:
        # Run test
        processor.test_with_sample_data()
        
    elif args.file:
        # Process real file
        stats = processor.process_notes_file(
            args.file,
            generate_letters=not args.no_letters
        )
        
        # Display results
        print("\n📊 Processing Complete:")
        print(f"   Notes parsed: {stats['parsed']}")
        print(f"   Titles extracted: {stats['titles_extracted']}")
        print(f"   Patients saved: {stats['saved']}")
        
        if not args.no_letters:
            print(f"   Letters generated: {stats['letters_generated']}")
            if stats['missing_addresses'] > 0:
                print(f"   ⚠️  Missing addresses: {stats['missing_addresses']}")
                print("      Run 'python letter_system_db_simple.py --show-missing' to see which patients need addresses")
    
    else:
        parser.print_help()
        print("\nExamples:")
        print("  python letter_processor.py --test")
        print("  python letter_processor.py clinic_notes.txt")
        print("  python letter_processor.py clinic_notes.txt --no-letters")
        print("  python letter_processor.py clinic_notes.txt --consultant-name 'Mr R Smith'")


if __name__ == "__main__":
    main()
