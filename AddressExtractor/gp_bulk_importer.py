#!/usr/bin/env python3
"""
GP Practice Bulk Data Importer
Downloads and imports NHS ODS GP practice data for local searching
"""

import csv
import sqlite3
import requests
import zipfile
import os
from pathlib import Path
from datetime import datetime
import logging
from typing import Dict, List, Optional
import re

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class GPBulkDataImporter:
    """Import NHS ODS bulk GP practice data"""
    
    def __init__(self, db_path: str = "gp_local.db"):
        self.db_path = db_path
        self.data_dir = Path("gp_data")
        self.data_dir.mkdir(exist_ok=True)
        self._init_database()
    
    def _init_database(self):
        """Create database schema for GP data"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Main GP practices table from NHS bulk data
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS gp_practices_bulk (
                ods_code TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                name_upper TEXT,  -- For faster searching
                address_1 TEXT,
                address_2 TEXT,
                address_3 TEXT,
                address_4 TEXT,
                address_5 TEXT,
                postcode TEXT,
                postcode_district TEXT,  -- e.g., "RH10" from "RH10 4HD"
                phone TEXT,
                status TEXT,
                practice_type TEXT,
                open_date TEXT,
                close_date TEXT,
                last_updated DATE
            )
        """)
        
        # Individual GP practitioners (to be populated if data available)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS gp_practitioners (
                id INTEGER PRIMARY KEY,
                gmc_number TEXT,
                surname TEXT,
                surname_upper TEXT,
                forenames TEXT,
                practice_ods_code TEXT,
                role TEXT,
                FOREIGN KEY (practice_ods_code) REFERENCES gp_practices_bulk(ods_code)
            )
        """)
        
        # Practice aliases and common names
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS practice_aliases (
                id INTEGER PRIMARY KEY,
                ods_code TEXT,
                alias TEXT,
                alias_upper TEXT,
                source TEXT,
                confidence REAL,
                FOREIGN KEY (ods_code) REFERENCES gp_practices_bulk(ods_code)
            )
        """)
        
        # Create indexes for fast searching
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_name_upper ON gp_practices_bulk(name_upper)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_postcode ON gp_practices_bulk(postcode)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_postcode_district ON gp_practices_bulk(postcode_district)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_gp_surname ON gp_practitioners(surname_upper)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_alias_upper ON practice_aliases(alias_upper)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_address ON gp_practices_bulk(address_1, address_2)")
        
        conn.commit()
        conn.close()
    
    def download_gp_data(self) -> bool:
        """Download latest GP practice data from NHS Digital"""
        
        # NHS ODS Downloads page
        # Main file: epraccur.zip (Current GP Practices)
        url = "https://files.digital.nhs.uk/assets/ods/current/epraccur.zip"
        
        zip_path = self.data_dir / "epraccur.zip"
        
        try:
            logger.info(f"Downloading GP practice data from NHS Digital...")
            response = requests.get(url, stream=True)
            response.raise_for_status()
            
            # Save zip file
            with open(zip_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            
            logger.info(f"Downloaded to {zip_path}")
            
            # Extract CSV
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(self.data_dir)
            
            logger.info("Extracted GP practice data")
            return True
            
        except Exception as e:
            logger.error(f"Failed to download GP data: {e}")
            logger.info("You can manually download from:")
            logger.info("https://digital.nhs.uk/services/organisation-data-service/file-downloads-other-nhs-organisations")
            logger.info("Look for 'GP and GP practice related data' -> 'epraccur.zip'")
            return False
    
    def import_csv_data(self, csv_path: Optional[str] = None) -> int:
        """Import GP practice data from CSV file"""
        
        if csv_path is None:
            # Look for extracted CSV
            csv_files = list(self.data_dir.glob("epraccur.csv"))
            if not csv_files:
                logger.error("No epraccur.csv found. Run download first or provide path.")
                return 0
            csv_path = csv_files[0]
        
        logger.info(f"Importing from {csv_path}")
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        count = 0
        with open(csv_path, 'r', encoding='latin-1') as f:
            reader = csv.reader(f)
            
            # Skip header
            header = next(reader)
            logger.debug(f"CSV Headers: {header}")
            
            for row in reader:
                if len(row) < 10:
                    continue
                
                # NHS CSV Format (typical columns):
                # 0: Organisation Code (ODS Code)
                # 1: Name
                # 2: National Grouping
                # 3: High Level Health Geography
                # 4: Address Line 1
                # 5: Address Line 2  
                # 6: Address Line 3
                # 7: Address Line 4
                # 8: Address Line 5
                # 9: Postcode
                # 10: Open Date
                # 11: Close Date
                # 12: Status Code (A=Active, C=Closed)
                # 13: Organisation Sub-Type Code
                # 14: Commissioner
                # 15: Join Provider/Purchaser Date
                # 16: Left Provider/Purchaser Date
                # 17: Contact Telephone Number
                
                try:
                    ods_code = row[0].strip()
                    name = row[1].strip()
                    
                    # Extract postcode district
                    postcode = row[9].strip() if len(row) > 9 else ""
                    postcode_district = postcode.split()[0] if postcode else ""
                    
                    # Get phone if available
                    phone = row[17].strip() if len(row) > 17 else ""
                    
                    # Get dates and status
                    open_date = row[10].strip() if len(row) > 10 else ""
                    close_date = row[11].strip() if len(row) > 11 else ""
                    status = row[12].strip() if len(row) > 12 else "U"
                    practice_type = row[13].strip() if len(row) > 13 else ""
                    
                    # Only import active GP practices (status A or blank, practice type 4 or B)
                    if status in ['A', ''] and practice_type in ['4', 'B', '']:
                        cursor.execute("""
                            INSERT OR REPLACE INTO gp_practices_bulk
                            (ods_code, name, name_upper, address_1, address_2, address_3, 
                             address_4, address_5, postcode, postcode_district, phone,
                             status, practice_type, open_date, close_date, last_updated)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """, (
                            ods_code,
                            name,
                            name.upper(),
                            row[4].strip() if len(row) > 4 else "",
                            row[5].strip() if len(row) > 5 else "",
                            row[6].strip() if len(row) > 6 else "",
                            row[7].strip() if len(row) > 7 else "",
                            row[8].strip() if len(row) > 8 else "",
                            postcode,
                            postcode_district,
                            phone,
                            status,
                            practice_type,
                            open_date,
                            close_date,
                            datetime.now()
                        ))
                        count += 1
                        
                        if count % 100 == 0:
                            logger.info(f"Imported {count} practices...")
                
                except Exception as e:
                    logger.warning(f"Error importing row: {e}")
                    continue
        
        conn.commit()
        conn.close()
        
        logger.info(f"✅ Imported {count} GP practices")
        return count
    
    def import_gp_names(self, csv_path: Optional[str] = None) -> int:
        """Import individual GP practitioner names if data available"""
        # This would import from workforce data if we have it
        # For now, we'll build this from our extracted data
        pass
    
    def add_practice_alias(self, ods_code: str, alias: str, source: str = "manual", confidence: float = 1.0):
        """Add an alias for a practice"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT OR REPLACE INTO practice_aliases
            (ods_code, alias, alias_upper, source, confidence)
            VALUES (?, ?, ?, ?, ?)
        """, (ods_code, alias, alias.upper(), source, confidence))
        
        conn.commit()
        conn.close()
    
    def get_stats(self) -> Dict:
        """Get database statistics"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        stats = {}
        
        # Count practices
        cursor.execute("SELECT COUNT(*) FROM gp_practices_bulk")
        stats['total_practices'] = cursor.fetchone()[0]
        
        # Count by postcode district
        cursor.execute("""
            SELECT postcode_district, COUNT(*) 
            FROM gp_practices_bulk 
            WHERE postcode_district != ''
            GROUP BY postcode_district
            ORDER BY COUNT(*) DESC
            LIMIT 10
        """)
        stats['top_districts'] = cursor.fetchall()
        
        # Count practitioners
        cursor.execute("SELECT COUNT(*) FROM gp_practitioners")
        stats['total_practitioners'] = cursor.fetchone()[0]
        
        # Count aliases
        cursor.execute("SELECT COUNT(*) FROM practice_aliases")
        stats['total_aliases'] = cursor.fetchone()[0]
        
        conn.close()
        return stats
    
    def show_sample_practices(self, postcode_start: str) -> List:
        """Show sample practices for a postcode area"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT ods_code, name, address_1, address_2, postcode
            FROM gp_practices_bulk
            WHERE postcode LIKE ?
            LIMIT 10
        """, (f"{postcode_start}%",))
        
        results = cursor.fetchall()
        conn.close()
        
        return results


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Import NHS GP bulk data')
    parser.add_argument('--download', action='store_true', 
                       help='Download latest GP data from NHS')
    parser.add_argument('--import', dest='import_csv', metavar='CSV_PATH',
                       help='Import from CSV file (or auto-find if not specified)', 
                       nargs='?', const=True)
    parser.add_argument('--stats', action='store_true',
                       help='Show database statistics')
    parser.add_argument('--sample', metavar='POSTCODE',
                       help='Show sample practices for postcode area (e.g., RH10)')
    
    args = parser.parse_args()
    
    importer = GPBulkDataImporter()
    
    if args.download:
        success = importer.download_gp_data()
        if success:
            print("✅ Download complete. Now run with --import to load into database")
    
    if args.import_csv:
        if args.import_csv == True:
            # Auto-find CSV
            count = importer.import_csv_data()
        else:
            # Use specified path
            count = importer.import_csv_data(args.import_csv)
        
        if count > 0:
            print(f"✅ Imported {count} GP practices")
    
    if args.stats:
        stats = importer.get_stats()
        print("\n📊 GP Database Statistics:")
        print(f"Total practices: {stats['total_practices']}")
        print(f"Total practitioners: {stats['total_practitioners']}")
        print(f"Total aliases: {stats['total_aliases']}")
        
        if stats['top_districts']:
            print("\nTop postcode districts:")
            for district, count in stats['top_districts']:
                print(f"  {district}: {count} practices")
    
    if args.sample:
        results = importer.show_sample_practices(args.sample.upper())
        if results:
            print(f"\nSample GP practices in {args.sample}:")
            print("-" * 80)
            for ods, name, addr1, addr2, postcode in results:
                print(f"{ods}: {name}")
                print(f"  {addr1}, {addr2}")
                print(f"  {postcode}")
                print()
        else:
            print(f"No practices found for {args.sample}")
    
    if not any([args.download, args.import_csv, args.stats, args.sample]):
        parser.print_help()
        print("\nQuick start:")
        print("  1. python gp_bulk_importer.py --download")
        print("  2. python gp_bulk_importer.py --import")
        print("  3. python gp_bulk_importer.py --stats")


if __name__ == "__main__":
    main()