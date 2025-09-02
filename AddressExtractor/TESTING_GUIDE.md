# Letter System Testing Guide

## Quick Test

Run the automated test suite:
```bash
python test_system.py
```

This will verify all components are working.

## Manual Testing Steps

### 1. Test the Clinic Notes Parser

Create a test file called `my_clinic_notes.txt` with this format:
```
0030730605
Patricia Wheatley
Doctor E Robinson

Patient seen for routine review.
Blood pressure stable.
Continue current medication.

---

0030730606
John Smith
Dr A Patel
Optician: Mr B Jones

Post-op review satisfactory.
Vision improving.
```

Then parse it:
```bash
python clinic_notes_parser.py my_clinic_notes.txt
```

You should see the extracted patient names, MRNs, GPs, and opticians.

### 2. Process Notes into Database

```bash
python letter_processor.py my_clinic_notes.txt
```

This will:
- Parse the notes
- Store patients in database
- Store GPs and opticians
- Flag any missing addresses
- Show a summary

### 3. Check What's in the Database

View statistics:
```bash
python letter_processor.py --stats
```

See who needs addresses:
```bash
python letter_processor.py --missing
```

### 4. Add a Patient Address Manually

```bash
# Check current state
python letter_system_db_simple.py --stats

# Add an address for a patient
sqlite3 letter_addresses.db
```

In SQLite:
```sql
UPDATE patients 
SET address_line_1 = '123 Main Street',
    address_line_2 = 'Apartment 4',
    city = 'London',
    postcode = 'SW1A 1AA'
WHERE spire_mrn = '0030730605';
```

### 5. Check Who's Ready for Letters

```bash
python letter_processor.py --ready
```

This shows patients who have addresses and can have letters generated.

### 6. Check the GP Database (if imported)

First check if you have it:
```bash
python gp_bulk_importer.py --stats
```

If not, you can download and import NHS data:
```bash
# Download NHS GP data
python gp_bulk_importer.py --download

# Import it
python gp_bulk_importer.py --import

# Check stats
python gp_bulk_importer.py --stats
```

### 7. Search for GP Practices

```bash
# Search by practice name
python gp_fuzzy_search.py --practice "HEALTH CENTRE"

# Search by address
python gp_fuzzy_search.py --address "BOWERS PLACE"

# Combined search
python gp_fuzzy_search.py --practice "HEALTH CENTRE" --address "BOWERS" --postcode "RH10"
```

## Testing with Your Real Data

### From Your Previous OCR Extractions

If you have the Address1.json, Address2.json files:
```bash
python process_ocr_json.py Address1.json
```

### From New Clinic Notes

1. Create a text file with your clinic notes in this format:
   - Line 1: MRN (10 digits)
   - Line 2: Patient name
   - Line 3: GP name (start with Doctor/Dr)
   - Line 4+: Clinical content
   - Separate patients with `---` or blank lines

2. Process the file:
```bash
python letter_processor.py your_notes.txt
```

## Checking the Databases Directly

View the letter database:
```bash
sqlite3 letter_addresses.db
.tables
.schema patients
SELECT * FROM patients;
SELECT * FROM missing_addresses;
SELECT * FROM letter_log;
```

View the GP database:
```bash
sqlite3 gp_local.db
.tables
SELECT COUNT(*) FROM gp_practices_bulk;
SELECT * FROM gp_practices_bulk WHERE postcode LIKE 'RH10%' LIMIT 5;
```

## Expected Results

When everything is working:
- ✅ Parser extracts MRNs, names, GPs correctly
- ✅ Database stores patient and practitioner info
- ✅ Missing addresses are flagged
- ✅ GP practices can be matched to NHS database
- ✅ System tracks what letters need to be generated

## Troubleshooting

### "No valid notes found"
- Check your file format matches the expected pattern
- MRN must be exactly 10 digits
- Use `---` or multiple blank lines between patients

### "GP not matched"
- This is OK - the system stores the GP anyway
- Matching only works if you've imported NHS data
- You can add GP addresses manually later

### Database errors
- Delete the .db files and start fresh:
```bash
rm letter_addresses.db
python letter_processor.py your_notes.txt
```

## Next Steps

Once this is working, the next components to build are:
1. LaTeX letter templates
2. PDF generation
3. Folder-based workflow (print-me/ → printed/)
4. Address entry interface