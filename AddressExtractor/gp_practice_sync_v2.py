#!/usr/bin/env python3
"""
GP Practice Synchronization with NHS APIs
Supports multiple API versions with easy migration path
"""

import requests
import sqlite3
from typing import Optional, Dict, List, Tuple
from datetime import datetime
import json
import logging
from enum import Enum
from abc import ABC, abstractmethod
import time

logger = logging.getLogger(__name__)


class APIVersion(Enum):
    STU3 = "STU3"      # Current working FHIR version
    FHIR_R4 = "FHIR_R4"  # Future FHIR version
    ORD = "ORD"        # Alternative ORD API


class ODSAPIAdapter(ABC):
    """Abstract base class for different ODS API versions"""
    
    @abstractmethod
    def search_by_name(self, name: str, postcode: Optional[str] = None) -> List[Dict]:
        """Search for organizations by name"""
        pass
    
    @abstractmethod
    def get_by_code(self, ods_code: str) -> Optional[Dict]:
        """Get organization by ODS code"""
        pass
    
    @abstractmethod
    def parse_to_common_format(self, data: Dict) -> Dict:
        """Convert API-specific format to common format"""
        pass


class STU3APIAdapter(ODSAPIAdapter):
    """Adapter for the current FHIR STU3 API (working)"""
    
    def __init__(self):
        self.base_url = "https://directory.spineservices.nhs.uk/STU3/Organization"
    
    def search_by_name(self, name: str, postcode: Optional[str] = None) -> List[Dict]:
        """Search using FHIR STU3 API"""
        try:
            params = {
                "name:contains": name,
                "_format": "json",
                "_count": "20"
            }
            
            # Add postcode if provided for better matching
            if postcode:
                params["address-postalcode:contains"] = postcode[:4]  # Use district
            
            response = requests.get(self.base_url, params=params, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                return data.get("entry", [])
            else:
                logger.warning(f"STU3 API returned {response.status_code}: {response.text[:200]}")
                return []
        except Exception as e:
            logger.error(f"STU3 search error: {e}")
            return []
    
    def get_by_code(self, ods_code: str) -> Optional[Dict]:
        """Get organization by ODS code"""
        try:
            response = requests.get(
                f"{self.base_url}/{ods_code}",
                params={"_format": "json"},
                timeout=10
            )
            
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            logger.error(f"STU3 get by code error: {e}")
            return None
    
    def parse_to_common_format(self, data: Dict) -> Dict:
        """Convert FHIR STU3 format to common format"""
        # Handle both search results and direct fetch
        if "resource" in data:
            org = data["resource"]
        else:
            org = data
        
        # Extract address
        addresses = org.get("address", [])
        address = addresses[0] if addresses else {}
        address_lines = address.get("line", [])
        
        # Extract contact details
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
        
        # Extract ODS code from ID or identifiers
        ods_code = org.get("id")  # In STU3, the ID is often the ODS code
        
        # Try to get from identifiers if not in ID
        if not ods_code:
            for identifier in org.get("identifier", []):
                if "ods" in identifier.get("system", "").lower():
                    ods_code = identifier.get("value")
                    break
        
        return {
            "ods_code": ods_code,
            "official_name": org.get("name"),
            "address_line1": address_lines[0] if len(address_lines) > 0 else None,
            "address_line2": address_lines[1] if len(address_lines) > 1 else None,
            "address_city": address.get("city"),
            "address_district": address.get("district"),
            "address_postcode": address.get("postalCode"),
            "phone": phone,
            "fax": fax,
            "website": website,
            "status": "active" if org.get("active", True) else "inactive",
            "last_change_date": org.get("meta", {}).get("lastUpdated"),
            "raw_data": json.dumps(org)
        }


class FHIRR4APIAdapter(ODSAPIAdapter):
    """Adapter for future FHIR R4 API"""
    
    def __init__(self):
        self.base_url = "https://directory.spineservices.nhs.uk/FHIR/R4/Organization"
    
    def search_by_name(self, name: str, postcode: Optional[str] = None) -> List[Dict]:
        """Search using FHIR R4 API (when available)"""
        try:
            params = {
                "name:contains": name,
                "_format": "json"
            }
            
            if postcode:
                params["address-postalcode"] = postcode
            
            response = requests.get(self.base_url, params=params, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                return data.get("entry", [])
            return []
        except Exception as e:
            logger.error(f"R4 search error: {e}")
            return []
    
    def get_by_code(self, ods_code: str) -> Optional[Dict]:
        """Get organization by ODS code"""
        try:
            response = requests.get(
                f"{self.base_url}/{ods_code}",
                params={"_format": "json"},
                timeout=10
            )
            
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            logger.error(f"R4 get by code error: {e}")
            return None
    
    def parse_to_common_format(self, data: Dict) -> Dict:
        """Convert FHIR R4 format to common format"""
        # Similar to STU3 but may have minor differences
        return self.__class__.bases[0].parse_to_common_format(self, data)


class GPPracticeSync:
    def __init__(self, db_path: str = "addresses.db", api_version: APIVersion = APIVersion.STU3):
        self.db_path = db_path
        self.api_version = api_version
        
        # Select the appropriate adapter
        if api_version == APIVersion.STU3:
            self.api = STU3APIAdapter()
        elif api_version == APIVersion.FHIR_R4:
            self.api = FHIRR4APIAdapter()
        else:
            raise ValueError(f"Unsupported API version: {api_version}")
        
        self._init_db()
        logger.info(f"Using {api_version.value} API")
    
    def _init_db(self):
        """Create tables if they don't exist"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # GP practices lookup table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS gp_practices (
                id INTEGER PRIMARY KEY,
                internal_name TEXT UNIQUE,
                ods_code TEXT UNIQUE,
                official_name TEXT,
                address_line1 TEXT,
                address_line2 TEXT,
                address_city TEXT,
                address_district TEXT,
                address_postcode TEXT,
                phone TEXT,
                fax TEXT,
                website TEXT,
                status TEXT,
                last_change_date TEXT,
                last_checked TIMESTAMP,
                raw_data TEXT,
                api_version TEXT
            )
        """)
        
        # Sync log
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS gp_sync_log (
                id INTEGER PRIMARY KEY,
                timestamp TIMESTAMP,
                practice_name TEXT,
                result TEXT,
                error TEXT,
                api_version TEXT
            )
        """)
        
        # Update extracted_addresses table if needed
        cursor.execute("PRAGMA table_info(extracted_addresses)")
        columns = [col[1] for col in cursor.fetchall()]
        
        if 'gp_ods_code' not in columns:
            cursor.execute("ALTER TABLE extracted_addresses ADD COLUMN gp_ods_code TEXT")
        
        if 'gp_official_name' not in columns:
            cursor.execute("ALTER TABLE extracted_addresses ADD COLUMN gp_official_name TEXT")
        
        conn.commit()
        conn.close()
    
    def search_practice(self, practice_name: str, postcode: Optional[str] = None) -> Optional[Dict]:
        """Search for a practice by name"""
        if not practice_name:
            return None
        
        try:
            # Clean up practice name for searching
            search_name = practice_name.strip()
            
            # Try exact name first
            results = self.api.search_by_name(practice_name, postcode)
            
            if not results and len(search_name) > 3:
                # Try with partial name
                words = search_name.upper().replace("THE ", "").split()
                if words:
                    # Try with first significant word
                    results = self.api.search_by_name(words[0], postcode)
            
            if results:
                # Parse the first result
                return self.api.parse_to_common_format(results[0])
            
            return None
            
        except Exception as e:
            logger.error(f"Search error for {practice_name}: {e}")
            self._log_error(practice_name, str(e))
            return None
    
    def sync_practice(self, internal_name: str, postcode: Optional[str] = None) -> bool:
        """Sync a practice from your internal list"""
        
        # Check if already synced recently
        if not self.needs_refresh(internal_name):
            logger.info(f"Practice {internal_name} already synced recently")
            return True
        
        logger.info(f"Searching for practice: {internal_name}")
        practice_data = self.search_practice(internal_name, postcode)
        
        if not practice_data:
            self._log_error(internal_name, "Practice not found in NHS directory")
            return False
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute("""
                INSERT OR REPLACE INTO gp_practices 
                (internal_name, ods_code, official_name, address_line1, address_line2,
                 address_city, address_district, address_postcode, phone, fax, website,
                 status, last_change_date, last_checked, raw_data, api_version)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                internal_name,
                practice_data.get("ods_code"),
                practice_data.get("official_name"),
                practice_data.get("address_line1"),
                practice_data.get("address_line2"),
                practice_data.get("address_city"),
                practice_data.get("address_district"),
                practice_data.get("address_postcode"),
                practice_data.get("phone"),
                practice_data.get("fax"),
                practice_data.get("website"),
                practice_data.get("status"),
                practice_data.get("last_change_date"),
                datetime.now(),
                practice_data.get("raw_data"),
                self.api_version.value
            ))
            
            conn.commit()
            self._log_success(internal_name, practice_data.get("ods_code", "N/A"))
            logger.info(f"✅ Synced: {internal_name} -> {practice_data.get('official_name')} ({practice_data.get('ods_code')})")
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
        
        cursor.execute("SELECT * FROM gp_practices WHERE internal_name = ?", (internal_name,))
        
        row = cursor.fetchone()
        conn.close()
        
        return dict(row) if row else None
    
    def needs_refresh(self, internal_name: str, days: int = 30) -> bool:
        """Check if practice data needs refreshing"""
        practice = self.get_practice_details(internal_name)
        if not practice or not practice.get('last_checked'):
            return True
        
        try:
            last_checked = datetime.fromisoformat(str(practice['last_checked']))
            return (datetime.now() - last_checked).days > days
        except:
            return True
    
    def sync_all_practices(self, practice_list: List[Tuple[str, Optional[str]]], force_refresh: bool = False):
        """Sync all practices from your pre-populated list
        
        Args:
            practice_list: List of tuples (practice_name, optional_postcode)
            force_refresh: Force refresh even if recently synced
        """
        results = {"success": 0, "failed": 0, "skipped": 0}
        
        for item in practice_list:
            if isinstance(item, tuple):
                practice_name, postcode = item
            else:
                practice_name, postcode = item, None
            
            if not force_refresh and not self.needs_refresh(practice_name):
                results["skipped"] += 1
                logger.info(f"Skipping {practice_name} - recently synced")
                continue
            
            # Rate limiting
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
            SELECT DISTINCT gp_name, gp_practice, gp_postcode
            FROM extracted_addresses 
            WHERE (gp_name IS NOT NULL OR gp_practice IS NOT NULL)
            AND gp_ods_code IS NULL
        """)
        
        gp_refs = cursor.fetchall()
        updated = 0
        
        for gp_name, gp_practice, gp_postcode in gp_refs:
            # Try to find matching practice in our synced data
            search_term = gp_practice or gp_name
            if not search_term:
                continue
            
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
                
                # Build full address
                address_parts = [p for p in [addr1, addr2, city] if p]
                full_address = ", ".join(address_parts)
                
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
                    full_address,
                    postcode,
                    gp_name,
                    gp_practice
                ))
                
                updated += cursor.rowcount
        
        conn.commit()
        conn.close()
        
        logger.info(f"Updated {updated} patient records with official GP data")
        return updated
    
    def migrate_to_new_api(self, new_version: APIVersion):
        """Helper to migrate data when switching APIs"""
        logger.info(f"Migrating from {self.api_version.value} to {new_version.value}")
        
        # Get all current practices
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT internal_name, address_postcode FROM gp_practices")
        practices = cursor.fetchall()
        conn.close()
        
        # Switch to new API
        old_version = self.api_version
        self.api_version = new_version
        
        if new_version == APIVersion.STU3:
            self.api = STU3APIAdapter()
        elif new_version == APIVersion.FHIR_R4:
            self.api = FHIRR4APIAdapter()
        
        # Re-sync all practices with new API
        results = self.sync_all_practices(practices, force_refresh=True)
        
        logger.info(f"Migration complete: {results}")
        return results
    
    def _log_success(self, practice_name: str, ods_code: str):
        self._log_event(practice_name, f"Success: mapped to {ods_code}", None)
    
    def _log_error(self, practice_name: str, error: str):
        self._log_event(practice_name, "Failed", error)
    
    def _log_event(self, practice_name: str, result: str, error: Optional[str]):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO gp_sync_log (timestamp, practice_name, result, error, api_version)
            VALUES (?, ?, ?, ?, ?)
        """, (datetime.now(), practice_name, result, error, self.api_version.value))
        
        conn.commit()
        conn.close()


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Sync GP practices with NHS APIs')
    parser.add_argument('--api', choices=['STU3', 'R4'], default='STU3',
                       help='API version to use (default: STU3)')
    parser.add_argument('--sync-extracted', action='store_true',
                       help='Sync all GP practices found in extracted addresses')
    parser.add_argument('--update-records', action='store_true',
                       help='Update patient records with official GP data')
    parser.add_argument('--sync-practice', help='Sync a specific practice by name')
    parser.add_argument('--postcode', help='Postcode hint for practice lookup')
    parser.add_argument('--list', action='store_true',
                       help='List all unique GP practices in database')
    parser.add_argument('--test-api', action='store_true',
                       help='Test API connection')
    
    args = parser.parse_args()
    
    # Setup logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    
    # Select API version
    api_version = APIVersion.STU3 if args.api == 'STU3' else APIVersion.FHIR_R4
    syncer = GPPracticeSync(api_version=api_version)
    
    if args.test_api:
        print(f"\nTesting {api_version.value} API...")
        # Test with a known practice
        result = syncer.search_practice("Crawley", "RH10")
        if result:
            print(f"✅ API is working!")
            print(f"  Found: {result.get('official_name')}")
            print(f"  ODS Code: {result.get('ods_code')}")
            print(f"  Address: {result.get('address_postcode')}")
        else:
            print("❌ API test failed")
    
    elif args.list:
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
                if practice['address_line2']:
                    print(f"           {practice['address_line2']}")
                print(f"           {practice['address_city']}, {practice['address_postcode']}")
                if practice['phone']:
                    print(f"  Phone: {practice['phone']}")
        else:
            print(f"❌ Failed to sync practice: {args.sync_practice}")
    
    elif args.sync_extracted:
        practices = syncer.get_unique_gp_practices()
        print(f"\nSyncing {len(practices)} GP practices from extracted data...")
        
        # Create list with postcodes where available
        practice_list = []
        for gp_name, gp_practice, gp_postcode in practices:
            name = gp_practice or gp_name
            if name:
                practice_list.append((name, gp_postcode))
        
        results = syncer.sync_all_practices(practice_list)
        print(f"\nSync complete:")
        print(f"  ✅ Success: {results['success']}")
        print(f"  ❌ Failed: {results['failed']}")
        print(f"  ⏭️  Skipped: {results['skipped']}")
    
    elif args.update_records:
        updated = syncer.update_extracted_addresses()
        print(f"\n✅ Updated {updated} patient records with official GP data")
    
    else:
        parser.print_help()


if __name__ == "__main__":
    main()