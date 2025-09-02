#!/usr/bin/env python3
"""
Database Schema and Management for Medical Letter System
Handles patients, practitioners, and letters
"""

import sqlite3
from datetime import datetime
from pathlib import Path
import json
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class LetterDatabase:
    """Database manager for medical letter system"""
    
    def __init__(self, db_path: str = "letter_system.db"):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Create all necessary tables"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # PATIENTS table - core patient information
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS patients (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                spire_mrn TEXT UNIQUE NOT NULL,  -- e.g., "0030730605"
                gpk_number TEXT,                  -- Full "GPK0030730605" if needed
                nhs_number TEXT,                  -- Optional NHS number
                
                -- Name details
                title TEXT,                       -- Mr, Mrs, Ms, Dr, etc.
                first_name TEXT,
                last_name TEXT,
                full_name TEXT NOT NULL,          -- "Patricia Wheatley"
                
                -- Demographics
                date_of_birth TEXT,
                age INTEGER,
                sex TEXT CHECK(sex IN ('M', 'F', NULL)),
                
                -- Address
                address_line_1 TEXT,
                address_line_2 TEXT,
                city TEXT,
                county TEXT,
                postcode TEXT,
                
                -- Contact
                phone_home TEXT,
                phone_mobile TEXT,
                email TEXT,
                
                -- Linked practitioners
                primary_gp_id INTEGER REFERENCES practitioners(id),
                primary_optician_id INTEGER REFERENCES practitioners(id),
                
                -- Metadata
                address_verified BOOLEAN DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP,
                notes TEXT
            )
        """)
        
        # PRACTITIONERS table - GPs, Opticians, Consultants
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS practitioners (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT CHECK(type IN ('GP', 'Optician', 'Consultant', 'Other')) NOT NULL,
                
                -- Name
                title TEXT,                      -- Dr, Mr, Ms, etc.
                first_name TEXT,
                last_name TEXT,
                full_name TEXT NOT NULL,         -- "Dr E Robinson"
                initials TEXT,                    -- "E"
                
                -- Practice details
                practice_name TEXT,               -- "The Surgery"
                practice_ods_code TEXT,           -- NHS ODS code if known
                
                -- Address (for letter window)
                address_line_1 TEXT,
                address_line_2 TEXT,
                address_line_3 TEXT,
                city TEXT,
                county TEXT,
                postcode TEXT,
                
                -- Contact
                phone TEXT,
                fax TEXT,
                email TEXT,
                
                -- Letter preferences
                salutation TEXT,                  -- "Dear Dr Robinson" vs "Dear Edward"
                requires_patient_nhs BOOLEAN DEFAULT 0,  -- Some want NHS numbers
                
                -- Status
                active BOOLEAN DEFAULT 1,
                verified BOOLEAN DEFAULT 0,       -- Address verified
                
                -- Metadata
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP,
                notes TEXT
            )
        """)
        
        # LETTERS table - generated letters
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS letters (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                
                -- Patient link
                patient_id INTEGER REFERENCES patients(id) NOT NULL,
                spire_mrn TEXT NOT NULL,         -- Quick reference
                
                -- Letter details
                letter_date TEXT NOT NULL,        -- Date of clinic/letter
                visit_type TEXT,                  -- 'Follow up', 'New visit', etc.
                
                -- Content
                clinical_content TEXT NOT NULL,   -- The "meat" of the letter
                
                -- Recipients
                primary_recipient TEXT NOT NULL,  -- 'patient' or practitioner_id
                copied_to TEXT,                   -- JSON array of practitioner IDs
                
                -- Generated files
                tex_source TEXT,                  -- LaTeX source
                pdf_paths TEXT,                   -- JSON array of PDF file paths
                
                -- Status tracking
                status TEXT DEFAULT 'draft',      -- draft, generated, printed, sent
                generated_at TIMESTAMP,
                printed_at TIMESTAMP,
                
                -- Metadata
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                template_used TEXT,
                notes TEXT
            )
        """)
        
        # PATIENT_PRACTITIONERS linking table (many-to-many)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS patient_practitioners (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                patient_id INTEGER REFERENCES patients(id),
                practitioner_id INTEGER REFERENCES practitioners(id),
                relationship_type TEXT,           -- 'GP', 'Optician', 'Consultant'
                is_primary BOOLEAN DEFAULT 0,
                always_copy BOOLEAN DEFAULT 0,    -- Always CC this practitioner
                start_date TEXT,
                end_date TEXT,
                active BOOLEAN DEFAULT 1,
                notes TEXT,
                UNIQUE(patient_id, practitioner_id, relationship_type)
            )
        """)
        
        # ADDRESSES_PENDING table - for patients needing address updates
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS addresses_pending (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                patient_id INTEGER REFERENCES patients(id),
                spire_mrn TEXT NOT NULL,
                patient_name TEXT,
                letter_id INTEGER REFERENCES letters(id),
                flagged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                resolved_at TIMESTAMP,
                notes TEXT
            )
        """)
        
        # Create indexes for faster lookups
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_patients_mrn ON patients(spire_mrn)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_patients_name ON patients(last_name, first_name)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_practitioners_name ON practitioners(last_name)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_practitioners_type ON practitioners(type)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_letters_patient ON letters(patient_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_letters_date ON letters(letter_date)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_letters_status ON letters(status)")
        
        conn.commit()
        conn.close()
        
        logger.info(f"Database initialized at {self.db_path}")
    
    def add_patient(self, spire_mrn: str, full_name: str, sex: str = None, 
                    age: int = None, **kwargs) -> int:
        """Add or update a patient record"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Parse name if in "Last, First" format
        if ',' in full_name:
            last_name, first_name = [n.strip() for n in full_name.split(',', 1)]
        else:
            parts = full_name.strip().split()
            first_name = ' '.join(parts[:-1]) if len(parts) > 1 else parts[0]
            last_name = parts[-1] if len(parts) > 1 else ''
        
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
            # Update existing patient
            patient_id = existing[0]
            updates = []
            params = []
            
            for field in ['title', 'first_name', 'last_name', 'full_name', 
                         'sex', 'age', 'date_of_birth']:
                value = kwargs.get(field) or locals().get(field)
                if value is not None:
                    updates.append(f"{field} = ?")
                    params.append(value)
            
            if updates:
                params.append(patient_id)
                cursor.execute(f"""
                    UPDATE patients 
                    SET {', '.join(updates)}, updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                """, params)
            
            logger.info(f"Updated patient {spire_mrn}: {full_name}")
        else:
            # Insert new patient
            cursor.execute("""
                INSERT INTO patients (
                    spire_mrn, title, first_name, last_name, full_name,
                    sex, age, date_of_birth, gpk_number
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                spire_mrn, title, first_name, last_name, full_name,
                sex, age, kwargs.get('date_of_birth'),
                f"GPK{spire_mrn}"
            ))
            patient_id = cursor.lastrowid
            logger.info(f"Added new patient {spire_mrn}: {full_name}")
        
        conn.commit()
        conn.close()
        return patient_id
    
    def add_practitioner(self, full_name: str, prac_type: str = 'GP', **kwargs) -> int:
        """Add or update a practitioner"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Parse name - handle "Doctor E Robinson" format
        name = full_name.replace('Doctor ', 'Dr ').replace('DR ', 'Dr ')
        
        # Extract title if present
        title = None
        if name.startswith('Dr '):
            title = 'Dr'
            name = name[3:].strip()
        elif name.startswith('Mr '):
            title = 'Mr'
            name = name[3:].strip()
        elif name.startswith('Ms '):
            title = 'Ms'
            name = name[3:].strip()
        elif name.startswith('Mrs '):
            title = 'Mrs'
            name = name[4:].strip()
        
        # Parse remaining name
        parts = name.strip().split()
        if len(parts) == 1:
            # Just surname
            last_name = parts[0]
            first_name = None
            initials = None
        elif len(parts[0]) <= 2 and '.' not in parts[-1]:
            # Likely initials + surname (E Robinson)
            initials = parts[0]
            last_name = ' '.join(parts[1:])
            first_name = None
        else:
            # Full name
            first_name = ' '.join(parts[:-1])
            last_name = parts[-1]
            initials = ''.join([n[0] for n in parts[:-1] if n])
        
        # Check if practitioner exists
        cursor.execute("""
            SELECT id FROM practitioners 
            WHERE full_name = ? AND type = ?
        """, (full_name, prac_type))
        existing = cursor.fetchone()
        
        if existing:
            practitioner_id = existing[0]
            logger.info(f"Found existing practitioner: {full_name}")
        else:
            # Insert new practitioner
            cursor.execute("""
                INSERT INTO practitioners (
                    type, title, first_name, last_name, full_name, initials,
                    practice_name, salutation
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                prac_type, title, first_name, last_name, full_name, initials,
                kwargs.get('practice_name'),
                f"Dear {title} {last_name}" if title else f"Dear {full_name}"
            ))
            practitioner_id = cursor.lastrowid
            logger.info(f"Added new practitioner: {full_name} ({prac_type})")
        
        conn.commit()
        conn.close()
        return practitioner_id
    
    def link_patient_practitioner(self, patient_id: int, practitioner_id: int, 
                                  relationship: str, is_primary: bool = False):
        """Link a patient to a practitioner"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Check if link exists
        cursor.execute("""
            SELECT id FROM patient_practitioners
            WHERE patient_id = ? AND practitioner_id = ? AND relationship_type = ?
        """, (patient_id, practitioner_id, relationship))
        
        if not cursor.fetchone():
            cursor.execute("""
                INSERT INTO patient_practitioners (
                    patient_id, practitioner_id, relationship_type, is_primary, active
                ) VALUES (?, ?, ?, ?, 1)
            """, (patient_id, practitioner_id, relationship, is_primary))
            
            # Update primary practitioner in patients table if needed
            if is_primary:
                if relationship == 'GP':
                    cursor.execute(
                        "UPDATE patients SET primary_gp_id = ? WHERE id = ?",
                        (practitioner_id, patient_id)
                    )
                elif relationship == 'Optician':
                    cursor.execute(
                        "UPDATE patients SET primary_optician_id = ? WHERE id = ?",
                        (practitioner_id, patient_id)
                    )
        
        conn.commit()
        conn.close()
    
    def add_letter(self, patient_id: int, letter_date: str, content: str,
                   visit_type: str = None, copied_to: list = None) -> int:
        """Add a letter record"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Get patient MRN
        cursor.execute("SELECT spire_mrn FROM patients WHERE id = ?", (patient_id,))
        mrn = cursor.fetchone()[0]
        
        # Insert letter
        cursor.execute("""
            INSERT INTO letters (
                patient_id, spire_mrn, letter_date, visit_type,
                clinical_content, primary_recipient, copied_to, status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            patient_id, mrn, letter_date, visit_type,
            content, 'patient', json.dumps(copied_to) if copied_to else '[]',
            'draft'
        ))
        
        letter_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        logger.info(f"Added letter {letter_id} for patient {mrn}")
        return letter_id
    
    def flag_missing_address(self, patient_id: int, letter_id: int = None):
        """Flag a patient as needing address information"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Get patient details
        cursor.execute("""
            SELECT spire_mrn, full_name FROM patients WHERE id = ?
        """, (patient_id,))
        mrn, name = cursor.fetchone()
        
        # Add to pending addresses
        cursor.execute("""
            INSERT INTO addresses_pending (patient_id, spire_mrn, patient_name, letter_id)
            VALUES (?, ?, ?, ?)
        """, (patient_id, mrn, name, letter_id))
        
        conn.commit()
        conn.close()
        
        logger.warning(f"Flagged missing address for {name} ({mrn})")
    
    def get_patient_by_mrn(self, spire_mrn: str) -> dict:
        """Get patient details by MRN"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM patients WHERE spire_mrn = ?", (spire_mrn,))
        row = cursor.fetchone()
        
        conn.close()
        return dict(row) if row else None
    
    def get_pending_addresses(self) -> list:
        """Get list of patients needing addresses"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT * FROM addresses_pending 
            WHERE resolved_at IS NULL
            ORDER BY flagged_at
        """)
        
        results = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return results
    
    def update_patient_address(self, patient_id: int, address_line_1: str, 
                              address_line_2: str = None, city: str = None,
                              county: str = None, postcode: str = None):
        """Update patient address"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE patients
            SET address_line_1 = ?, address_line_2 = ?, city = ?, 
                county = ?, postcode = ?, address_verified = 1,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
        """, (address_line_1, address_line_2, city, county, postcode, patient_id))
        
        # Mark as resolved in pending table
        cursor.execute("""
            UPDATE addresses_pending
            SET resolved_at = CURRENT_TIMESTAMP
            WHERE patient_id = ? AND resolved_at IS NULL
        """, (patient_id,))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Updated address for patient {patient_id}")
    
    def get_database_stats(self) -> dict:
        """Get database statistics"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        stats = {}
        
        # Count patients
        cursor.execute("SELECT COUNT(*) FROM patients")
        stats['total_patients'] = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM patients WHERE address_verified = 1")
        stats['patients_with_addresses'] = cursor.fetchone()[0]
        
        # Count practitioners
        cursor.execute("SELECT type, COUNT(*) FROM practitioners GROUP BY type")
        for prac_type, count in cursor.fetchall():
            stats[f'total_{prac_type.lower()}s'] = count
        
        # Count letters
        cursor.execute("SELECT status, COUNT(*) FROM letters GROUP BY status")
        for status, count in cursor.fetchall():
            stats[f'letters_{status}'] = count
        
        # Pending addresses
        cursor.execute("SELECT COUNT(*) FROM addresses_pending WHERE resolved_at IS NULL")
        stats['pending_addresses'] = cursor.fetchone()[0]
        
        conn.close()
        return stats


def main():
    """Test database creation and basic operations"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Letter System Database Manager')
    parser.add_argument('--init', action='store_true', help='Initialize database')
    parser.add_argument('--stats', action='store_true', help='Show database statistics')
    parser.add_argument('--add-patient', nargs=3, metavar=('MRN', 'NAME', 'SEX'),
                       help='Add a patient (MRN "Last, First" M/F)')
    parser.add_argument('--add-gp', help='Add a GP by name')
    parser.add_argument('--pending', action='store_true', 
                       help='Show patients needing addresses')
    
    args = parser.parse_args()
    
    db = LetterDatabase()
    
    if args.stats:
        stats = db.get_database_stats()
        print("\n📊 Database Statistics:")
        print("-" * 40)
        for key, value in stats.items():
            label = key.replace('_', ' ').title()
            print(f"{label:30} {value:5}")
    
    elif args.add_patient:
        mrn, name, sex = args.add_patient
        patient_id = db.add_patient(mrn, name, sex)
        print(f"✅ Added patient {name} (ID: {patient_id})")
    
    elif args.add_gp:
        gp_id = db.add_practitioner(args.add_gp, 'GP')
        print(f"✅ Added GP {args.add_gp} (ID: {gp_id})")
    
    elif args.pending:
        pending = db.get_pending_addresses()
        if pending:
            print("\n⚠️  Patients Needing Addresses:")
            print("-" * 60)
            for p in pending:
                print(f"{p['spire_mrn']:12} {p['patient_name']:30} Flagged: {p['flagged_at']}")
        else:
            print("✅ No patients need addresses")
    
    else:
        parser.print_help()
        print("\n✅ Database ready at letter_system.db")


if __name__ == "__main__":
    main()