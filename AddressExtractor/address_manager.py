#!/usr/bin/env python3
"""
Address Management Tool
Interactive tool for managing missing patient addresses
"""

import argparse
import sqlite3
from pathlib import Path
from typing import List, Dict, Optional
import json
from datetime import datetime
import logging

from letter_system_db_simple import SimpleLetterDatabase
from gp_fuzzy_search import GPFuzzySearch

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class AddressManager:
    """Manage patient and practitioner addresses"""
    
    def __init__(self, db_path: str = "letter_addresses.db"):
        self.db = SimpleLetterDatabase(db_path)
        self.gp_search = GPFuzzySearch()
    
    def import_addresses_from_csv(self, csv_file: str) -> Dict:
        """
        Import patient addresses from CSV file
        Expected format: MRN,Name,Address1,Address2,City,Postcode,Phone
        """
        import csv
        
        stats = {'imported': 0, 'updated': 0, 'errors': 0}
        
        try:
            with open(csv_file, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                
                for row in reader:
                    try:
                        mrn = row.get('MRN', '').strip()
                        if not mrn:
                            continue
                        
                        # Check if patient exists
                        patient = self.db.get_patient(mrn)
                        if not patient:
                            logger.warning(f"Patient {mrn} not found, skipping")
                            stats['errors'] += 1
                            continue
                        
                        # Update address
                        self.db.save_patient(
                            mrn,
                            patient['full_name'],
                            address_line_1=row.get('Address1', '').strip(),
                            address_line_2=row.get('Address2', '').strip(),
                            city=row.get('City', '').strip(),
                            postcode=row.get('Postcode', '').strip(),
                            phone=row.get('Phone', '').strip()
                        )
                        
                        # Remove from missing addresses
                        conn = sqlite3.connect(self.db.db_path)
                        cursor = conn.cursor()
                        cursor.execute("DELETE FROM missing_addresses WHERE spire_mrn = ?", (mrn,))
                        conn.commit()
                        conn.close()
                        
                        stats['updated'] += 1
                        logger.info(f"Updated address for {mrn}")
                        
                    except Exception as e:
                        logger.error(f"Error processing row: {e}")
                        stats['errors'] += 1
                
        except Exception as e:
            logger.error(f"Error reading CSV file: {e}")
            return stats
        
        return stats
    
    def export_missing_to_csv(self, output_file: str) -> int:
        """Export patients with missing addresses to CSV for data entry"""
        
        conn = sqlite3.connect(self.db.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT m.spire_mrn, m.patient_name, p.title, p.sex, p.age,
                   m.first_seen, m.times_needed
            FROM missing_addresses m
            LEFT JOIN patients p ON m.spire_mrn = p.spire_mrn
            ORDER BY m.times_needed DESC, m.first_seen
        """)
        
        missing = cursor.fetchall()
        conn.close()
        
        if not missing:
            print("No patients with missing addresses")
            return 0
        
        import csv
        
        with open(output_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow(['MRN', 'Name', 'Title', 'Sex', 'Age', 'Address1', 
                           'Address2', 'City', 'Postcode', 'Phone', 
                           'First_Needed', 'Times_Needed'])
            
            for row in missing:
                mrn, name, title, sex, age, first_seen, times = row
                writer.writerow([mrn, name, title or '', sex or '', age or '',
                               '', '', '', '', '',  # Empty address fields for filling
                               first_seen, times])
        
        print(f"✅ Exported {len(missing)} patients to {output_file}")
        print("   Fill in the address fields and import with --import-csv")
        return len(missing)
    
    def interactive_add(self) -> None:
        """Interactive mode to add addresses for missing patients"""
        
        conn = sqlite3.connect(self.db.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT m.spire_mrn, m.patient_name, p.title, p.sex
            FROM missing_addresses m
            LEFT JOIN patients p ON m.spire_mrn = p.spire_mrn
            ORDER BY m.times_needed DESC
            LIMIT 10
        """)
        
        missing = cursor.fetchall()
        conn.close()
        
        if not missing:
            print("✅ No patients with missing addresses!")
            return
        
        print(f"\n📋 Patients needing addresses ({len(missing)} shown):\n")
        
        for i, (mrn, name, title, sex) in enumerate(missing, 1):
            print(f"{i}. {title or ''} {name} (MRN: {mrn})")
        
        print("\nEnter number to add address, or 'q' to quit")
        
        while True:
            choice = input("\nChoice: ").strip()
            
            if choice.lower() == 'q':
                break
            
            try:
                idx = int(choice) - 1
                if 0 <= idx < len(missing):
                    mrn, name, title, sex = missing[idx]
                    print(f"\n📝 Adding address for {title or ''} {name} (MRN: {mrn})")
                    
                    address1 = input("Address Line 1: ").strip()
                    address2 = input("Address Line 2 (optional): ").strip()
                    city = input("City: ").strip()
                    postcode = input("Postcode: ").strip()
                    phone = input("Phone (optional): ").strip()
                    
                    if address1 and city and postcode:
                        self.db.save_patient(
                            mrn, name,
                            title=title,
                            address_line_1=address1,
                            address_line_2=address2 if address2 else None,
                            city=city,
                            postcode=postcode,
                            phone=phone if phone else None
                        )
                        
                        # Remove from missing
                        conn = sqlite3.connect(self.db.db_path)
                        cursor = conn.cursor()
                        cursor.execute("DELETE FROM missing_addresses WHERE spire_mrn = ?", (mrn,))
                        conn.commit()
                        conn.close()
                        
                        print(f"✅ Address saved for {name}")
                    else:
                        print("❌ Address, city, and postcode are required")
                else:
                    print("Invalid choice")
            except ValueError:
                print("Please enter a number or 'q'")
    
    def bulk_match_gps(self) -> Dict:
        """Try to automatically match GPs without addresses to the database"""
        
        conn = sqlite3.connect(self.db.db_path)
        cursor = conn.cursor()
        
        # Find GPs without addresses
        cursor.execute("""
            SELECT DISTINCT name_as_written
            FROM practitioners
            WHERE type = 'GP'
            AND (address_line_1 IS NULL OR address_line_1 = '')
        """)
        
        gps_without_address = cursor.fetchall()
        
        stats = {'matched': 0, 'no_match': 0, 'multiple': 0}
        
        for (gp_name,) in gps_without_address:
            print(f"\n🔍 Searching for: {gp_name}")
            
            results = self.gp_search.search(gp_name)
            
            if len(results) == 1:
                # Single match - auto-save
                result = results[0]
                cursor.execute("""
                    UPDATE practitioners
                    SET practice_name = ?,
                        address_line_1 = ?,
                        address_line_2 = ?,
                        city = ?,
                        postcode = ?,
                        last_updated = ?
                    WHERE name_as_written = ?
                """, (
                    result.get('practice_name'),
                    result['address_line_1'],
                    result.get('address_line_2'),
                    result.get('city'),
                    result['postcode'],
                    datetime.now(),
                    gp_name
                ))
                print(f"   ✅ Matched: {result['practice_name'] or result['address_line_1']}")
                stats['matched'] += 1
                
            elif len(results) > 1:
                print(f"   ⚠️  Multiple matches ({len(results)})")
                stats['multiple'] += 1
                
                # Show options
                for i, result in enumerate(results[:3], 1):
                    print(f"      {i}. {result.get('practice_name', result['address_line_1'])}, {result['postcode']}")
                
            else:
                print(f"   ❌ No matches found")
                stats['no_match'] += 1
        
        conn.commit()
        conn.close()
        
        print(f"\n📊 GP Matching Results:")
        print(f"   Matched: {stats['matched']}")
        print(f"   No match: {stats['no_match']}")
        print(f"   Multiple matches: {stats['multiple']}")
        
        return stats
    
    def validate_addresses(self) -> Dict:
        """Validate all addresses for completeness"""
        
        conn = sqlite3.connect(self.db.db_path)
        cursor = conn.cursor()
        
        # Check patients
        cursor.execute("""
            SELECT COUNT(*) FROM patients
            WHERE address_line_1 IS NOT NULL
            AND city IS NOT NULL
            AND postcode IS NOT NULL
        """)
        patients_complete = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM patients")
        patients_total = cursor.fetchone()[0]
        
        # Check GPs
        cursor.execute("""
            SELECT COUNT(*) FROM practitioners
            WHERE type = 'GP'
            AND address_line_1 IS NOT NULL
            AND postcode IS NOT NULL
        """)
        gps_complete = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM practitioners WHERE type = 'GP'")
        gps_total = cursor.fetchone()[0]
        
        conn.close()
        
        print("\n📊 Address Validation Report:\n")
        print(f"Patients:")
        print(f"  Complete: {patients_complete}/{patients_total} ({patients_complete*100//patients_total if patients_total else 0}%)")
        print(f"  Missing: {patients_total - patients_complete}")
        
        print(f"\nGPs:")
        print(f"  Complete: {gps_complete}/{gps_total} ({gps_complete*100//gps_total if gps_total else 0}%)")
        print(f"  Missing: {gps_total - gps_complete}")
        
        return {
            'patients_complete': patients_complete,
            'patients_total': patients_total,
            'gps_complete': gps_complete,
            'gps_total': gps_total
        }


def main():
    """Command-line interface"""
    
    parser = argparse.ArgumentParser(description='Address Management Tool')
    parser.add_argument('--import-csv', help='Import addresses from CSV file')
    parser.add_argument('--export-missing', help='Export missing addresses to CSV')
    parser.add_argument('--interactive', action='store_true', 
                       help='Interactive mode to add addresses')
    parser.add_argument('--match-gps', action='store_true',
                       help='Try to auto-match GPs to database')
    parser.add_argument('--validate', action='store_true',
                       help='Validate address completeness')
    
    args = parser.parse_args()
    
    manager = AddressManager()
    
    if args.import_csv:
        stats = manager.import_addresses_from_csv(args.import_csv)
        print(f"\n📊 Import Results:")
        print(f"   Updated: {stats['updated']}")
        print(f"   Errors: {stats['errors']}")
        
    elif args.export_missing:
        count = manager.export_missing_to_csv(args.export_missing)
        
    elif args.interactive:
        manager.interactive_add()
        
    elif args.match_gps:
        manager.bulk_match_gps()
        
    elif args.validate:
        manager.validate_addresses()
        
    else:
        parser.print_help()
        print("\nExamples:")
        print("  python address_manager.py --export-missing missing.csv")
        print("  python address_manager.py --import-csv completed.csv")
        print("  python address_manager.py --interactive")
        print("  python address_manager.py --match-gps")
        print("  python address_manager.py --validate")


if __name__ == "__main__":
    main()