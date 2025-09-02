#!/bin/bash
# Setup script for Address Extraction Service

echo "Setting up Address Extraction Service..."

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Make scripts executable
chmod +x *.py

echo ""
echo "Setup complete!"
echo ""
echo "To run the service:"
echo "  1. Activate virtual environment: source venv/bin/activate"
echo "  2. Run service: python extraction_service.py"
echo ""
echo "Options:"
echo "  --no-watch      Process existing files only"
echo "  --use-llm       Use Ollama for better extraction (requires Ollama)"
echo "  --query         Query extracted addresses"
echo ""
echo "For LLM support, install Ollama from https://ollama.ai"
echo "Then run: ollama pull mistral:7b"