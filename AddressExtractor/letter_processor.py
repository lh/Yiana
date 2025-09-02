#!/usr/bin/env python3
"""
Letter Processor
Integrates clinic notes parser with database and manages the letter workflow
"""

import sqlite3
from pathlib import Path
from typing import List, Dict, Optional
import logging
from datetime import datetime

from clinic_notes_parser import ClinicNotesParser, PatientNote
from letter_system_db_simple import SimpleLetterDatabase
from gp_fuzzy_search import GPFuzzySearch

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class LetterProcessor:
    """Process clinic notes into the letter system"""
    
    def __init__(self, 
                 letter_db_path: str = "letter_addresses.db",
                 gp_db_path: str = "gp_local.db"):
        self.parser = ClinicNotesParser()
        self.db = SimpleLetterDatabase(letter_db_path)
        self.gp_searcher = GPFuzzySearch(gp_db_path) if Path(gp_db_path).exists() else None
    
    def process_notes_file(self, file_path: str) -> Dict:
        """
        Process a clinic notes file
        
        Returns:
            Dict with statistics about processing
        """
        logger.info(f"Processing notes from {file_path}")
        
        # Parse the notes
        notes = self.parser.parse_file(file_path)
        
        if not notes:
            logger.warning("No valid notes found in file")
            return {'total': 0, 'processed': 0, 'missing_addresses': 0}
        
        stats = {
            'total': len(notes),
            'processed': 0,
            'missing_addresses': 0,
            'gps_matched': 0,
            'opticians_added': 0
        }
        
        for note in notes:
            try:
                self._process_single_note(note, stats)
                stats['processed'] += 1
            except Exception as e:
                logger.error(f"Error processing note for {note.patient_name}: {e}")
        
        return stats
    
    def _process_single_note(self, note: PatientNote, stats: Dict):
        """Process a single parsed note"""
        
        # Save or update patient
        patient = self.db.get_patient(note.spire_mrn)
        
        if not patient:
            # New patient - save basic info
            self.db.save_patient(
                spire_mrn=note.spire_mrn,
                full_name=note.patient_name
            )
            logger.info(f"Added new patient: {note.patient_name} ({note.spire_mrn})")
            
            # Check if we need address
            patient = self.db.get_patient(note.spire_mrn)
            if not patient.get('address_line_1'):
                self.db.flag_missing_address(note.spire_mrn, note.patient_name)
                stats['missing_addresses'] += 1
                logger.warning(f"Need address for {note.patient_name}")
        
        # Process GP
        if note.gp_name and note.gp_name != "Unknown GP":
            self._process_gp(note.gp_name, stats)
        
        # Process Optician if present
        if note.optician_name:
            self._process_optician(note.optician_name, stats)
        
        # Log the letter creation (but don't generate yet)
        recipients = [f"Patient"]
        if note.gp_name:
            recipients.append(note.gp_name)
        if note.optician_name:
            recipients.append(note.optician_name)
        
        self.db.log_letter(
            spire_mrn=note.spire_mrn,
            patient_name=note.patient_name,
            letter_date=note.date or datetime.now().strftime('%Y-%m-%d'),
            recipients=", ".join(recipients)
        )
    
    def _process_gp(self, gp_name: str, stats: Dict):
        """Process GP - save and try to match to official database"""
        
        # Check if we already have this GP
        practitioner = self.db.get_practitioner(gp_name)
        
        if not practitioner:
            # Try to find in NHS database if available
            if self.gp_searcher:
                results = self.gp_searcher.search(
                    gp_name=gp_name,
                    limit=1
                )
                
                if results and results[0].score > 30:
                    match = results[0]
                    # Save with full address
                    self.db.save_practitioner(
                        name_as_written=gp_name,
                        prac_type='GP',
                        practice_name=match.name,
                        address_line_1=match.address_1,
                        address_line_2=match.address_2,
                        postcode=match.postcode
                    )
                    logger.info(f"Matched GP {gp_name} to {match.name}")
                    stats['gps_matched'] += 1
                else:
                    # Save without address
                    self.db.save_practitioner(gp_name, 'GP')
                    logger.info(f"Added GP {gp_name} (no address match found)")
            else:
                # No GP database available
                self.db.save_practitioner(gp_name, 'GP')
                logger.info(f"Added GP {gp_name}")
    
    def _process_optician(self, optician_name: str, stats: Dict):
        """Process Optician"""
        
        practitioner = self.db.get_practitioner(optician_name)
        
        if not practitioner:
            self.db.save_practitioner(optician_name, 'Optician')
            logger.info(f"Added Optician {optician_name}")
            stats['opticians_added'] += 1
    
    def get_ready_for_letters(self) -> List[Dict]:
        """
        Get list of patients ready for letter generation
        (have addresses and GP details)
        """
        conn = sqlite3.connect(self.db.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT DISTINCT
                p.spire_mrn,
                p.full_name,
                p.title,
                p.address_line_1,
                p.address_line_2,
                p.city,
                p.postcode,
                l.letter_date,
                l.recipients
            FROM patients p
            JOIN letter_log l ON p.spire_mrn = l.spire_mrn
            WHERE p.address_line_1 IS NOT NULL
            ORDER BY l.created_at DESC
        """)
        
        results = [dict(row) for row in cursor.fetchall()]
        conn.close()
        
        return results
    
    def show_processing_summary(self, stats: Dict):
        """Display processing summary"""
        print("\n" + "="*60)
        print("📊 PROCESSING SUMMARY")
        print("="*60)
        print(f"Total notes found:        {stats['total']:3}")
        print(f"Successfully processed:   {stats['processed']:3}")
        print(f"Missing patient addresses:{stats['missing_addresses']:3}")
        print(f"GPs matched to database:  {stats.get('gps_matched', 0):3}")
        print(f"New opticians added:      {stats.get('opticians_added', 0):3}")
        print("="*60)
        
        # Show database stats
        db_stats = self.db.get_stats()
        print("\n📈 DATABASE STATUS")
        print("-"*40)
        print(f"Total patients:           {db_stats['total_patients']:3}")
        print(f"Patients with addresses:  {db_stats['patients_with_addresses']:3}")
        print(f"GPs in database:          {db_stats.get('gps', 0):3}")
        print(f"Opticians in database:    {db_stats.get('opticians', 0):3}")
        print(f"Letters logged:           {db_stats['letters_created']:3}")
        print(f"Missing addresses:        {db_stats['missing_addresses']:3}")
        
        # Show missing addresses if any
        if db_stats['missing_addresses'] > 0:
            missing = self.db.get_missing_addresses()
            print("\n⚠️  PATIENTS NEEDING ADDRESSES:")
            print("-"*40)
            for p in missing[:5]:  # Show first 5
                print(f"  {p['spire_mrn']} - {p['patient_name']}")
            if len(missing) > 5:
                print(f"  ... and {len(missing)-5} more")


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Process clinic notes for letter system')
    parser.add_argument('file', nargs='?', help='Clinic notes file to process')
    parser.add_argument('--ready', action='store_true', 
                       help='Show patients ready for letter generation')
    parser.add_argument('--missing', action='store_true',
                       help='Show patients missing addresses')
    parser.add_argument('--stats', action='store_true',
                       help='Show database statistics')
    
    args = parser.parse_args()
    
    processor = LetterProcessor()
    
    if args.file:
        stats = processor.process_notes_file(args.file)
        processor.show_processing_summary(stats)
    
    elif args.ready:
        ready = processor.get_ready_for_letters()
        if ready:
            print("\n✉️  PATIENTS READY FOR LETTERS:")
            print("-"*60)
            for patient in ready:
                print(f"{patient['spire_mrn']} - {patient['full_name']}")
                if patient['address_line_1']:
                    print(f"  Address: {patient['address_line_1']}, {patient['postcode']}")
                print(f"  Recipients: {patient['recipients']}")
                print()
        else:
            print("No patients ready for letters (need addresses)")
    
    elif args.missing:
        missing = processor.db.get_missing_addresses()
        if missing:
            print("\n⚠️  PATIENTS NEEDING ADDRESSES:")
            print("-"*60)
            for p in missing:
                print(f"{p['spire_mrn']} - {p['patient_name']} (needed {p['times_needed']}x)")
        else:
            print("✅ No missing addresses")
    
    elif args.stats:
        stats = processor.db.get_stats()
        print("\n📊 DATABASE STATISTICS:")
        print("-"*40)
        for key, value in stats.items():
            label = key.replace('_', ' ').title()
            print(f"{label:25} {value:5}")
    
    else:
        parser.print_help()
        print("\nExample usage:")
        print("  python letter_processor.py clinic_notes.txt")
        print("  python letter_processor.py --ready")
        print("  python letter_processor.py --missing")


if __name__ == "__main__":
    main()