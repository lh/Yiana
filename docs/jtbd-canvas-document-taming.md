---
artifact: jtbd-canvas
version: "1.0"
created: 2026-02-22
status: draft
context: Yiana — document scanning and PDF management app (iOS/macOS)
---

# Jobs to be Done Canvas: Taming the Paper Pile

## Job Overview

**Job Title:** Taming the Paper Pile
**Date:** February 2026
**Author:** Product/Founder
**Research Basis:** Founder domain experience (GP managing clinical correspondence), competitive landscape analysis, first-principles reasoning from building and using the product daily

---

## Job Performer

**Who:** A professional or small-business owner who regularly receives paper documents (or digital PDFs) that need to be captured, organised, and retrievable — and who currently has no system, or a system that's too heavy, too flimsy, or too manual.

**Key Characteristics:**
- Receives a steady stream of paper or PDF documents they need to keep (not just receipts — letters, reports, correspondence, forms)
- Has tried other tools and found them either too complex (DEVONthink) or too note-centric (Notability, Apple Notes)
- Values being able to *find* a document later more than filing it perfectly now
- Comfortable with Apple ecosystem (iPhone/iPad + Mac)
- Technically willing but not a developer — though with LLM coding help, could adapt a backend pipeline

**Not Defined By:**
- Specific profession (doctors, lawyers, accountants, landlords — the job is the same)
- Organisation size (solo practitioner to small practice)
- Age or tech sophistication (the job arises from the *paper*, not the person)

---

## The Circumstance

**When does this job arise?**

When a document arrives — a letter lands on the desk, a PDF arrives by email, a form is handed over in person — and the professional knows they'll need it again but has no reliable place to put it. The trigger is the moment of "I need to deal with this piece of paper before it disappears into a pile."

A secondary trigger: needing to *find* something that was scanned or filed weeks ago. "Which letter was it that mentioned the referral to cardiology?" The retrieval job is as important as the capture job.

**Where does this happen?**

- At a desk (office, clinic, home office) — the primary scanning location
- On the move (iPad/iPhone) — quick capture of a document handed to you
- At the computer (Mac) — reviewing, searching, organising accumulated documents

**Frequency:**

Daily to several times per week. For a GP, multiple documents per day. For a solicitor or small business owner, several per week. The volume isn't enormous, but it's persistent — and it compounds if not handled.

**Urgency:**

Medium. Each individual document isn't urgent, but the *accumulation* creates urgency. The pile grows. The system either handles it gracefully or the user drowns. The retrieval job can be urgent — "I need that letter *now* for this phone call."

---

## Job Statement

> **"When** a paper document or PDF arrives that I need to keep and may need to find again, **I want to** capture it as a proper PDF I can build on over time — adding pages as follow-ups arrive — and have it become searchable without manual effort, **so I can** get back to my actual work and trust that I'll find it when I need it.

---

## Functional Job

**What is the practical task to accomplish?**

Two intertwined tasks: (1) Turn a physical or digital document into a searchable, retrievable PDF — a first-class digital object, not an attachment buried inside a note or filing system. (2) Be able to find it again by content, date, or context when needed, and to grow it over time (adding pages from later correspondence to the same document).

**Definition of "Done":**

- Document exists as a proper PDF — a first-class object you can see, name, and manage directly
- Pages can be added to an existing document easily (a follow-up letter appended to the original)
- Text is extractable/searchable (OCR has run)
- Document is findable by searching its content, not just its filename
- Document syncs across devices (scan on phone, find on Mac)
- The whole process took under 30 seconds of active attention

**Key Steps in the Job:**

1. Document arrives (paper letter, emailed PDF, handed form)
2. Capture it (scan with phone/iPad camera, or import PDF on Mac)
3. Either create a new document or **add pages to an existing one** — this must be trivially easy
4. Optionally tag or file it (but this shouldn't be required)
5. OCR runs and makes content searchable (ideally without user action)
6. Document syncs to other devices via iCloud
7. Later: search by content, browse by date, or navigate by folder to find it

**Functional Pains:**

- **PDFs are not first-class objects** in most tools — in Apple Notes they're buried inside notes; in DEVONthink they're first-class but the workflow to get them there is painful (scan to temp file, then manually file)
- **Adding pages to an existing document is hard or impossible** — most scanner apps create a new PDF per scan; assembling a multi-page document from scans taken on different days requires separate PDF-editing tools
- Scanning is slow or fiddly (bad edge detection, multiple retakes)
- OCR is unreliable or missing entirely — documents are captured but not searchable
- Organisation requires too much upfront effort (complex folder hierarchies, mandatory tagging)
- Search doesn't actually work on document *content* — just filenames
- Sync is unreliable or slow (scan on phone, not on Mac for hours)
- Tools are either too simple (Apple Notes — no real document management) or too complex (DEVONthink — overwhelming UI, steep learning curve)
- **DEVONthink's "it can do that" problem** — the feature exists but requires acrobatics to use. Every question of "why doesn't it do X?" is met with "it does, but you have to..." — which means functionally, it doesn't

---

## Emotional Job

**How do they want to feel?**

| Desired Feeling | Why It Matters |
|-----------------|----------------|
| In control | The paper isn't winning. There's a system and it works. |
| Unburdened | Each document is dealt with in seconds, not minutes. The pile doesn't grow. |
| Confident | "I know I can find that letter." Trust in the system reduces background anxiety. |
| Professional | Having an organised document system reflects competence to self and others. |
| Light | The tool doesn't add cognitive weight. It's not another complex system to learn. |

**How do they want to avoid feeling?**

| Feeling to Avoid | Current Trigger |
|------------------|-----------------|
| Overwhelmed | The physical pile of unfiled documents growing on the desk |
| Anxious | "I know I had that letter somewhere..." and not being able to find it |
| Guilty | Knowing they should have a system but not having one, or having abandoned one |
| Frustrated | Fighting with a tool that's too complex, too slow, or doesn't work as promised |
| Embarrassed | Colleague asks for a document and they can't produce it quickly |

**Emotional Pains:**

- The dread of the growing pile — each unfiled document is a small failure
- The nagging feeling that something important is lost in the stack
- Past experiences with tools that promised organisation but added complexity

---

## Social Job

**How do they want to be perceived?**

| Desired Perception | By Whom |
|--------------------|---------|
| Organised and on top of things | Colleagues, staff, patients/clients |
| Someone who takes documentation seriously | Regulators, auditors, legal |
| Efficient — not drowning in admin | Themselves, partners |

**What perception do they want to avoid?**

| Perception to Avoid | By Whom |
|---------------------|---------|
| Disorganised or chaotic | Colleagues, staff |
| Someone who loses important documents | Patients/clients, regulators |
| A technophobe clinging to paper piles | Younger colleagues, staff |

**Social Context:**

- In regulated professions (medicine, law, finance), document management has compliance implications — but the user isn't looking for a compliance tool, they want a practical one that happens to make compliance easier
- In small businesses, the person managing documents is often the same person doing the core work — there's no admin team to delegate to
- Being seen as "someone who has their documents sorted" carries quiet professional credibility

---

## Competing Solutions

**What do customers currently "hire" for this job?**

| Solution Type | Solution | Strengths | Weaknesses |
|---------------|----------|-----------|------------|
| Direct Competitor | **DEVONthink** | Powerful search, AI classification, mature | Complex, steep learning curve, overwhelming UI, expensive |
| Direct Competitor | **Adobe Scan + Acrobat** | Good OCR, PDF standard, brand trust | Subscription-heavy, clunky organisation, no native feel |
| Direct Competitor | **Genius Scan / Scanner Pro** | Fast scanning, good edge detection | Scanning-focused only — weak on organisation and retrieval; each scan is a new PDF, no easy way to append pages to existing documents |
| Closest Workflow Match | **Notability** | Clean interface, easy PDF creation, can add arbitrary pages, non-cluttered | Note-taking first — OCR and search are weak; organisation is note-centric not document-centric; subscription pricing controversial; no true macOS app |
| Indirect Alternative | **Apple Notes** (scan feature) | Free, built-in, dead simple | PDFs buried inside notes — not first-class objects; no real document management, weak OCR search, not designed for volume |
| Indirect Alternative | **Apple Files + iCloud** | Free, syncs, familiar | No OCR, no search by content, manual folder management only |
| Indirect Alternative | **Email (just leave it in inbox)** | Zero effort | Unfindable after a week, no organisation, mixes documents with everything else |
| Non-consumption | **The physical pile** | No learning curve | Documents get lost, no search, doesn't scale, looks bad |
| DIY/Manual | **Scan + manual folder structure** | Full control | Time-consuming, requires discipline, no content search |

**Why Do They Switch?**

- A crisis moment: "I couldn't find the letter I needed for the appointment/meeting/court date"
- The pile reaches a tipping point and they feel something has to change
- They discover a tool that removes enough friction to actually adopt (low switching cost)
- A colleague shows them something that "just works"

**Why Do They Stay?**

- Switching cost: all their existing documents are in the current system (or pile)
- Fear the new tool will be yet another thing they try and abandon
- "Good enough" inertia — the current chaos is familiar
- DEVONthink users: sunk cost in learning the complex UI

---

## Hiring Criteria

**Must-Have (Table Stakes):**

- Fast, reliable scanning from iPhone/iPad camera
- **PDFs as first-class objects** — not attachments inside notes, not files buried in a database
- **Easy page management** — add pages to an existing PDF, reorder, delete — without fighting the UI
- OCR that makes document text searchable
- iCloud sync across Apple devices (scan on phone, find on Mac)
- Works with existing PDFs (import, not just scan)
- Simple enough to use without reading a manual

**Differentiators (Decision Drivers):**

- **Lightness** — feels like a native Apple app, not enterprise software
- **PDF assembly as a core workflow** — scan three pages today, add two more next week, all in the same document. This is what Notability did reasonably well and what DEVONthink makes painful. It's the workflow that Scanner Pro and Genius Scan don't even attempt.
- **Scan-to-searchable in seconds** — minimal steps from paper to findable document
- **Content search that actually works** — find documents by what's *in* them, not just filenames
- **Doesn't force a filing system** — works whether you meticulously organise or just dump everything in
- **Adaptable backend** (power users) — technically capable users can extend the processing pipeline for their domain (address extraction, classification, structured data) using LLM coding tools

**Nice-to-Have:**

- Light text/note-taking alongside scanned documents (but this is not the emphasis)
- Folder organisation for those who want it
- Bulk import of existing PDF archives
- Print support (macOS)

---

## Insights and Implications

**Key Insight 1:** The job is *retrieval*, not *filing*. Users don't enjoy organising documents — they endure it because they need to find things later. A system that makes retrieval excellent can be forgiving about organisation.
- Product Implication: Invest in search (OCR quality, full-text search, date-based browse) over complex folder/tag hierarchies. Let users organise if they want, but don't require it.

**Key Insight 2:** The competition isn't other scanning apps — it's the pile on the desk. The real competitor is *doing nothing*. This means the activation energy to start using Yiana must be near zero. If it takes more than 30 seconds to scan and file a document, users will default to the pile.
- Product Implication: Ruthlessly minimise the scan-to-done path. Open app, scan, done. Everything else (OCR, sync, organisation) should happen automatically in the background.

**Key Insight 3:** The real job has two halves: *capture* and *assembly*. Most tools only do capture (scan → new PDF → done). But documents in professional life are living objects — a patient file grows as letters arrive, a property transaction accumulates documents over weeks. The ability to easily add pages to an existing PDF over time is the workflow that Notability handled reasonably well but nobody else does without friction. DEVONthink *can* do it but requires acrobatics ("it does that, you just have to..."). Scanner apps don't even try.
- Product Implication: Make "add pages to this document" as easy as "create a new document." This is the workflow differentiator that separates Yiana from every scanner app and from DEVONthink's hostile UX.

**Key Insight 4 (previously 3):** There's a gap in the market between "too simple" (Apple Notes scanning, Scanner Pro) and "too complex" (DEVONthink). Users in this gap don't need AI classification or smart rules — they need solid scanning, reliable OCR, good search, and sync. That's it.
- Product Implication: Resist feature creep. The value proposition is *the right amount of tool* — more than a scanner, less than a document management system. The simplicity IS the feature.

**Key Insight 5:** The adaptable backend is a hidden moat. Most users will never touch it. But for power users in specific domains (medicine, law, property), the ability to build domain-specific processing (address extraction, entity recognition, structured data) — especially with LLM coding assistance — creates lock-in and community potential that no competitor offers.
- Product Implication: Keep the backend modular and well-documented. Don't hide it, but don't make it a first-run feature either. Let it be discovered by users who outgrow the defaults.

---

## Supporting Quotes

> "I've tried DEVONthink three times. Each time I spend a weekend setting it up and then never open it again." — Composite: common sentiment in productivity forums

> "Every time you ask why DEVONthink doesn't do X, you're told it does — but you have to do acrobatics to get it to work. Like scanning into a temp file then filing it yourself." — Founder experience

> "Notability was the only app that had a reasonable way of making a PDF, adding arbitrary pages to it easily, with a non-cluttered interface." — Founder experience; the PDF-assembly job that nobody else solved cleanly

> "Apple Notes is all very well, but the PDFs are buried in the notes." — The first-class-object problem: PDFs as attachments vs. PDFs as the thing

> "I just need to scan it, find it later, and not think about it in between." — Founder's own use case, echoed by colleagues

> "I don't want to tag things. I don't want to file things. I want to search for what was in the letter and have it appear." — The retrieval-over-filing insight

---

## Questions for Further Research

- What is the volume threshold where users actively seek a tool? (5 docs/week? 20? 50?)
- How important is *existing archive import* vs. *going forward only*? Would users adopt if they can't bring their backlog?
- What's the perceived value difference between "scanning app" and "document management"? Does positioning as one vs. the other affect willingness to pay?
- How do users in regulated professions (medicine, law) think about document retention? Is compliance a buying trigger or just a background concern?
- Would users pay for backend processing as a service, or is the self-hosted model part of the appeal?

---

*This canvas should be validated and updated as you learn more about customers.*
