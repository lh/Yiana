#!/usr/bin/env python3
"""
GP Practice Matcher
Automatically matches extracted GP references to official NHS practices
"""

import sqlite3
from typing import Dict, List, Optional, Tuple
import logging
from gp_fuzzy_search import GPFuzzySearch

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class GPMatcher:
    """Match extracted GP references to official NHS practices"""
    
    def __init__(self, extraction_db: str = "addresses.db", gp_db: str = "gp_local.db"):
        self.extraction_db = extraction_db
        self.gp_db = gp_db
        self.searcher = GPFuzzySearch(gp_db)
    
    def get_unmatched_gps(self) -> List[Dict]:
        """Get all unique GP references that haven't been matched yet"""
        conn = sqlite3.connect(self.extraction_db)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT DISTINCT 
                gp_name, 
                gp_practice, 
                gp_address,
                postcode,
                COUNT(*) as patient_count
            FROM extracted_addresses
            WHERE (gp_name IS NOT NULL OR gp_practice IS NOT NULL)
            AND gp_ods_code IS NULL
            GROUP BY gp_name, gp_practice, gp_address, postcode
            ORDER BY patient_count DESC
        """)
        
        results = []
        for row in cursor.fetchall():
            results.append({
                'gp_name': row[0],
                'gp_practice': row[1],
                'gp_address': row[2],
                'patient_postcode': row[3],
                'patient_count': row[4]
            })
        
        conn.close()
        return results
    
    def match_gp_practice(self, gp_ref: Dict, confidence_threshold: float = 30.0) -> Optional[Dict]:
        """
        Match a GP reference to an official practice
        
        Returns dict with:
            - ods_code
            - official_name
            - full_address
            - postcode
            - phone
            - confidence
        """
        
        # Use fuzzy search
        results = self.searcher.search(
            gp_name=gp_ref.get('gp_name'),
            practice_hint=gp_ref.get('gp_practice'),
            address_hint=gp_ref.get('gp_address'),
            patient_postcode=gp_ref.get('patient_postcode'),
            limit=3
        )
        
        if results and results[0].score >= confidence_threshold:
            best_match = results[0]
            
            # Build full address
            address_parts = [best_match.address_1]
            if best_match.address_2:
                address_parts.append(best_match.address_2)
            
            return {
                'ods_code': best_match.ods_code,
                'official_name': best_match.name,
                'full_address': ', '.join(address_parts),
                'postcode': best_match.postcode,
                'phone': best_match.phone,
                'confidence': best_match.score,
                'match_reasons': best_match.match_reasons
            }
        
        return None
    
    def update_patient_records(self, gp_ref: Dict, match: Dict) -> int:
        """Update patient records with matched GP practice data"""
        
        conn = sqlite3.connect(self.extraction_db)
        cursor = conn.cursor()
        
        # Build update query based on what we're matching on
        conditions = []
        params = []
        
        if gp_ref.get('gp_name'):
            conditions.append("gp_name = ?")
            params.append(gp_ref['gp_name'])
        
        if gp_ref.get('gp_practice'):
            conditions.append("gp_practice = ?")
            params.append(gp_ref['gp_practice'])
        
        if not conditions:
            return 0
        
        where_clause = " AND ".join(conditions)
        
        # Update with official data
        cursor.execute(f"""
            UPDATE extracted_addresses
            SET gp_ods_code = ?,
                gp_official_name = ?,
                gp_address = ?,
                gp_postcode = ?
            WHERE {where_clause}
            AND gp_ods_code IS NULL
        """, (
            match['ods_code'],
            match['official_name'],
            match['full_address'],
            match['postcode'],
            *params
        ))
        
        updated = cursor.rowcount
        conn.commit()
        conn.close()
        
        return updated
    
    def auto_match_all(self, confidence_threshold: float = 40.0, manual_review_threshold: float = 30.0):
        """
        Automatically match all unmatched GP references
        
        Args:
            confidence_threshold: Auto-accept matches above this score
            manual_review_threshold: Show matches between manual and confidence threshold for review
        """
        
        unmatched = self.get_unmatched_gps()
        
        print(f"\n📊 Found {len(unmatched)} unique unmatched GP references")
        print("="*80)
        
        auto_matched = 0
        review_needed = 0
        no_match = 0
        
        for gp_ref in unmatched:
            print(f"\n🔍 Searching for: {gp_ref.get('gp_practice') or gp_ref.get('gp_name')}")
            print(f"   Patients affected: {gp_ref['patient_count']}")
            
            match = self.match_gp_practice(gp_ref, manual_review_threshold)
            
            if match:
                confidence = match['confidence']
                
                if confidence >= confidence_threshold:
                    # Auto-accept high confidence matches
                    print(f"   ✅ AUTO-MATCHED: {match['official_name']} (ODS: {match['ods_code']})")
                    print(f"      Confidence: {confidence:.1f}")
                    print(f"      Address: {match['full_address']}, {match['postcode']}")
                    
                    updated = self.update_patient_records(gp_ref, match)
                    print(f"      Updated {updated} patient records")
                    auto_matched += 1
                    
                else:
                    # Needs manual review
                    print(f"   ⚠️  REVIEW NEEDED: {match['official_name']} (ODS: {match['ods_code']})")
                    print(f"      Confidence: {confidence:.1f} (below auto-threshold of {confidence_threshold})")
                    print(f"      Address: {match['full_address']}, {match['postcode']}")
                    print(f"      Match reasons: {', '.join(match['match_reasons'])}")
                    
                    # Ask for confirmation
                    response = input("      Accept this match? (y/n/skip): ").lower().strip()
                    
                    if response == 'y':
                        updated = self.update_patient_records(gp_ref, match)
                        print(f"      Updated {updated} patient records")
                        auto_matched += 1
                    else:
                        review_needed += 1
            else:
                print(f"   ❌ NO MATCH FOUND")
                no_match += 1
        
        # Summary
        print("\n" + "="*80)
        print("📊 MATCHING SUMMARY:")
        print(f"   ✅ Auto-matched: {auto_matched}")
        print(f"   ⚠️  Review needed: {review_needed}")
        print(f"   ❌ No match: {no_match}")
        
        return auto_matched, review_needed, no_match
    
    def add_manual_match(self, gp_name: str, gp_practice: str, ods_code: str):
        """Manually specify a match for a GP practice"""
        
        # Get official data from NHS database
        conn = sqlite3.connect(self.gp_db)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT name, address_1, address_2, postcode, phone
            FROM gp_practices_bulk
            WHERE ods_code = ?
        """, (ods_code,))
        
        row = cursor.fetchone()
        conn.close()
        
        if not row:
            logger.error(f"ODS code {ods_code} not found in database")
            return False
        
        official_name, addr1, addr2, postcode, phone = row
        full_address = f"{addr1}, {addr2}" if addr2 else addr1
        
        # Update patient records
        conn = sqlite3.connect(self.extraction_db)
        cursor = conn.cursor()
        
        conditions = []
        params = []
        
        if gp_name:
            conditions.append("gp_name = ?")
            params.append(gp_name)
        
        if gp_practice:
            conditions.append("gp_practice = ?")
            params.append(gp_practice)
        
        where_clause = " OR ".join(conditions) if conditions else "1=0"
        
        cursor.execute(f"""
            UPDATE extracted_addresses
            SET gp_ods_code = ?,
                gp_official_name = ?,
                gp_address = ?,
                gp_postcode = ?
            WHERE ({where_clause})
            AND gp_ods_code IS NULL
        """, (ods_code, official_name, full_address, postcode, *params))
        
        updated = cursor.rowcount
        conn.commit()
        conn.close()
        
        print(f"✅ Manually matched {updated} records to {official_name}")
        return True


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Match GP practices to NHS data')
    parser.add_argument('--auto', action='store_true',
                       help='Automatically match all unmatched GPs')
    parser.add_argument('--list', action='store_true',
                       help='List unmatched GP references')
    parser.add_argument('--manual', nargs=3, metavar=('GP_NAME', 'PRACTICE', 'ODS_CODE'),
                       help='Manually match a GP practice to an ODS code')
    parser.add_argument('--confidence', type=float, default=40.0,
                       help='Confidence threshold for auto-matching (default: 40)')
    
    args = parser.parse_args()
    
    matcher = GPMatcher()
    
    if args.list:
        unmatched = matcher.get_unmatched_gps()
        print(f"\n📋 Unmatched GP References ({len(unmatched)} total):")
        print("-"*80)
        for ref in unmatched:
            print(f"GP: {ref.get('gp_name') or 'N/A':20} Practice: {ref.get('gp_practice') or 'N/A':30}")
            print(f"   Patients: {ref['patient_count']}")
            if ref.get('gp_address'):
                print(f"   Address hint: {ref['gp_address']}")
            print()
    
    elif args.auto:
        matcher.auto_match_all(confidence_threshold=args.confidence)
    
    elif args.manual:
        gp_name, practice, ods_code = args.manual
        matcher.add_manual_match(gp_name, practice, ods_code)
    
    else:
        parser.print_help()
        print("\nExamples:")
        print("  python gp_matcher.py --list")
        print("  python gp_matcher.py --auto")
        print('  python gp_matcher.py --manual "Dr Croucher" "THE HEALTH CENTRE" "H82040"')


if __name__ == "__main__":
    main()