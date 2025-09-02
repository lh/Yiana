#!/usr/bin/env python3
"""
Improved Letter Generator
Uses the enhanced template with comprehensive patient details
"""

from letter_generator import LetterGenerator
from pathlib import Path

class ImprovedLetterGenerator(LetterGenerator):
    """Letter generator using the improved template"""
    
    def __init__(self, 
                 db_path: str = "letter_addresses.db",
                 output_dir: str = "letters",
                 consultant_details: dict = None):
        
        # Use the improved template
        super().__init__(
            db_path=db_path,
            template_path="letter_template_improved.tex",
            output_dir=output_dir,
            consultant_details=consultant_details
        )


def main():
    """Test the improved letter generator"""
    import argparse
    from clinic_notes_parser import PatientNote
    
    parser = argparse.ArgumentParser(description='Generate improved medical letters')
    parser.add_argument('--test', action='store_true', help='Generate test letter with improved layout')
    parser.add_argument('--notes', help='Process clinic notes file')
    
    args = parser.parse_args()
    
    # Use your actual consultant details
    consultant_info = {
        'name': 'Mr Luke Herbert',
        'title': 'Consultant Ophthalmologist',
        'qualifications': 'FRCOphth'
    }
    
    generator = ImprovedLetterGenerator(consultant_details=consultant_info)
    
    if args.test:
        # Create comprehensive test note
        test_note = PatientNote(
            spire_mrn='0015797750',
            patient_name='Catherine Farley',
            gp_name='Dr D Holwell',
            optician_name=None,
            clinical_content="""It was a pleasure to meet you in clinic for the first time today. You came to see me because your optician thought the lens capsule had become thickened in the left eye and you might benefit from a YAG capsulotomy. In fact, the lens implant in your left eye has become cloudy. This is bothering you significantly, and after a discussion about the risks and benefits of surgery you have decided you would like to have the lens exchanged.

Your vision today measured 6/12 in the left eye with the cloudy lens implant. The lens has developed opacification, which is causing the reduced vision and visual symptoms you are experiencing.

I will arrange lens exchange surgery for your left eye. However, this is a more complex procedure than standard cataract surgery as I need to remove your existing lens implant and replace it with a new one. I will wait for your old measurement details so I can calculate the correct power for your new lens implant.""",
            date='02/09/2025'
        )
        
        # Add comprehensive patient data to database
        # First save creates the patient
        generator.db.save_patient(
            '0015797750',
            'Catherine Farley',
            sex='F'
        )
        
        # Second save updates with address details
        generator.db.save_patient(
            '0015797750',
            'Catherine Farley',
            sex='F',
            address_line_1='Porterhouse 52 Kings Gate',
            city='Horsham',
            postcode='RH12 1AE',
            phone='01403275663'
        )
        
        # Add mobile phone separately (since our simple DB doesn't have that field yet)
        # For now, we'll just note this limitation
        
        # Add GP with practice details
        generator.db.save_practitioner(
            'Dr D Holwell',
            'GP',
            practice_name='The Park Surgery',
            address_line_1='Albion Way',
            postcode='RH12 1BG'
        )
        
        # Generate letter
        pdf_path = generator.generate_letter(test_note, 'patient')
        if pdf_path:
            print(f"✅ Improved letter generated: {pdf_path}")
            print(f"   Check the print-me folder")
        else:
            print("❌ Failed to generate letter")
    
    elif args.notes:
        from clinic_notes_parser import ClinicNotesParser
        
        parser = ClinicNotesParser()
        notes = parser.parse_file(args.notes)
        
        if notes:
            stats = generator.batch_generate(notes)
            print(f"\n📊 Generated:")
            print(f"   Patient letters: {stats['patient_letters']}")
            print(f"   GP letters: {stats['gp_letters']}")
    
    else:
        parser.print_help()


if __name__ == "__main__":
    main()