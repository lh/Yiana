#!/usr/bin/env python3
"""
Medical Letter System CLI
Complete command-line interface for the letter generation workflow
"""

import argparse
import sys
from pathlib import Path
from datetime import datetime
import json

from letter_processor import LetterProcessor
from letter_system_db_simple import SimpleLetterDatabase
from gp_fuzzy_search import GPFuzzySearch
from letter_generator_improved import ImprovedLetterGenerator


class LetterSystemCLI:
    """Main CLI for the medical letter system"""
    
    def __init__(self):
        self.db = SimpleLetterDatabase()
        self.gp_finder = GPFuzzySearch()
        
    def process_notes(self, args):
        """Process clinic notes and generate letters"""
        processor = LetterProcessor()
        
        if not Path(args.file).exists():
            print(f"❌ File not found: {args.file}")
            return 1
        
        stats = processor.process_notes_file(
            args.file,
            generate_letters=not args.no_letters
        )
        
        print("\n📊 Processing Complete:")
        print(f"   Notes parsed: {stats['parsed']}")
        print(f"   Titles extracted: {stats['titles_extracted']}")
        print(f"   Patients saved: {stats['saved']}")
        
        if not args.no_letters:
            print(f"   Letters generated: {stats['letters_generated']}")
            if stats['missing_addresses'] > 0:
                print(f"   ⚠️  Missing addresses: {stats['missing_addresses']}")
                print("      Use 'letter-cli missing' to see which patients need addresses")
        
        return 0
    
    def show_missing(self, args):
        """Show patients with missing addresses"""
        import sqlite3
        conn = sqlite3.connect(self.db.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT spire_mrn, patient_name, first_seen, times_needed
            FROM missing_addresses
            ORDER BY times_needed DESC, first_seen
        """)
        
        missing = cursor.fetchall()
        conn.close()
        
        if not missing:
            print("✅ No patients with missing addresses")
            return 0
        
        print(f"\n📋 Patients needing addresses ({len(missing)}):\n")
        print(f"{'MRN':<12} {'Name':<30} {'First Seen':<12} {'Times':<6}")
        print("-" * 62)
        
        for mrn, name, first_seen, times in missing:
            print(f"{mrn:<12} {name:<30} {first_seen:<12} {times:<6}")
        
        print("\nUse 'letter-cli add-address <mrn>' to add an address")
        return 0
    
    def add_address(self, args):
        """Add or update patient address"""
        patient = self.db.get_patient(args.mrn)
        
        if not patient:
            print(f"❌ Patient {args.mrn} not found")
            return 1
        
        print(f"\n📝 Adding address for: {patient['full_name']} (MRN: {args.mrn})")
        
        # Interactive input if not provided via args
        address_line_1 = args.address1 or input("Address Line 1: ").strip()
        address_line_2 = args.address2 or input("Address Line 2 (optional): ").strip()
        city = args.city or input("City: ").strip()
        postcode = args.postcode or input("Postcode: ").strip()
        phone = args.phone or input("Phone (optional): ").strip()
        
        if not address_line_1 or not city or not postcode:
            print("❌ Address line 1, city, and postcode are required")
            return 1
        
        # Update patient
        self.db.save_patient(
            args.mrn,
            patient['full_name'],
            address_line_1=address_line_1,
            address_line_2=address_line_2 if address_line_2 else None,
            city=city,
            postcode=postcode,
            phone=phone if phone else None
        )
        
        # Remove from missing addresses
        import sqlite3
        conn = sqlite3.connect(self.db.db_path)
        cursor = conn.cursor()
        cursor.execute("DELETE FROM missing_addresses WHERE spire_mrn = ?", (args.mrn,))
        conn.commit()
        conn.close()
        
        print(f"✅ Address updated for {patient['full_name']}")
        return 0
    
    def search_gp(self, args):
        """Search for GP addresses"""
        print(f"\n🔍 Searching for GP: {args.name}")
        
        # Build search parameters
        search_params = {}
        if args.practice:
            search_params['practice_hint'] = args.practice
        if args.address:
            search_params['address_hint'] = args.address
        if args.postcode:
            search_params['postcode_hint'] = args.postcode
        
        results = self.gp_finder.search(args.name, **search_params)
        
        if not results:
            print("❌ No matches found")
            return 1
        
        print(f"\n📋 Found {len(results)} matches:\n")
        
        for i, result in enumerate(results, 1):
            print(f"{i}. {result['name']}")
            if result.get('practice_name'):
                print(f"   Practice: {result['practice_name']}")
            print(f"   Address: {result['address_line_1']}")
            if result.get('address_line_2'):
                print(f"            {result['address_line_2']}")
            print(f"   {result.get('city', '')}, {result['postcode']}")
            print(f"   Match score: {result.get('score', 0)}")
            print()
        
        if args.save and len(results) == 1:
            # Auto-save if only one result
            result = results[0]
            self.db.save_practitioner(
                name_as_written=args.name,
                prac_type='GP',
                practice_name=result.get('practice_name'),
                address_line_1=result['address_line_1'],
                address_line_2=result.get('address_line_2'),
                city=result.get('city'),
                postcode=result['postcode']
            )
            print(f"✅ Saved GP address for {args.name}")
        elif args.save and len(results) > 1:
            print("Multiple results found. Please refine search or save manually.")
        
        return 0
    
    def list_ready(self, args):
        """List letters ready to print"""
        generator = ImprovedLetterGenerator()
        print_me_files = list(generator.print_me_dir.glob("*.pdf"))
        
        if not print_me_files:
            print("✅ No letters waiting to be printed")
            return 0
        
        print(f"\n📄 Letters ready to print ({len(print_me_files)}):\n")
        
        for pdf in sorted(print_me_files):
            # Parse filename for details
            parts = pdf.stem.split('_')
            if len(parts) >= 4:
                mrn = parts[0]
                name = ' '.join(parts[1:-2])
                recipient = parts[-2]
                timestamp = parts[-1]
                
                print(f"  {mrn:<12} {name:<25} {recipient:<10} {timestamp}")
            else:
                print(f"  {pdf.name}")
        
        print(f"\nTotal: {len(print_me_files)} letters")
        print("Use 'letter-cli mark-printed <file>' to move to printed folder")
        return 0
    
    def mark_printed(self, args):
        """Mark letters as printed"""
        generator = ImprovedLetterGenerator()
        
        if args.all:
            # Move all letters
            print_me_files = list(generator.print_me_dir.glob("*.pdf"))
            if not print_me_files:
                print("No letters to mark as printed")
                return 0
            
            moved = 0
            for pdf in print_me_files:
                if generator.move_to_printed(str(pdf)):
                    moved += 1
            
            print(f"✅ Moved {moved} letters to printed folder")
        else:
            # Move specific file
            file_path = generator.print_me_dir / args.file
            if not file_path.exists():
                # Try as full path
                file_path = Path(args.file)
            
            if not file_path.exists():
                print(f"❌ File not found: {args.file}")
                return 1
            
            if generator.move_to_printed(str(file_path)):
                print(f"✅ Moved {file_path.name} to printed folder")
            else:
                print(f"❌ Failed to move {file_path.name}")
                return 1
        
        return 0
    
    def stats(self, args):
        """Show system statistics"""
        import sqlite3
        conn = sqlite3.connect(self.db.db_path)
        cursor = conn.cursor()
        
        # Count patients
        cursor.execute("SELECT COUNT(*) FROM patients")
        patient_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM patients WHERE address_line_1 IS NOT NULL")
        patients_with_address = cursor.fetchone()[0]
        
        # Count practitioners
        cursor.execute("SELECT COUNT(*) FROM practitioners WHERE type = 'GP'")
        gp_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM practitioners WHERE type = 'Optician'")
        optician_count = cursor.fetchone()[0]
        
        # Count letters
        cursor.execute("SELECT COUNT(*) FROM letter_log")
        letter_count = cursor.fetchone()[0]
        
        # Missing addresses
        cursor.execute("SELECT COUNT(*) FROM missing_addresses")
        missing_count = cursor.fetchone()[0]
        
        conn.close()
        
        # Count PDFs
        generator = ImprovedLetterGenerator()
        print_me_count = len(list(generator.print_me_dir.glob("*.pdf")))
        printed_count = len(list(generator.printed_dir.glob("*.pdf")))
        
        print("\n📊 System Statistics\n")
        print("Database:")
        print(f"  Patients: {patient_count} ({patients_with_address} with addresses)")
        print(f"  GPs: {gp_count}")
        print(f"  Opticians: {optician_count}")
        print(f"  Letters logged: {letter_count}")
        print(f"  Missing addresses: {missing_count}")
        
        print("\nFiles:")
        print(f"  Ready to print: {print_me_count}")
        print(f"  Already printed: {printed_count}")
        
        return 0


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Medical Letter System CLI',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  letter-cli process clinic_notes.txt
  letter-cli missing
  letter-cli add-address 0030730605
  letter-cli search-gp "Dr Robinson" --practice "The Surgery"
  letter-cli list-ready
  letter-cli mark-printed --all
  letter-cli stats
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Process notes command
    process_parser = subparsers.add_parser('process', help='Process clinic notes')
    process_parser.add_argument('file', help='Clinic notes file')
    process_parser.add_argument('--no-letters', action='store_true', 
                               help='Parse only, do not generate letters')
    
    # Show missing addresses
    missing_parser = subparsers.add_parser('missing', help='Show patients with missing addresses')
    
    # Add address command
    address_parser = subparsers.add_parser('add-address', help='Add patient address')
    address_parser.add_argument('mrn', help='Patient MRN')
    address_parser.add_argument('--address1', help='Address line 1')
    address_parser.add_argument('--address2', help='Address line 2')
    address_parser.add_argument('--city', help='City')
    address_parser.add_argument('--postcode', help='Postcode')
    address_parser.add_argument('--phone', help='Phone number')
    
    # Search GP command
    gp_parser = subparsers.add_parser('search-gp', help='Search for GP address')
    gp_parser.add_argument('name', help='GP name')
    gp_parser.add_argument('--practice', help='Practice name hint')
    gp_parser.add_argument('--address', help='Address hint')
    gp_parser.add_argument('--postcode', help='Postcode hint')
    gp_parser.add_argument('--save', action='store_true', 
                          help='Save to database if single match found')
    
    # List ready command
    ready_parser = subparsers.add_parser('list-ready', help='List letters ready to print')
    
    # Mark printed command
    printed_parser = subparsers.add_parser('mark-printed', help='Mark letters as printed')
    printed_parser.add_argument('file', nargs='?', help='Specific file to mark as printed')
    printed_parser.add_argument('--all', action='store_true', help='Mark all letters as printed')
    
    # Stats command
    stats_parser = subparsers.add_parser('stats', help='Show system statistics')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    cli = LetterSystemCLI()
    
    # Route to appropriate handler
    if args.command == 'process':
        return cli.process_notes(args)
    elif args.command == 'missing':
        return cli.show_missing(args)
    elif args.command == 'add-address':
        return cli.add_address(args)
    elif args.command == 'search-gp':
        return cli.search_gp(args)
    elif args.command == 'list-ready':
        return cli.list_ready(args)
    elif args.command == 'mark-printed':
        return cli.mark_printed(args)
    elif args.command == 'stats':
        return cli.stats(args)
    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    sys.exit(main())