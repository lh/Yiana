#!/usr/bin/env python3
"""
Optician Database
Database of UK opticians with fuzzy search capabilities
Similar to GP database but for optometry practices
"""

import sqlite3
import logging
from pathlib import Path
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass
from difflib import SequenceMatcher
import re

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class OpticianSearchResult:
    """Search result for optician lookup"""
    name: str
    practice_name: str
    address_line_1: str
    address_line_2: Optional[str]
    city: str
    postcode: str
    phone: Optional[str]
    score: float
    match_reasons: List[str]


class OpticianDatabase:
    """Database and search for UK opticians"""
    
    def __init__(self, db_path: str = "opticians_uk.db"):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Create optician database schema"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS opticians (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                practice_name TEXT NOT NULL,
                branch_name TEXT,
                
                -- Address
                address_line_1 TEXT NOT NULL,
                address_line_2 TEXT,
                address_line_3 TEXT,
                city TEXT,
                county TEXT,
                postcode TEXT NOT NULL,
                
                -- Contact
                phone TEXT,
                email TEXT,
                website TEXT,
                
                -- Type/Chain
                chain_name TEXT,  -- Specsavers, Vision Express, etc.
                practice_type TEXT,  -- Independent, Chain, Hospital
                
                -- Services
                nhs_provider BOOLEAN DEFAULT 1,
                private_only BOOLEAN DEFAULT 0,
                domiciliary BOOLEAN DEFAULT 0,
                
                -- Search optimization
                search_text TEXT,  -- Concatenated searchable text
                
                -- Metadata
                source TEXT,
                last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                verified BOOLEAN DEFAULT 0
            )
        """)
        
        # Create indexes for search
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_opticians_practice 
            ON opticians(practice_name)
        """)
        
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_opticians_postcode 
            ON opticians(postcode)
        """)
        
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_opticians_city 
            ON opticians(city)
        """)
        
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_opticians_chain 
            ON opticians(chain_name)
        """)
        
        conn.commit()
        conn.close()
        
        logger.info(f"Optician database initialized at {self.db_path}")
    
    def add_optician(self, practice_name: str, address_line_1: str, 
                    postcode: str, **kwargs) -> int:
        """Add an optician to the database"""
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Build search text for optimization
        search_parts = [
            practice_name,
            kwargs.get('branch_name', ''),
            address_line_1,
            kwargs.get('city', ''),
            postcode,
            kwargs.get('chain_name', '')
        ]
        search_text = ' '.join(filter(None, search_parts)).lower()
        
        cursor.execute("""
            INSERT INTO opticians (
                practice_name, branch_name, address_line_1, address_line_2,
                address_line_3, city, county, postcode, phone, email,
                website, chain_name, practice_type, nhs_provider,
                private_only, domiciliary, search_text, source, verified
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            practice_name,
            kwargs.get('branch_name'),
            address_line_1,
            kwargs.get('address_line_2'),
            kwargs.get('address_line_3'),
            kwargs.get('city'),
            kwargs.get('county'),
            postcode,
            kwargs.get('phone'),
            kwargs.get('email'),
            kwargs.get('website'),
            kwargs.get('chain_name'),
            kwargs.get('practice_type', 'Independent'),
            kwargs.get('nhs_provider', True),
            kwargs.get('private_only', False),
            kwargs.get('domiciliary', False),
            search_text,
            kwargs.get('source', 'Manual'),
            kwargs.get('verified', False)
        ))
        
        optician_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        logger.info(f"Added optician: {practice_name} at {postcode}")
        return optician_id
    
    def search(self, name: str, postcode_hint: str = None, 
              city_hint: str = None, chain_hint: str = None,
              max_results: int = 10) -> List[Dict]:
        """
        Fuzzy search for opticians
        
        Args:
            name: Optician or practice name to search for
            postcode_hint: Optional postcode area hint
            city_hint: Optional city hint
            chain_hint: Optional chain name hint (Specsavers, etc.)
            max_results: Maximum number of results to return
        """
        
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        # Get all opticians for scoring
        cursor.execute("""
            SELECT * FROM opticians
        """)
        
        all_opticians = cursor.fetchall()
        conn.close()
        
        results = []
        
        # Clean search term
        search_name = self._clean_name(name)
        
        for optician in all_opticians:
            score = 0
            match_reasons = []
            
            # Score practice name match
            practice_score = self._fuzzy_match(
                search_name, 
                self._clean_name(optician['practice_name'])
            )
            if practice_score > 0.7:
                score += practice_score * 10
                match_reasons.append(f"Practice name match ({practice_score:.2f})")
            
            # Check branch name if present
            if optician['branch_name']:
                branch_score = self._fuzzy_match(
                    search_name,
                    self._clean_name(optician['branch_name'])
                )
                if branch_score > 0.7:
                    score += branch_score * 5
                    match_reasons.append(f"Branch name match ({branch_score:.2f})")
            
            # Chain matching
            if chain_hint and optician['chain_name']:
                if chain_hint.lower() in optician['chain_name'].lower():
                    score += 5
                    match_reasons.append("Chain match")
            
            # Check if it's a known chain in the name
            chains = ['specsavers', 'vision express', 'boots', 'tesco', 'asda']
            for chain in chains:
                if chain in search_name.lower() and optician['chain_name']:
                    if chain in optician['chain_name'].lower():
                        score += 8
                        match_reasons.append(f"Chain '{chain}' match")
                        break
            
            # Postcode matching
            if postcode_hint:
                postcode_clean = postcode_hint.upper().replace(' ', '')
                optician_postcode = optician['postcode'].upper().replace(' ', '')
                
                # Exact match
                if postcode_clean == optician_postcode:
                    score += 10
                    match_reasons.append("Exact postcode match")
                # Same area (first part)
                elif postcode_clean[:3] == optician_postcode[:3]:
                    score += 5
                    match_reasons.append("Postcode area match")
                # Same district
                elif postcode_clean[:2] == optician_postcode[:2]:
                    score += 2
                    match_reasons.append("Postcode district match")
            
            # City matching
            if city_hint and optician['city']:
                if city_hint.lower() in optician['city'].lower():
                    score += 3
                    match_reasons.append("City match")
            
            # Address matching
            if optician['address_line_1']:
                addr_words = search_name.lower().split()
                addr_line = optician['address_line_1'].lower()
                for word in addr_words:
                    if len(word) > 3 and word in addr_line:
                        score += 1
                        match_reasons.append(f"Address word '{word}'")
            
            # Only include if score is significant
            if score > 0:
                results.append({
                    'practice_name': optician['practice_name'],
                    'branch_name': optician['branch_name'],
                    'chain_name': optician['chain_name'],
                    'address_line_1': optician['address_line_1'],
                    'address_line_2': optician['address_line_2'],
                    'city': optician['city'],
                    'postcode': optician['postcode'],
                    'phone': optician['phone'],
                    'practice_type': optician['practice_type'],
                    'score': score,
                    'match_reasons': match_reasons
                })
        
        # Sort by score and return top results
        results.sort(key=lambda x: x['score'], reverse=True)
        return results[:max_results]
    
    def _clean_name(self, name: str) -> str:
        """Clean and normalize name for matching"""
        if not name:
            return ""
        
        # Remove common optician terms
        name = re.sub(r'\b(opticians?|optometry|optical|eyecare|vision)\b', 
                      '', name, flags=re.IGNORECASE)
        
        # Remove punctuation and extra spaces
        name = re.sub(r'[^\w\s]', ' ', name)
        name = ' '.join(name.split())
        
        return name.lower()
    
    def _fuzzy_match(self, str1: str, str2: str) -> float:
        """Calculate fuzzy match score between two strings"""
        if not str1 or not str2:
            return 0.0
        
        # Use SequenceMatcher for fuzzy matching
        return SequenceMatcher(None, str1.lower(), str2.lower()).ratio()
    
    def populate_sample_data(self):
        """Populate database with sample UK optician data"""
        
        sample_opticians = [
            {
                'practice_name': 'Specsavers Opticians',
                'branch_name': 'Horsham',
                'address_line_1': '47-48 West Street',
                'city': 'Horsham',
                'postcode': 'RH12 1PQ',
                'phone': '01403 251841',
                'chain_name': 'Specsavers',
                'practice_type': 'Chain'
            },
            {
                'practice_name': 'Vision Express',
                'branch_name': 'Horsham',
                'address_line_1': '15 Swan Walk',
                'city': 'Horsham',
                'postcode': 'RH12 1HQ',
                'phone': '01403 217925',
                'chain_name': 'Vision Express',
                'practice_type': 'Chain'
            },
            {
                'practice_name': 'Boots Opticians',
                'branch_name': 'Horsham',
                'address_line_1': '58-60 West Street',
                'city': 'Horsham',
                'postcode': 'RH12 1PL',
                'phone': '01403 255925',
                'chain_name': 'Boots',
                'practice_type': 'Chain'
            },
            {
                'practice_name': 'Eye Society',
                'address_line_1': '5 Park Place',
                'city': 'Horsham',
                'postcode': 'RH12 1DG',
                'phone': '01403 252888',
                'practice_type': 'Independent'
            },
            {
                'practice_name': 'Leightons Opticians',
                'branch_name': 'Horsham',
                'address_line_1': '60 Carfax',
                'city': 'Horsham',
                'postcode': 'RH12 1EQ',
                'phone': '01403 213111',
                'chain_name': 'Leightons',
                'practice_type': 'Regional Chain'
            },
            # London examples
            {
                'practice_name': 'Moorfields Eye Hospital Opticians',
                'address_line_1': '162 City Road',
                'city': 'London',
                'postcode': 'EC1V 2PD',
                'phone': '020 7253 3411',
                'practice_type': 'Hospital'
            },
            {
                'practice_name': 'David Clulow Opticians',
                'branch_name': 'Marylebone',
                'address_line_1': '114 Marylebone High Street',
                'city': 'London',
                'postcode': 'W1U 4RY',
                'phone': '020 7224 6323',
                'chain_name': 'David Clulow',
                'practice_type': 'Chain'
            }
        ]
        
        for optician_data in sample_opticians:
            practice_name = optician_data.pop('practice_name')
            address_line_1 = optician_data.pop('address_line_1')
            postcode = optician_data.pop('postcode')
            
            self.add_optician(practice_name, address_line_1, postcode, **optician_data)
        
        logger.info(f"Added {len(sample_opticians)} sample opticians")
    
    def import_from_csv(self, csv_file: str) -> int:
        """Import optician data from CSV file"""
        import csv
        
        count = 0
        with open(csv_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            for row in reader:
                try:
                    self.add_optician(
                        practice_name=row['practice_name'],
                        address_line_1=row['address_line_1'],
                        postcode=row['postcode'],
                        branch_name=row.get('branch_name'),
                        address_line_2=row.get('address_line_2'),
                        city=row.get('city'),
                        county=row.get('county'),
                        phone=row.get('phone'),
                        chain_name=row.get('chain_name'),
                        practice_type=row.get('practice_type', 'Independent')
                    )
                    count += 1
                except Exception as e:
                    logger.error(f"Error importing row: {e}")
        
        logger.info(f"Imported {count} opticians from CSV")
        return count


def test_optician_search():
    """Test the optician search functionality"""
    
    db = OpticianDatabase()
    
    # Check if we have data
    conn = sqlite3.connect(db.db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM opticians")
    count = cursor.fetchone()[0]
    conn.close()
    
    if count == 0:
        print("Populating sample data...")
        db.populate_sample_data()
    
    # Test searches
    test_cases = [
        ("Specsavers", None, "Horsham", None),
        ("boots", None, None, None),
        ("Eye Society", "RH12", None, None),
        ("Mr B Jones", None, "Horsham", None),
        ("Optician Horsham", None, "Horsham", None),
    ]
    
    for name, postcode, city, chain in test_cases:
        print(f"\n🔍 Searching for: {name}")
        if postcode:
            print(f"   Postcode hint: {postcode}")
        if city:
            print(f"   City hint: {city}")
        
        results = db.search(name, postcode_hint=postcode, city_hint=city, chain_hint=chain)
        
        if results:
            print(f"\n   Found {len(results)} matches:")
            for i, result in enumerate(results[:3], 1):
                print(f"\n   {i}. {result['practice_name']}")
                if result['branch_name']:
                    print(f"      Branch: {result['branch_name']}")
                if result['chain_name']:
                    print(f"      Chain: {result['chain_name']}")
                print(f"      {result['address_line_1']}")
                print(f"      {result['city']}, {result['postcode']}")
                if result['phone']:
                    print(f"      Phone: {result['phone']}")
                print(f"      Score: {result['score']}")
                print(f"      Reasons: {', '.join(result['match_reasons'])}")
        else:
            print("   No matches found")


def main():
    """Command-line interface"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Optician Database Search')
    parser.add_argument('name', nargs='?', help='Optician name to search for')
    parser.add_argument('--postcode', help='Postcode hint')
    parser.add_argument('--city', help='City hint')
    parser.add_argument('--chain', help='Chain name hint')
    parser.add_argument('--populate', action='store_true', help='Populate sample data')
    parser.add_argument('--import-csv', help='Import from CSV file')
    parser.add_argument('--test', action='store_true', help='Run test searches')
    
    args = parser.parse_args()
    
    db = OpticianDatabase()
    
    if args.populate:
        db.populate_sample_data()
        print("✅ Sample data populated")
        
    elif args.import_csv:
        count = db.import_from_csv(args.import_csv)
        print(f"✅ Imported {count} opticians")
        
    elif args.test:
        test_optician_search()
        
    elif args.name:
        results = db.search(
            args.name,
            postcode_hint=args.postcode,
            city_hint=args.city,
            chain_hint=args.chain
        )
        
        if results:
            print(f"\n📋 Found {len(results)} matches:\n")
            for i, result in enumerate(results, 1):
                print(f"{i}. {result['practice_name']}")
                if result['branch_name']:
                    print(f"   Branch: {result['branch_name']}")
                if result['chain_name']:
                    print(f"   Chain: {result['chain_name']}")
                print(f"   {result['address_line_1']}")
                if result['address_line_2']:
                    print(f"   {result['address_line_2']}")
                print(f"   {result['city']}, {result['postcode']}")
                if result['phone']:
                    print(f"   Phone: {result['phone']}")
                print(f"   Match score: {result['score']}")
                print()
        else:
            print("❌ No matches found")
    else:
        parser.print_help()
        print("\nExamples:")
        print("  python optician_database.py --populate")
        print("  python optician_database.py --test")
        print("  python optician_database.py 'Specsavers' --city Horsham")
        print("  python optician_database.py 'Mr B Jones' --postcode RH12")


if __name__ == "__main__":
    main()