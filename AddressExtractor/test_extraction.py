#!/usr/bin/env python3
"""
Test script for address extraction
Processes specific test files and shows results
"""

import json
import sys
from pathlib import Path
import logging
from address_extractor import AddressExtractor
from llm_extractor import HybridExtractor

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)


def test_file(ocr_file: Path, use_llm: bool = True):
    """Test extraction on a single OCR file"""
    
    print(f"\n{'='*60}")
    print(f"Testing: {ocr_file.name}")
    print(f"{'='*60}")
    
    # Load OCR data
    try:
        with open(ocr_file, 'r') as f:
            ocr_data = json.load(f)
    except Exception as e:
        print(f"Error loading file: {e}")
        return
    
    # Initialize extractor
    if use_llm:
        print("Using Hybrid Extractor (Pattern + LLM)")
        extractor = HybridExtractor(use_llm=True)
    else:
        print("Using Pattern Extractor only")
        from address_extractor import AddressExtractor as AE
        extractor = AE()
    
    # Process each page
    for page in ocr_data.get('pages', []):
        page_num = page.get('pageNumber', 1)
        text = page.get('text', '')
        
        print(f"\n--- Page {page_num} ---")
        print(f"Text preview: {text[:200]}...")
        
        # Try extraction
        if use_llm and hasattr(extractor, 'extract'):
            result = extractor.extract(text, page_num)
        else:
            # Try different methods
            result = extractor.extract_from_form(text, page_num)
            if not result:
                result = extractor.extract_from_label(text, page_num)
            if not result:
                result = extractor.extract_unstructured(text, page_num)
        
        if result:
            print(f"\n✅ EXTRACTED DATA:")
            print(f"  Method: {result.get('extraction_method', 'unknown')}")
            print(f"  Confidence: {result.get('extraction_confidence', result.get('confidence', 0)):.2f}")
            print(f"  Name: {result.get('full_name', 'Not found')}")
            print(f"  DOB: {result.get('date_of_birth', 'Not found')}")
            print(f"  Address Line 1: {result.get('address_line_1', 'Not found')}")
            print(f"  Address Line 2: {result.get('address_line_2', 'Not found')}")
            print(f"  City: {result.get('city', 'Not found')}")
            print(f"  County: {result.get('county', 'Not found')}")
            print(f"  Postcode: {result.get('postcode', 'Not found')}")
            
            # Validate postcode
            if result.get('postcode'):
                from address_extractor import AddressExtractor
                ae = AddressExtractor()
                valid, district = ae.validate_postcode(result['postcode'])
                print(f"  Postcode Valid: {'✅' if valid else '❌'}")
                if valid:
                    print(f"  Postcode District: {district}")
        else:
            print("\n❌ No data extracted")


def test_all_addresses():
    """Test all Address files in the OCR directory"""
    
    # Look for Address files
    ocr_dirs = [
        Path("/Users/rose/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/.ocr_results"),
        Path("/Users/rose/Documents/Yiana/.ocr_results"),
    ]
    
    address_files = []
    for ocr_dir in ocr_dirs:
        if ocr_dir.exists():
            # Look for Address1.json, Address2.json, Address3.json
            for i in range(1, 4):
                patterns = [
                    f"Address{i}.json",
                    f"**/Address{i}.json",
                    f"Address{i}*.json",
                    f"**/Address{i}*.json"
                ]
                for pattern in patterns:
                    files = list(ocr_dir.glob(pattern)) + list(ocr_dir.rglob(pattern))
                    address_files.extend(files)
    
    # Remove duplicates
    address_files = list(set(address_files))
    
    if not address_files:
        print("No Address test files found in OCR directories")
        print("Looking in:")
        for d in ocr_dirs:
            print(f"  {d}")
        return
    
    print(f"Found {len(address_files)} address test files:")
    for f in sorted(address_files):
        print(f"  {f}")
    
    # Test with both methods
    print("\n" + "="*60)
    print("TESTING WITH PATTERN MATCHING ONLY")
    print("="*60)
    
    for ocr_file in sorted(address_files):
        test_file(ocr_file, use_llm=False)
    
    # Check if Ollama is available
    try:
        import subprocess
        result = subprocess.run(['ollama', 'list'], capture_output=True, text=True)
        if result.returncode == 0:
            print("\n" + "="*60)
            print("TESTING WITH LLM (OLLAMA)")
            print("="*60)
            
            for ocr_file in sorted(address_files):
                test_file(ocr_file, use_llm=True)
        else:
            print("\n⚠️ Ollama not available, skipping LLM tests")
    except:
        print("\n⚠️ Ollama not installed, skipping LLM tests")


def compare_methods(ocr_file: Path):
    """Compare pattern vs LLM extraction"""
    
    print(f"\n{'='*60}")
    print(f"COMPARISON: {ocr_file.name}")
    print(f"{'='*60}")
    
    with open(ocr_file, 'r') as f:
        ocr_data = json.load(f)
    
    for page in ocr_data.get('pages', []):
        page_num = page.get('pageNumber', 1)
        text = page.get('text', '')
        
        print(f"\n--- Page {page_num} ---")
        
        # Pattern extraction
        pattern_ext = AddressExtractor()
        pattern_result = (
            pattern_ext.extract_from_form(text, page_num) or
            pattern_ext.extract_from_label(text, page_num) or
            pattern_ext.extract_unstructured(text, page_num)
        )
        
        # LLM extraction
        llm_result = None
        try:
            hybrid = HybridExtractor(use_llm=True)
            llm_result = hybrid.extract(text, page_num)
        except:
            pass
        
        # Compare results
        print("\n📊 COMPARISON:")
        print("Pattern Matching:")
        if pattern_result:
            print(f"  ✅ Name: {pattern_result.get('full_name', 'N/A')}")
            print(f"  ✅ Postcode: {pattern_result.get('postcode', 'N/A')}")
            print(f"  ✅ Confidence: {pattern_result.get('extraction_confidence', 0):.2f}")
        else:
            print("  ❌ No extraction")
        
        print("\nLLM (Ollama):")
        if llm_result:
            print(f"  ✅ Name: {llm_result.get('full_name', 'N/A')}")
            print(f"  ✅ Postcode: {llm_result.get('postcode', 'N/A')}")
            print(f"  ✅ Confidence: {llm_result.get('confidence', 0):.2f}")
        else:
            print("  ❌ No extraction")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Test address extraction")
    parser.add_argument("--file", help="Test specific OCR file")
    parser.add_argument("--compare", help="Compare methods on specific file")
    parser.add_argument("--no-llm", action="store_true", help="Skip LLM testing")
    
    args = parser.parse_args()
    
    if args.file:
        test_file(Path(args.file), use_llm=not args.no_llm)
    elif args.compare:
        compare_methods(Path(args.compare))
    else:
        test_all_addresses()