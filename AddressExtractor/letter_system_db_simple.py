#!/usr/bin/env python3
"""
Simple Database for Medical Letter System
Just stores patient and practitioner addresses - no status tracking
File system handles letter state (print-me/, printed/ folders)
"""

import sqlite3
from datetime import datetime
from pathlib import Path
import json
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class SimpleLetterDatabase:
    """Simple address book for patients and practitioners"""
    
    def __init__(self, db_path: str = "letter_addresses.db"):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Create simple tables for addresses only"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # PATIENTS table - just the address book info
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS patients (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                spire_mrn TEXT UNIQUE NOT NULL,  -- e.g., "0030730605"
                
                -- Name details
                title TEXT,                       -- Mr, Mrs, Ms, Dr, etc.
                first_name TEXT,
                last_name TEXT,
                full_name TEXT NOT NULL,          -- "Patricia Wheatley"
                
                -- Demographics (helps with title inference)
                sex TEXT CHECK(sex IN ('M', 'F', NULL)),
                age INTEGER,
                date_of_birth TEXT,
                
                -- Address
                address_line_1 TEXT,
                address_line_2 TEXT,
                city TEXT,
                county TEXT,
                postcode TEXT,
                
                -- Contact (optional)
                phone TEXT,
                email TEXT,
                
                -- Links
                usual_gp_id INTEGER REFERENCES practitioners(id),
                usual_optician_id INTEGER REFERENCES practitioners(id),
                
                -- Metadata
                last_updated TIMESTAMP,
                notes TEXT
            )
        """)
        
        # PRACTITIONERS table - address book for GPs/Opticians
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS practitioners (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT CHECK(type IN ('GP', 'Optician', 'Consultant', 'Other')) NOT NULL,
                
                -- Name (as it appears in notes)
                name_as_written TEXT UNIQUE NOT NULL,  -- "Doctor E Robinson"
                
                -- Parsed name for letters
                title TEXT,                      -- Dr, Mr, Ms, etc.
                full_name TEXT,                  -- "Dr E Robinson" 
                salutation TEXT,                 -- "Dear Dr Robinson"
                
                -- Practice address (for window envelope)
                practice_name TEXT,              -- "The Surgery"
                address_line_1 TEXT,
                address_line_2 TEXT,
                address_line_3 TEXT,
                city TEXT,
                county TEXT,
                postcode TEXT,
                
                -- Contact (optional)
                phone TEXT,
                email TEXT,
                
                -- Metadata
                last_updated TIMESTAMP,
                notes TEXT
            )
        """)
        
        # LETTER_LOG table - simple record that a letter was created
        # No status tracking - folders handle that
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS letter_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                spire_mrn TEXT NOT NULL,
                patient_name TEXT,
                letter_date TEXT,
                recipients TEXT,  -- Simple text: "Patient, Dr Robinson"
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # MISSING_ADDRESSES table - patients we need addresses for
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS missing_addresses (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                spire_mrn TEXT UNIQUE NOT NULL,
                patient_name TEXT,
                first_seen TEXT,  -- Date we first tried to create letter
                times_needed INTEGER DEFAULT 1
            )
        """)
        
        # Simple indexes
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_patients_mrn ON patients(spire_mrn)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_practitioners_name ON practitioners(name_as_written)")
        
        conn.commit()
        conn.close()
        
        logger.info(f"Simple database initialized at {self.db_path}")
    
    def get_patient(self, spire_mrn: str) -> dict:
        """Get patient details by MRN"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM patients WHERE spire_mrn = ?", (spire_mrn,))
        row = cursor.fetchone()
        
        conn.close()
        return dict(row) if row else None
    
    def save_patient(self, spire_mrn: str, full_name: str, sex: str = None, 
                    age: int = None, **kwargs) -> int:
        """Save or update patient - just stores what we have"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Parse name if in "Last, First" format
        first_name = None
        last_name = None
        if ',' in full_name:
            last_name, first_name = [n.strip() for n in full_name.split(',', 1)]
            # Reconstruct as "First Last" for letters
            full_name = f"{first_name} {last_name}"
        
        # Infer title from sex and age if not provided
        title = kwargs.get('title')
        if not title and sex:
            if sex == 'F':
                title = 'Mrs' if age and age > 30 else 'Ms'
            elif sex == 'M':
                title = 'Mr'
        
        # Check if patient exists
        cursor.execute("SELECT id FROM patients WHERE spire_mrn = ?", (spire_mrn,))
        existing = cursor.fetchone()
        
        if existing:
            # Update only if we have new information
            patient_id = existing[0]
            updates = []
            params = []
            
            # Only update non-null values
            fields = {
                'title': title,
                'first_name': first_name,
                'last_name': last_name,
                'full_name': full_name,
                'sex': sex,
                'age': age,
                'address_line_1': kwargs.get('address_line_1'),
                'address_line_2': kwargs.get('address_line_2'),
                'city': kwargs.get('city'),
                'county': kwargs.get('county'),
                'postcode': kwargs.get('postcode'),
                'phone': kwargs.get('phone')
            }
            
            for field, value in fields.items():
                if value is not None:
                    updates.append(f"{field} = ?")
                    params.append(value)
            
            if updates:
                params.append(datetime.now())
                params.append(patient_id)
                cursor.execute(f"""
                    UPDATE patients 
                    SET {', '.join(updates)}, last_updated = ?
                    WHERE id = ?
                """, params)
                logger.info(f"Updated patient {spire_mrn}")
        else:
            # Insert new patient with whatever we have
            cursor.execute("""
                INSERT INTO patients (
                    spire_mrn, title, first_name, last_name, full_name,
                    sex, age, last_updated
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                spire_mrn, title, first_name, last_name, full_name,
                sex, age, datetime.now()
            ))
            patient_id = cursor.lastrowid
            logger.info(f"Added new patient {spire_mrn}: {full_name}")
        
        conn.commit()
        conn.close()
        return patient_id
    
    def get_practitioner(self, name_as_written: str) -> dict:
        """Get practitioner by name as it appears in notes"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT * FROM practitioners 
            WHERE name_as_written = ?
        """, (name_as_written,))
        row = cursor.fetchone()
        
        conn.close()
        return dict(row) if row else None
    
    def save_practitioner(self, name_as_written: str, prac_type: str = 'GP', **kwargs) -> int:
        """Save practitioner details"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Clean up the name for display
        full_name = name_as_written.replace('Doctor ', 'Dr ').replace('DR ', 'Dr ')
        
        # Work out salutation
        if full_name.startswith('Dr '):
            salutation = f"Dear {full_name}"
        else:
            salutation = f"Dear {full_name}"
        
        # Check if exists
        cursor.execute("""
            SELECT id FROM practitioners WHERE name_as_written = ?
        """, (name_as_written,))
        existing = cursor.fetchone()
        
        if existing:
            practitioner_id = existing[0]
            # Update if we have address info
            if any(kwargs.get(f) for f in ['practice_name', 'address_line_1', 'postcode']):
                cursor.execute("""
                    UPDATE practitioners
                    SET practice_name = ?, address_line_1 = ?, address_line_2 = ?,
                        address_line_3 = ?, city = ?, county = ?, postcode = ?,
                        last_updated = ?
                    WHERE id = ?
                """, (
                    kwargs.get('practice_name'),
                    kwargs.get('address_line_1'),
                    kwargs.get('address_line_2'),
                    kwargs.get('address_line_3'),
                    kwargs.get('city'),
                    kwargs.get('county'),
                    kwargs.get('postcode'),
                    datetime.now(),
                    practitioner_id
                ))
        else:
            # Insert new
            cursor.execute("""
                INSERT INTO practitioners (
                    type, name_as_written, full_name, salutation,
                    practice_name, address_line_1, address_line_2, address_line_3,
                    city, county, postcode, last_updated
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                prac_type, name_as_written, full_name, salutation,
                kwargs.get('practice_name'),
                kwargs.get('address_line_1'),
                kwargs.get('address_line_2'),
                kwargs.get('address_line_3'),
                kwargs.get('city'),
                kwargs.get('county'),
                kwargs.get('postcode'),
                datetime.now()
            ))
            practitioner_id = cursor.lastrowid
            logger.info(f"Added practitioner: {name_as_written}")
        
        conn.commit()
        conn.close()
        return practitioner_id
    
    def flag_missing_address(self, spire_mrn: str, patient_name: str):
        """Note that we need an address for this patient"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT OR REPLACE INTO missing_addresses (spire_mrn, patient_name, first_seen, times_needed)
            VALUES (
                ?,
                ?,
                COALESCE((SELECT first_seen FROM missing_addresses WHERE spire_mrn = ?), date('now')),
                COALESCE((SELECT times_needed + 1 FROM missing_addresses WHERE spire_mrn = ?), 1)
            )
        """, (spire_mrn, patient_name, spire_mrn, spire_mrn))
        
        conn.commit()
        conn.close()
        logger.warning(f"Need address for {patient_name} ({spire_mrn})")
    
    def clear_missing_address(self, spire_mrn: str):
        """Remove from missing addresses list"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("DELETE FROM missing_addresses WHERE spire_mrn = ?", (spire_mrn,))
        
        conn.commit()
        conn.close()
    
    def get_missing_addresses(self) -> list:
        """Get list of patients needing addresses"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT * FROM missing_addresses 
            ORDER BY times_needed DESC, first_seen
        """)
        
        results = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return results
    
    def log_letter(self, spire_mrn: str, patient_name: str, letter_date: str, recipients: str):
        """Simple log that we created a letter - no status tracking"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO letter_log (spire_mrn, patient_name, letter_date, recipients)
            VALUES (?, ?, ?, ?)
        """, (spire_mrn, patient_name, letter_date, recipients))
        
        conn.commit()
        conn.close()
    
    def get_stats(self) -> dict:
        """Get simple statistics"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        stats = {}
        
        # Patients
        cursor.execute("SELECT COUNT(*) FROM patients")
        stats['total_patients'] = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM patients WHERE address_line_1 IS NOT NULL")
        stats['patients_with_addresses'] = cursor.fetchone()[0]
        
        # Practitioners
        cursor.execute("SELECT type, COUNT(*) FROM practitioners GROUP BY type")
        for prac_type, count in cursor.fetchall():
            stats[f'{prac_type.lower()}s'] = count
        
        # Missing addresses
        cursor.execute("SELECT COUNT(*) FROM missing_addresses")
        stats['missing_addresses'] = cursor.fetchone()[0]
        
        # Letters created (just count)
        cursor.execute("SELECT COUNT(*) FROM letter_log")
        stats['letters_created'] = cursor.fetchone()[0]
        
        conn.close()
        return stats


def main():
    """Test the simple database"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Simple Letter Address Database')
    parser.add_argument('--stats', action='store_true', help='Show statistics')
    parser.add_argument('--missing', action='store_true', help='Show missing addresses')
    parser.add_argument('--add-patient', nargs=3, metavar=('MRN', 'NAME', 'SEX'),
                       help='Add patient: MRN "Last, First" M/F')
    parser.add_argument('--add-gp', help='Add GP: "Doctor E Robinson"')
    
    args = parser.parse_args()
    
    db = SimpleLetterDatabase()
    
    if args.stats:
        stats = db.get_stats()
        print("\n📊 Address Database Statistics:")
        print("-" * 40)
        for key, value in stats.items():
            label = key.replace('_', ' ').title()
            print(f"{label:25} {value:5}")
    
    elif args.missing:
        missing = db.get_missing_addresses()
        if missing:
            print("\n⚠️  Patients Needing Addresses:")
            print("-" * 60)
            for p in missing:
                print(f"{p['spire_mrn']:12} {p['patient_name']:30} Needed: {p['times_needed']}x")
        else:
            print("✅ No missing addresses")
    
    elif args.add_patient:
        mrn, name, sex = args.add_patient
        db.save_patient(mrn, name, sex)
        print(f"✅ Saved patient {name}")
    
    elif args.add_gp:
        db.save_practitioner(args.add_gp, 'GP')
        print(f"✅ Saved GP {args.add_gp}")
    
    else:
        parser.print_help()


if __name__ == "__main__":
    main()