#!/usr/bin/env python3
"""
LLM-based Address Extraction using Ollama
For more intelligent extraction when pattern matching fails
"""

import json
import subprocess
import logging
import re
from typing import Dict, Optional

logger = logging.getLogger(__name__)


class LLMAddressExtractor:
    """Use local LLM via Ollama for address extraction"""
    
    def __init__(self, model: str = "qwen2.5:3b"):
        self.model = model
        self.check_ollama()
        self.check_model()
    
    def check_ollama(self) -> bool:
        """Check if Ollama is installed and running"""
        try:
            result = subprocess.run(['ollama', 'list'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                logger.info("Ollama is available")
                return True
        except FileNotFoundError:
            logger.warning("Ollama not found. Install from https://ollama.ai")
        return False
    
    def check_model(self) -> bool:
        """Check if the model is available, pull if not"""
        try:
            result = subprocess.run(['ollama', 'list'], 
                                  capture_output=True, text=True)
            if self.model.split(':')[0] not in result.stdout:
                logger.info(f"Pulling model {self.model}...")
                pull_result = subprocess.run(['ollama', 'pull', self.model],
                                           capture_output=True, text=True)
                if pull_result.returncode == 0:
                    logger.info(f"Model {self.model} ready")
                    return True
                else:
                    logger.error(f"Failed to pull model: {pull_result.stderr}")
                    return False
            else:
                logger.info(f"Model {self.model} is available")
                return True
        except Exception as e:
            logger.error(f"Error checking model: {e}")
            return False
    
    def extract_with_llm(self, text: str) -> Optional[Dict]:
        """Use LLM to extract structured address data"""
        
        prompt = '''You are extracting UK patient information from a medical form OCR text. Extract ONLY the following as valid JSON with no additional text:

{
  "full_name": "patient's full name",
  "date_of_birth": "date in DD/MM/YYYY format",
  "address_line_1": "first line of address",
  "address_line_2": "second line of address",
  "city": "town or city name",
  "county": "county if mentioned",
  "postcode": "UK postcode (e.g., RH1 2AA)",
  "phone_home": "home phone number",
  "phone_mobile": "mobile phone number",
  "phone_work": "work phone number",
  "gp_name": "doctor/GP name if mentioned",
  "gp_practice": "GP practice/surgery name",
  "confidence": 0.8
}

Rules:
- UK phone numbers are typically 11 digits (starting 01, 02, 07)
- Mobile numbers start with 07 (e.g., 07768 123456)
- Home/landline numbers start with 01 or 02 (e.g., 01403 123456)
- Extract ALL phone numbers you find - there may be multiple
- UK postcodes: 1-2 letters, 1-2 numbers, optional letter, space, 1 number, 2 letters
- Look for phone numbers near "Tel", "Telephone", "Phone", "Mobile" labels
- Doctor names often appear after "GP" or "Doctor" labels
- Return null for missing fields
- Return ONLY the JSON object

Text to extract from:
''' + text[:2000]  # Limit text length
        
        try:
            # Call Ollama
            result = subprocess.run(
                ['ollama', 'run', self.model, prompt],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                response = result.stdout.strip()
                
                # Extract JSON from response
                # Try to find JSON object in the response
                import re
                
                # First try: Look for JSON between curly braces
                json_match = re.search(r'\{[^{}]*\}', response, re.DOTALL)
                if not json_match:
                    # Second try: Look for JSON with nested objects
                    json_match = re.search(r'\{.*\}', response, re.DOTALL)
                
                if json_match:
                    try:
                        data = json.loads(json_match.group())
                        
                        # Clean up the data
                        for key in data:
                            if isinstance(data[key], str):
                                # Remove example text in parentheses
                                data[key] = re.sub(r'\(e\.g\.[^)]*\)', '', data[key]).strip()
                                # Convert "null" string to None
                                if data[key].lower() in ['null', 'none', 'n/a', '']:
                                    data[key] = None
                        
                        # Set confidence based on how many fields were found
                        fields_found = sum(1 for v in data.values() if v and v != 'null')
                        data['confidence'] = min(fields_found / 7, 1.0)
                        
                        # Validate required fields
                        if data.get('full_name') or data.get('postcode'):
                            logger.info(f"LLM extracted: {data.get('full_name')} - {data.get('postcode')}")
                            return data
                    except json.JSONDecodeError as e:
                        logger.error(f"Failed to parse LLM JSON: {e}")
                        logger.debug(f"Response was: {response}")
                else:
                    logger.error(f"No JSON found in LLM response: {response[:200]}")
            
        except subprocess.TimeoutExpired:
            logger.error("LLM extraction timed out")
        except Exception as e:
            logger.error(f"LLM extraction failed: {e}")
        
        return None


class HybridExtractor:
    """Combine pattern matching with LLM for best results"""
    
    def __init__(self, use_llm: bool = True):
        from address_extractor import AddressExtractor
        self.pattern_extractor = AddressExtractor()
        self.llm_extractor = LLMAddressExtractor() if use_llm else None
    
    def extract(self, text: str, page_num: int = 1) -> Optional[Dict]:
        """Try pattern matching first, fall back to LLM"""
        
        # Check for Spire Healthcare form first (highest priority)
        if "Spire Healthcare" in text and "Registration Form" in text:
            from spire_form_extractor import extract_from_spire_form
            result = extract_from_spire_form(text)
            if result:
                result['extraction_method'] = 'spire_form'
                
                # If critical fields are missing and LLM is available, try to fill gaps
                missing_critical = (not result.get('date_of_birth') or 
                                  not result.get('phone_home') and not result.get('phone_mobile'))
                
                if self.llm_extractor and missing_critical:
                    llm_result = self.llm_extractor.extract_with_llm(text)
                    if llm_result:
                        # Fill in missing DOB
                        if not result.get('date_of_birth') and llm_result.get('date_of_birth'):
                            result['date_of_birth'] = llm_result['date_of_birth']
                            result['extraction_method'] = 'spire_form+llm'
                        
                        # Fill in missing phone numbers - LLM might find them
                        phone_filled = False
                        
                        # Try to fill home phone
                        if not result.get('phone_home') and llm_result.get('phone_home'):
                            phone = re.sub(r'[^\d]', '', str(llm_result['phone_home']))
                            if len(phone) >= 10:
                                result['phone_home'] = phone
                                phone_filled = True
                        
                        # Try to fill mobile phone
                        if not result.get('phone_mobile') and llm_result.get('phone_mobile'):
                            phone = re.sub(r'[^\d]', '', str(llm_result['phone_mobile']))
                            if len(phone) >= 10:
                                result['phone_mobile'] = phone
                                phone_filled = True
                        
                        # Try to fill work phone
                        if not result.get('phone_work') and llm_result.get('phone_work'):
                            phone = re.sub(r'[^\d]', '', str(llm_result['phone_work']))
                            if len(phone) >= 10:
                                result['phone_work'] = phone
                                phone_filled = True
                        
                        if phone_filled:
                            result['extraction_method'] = 'spire_form+llm'
                
                return result
        
        # Try pattern-based extraction
        result = self.pattern_extractor.extract_from_form(text, page_num)
        if not result:
            result = self.pattern_extractor.extract_from_label(text, page_num)
        if not result:
            result = self.pattern_extractor.extract_unstructured(text, page_num)
        
        # If pattern matching found something with good confidence, use it
        if result and result.get('extraction_confidence', 0) >= 0.7:
            return result
        
        # Try LLM if available
        if self.llm_extractor:
            llm_result = self.llm_extractor.extract_with_llm(text)
            if llm_result:
                # Merge results, preferring LLM for missing fields
                if result:
                    for key, value in llm_result.items():
                        if value and not result.get(key):
                            result[key] = value
                else:
                    result = llm_result
                    result['extraction_method'] = 'llm'
        
        return result


if __name__ == "__main__":
    # Test with sample text
    sample = """
    Patient Information
    
    Name: John Smith
    Date of Birth: 15/03/1980
    
    Address:
    123 High Street
    Flat 4B
    Redhill
    Surrey
    RH1 2AA
    """
    
    extractor = HybridExtractor(use_llm=False)  # Set to True if Ollama installed
    result = extractor.extract(sample)
    
    if result:
        print("Extracted:")
        print(json.dumps(result, indent=2))
    else:
        print("No data extracted")