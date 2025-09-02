#!/usr/bin/env python3
"""
GP Practice Synchronization with NHS FHIR API
Fetches and caches GP practice details from NHS Organization Data Service
"""

import requests
import sqlite3
from typing import Optional, Dict, List, Tuple
from datetime import datetime
import json
import logging
import time

logger = logging.getLogger(__name__)


class GPPracticeSync:
    def __init__(self, db_path: str = "addresses.db"):
        self.db_path = db_path
        self.base_url = "https://directory.spineservices.nhs.uk/FHIR/R4/Organization"
        self._init_db()
    
    def _init_db(self):
        """Create tables if they don't exist"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # GP practices lookup table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS gp_practices (
                id INTEGER PRIMARY KEY,
                internal_name TEXT UNIQUE,  -- Name as extracted from forms
                ods_code TEXT UNIQUE,       -- NHS ODS code
                official_name TEXT,         -- Official NHS name
                address_line1 TEXT,
                address_line2 TEXT,
                address_city TEXT,
                address_county TEXT,
                address_postcode TEXT,
                phone TEXT,
                fax TEXT,
                website TEXT,
                status TEXT,
                last_checked TIMESTAMP,
                raw_fhir_data TEXT
            )
        """)
        
        # Sync log for tracking API calls
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS gp_sync_log (
                id INTEGER PRIMARY KEY,
                timestamp TIMESTAMP,
                practice_name TEXT,
                result TEXT,
                error TEXT
            )
        """)
        
        # Add GP lookup fields to main extraction table if not present
        cursor.execute("""
            PRAGMA table_info(extracted_addresses)
        """)
        columns = [col[1] for col in cursor.fetchall()]
        
        if 'gp_ods_code' not in columns:
            cursor.execute("""
                ALTER TABLE extracted_addresses 
                ADD COLUMN gp_ods_code TEXT
            """)
        
        if 'gp_official_name' not in columns:
            cursor.execute("""
                ALTER TABLE extracted_addresses 
                ADD COLUMN gp_official_name TEXT
            """)
        
        conn.commit()
        conn.close()
    
    def search_practice(self, practice_name: str, postcode: Optional[str] = None) -> Optional[Dict]:
        """Search for a practice by name in the FHIR API"""
        if not practice_name:
            return None
        
        # Clean up practice name for searching
        search_name = practice_name.upper()
        search_name = search_name.replace("THE ", "").replace("SURGERY", "").replace("PRACTICE", "")
        search_name = search_name.replace("MEDICAL CENTRE", "").replace("HEALTH CENTRE", "")
        search_name = search_name.strip()
        
        try:
            # Try exact match first
            logger.info(f"Searching NHS FHIR for practice: {practice_name}")
            
            params = {
                "name:exact": practice_name,
                "_format": "json"
            }
            
            # Add postcode if available for better matching
            if postcode:
                params["address-postalcode"] = postcode
            
            response = requests.get(self.base_url, params=params, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                if data.get("total", 0) > 0:
                    return self._parse_fhir_organization(data["entry"][0]["resource"])
            
            # If no exact match, try contains search
            params = {
                "name:contains": search_name,
                "_format": "json"
            }
            if postcode:
                params["address-postalcode"] = postcode[:4]  # Use district only
            
            response = requests.get(self.base_url, params=params, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                entries = data.get("entry", [])
                
                if len(entries) == 1:
                    return self._parse_fhir_organization(entries[0]["resource"])
                elif len(entries) > 1:
                    # Multiple matches - try to find best match
                    for entry in entries:
                        org = entry["resource"]
                        org_name = org.get("name", "").upper()
                        
                        # Check for exact name match
                        if search_name in org_name or practice_name.upper() in org_name:
                            return self._parse_fhir_organization(org)
                    
                    # If postcode provided, prefer local match
                    if postcode:
                        for entry in entries:
                            org = entry["resource"]
                            org_postcode = org.get("address", [{}])[0].get("postalCode", "")
                            if org_postcode.startswith(postcode[:4]):
                                return self._parse_fhir_organization(org)
                    
                    # Return first if no better match
                    logger.warning(f"Multiple matches for {practice_name}, using first")
                    return self._parse_fhir_organization(entries[0]["resource"])
            
            logger.warning(f"No match found for practice: {practice_name}")
            return None
            
        except requests.RequestException as e:
            logger.error(f"API request failed for {practice_name}: {e}")
            self._log_error(practice_name, f"API error: {str(e)}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error searching for {practice_name}: {e}")
            self._log_error(practice_name, str(e))
            return None
    
    def _parse_fhir_organization(self, org: Dict) -> Dict:
        """Parse FHIR Organization resource into our format"""
        address = org.get("address", [{}])[0] if org.get("address") else {}
        
        # Extract phone, fax, website from telecom
        phone = None
        fax = None
        website = None
        
        for telecom in org.get("telecom", []):
            system = telecom.get("system")
            if system == "phone" and not phone:
                phone = telecom.get("value")
            elif system == "fax" and not fax:
                fax = telecom.get("value")
            elif system == "url" and not website:
                website = telecom.get("value")
        
        # Extract ODS code
        ods_code = None
        for identifier in org.get("identifier", []):
            if "ods-organization-code" in identifier.get("system", ""):
                ods_code = identifier.get("value")
                break
        
        # Get address lines
        address_lines = address.get("line", [])
        
        return {
            "ods_code": ods_code,
            "official_name": org.get("name"),
            "address_line1": address_lines[0] if len(address_lines) > 0 else None,
            "address_line2": address_lines[1] if len(address_lines) > 1 else None,
            "address_city": address.get("city"),
            "address_county": address.get("district"),
            "address_postcode": address.get("postalCode"),
            "phone": phone,
            "fax": fax,
            "website": website,
            "status": "active" if org.get("active", True) else "inactive",
            "raw_fhir_data": json.dumps(org)
        }
    
    def sync_practice(self, internal_name: str, postcode: Optional[str] = None) -> bool:
        """Sync a practice from your internal list"""
        # Check if already synced recently
        existing = self.get_practice_details(internal_name)
        if existing and existing.get('last_checked'):
            last_check = datetime.fromisoformat(existing['last_checked'])
            if (datetime.now() - last_check).days < 30:
                logger.info(f"Practice {internal_name} already synced recently")
                return True
        
        practice_data = self.search_practice(internal_name, postcode)
        
        if not practice_data:
            self._log_error(internal_name, "Practice not found in NHS ODS")
            return False
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute("""
                INSERT OR REPLACE INTO gp_practices 
                (internal_name, ods_code, official_name, address_line1, address_line2,
                 address_city, address_county, address_postcode, phone, fax, website,
                 status, last_checked, raw_fhir_data)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                internal_name,
                practice_data["ods_code"],
                practice_data["official_name"],
                practice_data["address_line1"],
                practice_data["address_line2"],
                practice_data["address_city"],
                practice_data["address_county"],
                practice_data["address_postcode"],
                practice_data["phone"],
                practice_data["fax"],
                practice_data["website"],
                practice_data["status"],
                datetime.now(),
                practice_data["raw_fhir_data"]
            ))
            
            conn.commit()
            self._log_success(internal_name, practice_data["ods_code"])
            logger.info(f"Synced practice {internal_name} -> {practice_data['official_name']} ({practice_data['ods_code']})")
            return True
            
        except Exception as e:
            logger.error(f"Database error for {internal_name}: {e}")
            self._log_error(internal_name, str(e))
            return False
        finally:
            conn.close()
    
    def get_practice_details(self, internal_name: str) -> Optional[Dict]:
        """Get practice details from local cache"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT * FROM gp_practices WHERE internal_name = ?
        """, (internal_name,))
        
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return dict(row)
        
        return None
    
    def sync_all_practices(self, practice_list: List[Tuple[str, Optional[str]]]):
        """Sync all practices from your pre-populated list
        
        Args:
            practice_list: List of tuples (practice_name, postcode)
        """
        results = {"success": 0, "failed": 0, "skipped": 0}
        
        for practice_name, postcode in practice_list:
            # Rate limiting - NHS API may have limits
            time.sleep(0.5)
            
            if self.sync_practice(practice_name, postcode):
                results["success"] += 1
            else:
                results["failed"] += 1
        
        return results
    
    def get_unique_gp_practices(self) -> List[Tuple[str, str, str]]:
        """Get unique GP practices from extracted addresses"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT DISTINCT gp_name, gp_practice, gp_postcode
            FROM extracted_addresses 
            WHERE gp_name IS NOT NULL OR gp_practice IS NOT NULL
            ORDER BY gp_practice, gp_name
        """)
        
        practices = cursor.fetchall()
        conn.close()
        
        return practices
    
    def update_extracted_addresses(self):
        """Update extracted addresses with official GP data"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Get all unique GP references
        cursor.execute("""
            SELECT DISTINCT gp_name, gp_practice 
            FROM extracted_addresses 
            WHERE (gp_name IS NOT NULL OR gp_practice IS NOT NULL)
            AND gp_ods_code IS NULL
        """)
        
        gp_refs = cursor.fetchall()
        updated = 0
        
        for gp_name, gp_practice in gp_refs:
            # Try to find matching practice in our synced data
            search_term = gp_practice or gp_name
            if not search_term:
                continue
            
            # Clean up search term
            search_term = search_term.upper().strip()
            
            cursor.execute("""
                SELECT ods_code, official_name, address_line1, address_line2, 
                       address_city, address_postcode
                FROM gp_practices
                WHERE UPPER(internal_name) = ? 
                   OR UPPER(official_name) LIKE ?
                   OR UPPER(internal_name) LIKE ?
            """, (search_term, f"%{search_term}%", f"%{search_term}%"))
            
            match = cursor.fetchone()
            
            if match:
                ods_code, official_name, addr1, addr2, city, postcode = match
                
                # Update all matching records
                cursor.execute("""
                    UPDATE extracted_addresses 
                    SET gp_ods_code = ?,
                        gp_official_name = ?,
                        gp_address = ?,
                        gp_postcode = ?
                    WHERE (gp_name = ? OR gp_practice = ?)
                    AND gp_ods_code IS NULL
                """, (
                    ods_code,
                    official_name,
                    f"{addr1}, {addr2}, {city}" if addr2 else f"{addr1}, {city}",
                    postcode,
                    gp_name,
                    gp_practice
                ))
                
                updated += cursor.rowcount
        
        conn.commit()
        conn.close()
        
        logger.info(f"Updated {updated} patient records with official GP data")
        return updated
    
    def _log_success(self, practice_name: str, ods_code: str):
        self._log_event(practice_name, f"Success: mapped to {ods_code}", None)
    
    def _log_error(self, practice_name: str, error: str):
        self._log_event(practice_name, "Failed", error)
    
    def _log_event(self, practice_name: str, result: str, error: Optional[str]):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO gp_sync_log (timestamp, practice_name, result, error)
            VALUES (?, ?, ?, ?)
        """, (datetime.now(), practice_name, result, error))
        
        conn.commit()
        conn.close()


def main():
    """Main entry point for GP practice synchronization"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Sync GP practices with NHS FHIR API')
    parser.add_argument('--sync-extracted', action='store_true',
                       help='Sync all GP practices found in extracted addresses')
    parser.add_argument('--update-records', action='store_true',
                       help='Update patient records with official GP data')
    parser.add_argument('--sync-practice', help='Sync a specific practice by name')
    parser.add_argument('--postcode', help='Postcode hint for practice lookup')
    parser.add_argument('--list', action='store_true',
                       help='List all unique GP practices in database')
    
    args = parser.parse_args()
    
    # Setup logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    syncer = GPPracticeSync()
    
    if args.list:
        practices = syncer.get_unique_gp_practices()
        print(f"\nFound {len(practices)} unique GP references:")
        print("-" * 60)
        for gp_name, gp_practice, gp_postcode in practices:
            print(f"Name: {gp_name or 'N/A':20} Practice: {gp_practice or 'N/A':30} Postcode: {gp_postcode or 'N/A'}")
    
    elif args.sync_practice:
        success = syncer.sync_practice(args.sync_practice, args.postcode)
        if success:
            practice = syncer.get_practice_details(args.sync_practice)
            if practice:
                print(f"\n✅ Successfully synced practice:")
                print(f"  Official Name: {practice['official_name']}")
                print(f"  ODS Code: {practice['ods_code']}")
                print(f"  Address: {practice['address_line1']}")
                print(f"           {practice['address_city']}, {practice['address_postcode']}")
                print(f"  Phone: {practice['phone']}")
        else:
            print(f"❌ Failed to sync practice: {args.sync_practice}")
    
    elif args.sync_extracted:
        practices = syncer.get_unique_gp_practices()
        print(f"\nSyncing {len(practices)} GP practices from extracted data...")
        
        # Create list with postcodes where available
        practice_list = []
        for gp_name, gp_practice, gp_postcode in practices:
            # Use practice name if available, otherwise use GP name
            name = gp_practice or gp_name
            if name:
                practice_list.append((name, gp_postcode))
        
        results = syncer.sync_all_practices(practice_list)
        print(f"\nSync complete:")
        print(f"  ✅ Success: {results['success']}")
        print(f"  ❌ Failed: {results['failed']}")
    
    elif args.update_records:
        updated = syncer.update_extracted_addresses()
        print(f"\n✅ Updated {updated} patient records with official GP data")
    
    else:
        parser.print_help()


if __name__ == "__main__":
    main()