import pdfplumber
import os

path = "/Users/rose/Code/Yiana/temp-debug-files/_Debug-Rendered-Text-Page.pdf"
print("exists:", os.path.exists(path))
if os.path.exists(path):
    with pdfplumber.open(path) as pdf:
        for i, page in enumerate(pdf.pages, 1):
            print("page", i, "text:")
            print(page.extract_text())