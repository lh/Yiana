#!/usr/bin/env python3
"""
Test Script for Letter System
Run this to verify everything is working correctly
"""

import os
import sqlite3
from pathlib import Path
import shutil
from datetime import datetime

def check_file_exists(filepath, description):
    """Check if a file exists and report"""
    if Path(filepath).exists():
        print(f"✅ {description}: {filepath}")
        return True
    else:
        print(f"❌ {description} NOT FOUND: {filepath}")
        return False

def check_database_tables(db_path, expected_tables):
    """Check if database has expected tables"""
    if not Path(db_path).exists():
        print(f"❌ Database not found: {db_path}")
        return False
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [row[0] for row in cursor.fetchall()]
    conn.close()
    
    for table in expected_tables:
        if table in tables:
            print(f"  ✅ Table '{table}' exists")
        else:
            print(f"  ❌ Table '{table}' missing")
    
    return all(t in tables for t in expected_tables)

def create_test_notes():
    """Create test clinic notes file"""
    test_content = """0030730605
Patricia Wheatley
Doctor E Robinson

Assessment and plan:
Patient seen for routine diabetic review on 15/01/2024. 
HbA1c 48 mmol/mol, improved from 52.
Blood pressure 128/78, well controlled on current medication.
Continue metformin 1g BD. Annual review in 12 months.
Diabetic retinal screening due - referred.

---

0030730606
John Smith
Dr A Patel
Optician: Mr B Jones

Follow-up post cataract surgery 16/01/2024.
Vision 6/6 right eye, 6/9 left eye.
No signs of infection or inflammation.
Drops can be discontinued.
Routine follow-up in 6 months.

===

0030730607
Margaret Thompson
Doctor K Williams

New patient consultation for dry eyes on 17/01/2024.
Symptoms: burning, grittiness, worse in evenings.
Schirmer test: 4mm both eyes.
Started on preservative-free lubricants QDS.
Review in 4 weeks.
"""
    
    with open('test_notes.txt', 'w') as f:
        f.write(test_content)
    
    print("✅ Created test_notes.txt with 3 patient records")
    return 'test_notes.txt'

def run_tests():
    """Run comprehensive system tests"""
    print("="*60)
    print("LETTER SYSTEM TEST SUITE")
    print("="*60)
    
    # 1. Check all required files exist
    print("\n1. CHECKING REQUIRED FILES:")
    print("-"*40)
    
    files_ok = all([
        check_file_exists("clinic_notes_parser.py", "Clinic Notes Parser"),
        check_file_exists("letter_system_db_simple.py", "Simple Database Module"),
        check_file_exists("letter_processor.py", "Letter Processor"),
        check_file_exists("gp_fuzzy_search.py", "GP Search Module"),
        check_file_exists("gp_bulk_importer.py", "GP Bulk Importer")
    ])
    
    # 2. Check databases
    print("\n2. CHECKING DATABASES:")
    print("-"*40)
    
    print("Letter Address Database:")
    letter_db_ok = check_database_tables("letter_addresses.db", 
        ["patients", "practitioners", "letter_log", "missing_addresses"])
    
    print("\nGP Database (optional):")
    gp_db_exists = Path("gp_local.db").exists()
    if gp_db_exists:
        gp_db_ok = check_database_tables("gp_local.db", 
            ["gp_practices_bulk", "gp_practitioners", "practice_aliases"])
    else:
        print("  ⚠️  GP database not found (OK - it's optional)")
        gp_db_ok = True  # Optional, so OK if missing
    
    # 3. Test the parser
    print("\n3. TESTING CLINIC NOTES PARSER:")
    print("-"*40)
    
    test_file = create_test_notes()
    
    # Test parsing
    from clinic_notes_parser import ClinicNotesParser
    parser = ClinicNotesParser()
    notes = parser.parse_file(test_file)
    
    if notes:
        print(f"✅ Parser found {len(notes)} notes")
        for i, note in enumerate(notes, 1):
            print(f"  {i}. {note.patient_name} (MRN: {note.spire_mrn})")
            print(f"     GP: {note.gp_name}")
            if note.optician_name:
                print(f"     Optician: {note.optician_name}")
    else:
        print("❌ Parser failed to find notes")
    
    # 4. Test database operations
    print("\n4. TESTING DATABASE OPERATIONS:")
    print("-"*40)
    
    from letter_system_db_simple import SimpleLetterDatabase
    db = SimpleLetterDatabase("test_letter_db.db")
    
    # Test adding patient
    patient_id = db.save_patient("0123456789", "Test Patient", sex="F", age=45)
    print(f"✅ Added test patient (ID: {patient_id})")
    
    # Test retrieving patient
    patient = db.get_patient("0123456789")
    if patient:
        print(f"✅ Retrieved patient: {patient['full_name']}")
    else:
        print("❌ Failed to retrieve patient")
    
    # Test adding practitioner
    prac_id = db.save_practitioner("Dr Test Doctor", "GP")
    print(f"✅ Added test practitioner (ID: {prac_id})")
    
    # Test flagging missing address
    db.flag_missing_address("0123456789", "Test Patient")
    missing = db.get_missing_addresses()
    if missing:
        print(f"✅ Missing address flagging works ({len(missing)} flagged)")
    else:
        print("❌ Missing address flagging failed")
    
    # Clean up test database
    os.remove("test_letter_db.db")
    
    # 5. Test the full processor
    print("\n5. TESTING LETTER PROCESSOR:")
    print("-"*40)
    
    from letter_processor import LetterProcessor
    processor = LetterProcessor()
    
    stats = processor.process_notes_file(test_file)
    
    print(f"Processed: {stats['processed']}/{stats['total']} notes")
    print(f"Missing addresses: {stats['missing_addresses']}")
    print(f"GPs matched: {stats.get('gps_matched', 0)}")
    print(f"Opticians added: {stats.get('opticians_added', 0)}")
    
    if stats['processed'] == stats['total']:
        print("✅ All notes processed successfully")
    else:
        print(f"⚠️  Only {stats['processed']}/{stats['total']} notes processed")
    
    # 6. Check final database state
    print("\n6. FINAL DATABASE STATE:")
    print("-"*40)
    
    db_stats = processor.db.get_stats()
    print(f"Total patients: {db_stats['total_patients']}")
    print(f"Patients with addresses: {db_stats['patients_with_addresses']}")
    print(f"GPs: {db_stats.get('gps', 0)}")
    print(f"Opticians: {db_stats.get('opticians', 0)}")
    print(f"Letters logged: {db_stats['letters_created']}")
    print(f"Missing addresses: {db_stats['missing_addresses']}")
    
    # 7. Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    
    all_ok = files_ok and letter_db_ok and gp_db_ok and notes and stats['processed'] > 0
    
    if all_ok:
        print("✅ ALL TESTS PASSED - System is working correctly!")
    else:
        print("⚠️  Some tests failed - check output above")
    
    print("\n" + "="*60)
    print("NEXT STEPS TO TEST MANUALLY:")
    print("="*60)
    print("""
1. Process your real clinic notes:
   python letter_processor.py your_clinic_notes.txt

2. Check for missing addresses:
   python letter_processor.py --missing

3. View database statistics:
   python letter_processor.py --stats

4. See who's ready for letters (once addresses added):
   python letter_processor.py --ready

5. To add patient addresses manually:
   python letter_system_db_simple.py --add-patient "0030730605" "Wheatley, Patricia" "F"
   
6. To check GP database (if you've imported it):
   python gp_bulk_importer.py --stats
   
7. To search for a GP practice:
   python gp_fuzzy_search.py --practice "HEALTH CENTRE" --address "BOWERS"
""")
    
    # Clean up
    if Path('test_notes.txt').exists():
        os.remove('test_notes.txt')
    
    return all_ok

if __name__ == "__main__":
    success = run_tests()
    exit(0 if success else 1)