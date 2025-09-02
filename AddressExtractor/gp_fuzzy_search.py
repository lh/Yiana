#!/usr/bin/env python3
"""
Fuzzy GP Practice Search System
Searches local database using multiple signals: GP name, practice hints, postcode, address
"""

import sqlite3
import re
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from difflib import SequenceMatcher
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class SearchResult:
    """GP practice search result with confidence score"""
    ods_code: str
    name: str
    address_1: str
    address_2: str
    postcode: str
    phone: str
    score: float
    match_reasons: List[str]


class GPFuzzySearch:
    """Fuzzy search for GP practices in local database"""
    
    def __init__(self, db_path: str = "gp_local.db"):
        self.db_path = db_path
    
    def fuzzy_match_score(self, query: str, target: str) -> float:
        """Calculate fuzzy match score between two strings"""
        if not query or not target:
            return 0.0
        
        query_upper = query.upper().strip()
        target_upper = target.upper().strip()
        
        # Exact match
        if query_upper == target_upper:
            return 1.0
        
        # Contains match
        if query_upper in target_upper:
            return 0.8
        
        # Word-level matching
        query_words = set(query_upper.split())
        target_words = set(target_upper.split())
        
        # All query words in target
        if query_words.issubset(target_words):
            return 0.7
        
        # Some query words in target
        common_words = query_words.intersection(target_words)
        if common_words:
            return 0.5 * (len(common_words) / len(query_words))
        
        # Use sequence matcher for similarity
        return SequenceMatcher(None, query_upper, target_upper).ratio() * 0.6
    
    def postcode_distance(self, postcode1: str, postcode2: str) -> int:
        """Rough distance estimate between postcodes (0=same, higher=farther)"""
        if not postcode1 or not postcode2:
            return 100
        
        p1 = postcode1.upper().strip()
        p2 = postcode2.upper().strip()
        
        # Same postcode
        if p1 == p2:
            return 0
        
        # Same district (e.g., RH10)
        district1 = p1.split()[0] if ' ' in p1 else p1[:4]
        district2 = p2.split()[0] if ' ' in p2 else p2[:4]
        
        if district1 == district2:
            return 1
        
        # Same area (e.g., RH)
        if district1[:2] == district2[:2]:
            return 5
        
        # Different area
        return 10
    
    def search(self, 
               gp_name: Optional[str] = None,
               practice_hint: Optional[str] = None,
               address_hint: Optional[str] = None,
               patient_postcode: Optional[str] = None,
               limit: int = 10) -> List[SearchResult]:
        """
        Multi-factor fuzzy search for GP practices
        
        Args:
            gp_name: GP doctor name (e.g., "Dr Croucher")
            practice_hint: Practice name hint (e.g., "HEALTH CENTRE")
            address_hint: Address keywords (e.g., "BOWERS")
            patient_postcode: Patient's postcode for proximity
            limit: Maximum results to return
        """
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Extract useful parts
        gp_surname = None
        if gp_name:
            # Extract surname from "Dr Surname" or "Doctor SURNAME"
            parts = gp_name.upper().replace("DR.", "").replace("DR", "").replace("DOCTOR", "").strip().split()
            if parts:
                gp_surname = parts[-1]  # Last word is usually surname
        
        patient_district = None
        if patient_postcode:
            patient_district = patient_postcode.upper().split()[0] if ' ' in patient_postcode else patient_postcode[:4]
        
        # Build query based on available hints
        candidates = []
        
        # Strategy 1: Search by postcode area if available
        if patient_district:
            cursor.execute("""
                SELECT ods_code, name, address_1, address_2, address_3, postcode, phone
                FROM gp_practices_bulk
                WHERE postcode_district = ?
            """, (patient_district,))
            
            for row in cursor.fetchall():
                candidates.append({
                    'ods_code': row[0],
                    'name': row[1],
                    'address_1': row[2],
                    'address_2': row[3],
                    'address_3': row[4],
                    'postcode': row[5],
                    'phone': row[6],
                    'source': 'postcode_area'
                })
        
        # Strategy 2: Search by practice name keywords
        if practice_hint:
            # Search for practices with matching words
            words = practice_hint.upper().split()
            for word in words:
                if len(word) > 3:  # Skip short words
                    cursor.execute("""
                        SELECT ods_code, name, address_1, address_2, address_3, postcode, phone
                        FROM gp_practices_bulk
                        WHERE name_upper LIKE ?
                        LIMIT 100
                    """, (f"%{word}%",))
                    
                    for row in cursor.fetchall():
                        candidates.append({
                            'ods_code': row[0],
                            'name': row[1],
                            'address_1': row[2],
                            'address_2': row[3],
                            'address_3': row[4],
                            'postcode': row[5],
                            'phone': row[6],
                            'source': f'name_match_{word}'
                        })
        
        # Strategy 3: Search by address keywords
        if address_hint:
            address_words = address_hint.upper().split()
            for word in address_words:
                if len(word) > 3:
                    cursor.execute("""
                        SELECT ods_code, name, address_1, address_2, address_3, postcode, phone
                        FROM gp_practices_bulk
                        WHERE address_1 LIKE ? OR address_2 LIKE ? OR address_3 LIKE ?
                        LIMIT 100
                    """, (f"%{word}%", f"%{word}%", f"%{word}%"))
                    
                    for row in cursor.fetchall():
                        candidates.append({
                            'ods_code': row[0],
                            'name': row[1],
                            'address_1': row[2],
                            'address_2': row[3],
                            'address_3': row[4],
                            'postcode': row[5],
                            'phone': row[6],
                            'source': f'address_match_{word}'
                        })
        
        # Deduplicate and score candidates
        seen = {}
        for candidate in candidates:
            ods_code = candidate['ods_code']
            if ods_code not in seen:
                seen[ods_code] = candidate
        
        # Score each unique candidate
        results = []
        for candidate in seen.values():
            score = 0
            match_reasons = []
            
            # Score based on practice name match
            if practice_hint:
                name_score = self.fuzzy_match_score(practice_hint, candidate['name'])
                score += name_score * 40
                if name_score > 0.5:
                    match_reasons.append(f"Name match ({name_score:.2f})")
            
            # Score based on address match
            if address_hint:
                full_address = f"{candidate['address_1']} {candidate['address_2']} {candidate.get('address_3', '')}"
                addr_score = self.fuzzy_match_score(address_hint, full_address)
                score += addr_score * 30
                if addr_score > 0.5:
                    match_reasons.append(f"Address match ({addr_score:.2f})")
            
            # Score based on postcode proximity
            if patient_postcode and candidate['postcode']:
                distance = self.postcode_distance(patient_postcode, candidate['postcode'])
                proximity_score = max(0, 10 - distance) / 10.0
                score += proximity_score * 20
                if proximity_score > 0.5:
                    match_reasons.append(f"Near patient (score: {proximity_score:.2f})")
            
            # Bonus for specific keyword matches
            if practice_hint and address_hint:
                # Check if both practice hint and address hint match
                if (practice_hint.upper() in candidate['name'].upper() and 
                    address_hint.upper() in f"{candidate['address_1']} {candidate['address_2']}".upper()):
                    score += 20
                    match_reasons.append("Both name and address match")
            
            # Special cases for common patterns
            if practice_hint and "HEALTH CENTRE" in practice_hint.upper() and "HEALTH" in candidate['name'].upper():
                score += 5
                match_reasons.append("Health Centre match")
            
            if practice_hint and "SURGERY" in practice_hint.upper() and "SURGERY" in candidate['name'].upper():
                score += 5
                match_reasons.append("Surgery match")
            
            if practice_hint and "MEDICAL" in practice_hint.upper() and "MEDICAL" in candidate['name'].upper():
                score += 5
                match_reasons.append("Medical Centre match")
            
            results.append(SearchResult(
                ods_code=candidate['ods_code'],
                name=candidate['name'],
                address_1=candidate['address_1'],
                address_2=candidate['address_2'],
                postcode=candidate['postcode'],
                phone=candidate['phone'] or '',
                score=score,
                match_reasons=match_reasons
            ))
        
        conn.close()
        
        # Sort by score and return top results
        results.sort(key=lambda x: x.score, reverse=True)
        return results[:limit]
    
    def find_practice_for_extraction(self, extracted_data: Dict) -> Optional[SearchResult]:
        """
        Find GP practice based on extracted patient data
        
        Args:
            extracted_data: Dictionary with keys like 'gp_name', 'gp_practice', 'gp_postcode', 'postcode'
        """
        
        results = self.search(
            gp_name=extracted_data.get('gp_name'),
            practice_hint=extracted_data.get('gp_practice'),
            address_hint=extracted_data.get('gp_address'),
            patient_postcode=extracted_data.get('postcode') or extracted_data.get('gp_postcode'),
            limit=5
        )
        
        if results and results[0].score > 30:
            return results[0]
        
        return None


def test_our_gps():
    """Test finding our known GP practices"""
    
    searcher = GPFuzzySearch()
    
    # Test cases from our extracted data
    test_cases = [
        {
            'name': 'Dr Croucher at THE HEALTH CENTRE',
            'gp_name': 'Dr Croucher',
            'gp_practice': 'THE HEALTH CENTRE',
            'gp_address': 'BOWERS PLACE',
            'postcode': 'RH10 4HD'
        },
        {
            'name': 'Dr Williamson at WAYSIDE SURGERY',
            'gp_name': 'Dr Williamson',
            'gp_practice': 'WAYSIDE SURGERY',
            'gp_address': None,
            'postcode': 'RH6 9EP'
        },
        {
            'name': 'Dr Reade at MENFIELD',
            'gp_name': 'Dr Reade',
            'gp_practice': 'MENFIELD',
            'gp_address': None,
            'postcode': 'RH13 8JT'
        }
    ]
    
    for test in test_cases:
        print(f"\n{'='*60}")
        print(f"Searching for: {test['name']}")
        print(f"{'='*60}")
        
        results = searcher.search(
            gp_name=test.get('gp_name'),
            practice_hint=test.get('gp_practice'),
            address_hint=test.get('gp_address'),
            patient_postcode=test.get('postcode'),
            limit=3
        )
        
        if results:
            print(f"\n✅ Found {len(results)} matches:")
            for i, result in enumerate(results, 1):
                print(f"\n{i}. {result.name} (ODS: {result.ods_code})")
                print(f"   Score: {result.score:.1f}")
                print(f"   Address: {result.address_1}, {result.address_2}")
                print(f"   Postcode: {result.postcode}")
                if result.phone:
                    print(f"   Phone: {result.phone}")
                print(f"   Match reasons: {', '.join(result.match_reasons)}")
        else:
            print("❌ No matches found")


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Fuzzy search GP practices')
    parser.add_argument('--test', action='store_true',
                       help='Test with our known GP practices')
    parser.add_argument('--gp', help='GP name (e.g., "Dr Smith")')
    parser.add_argument('--practice', help='Practice name hint')
    parser.add_argument('--address', help='Address keywords')
    parser.add_argument('--postcode', help='Patient postcode')
    parser.add_argument('--limit', type=int, default=5,
                       help='Maximum results to show')
    
    args = parser.parse_args()
    
    if args.test:
        test_our_gps()
    elif any([args.gp, args.practice, args.address, args.postcode]):
        searcher = GPFuzzySearch()
        results = searcher.search(
            gp_name=args.gp,
            practice_hint=args.practice,
            address_hint=args.address,
            patient_postcode=args.postcode,
            limit=args.limit
        )
        
        if results:
            print(f"Found {len(results)} matches:")
            for i, result in enumerate(results, 1):
                print(f"\n{i}. {result.name} (ODS: {result.ods_code})")
                print(f"   Score: {result.score:.1f}")
                print(f"   Address: {result.address_1}, {result.address_2}")
                print(f"   Postcode: {result.postcode}")
                if result.phone:
                    print(f"   Phone: {result.phone}")
                print(f"   Match reasons: {', '.join(result.match_reasons)}")
        else:
            print("No matches found")
    else:
        parser.print_help()


if __name__ == "__main__":
    main()