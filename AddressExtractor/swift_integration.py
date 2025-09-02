#!/usr/bin/env python3
"""
Swift Integration Bridge for Address Extraction
This script provides a simple interface for the Swift app to call
"""

import json
import sys
import argparse
from pathlib import Path
from typing import Dict, Optional
import logging

# Add the extraction modules
from address_extractor import AddressExtractor
from llm_extractor import HybridExtractor
from spire_form_extractor import extract_from_spire_form

# Configure logging
logging.basicConfig(level=logging.WARNING)  # Quiet by default
logger = logging.getLogger(__name__)


def extract_single_file(ocr_file: str, use_llm: bool = False, output_format: str = 'json') -> Dict:
    """
    Extract address from a single OCR JSON file
    
    Args:
        ocr_file: Path to OCR JSON file
        use_llm: Whether to use LLM enhancement
        output_format: 'json', 'db', or 'both'
    
    Returns:
        Dictionary with extracted data
    """
    
    # Load OCR data
    with open(ocr_file, 'r') as f:
        ocr_data = json.load(f)
    
    # Extract document ID from filename
    doc_id = Path(ocr_file).stem
    
    results = []
    
    for page in ocr_data.get('pages', []):
        page_num = page.get('pageNumber', 1)
        text = page.get('text', '')
        
        # Try extraction
        if use_llm:
            extractor = HybridExtractor(use_llm=True)
            result = extractor.extract(text, page_num)
        else:
            # Try Spire form first
            if "Spire Healthcare" in text:
                result = extract_from_spire_form(text)
            else:
                # Fall back to pattern extraction
                extractor = AddressExtractor()
                result = extractor.extract_from_form(text, page_num)
                if not result:
                    result = extractor.extract_from_label(text, page_num)
                if not result:
                    result = extractor.extract_unstructured(text, page_num)
        
        if result:
            # Add metadata
            result['document_id'] = doc_id
            result['page_number'] = page_num
            result['source_file'] = ocr_file
            
            # Format for output
            formatted = {
                'document_id': doc_id,
                'page_number': page_num,
                'patient': {
                    'full_name': result.get('full_name'),
                    'date_of_birth': result.get('date_of_birth'),
                    'phones': {
                        'home': result.get('phone_home'),
                        'work': result.get('phone_work'),
                        'mobile': result.get('phone_mobile')
                    }
                },
                'address': {
                    'line_1': result.get('address_line_1'),
                    'line_2': result.get('address_line_2'),
                    'city': result.get('city'),
                    'county': result.get('county'),
                    'postcode': result.get('postcode'),
                    'country': result.get('country', 'UK')
                },
                'gp': {
                    'name': result.get('gp_name'),
                    'practice': result.get('gp_practice'),
                    'address': result.get('gp_address'),
                    'postcode': result.get('gp_postcode')
                },
                'extraction': {
                    'method': result.get('extraction_method', 'unknown'),
                    'confidence': result.get('extraction_confidence', 0)
                }
            }
            
            results.append(formatted)
            
            # Save to database if requested
            if output_format in ['db', 'both']:
                extractor = AddressExtractor()
                extractor.save_to_database([result])
    
    return {
        'success': len(results) > 0,
        'count': len(results),
        'results': results
    }


def main():
    """Main entry point for command line usage"""
    
    parser = argparse.ArgumentParser(description='Extract addresses for Swift integration')
    parser.add_argument('ocr_file', help='Path to OCR JSON file')
    parser.add_argument('--use-llm', action='store_true', help='Use LLM enhancement')
    parser.add_argument('--format', choices=['json', 'db', 'both'], default='json',
                       help='Output format')
    parser.add_argument('--output', help='Output file (default: stdout)')
    parser.add_argument('--quiet', action='store_true', help='Suppress logging')
    
    args = parser.parse_args()
    
    if args.quiet:
        logging.disable(logging.CRITICAL)
    
    try:
        # Extract data
        result = extract_single_file(
            args.ocr_file,
            use_llm=args.use_llm,
            output_format=args.format
        )
        
        # Output result
        json_output = json.dumps(result, indent=2, default=str)
        
        if args.output:
            with open(args.output, 'w') as f:
                f.write(json_output)
        else:
            print(json_output)
        
        # Exit with success code if extraction worked
        sys.exit(0 if result['success'] else 1)
        
    except Exception as e:
        error_result = {
            'success': False,
            'error': str(e),
            'count': 0,
            'results': []
        }
        print(json.dumps(error_result))
        sys.exit(1)


if __name__ == "__main__":
    main()