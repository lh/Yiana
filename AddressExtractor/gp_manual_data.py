#!/usr/bin/env python3
"""
Manual GP Practice Data Entry
For practices that can't be found via API or need manual verification
"""

import sqlite3
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


# Manual GP practice data for known local practices
# You can expand this list with accurate local information
MANUAL_GP_PRACTICES = [
    {
        "internal_name": "THE HEALTH CENTRE",
        "official_name": "The Health Centre",
        "address_line1": "Bowers Place",
        "address_line2": "",
        "address_city": "Crawley",
        "address_county": "West Sussex",
        "address_postcode": "RH10 4XX",  # Update with correct postcode
        "gp_names": ["Dr Croucher"],
        "phone": "",  # Add if known
    },
    {
        "internal_name": "WAYSIDE SURGERY",
        "official_name": "Wayside Medical Centre",
        "address_line1": "Wayside",
        "address_line2": "",
        "address_city": "Horley",
        "address_county": "Surrey",
        "address_postcode": "RH6 7XX",  # Update with correct postcode
        "gp_names": ["Dr Williamson"],
        "phone": "",
    },
    {
        "internal_name": "MENFIELD",
        "official_name": "Menfield Medical Practice",
        "address_line1": "Menfield",
        "address_line2": "",
        "address_city": "Horsham",
        "address_county": "West Sussex",
        "address_postcode": "RH13 XXX",  # Update with correct postcode
        "gp_names": ["Dr Reade"],
        "phone": "",
    }
]


def populate_manual_gp_data(db_path: str = "addresses.db"):
    """Populate database with manual GP practice data"""
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Ensure tables exist
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS gp_practices_manual (
            id INTEGER PRIMARY KEY,
            internal_name TEXT UNIQUE,
            official_name TEXT,
            address_line1 TEXT,
            address_line2 TEXT,
            address_city TEXT,
            address_county TEXT,
            address_postcode TEXT,
            phone TEXT,
            gp_names TEXT,  -- JSON list of GP names
            notes TEXT,
            created_at TIMESTAMP,
            updated_at TIMESTAMP
        )
    """)
    
    count = 0
    for practice in MANUAL_GP_PRACTICES:
        try:
            # Check if already exists
            cursor.execute(
                "SELECT id FROM gp_practices_manual WHERE internal_name = ?",
                (practice["internal_name"],)
            )
            
            if cursor.fetchone():
                # Update existing
                cursor.execute("""
                    UPDATE gp_practices_manual 
                    SET official_name = ?, address_line1 = ?, address_line2 = ?,
                        address_city = ?, address_county = ?, address_postcode = ?,
                        phone = ?, gp_names = ?, updated_at = ?
                    WHERE internal_name = ?
                """, (
                    practice["official_name"],
                    practice["address_line1"],
                    practice["address_line2"],
                    practice["address_city"],
                    practice["address_county"],
                    practice["address_postcode"],
                    practice["phone"],
                    str(practice["gp_names"]),
                    datetime.now(),
                    practice["internal_name"]
                ))
            else:
                # Insert new
                cursor.execute("""
                    INSERT INTO gp_practices_manual 
                    (internal_name, official_name, address_line1, address_line2,
                     address_city, address_county, address_postcode, phone,
                     gp_names, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    practice["internal_name"],
                    practice["official_name"],
                    practice["address_line1"],
                    practice["address_line2"],
                    practice["address_city"],
                    practice["address_county"],
                    practice["address_postcode"],
                    practice["phone"],
                    str(practice["gp_names"]),
                    datetime.now(),
                    datetime.now()
                ))
            
            count += 1
            print(f"✅ Added/Updated: {practice['internal_name']}")
            
        except Exception as e:
            print(f"❌ Error with {practice['internal_name']}: {e}")
    
    conn.commit()
    conn.close()
    
    print(f"\n📊 Processed {count} manual GP practice entries")
    return count


def update_patient_records_with_manual_gp(db_path: str = "addresses.db"):
    """Update patient records with manual GP data"""
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Join manual GP data with patient records
    cursor.execute("""
        UPDATE extracted_addresses 
        SET gp_address = (
            SELECT address_line1 || ', ' || address_city || ', ' || address_postcode
            FROM gp_practices_manual
            WHERE UPPER(gp_practices_manual.internal_name) = UPPER(extracted_addresses.gp_practice)
               OR gp_practices_manual.gp_names LIKE '%' || extracted_addresses.gp_name || '%'
        ),
        gp_postcode = (
            SELECT address_postcode
            FROM gp_practices_manual
            WHERE UPPER(gp_practices_manual.internal_name) = UPPER(extracted_addresses.gp_practice)
               OR gp_practices_manual.gp_names LIKE '%' || extracted_addresses.gp_name || '%'
        )
        WHERE EXISTS (
            SELECT 1 FROM gp_practices_manual
            WHERE UPPER(gp_practices_manual.internal_name) = UPPER(extracted_addresses.gp_practice)
               OR gp_practices_manual.gp_names LIKE '%' || extracted_addresses.gp_name || '%'
        )
        AND gp_address IS NULL
    """)
    
    updated = cursor.rowcount
    conn.commit()
    
    print(f"✅ Updated {updated} patient records with manual GP addresses")
    
    # Show the updates
    cursor.execute("""
        SELECT full_name, gp_name, gp_practice, gp_address, gp_postcode
        FROM extracted_addresses
        WHERE gp_address IS NOT NULL
    """)
    
    results = cursor.fetchall()
    if results:
        print("\n📋 Patient Records with GP Addresses:")
        print("-" * 80)
        for name, gp_name, gp_practice, gp_address, gp_postcode in results:
            print(f"Patient: {name}")
            print(f"  GP: {gp_name} at {gp_practice}")
            print(f"  Address: {gp_address}")
            print(f"  Postcode: {gp_postcode}")
            print()
    
    conn.close()
    return updated


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Manual GP Practice Data Management')
    parser.add_argument('--populate', action='store_true',
                       help='Populate manual GP practice data')
    parser.add_argument('--update-patients', action='store_true',
                       help='Update patient records with manual GP data')
    parser.add_argument('--list', action='store_true',
                       help='List manual GP practices')
    
    args = parser.parse_args()
    
    if args.populate:
        populate_manual_gp_data()
    
    if args.update_patients:
        update_patient_records_with_manual_gp()
    
    if args.list:
        conn = sqlite3.connect("addresses.db")
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT internal_name, official_name, address_city, address_postcode, gp_names
            FROM gp_practices_manual
            ORDER BY internal_name
        """)
        
        results = cursor.fetchall()
        if results:
            print("\n📋 Manual GP Practice Data:")
            print("-" * 80)
            for internal, official, city, postcode, gps in results:
                print(f"{internal:30} {official:30}")
                print(f"  {city:20} {postcode:10} GPs: {gps}")
        else:
            print("No manual GP data found. Run with --populate first.")
        
        conn.close()
    
    if not any([args.populate, args.update_patients, args.list]):
        parser.print_help()


if __name__ == "__main__":
    main()