import sys
import os
import pdfplumber

if len(sys.argv) > 1:
    paths = sys.argv[1:]
else:
    paths = [
        "/private/var/mobile/Library/Mobile Documents/"
        "iCloud~com~vitygas~Yiana/Documents/_Debug-Rendered-Text-Page.pdf"
    ]

for path in paths:
    exists = os.path.exists(path)
    print('---', path, 'exists:', exists)
    if not exists:
        continue
    with pdfplumber.open(path) as pdf:
        print('pages:', len(pdf.pages))
        for i, page in enumerate(pdf.pages, 1):
            text = page.extract_text()
            print('page', i, 'text:')
            print(text)
