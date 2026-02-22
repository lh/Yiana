---
artifact: opportunity-tree
version: "1.0"
created: 2026-02-22
status: draft
context: Yiana — growing from personal tool to product with wider appeal
---

# Opportunity Solution Tree: First 100 Users Beyond the Founder

## Desired Outcome

**Outcome Statement:** Get 100 active users who are not the founder — people who independently adopt Yiana for their own document workflows
**Current State:** 1 user (founder). App is functional on iOS and macOS, on TestFlight, not publicly launched.
**Target State:** 100 active users (opened the app in the last 30 days, have 5+ documents)
**Timeframe:** 6 months from public launch
**Owner:** Founder

### Why This Outcome Matters

Yiana currently solves the founder's problem perfectly. But the JTBD and competitive analysis suggest a genuine gap in the market: simple-but-deep document management for Apple professionals. 100 users is the minimum signal that the gap is real and the product fills it — small enough to reach without marketing spend, large enough to prove the value proposition isn't just founder bias. Every insight from the JTBD canvas ("the job is retrieval, not filing"; "PDFs as first-class objects"; "the DEVONthink you'll actually use") needs validation with people who aren't the builder.

---

## Visual Tree

```
                              [OUTCOME]
                   100 active users in 6 months
                              |
          ┌───────────────────┼───────────────────┐
          |                   |                   |
    [Opportunity 1]     [Opportunity 2]     [Opportunity 3]
    "I can't get       "I scanned it but   "I'd try it but I
    my documents       now I can't find    can't get started
    INTO the app       it again"           / trust it"
    easily"                  |                   |
          |            ┌─────┴─────┐       ┌─────┴─────┐
     ┌────┴────┐       |           |       |           |
     |         |    [OCR that   [Smart   [5-min      [Land on
  [1-tap    [PDF     just       browse]  onboard]   App Store
  append]  import    works]                          page]
     |     flow]        |           |       |           |
  [Test]  [Test]    [Test]     [Test]   [Test]     [Test]

          ┌───────────────────┐
          |                   |
    [Opportunity 4]     [Opportunity 5]
    "I want to do       "I don't know
    more with my        this exists"
    documents"                |
          |            ┌──────┴──────┐
     ┌────┴────┐       |             |
     |         |    [Niche       [DEVONthink
  [Backend  [Domain  community    refugee
  docs]    examples] posts]      messaging]
```

---

## Opportunity Branches

### Opportunity 1: "I can't get my documents INTO the app easily enough"

**Description:** The scan-and-assemble workflow must feel effortless or users default to the pile. This includes first scan, adding pages to existing documents, and importing PDFs they already have. If capture has friction, nothing else matters — they never get to retrieval.
**Impact Potential:** High
**Confidence:** High

**Evidence:**
- JTBD Canvas: "If it takes more than 30 seconds to scan and file a document, users will default to the pile"
- Competitive Analysis: Notability was the only competitor with easy PDF assembly — and it's a note-taking app, not a document app
- Founder experience: the append-pages workflow is what made Notability tolerable for documents despite it not being designed for the job
- DEVONthink forums: "scanning into DT requires scanning to a temp file then filing it yourself" — hostile workflow is the #1 complaint

#### Solutions

**Solution 1A: One-tap append to existing document**
- Description: From any document, a single tap opens the camera to scan new pages that append directly to that PDF. No intermediate steps, no temp files, no "import from..." dialogs. The mental model is "open document, add pages, done."
- Effort: S (core plumbing exists — this is UX polish)
- Riskiest Assumption: Users will understand that a document can grow over time (not just be created once)
- Assumption Test: Give 5 non-founder users a scenario ("you received a follow-up letter — add it to the existing file") and observe. Do they find the append action? Do they expect it to exist?

**Solution 1B: Drag-and-drop PDF import on Mac**
- Description: Drag a PDF from Finder or email onto the Yiana window and it becomes a Yiana document — or drops into an existing document as new pages. Zero-friction for the Mac workflow.
- Effort: M (drag-and-drop exists but import-to-existing may need work)
- Riskiest Assumption: Mac users actually have existing PDFs they want to bring in (vs. starting fresh)
- Assumption Test: Ask 10 potential users: "Do you have existing PDFs you'd want to import, or would you start fresh?" If >70% say import, this is critical.

**Solution 1C: Share Sheet integration (iOS)**
- Description: From any app (Mail, Files, Safari), tap Share → Yiana to import a PDF directly. Offer "New document" or "Add to existing."
- Effort: S
- Riskiest Assumption: Users discover and use Share Sheet extensions
- Assumption Test: Check App Store analytics on share sheet adoption rates for similar document apps

---

### Opportunity 2: "I scanned it weeks ago but now I can't find it"

**Description:** The retrieval job is where Yiana must beat every competitor except DEVONthink — and match DEVONthink's results with a fraction of the complexity. If search doesn't work on document content, Yiana is just another scanner.
**Impact Potential:** High
**Confidence:** High

**Evidence:**
- JTBD Canvas: "The job is retrieval, not filing" — Insight #1
- Competitive Analysis: Apple Notes, Notability, Scanner Pro all have weak content search. This is the gap.
- Founder experience: "I need that letter NOW for this phone call" — the urgency of retrieval
- DEVONthink's moat is search quality, but users bounce off the complexity to get there

#### Solutions

**Solution 2A: OCR that just works (background, automatic, server-side)**
- Description: Every scanned document gets OCR'd automatically — no user action required. The Mac mini backend processes documents as they sync via iCloud. Text becomes searchable within minutes of scanning.
- Effort: M (core infrastructure exists — reliability and speed need hardening)
- Riskiest Assumption: iCloud sync is fast enough that documents reach the backend promptly
- Assumption Test: Measure round-trip time: scan on iPhone → iCloud sync → backend OCR → results available on Mac. Target: <5 minutes for 95% of documents.

**Solution 2B: Smart browse (date, recent, folder)**
- Description: Not every retrieval is a search query. Sometimes it's "the letter I scanned last Tuesday" or "everything in the cardiology folder." Offer multiple retrieval paths: chronological timeline, recents, folders, and full-text search.
- Effort: S (most UI exists — needs polish)
- Riskiest Assumption: Users will find the browse modes discoverable
- Assumption Test: Task test with 5 users: "Find the document you scanned 3 days ago." Observe which path they try first.

**Solution 2C: Search results show context (not just filenames)**
- Description: When searching, show a snippet of the matching text with the search term highlighted — like a web search engine. This confirms the result is what you're looking for before opening it.
- Effort: M
- Riskiest Assumption: OCR quality is good enough that text snippets are readable and useful
- Assumption Test: Run OCR on 50 real scanned documents; manually assess snippet quality. If >80% produce readable, meaningful snippets, proceed.

---

### Opportunity 3: "I'd try it but I can't get started / I don't trust a new tool"

**Description:** The activation barrier. Even users in the target segment won't adopt if the first experience is confusing, if they can't assess the app quickly, or if they don't trust it with important documents. Trust requires seeing that sync works, that documents are safe, and that the app is maintained.
**Impact Potential:** High
**Confidence:** Medium

**Evidence:**
- JTBD Canvas: "Fear the new tool will be yet another thing they try and abandon"
- Competitive Analysis: DEVONthink's #1 problem is that users try it and bounce. Yiana must not repeat this.
- Market reality: App Store is full of scanner apps — users are skeptical of "yet another one"
- Founder experience: the "aha moment" is scanning something and finding it by searching its content. If users don't reach that moment in the first session, they won't return.

#### Solutions

**Solution 3A: Five-minute onboarding flow**
- Description: First launch walks the user through: (1) scan a document, (2) watch OCR happen, (3) search for a word in that document and find it. Three steps, under five minutes, and the user has experienced the core value proposition. No setup, no configuration, no account creation.
- Effort: M
- Riskiest Assumption: Users will scan a real document during onboarding (not skip it)
- Assumption Test: Prototype test with 5 users. Give them the app with no instructions. Do they scan something? How long until they search?

**Solution 3B: App Store presence that communicates the gap**
- Description: App Store page that positions Yiana clearly in the gap: "More than a scanner. Simpler than DEVONthink." Screenshots showing the scan → search → find workflow. Not feature lists — outcome stories.
- Effort: S
- Riskiest Assumption: The positioning resonates with people who don't know they're in the gap
- Assumption Test: Create two landing page variants (one feature-focused, one outcome-focused) and measure click-through. Or: show screenshots to 10 target users and ask "what do you think this app does?"

**Solution 3C: Import existing documents on first launch**
- Description: Offer to import PDFs from Files/iCloud on first launch so the user immediately has a populated library, not an empty screen. An empty app feels like work; a populated one feels useful.
- Effort: M
- Riskiest Assumption: Users have existing PDFs in accessible locations (Files, iCloud Drive)
- Assumption Test: Ask 10 target users where their current PDFs live. If >50% say iCloud/Files/Desktop, this is viable.

---

### Opportunity 4: "I want to do more with my documents — extract data, classify, automate"

**Description:** Power users who outgrow basic scan-and-search want domain-specific processing: address extraction (medical), entity recognition (legal), structured data export. The extensible backend is the moat — but it needs to be discoverable and approachable.
**Impact Potential:** Medium (small audience, high lock-in)
**Confidence:** Medium

**Evidence:**
- Founder experience: the address extraction backend already exists and works
- JTBD Canvas: "The adaptable backend is a hidden moat... creates lock-in and community potential"
- Market trend: LLM-assisted coding means non-developers can now adapt backend pipelines
- No competitor offers this — unique positioning

#### Solutions

**Solution 4A: Backend documentation and examples**
- Description: Clear README, example scripts, and a "getting started with the backend" guide that a technically-willing user (with LLM coding help) can follow to set up their own processing pipeline. Not a GUI — documentation and code.
- Effort: S
- Riskiest Assumption: There are enough technically-willing users in the target segment to justify the effort
- Assumption Test: Post in relevant communities (r/selfhosted, Hacker News, MPU forum) about the concept. Gauge interest. 10+ engaged responses = proceed.

**Solution 4B: Domain-specific example pipelines**
- Description: Ship 2-3 example backend configurations: (1) medical letter address extraction, (2) invoice data extraction, (3) legal document classification. Users can clone and adapt for their domain.
- Effort: M
- Riskiest Assumption: Example domains match where actual demand exists
- Assumption Test: The medical pipeline already works (founder uses it). Build one more (invoices) and see if non-founder users attempt to use it.

---

### Opportunity 5: "I don't know this app exists"

**Description:** Discovery. The target users aren't searching for "document scanner" — they're searching for solutions to workflow problems, or they're in communities where tools get recommended. Paid marketing is unlikely to work for a solo founder; organic discovery and word-of-mouth are the path.
**Impact Potential:** High
**Confidence:** Low (distribution is always uncertain)

**Evidence:**
- Market reality: the App Store is crowded with scanners; organic search for "scanner" won't work
- Competitive Analysis: Yiana's positioning is in a gap — but users don't search for gaps
- DEVONthink forums: users actively asking for simpler alternatives — these are Yiana's early adopters
- Mac Power Users, r/productivity, r/selfhosted — communities where tool recommendations drive adoption

#### Solutions

**Solution 5A: Niche community presence**
- Description: Write posts / comments in communities where the target users congregate: Mac Power Users forum, r/macapps, r/productivity, r/selfhosted, DEVONthink community forums. Not "check out my app" spam — genuine "here's how I solved the paper pile problem" content.
- Effort: S (ongoing time investment, not code)
- Riskiest Assumption: Community posts convert to downloads
- Assumption Test: Write 3 posts in different communities. Track App Store impressions/downloads in the following week. Any measurable spike = proceed.

**Solution 5B: "DEVONthink refugee" messaging**
- Description: Content specifically targeting users who tried DEVONthink and bounced: "I tried DEVONthink three times. Here's what I built instead." Blog post, forum post, or short video.
- Effort: S
- Riskiest Assumption: There are enough DEVONthink bouncers to matter, and they'll find the content
- Assumption Test: Search DEVONthink forums and Reddit for posts about abandoning DEVONthink. If there are 50+ such posts in the last year, the audience exists.

**Solution 5C: Notability-to-Yiana migration story**
- Description: Content targeting Notability users who are unhappy with the subscription change or who were using Notability for documents rather than notes: "If you used Notability for documents, not notes, Yiana is what you actually wanted."
- Effort: S
- Riskiest Assumption: Notability's subscription backlash created a migration moment that hasn't passed
- Assumption Test: Search App Store reviews and Reddit for Notability pricing complaints. If sentiment is still active, the window is open.

---

## Prioritization

### Current Focus

**Priority Opportunity:** Opportunity 1 — "I can't get my documents INTO the app easily enough"
**Priority Solution:** Solution 1A — One-tap append to existing document
**Rationale:** Capture must work before retrieval matters. The append-pages workflow is Yiana's key differentiator (competitive analysis: only Notability does this well, and it's a note-taking app). If this workflow isn't delightful, the rest of the positioning falls apart. It's also small effort — the plumbing exists, this is UX polish.

**Parallel track:** Solution 2A (OCR reliability) should be hardened in parallel because search is the second half of the value proposition.

### Opportunity Ranking

| Rank | Opportunity | Impact | Confidence | Effort | Score |
|------|-------------|--------|------------|--------|-------|
| 1 | Easy document capture & assembly | High | High | Small | 9/10 |
| 2 | Reliable retrieval & search | High | High | Medium | 8/10 |
| 3 | First-run activation & trust | High | Medium | Medium | 7/10 |
| 4 | Discovery & distribution | High | Low | Small | 5/10 |
| 5 | Power user extensibility | Medium | Medium | Small | 5/10 |

### Parking Lot

- **Collaboration / sharing features:** Premature. Solve the single-user job perfectly first.
- **Android / Windows support:** Apple-only is a feature, not a limitation, for the target segment. Revisit only if demand data suggests otherwise.
- **AI-powered auto-classification:** DEVONthink territory. Resist the urge. The positioning is simplicity, not AI features.
- **Handwriting / annotation depth:** Notability territory. Keep notes as "partial" — enough to jot something, not enough to compete with Notability or GoodNotes on their turf.

---

## Experiments Backlog

| Solution | Assumption | Test Method | Success Criteria | Status |
|----------|------------|-------------|------------------|--------|
| 1A: One-tap append | Users find and understand the append action | Task test with 5 users | >4/5 complete task without prompting | Planned |
| 1B: Drag-and-drop import | Mac users have existing PDFs to import | Survey 10 target users | >70% say they'd import existing PDFs | Planned |
| 2A: Background OCR | iCloud round-trip is <5 min | Measure 20 real documents | 95th percentile <5 minutes | Planned |
| 2C: Search snippets | OCR quality produces readable snippets | Manual review of 50 documents | >80% readable snippets | Planned |
| 3A: Onboarding flow | Users scan a real document in first 5 min | Prototype test with 5 users | >3/5 scan something without prompting | Planned |
| 3B: App Store positioning | Outcome-focused page outperforms features | A/B landing page test | Higher click-through on outcome version | Planned |
| 5A: Community posts | Posts drive measurable downloads | Post in 3 communities, track impressions | Any measurable spike in 7 days | Planned |

---

## Learning Log

| Date | Experiment | Result | Learning | Impact on Tree |
|------|------------|--------|----------|----------------|
| — | (No experiments run yet) | — | — | — |

---

## Next Steps

- [ ] **Audit the current append-pages UX** — how many taps does it take today? Map the current flow and identify friction points (this week)
- [ ] **Measure OCR round-trip time** — scan 10 documents on iPhone, time until searchable on Mac (this week)
- [ ] **Identify 5 non-founder test users** — colleagues, friends, or forum contacts who deal with paper documents professionally (this week)
- [ ] **Search DEVONthink forums and Reddit** for "abandoned DEVONthink" / "DEVONthink too complex" posts — size the refugee audience (next week)
- [ ] **Draft App Store description** — two versions (feature-focused vs. outcome-focused) for testing (next week)
- [ ] **Write one community post** — Mac Power Users or r/macapps — "how I solved my paper pile problem" (next week)

---

*This is a living document. Update as you learn from experiments and customer feedback.*
