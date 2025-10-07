import os
import pdfplumber

path = "/private/var/mobile/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents/_Debug-Rendered-Text-Page.pdf"
print("exists:", os.path.exists(path))
if os.path.exists(path):
    with pdfplumber.open(path) as pdf:
        print("pages:", len(pdf.pages))
        for i, page in enumerate(pdf.pages, 1):
            print("page", i, "text:")
            print(page.extract_text())