---
artifact: problem-statement
version: "1.0"
created: 2026-02-22
status: draft
context: Yiana — document scanning and management app for Apple professionals
---

# Problem Statement: The Paper Pile Has No Good Digital Home

## Problem Summary

Professionals who deal with a steady flow of paper documents — letters, referrals, reports, forms — have no tool that lets them easily capture documents as proper PDFs, grow them over time by adding pages, and then find them later by searching their content. The tools that exist are either too simple (Apple Notes buries PDFs inside notes; scanner apps create isolated files with no management), too complex (DEVONthink is powerful but hostile to use), or solving the wrong job (Notability handles PDF assembly well but is a note-taking app with weak search and retrieval). The result: documents pile up physically or digitally, important things get lost, and professionals feel disorganised despite knowing they should have a system.

## User Impact

### Who is affected?

Professionals and small-business owners in the Apple ecosystem who receive 5-50+ paper or PDF documents per week that they need to keep and may need to find again. This includes:

- **GPs and hospital doctors** — referral letters, clinic letters, discharge summaries, lab results
- **Solicitors and barristers** — case correspondence, contracts, court documents
- **Accountants and financial advisers** — client documents, tax forms, receipts
- **Small business owners** — invoices, permits, insurance documents, contracts
- **Property managers and landlords** — tenancy agreements, inspection reports, correspondence

The common thread is not the profession but the *circumstance*: a persistent stream of paper that must be captured, kept, and found later — managed by the same person doing the core work (no admin team to delegate to).

### How are they affected?

**The capture problem:**
- Scanning is either too fiddly (DEVONthink's temp-file-then-manually-file workflow) or too shallow (scanner apps create a new isolated PDF per scan with no way to build a document over time)
- Adding pages to an existing document — the follow-up letter, the second lab result — requires either a separate PDF-editing tool or is simply not possible
- Apple Notes can scan but the PDF is an attachment buried inside a note, not a first-class object
- The only app that handled PDF assembly with a clean interface was Notability — a note-taking app

**The retrieval problem:**
- Documents are captured but not findable by content — only by filename or date
- Full-text search of scanned document content requires either DEVONthink (complex, $199) or manual OCR workflows
- "I know I scanned that letter — where is it?" becomes a recurring source of stress
- Without reliable retrieval, the digital system is no better than the physical pile

**The trust problem:**
- Users have tried tools before and abandoned them — DEVONthink setup weekends that led nowhere, scanner apps that created a graveyard of unsorted PDFs
- Each failed attempt makes the next tool harder to adopt ("it'll just be another thing I try and give up on")

### Scale of impact

- The mobile scanner app market is ~$1B (2026), growing at 8-18% CAGR
- Over 70% of small businesses rely on mobile document capture tools
- DEVONthink has a loyal but small user base; its forums show a persistent stream of users trying and abandoning it due to complexity
- Notability's controversial subscription change (2021-2023) created a wave of users looking for alternatives — those who used it for documents rather than notes had nowhere to go
- The addressable segment is not "everyone who scans" but the narrower "professionals who deal with persistent document flows" — likely low millions globally in the Apple ecosystem

## Business Context

### Strategic Alignment

Yiana exists because the founder (a GP) needed this tool and nothing adequate existed. The product is built, functional on iOS and macOS, and in daily use. The strategic question is: **does the founder's problem generalise?** The JTBD analysis and competitive mapping suggest yes — there is a clear gap between "too simple" and "too complex" that no product occupies. Validating this with external users is the single most important next step.

### Business Impact

- **If the gap is real:** A product positioned as "the DEVONthink you'll actually use" with Notability's ease of PDF assembly, targeting Apple professionals, has a viable niche market. Even 10,000 paying users at $25-50 would generate meaningful indie revenue.
- **If the gap isn't real:** The product remains a useful personal tool. The founder loses nothing — the product already solves their own problem.
- **Upside scenario:** The extensible backend creates a power-user moat that no competitor can match. Domain-specific processing (medical addresses, legal entities, invoice data) — buildable with LLM coding assistance — creates lock-in and potential community effects.

### Why Now?

1. **The competitive window is open.** DEVONthink 4 just launched with more complexity (AI chatbots, graph views), moving further from simplicity. Notability continues to focus on note-taking. Scanner apps remain shallow. Nobody is moving into Yiana's gap.
2. **Apple's platform is ready.** iOS 17+ VisionKit scanning, on-device OCR via Apple Vision framework, and iCloud Drive sync are mature and reliable. The infrastructure cost of building this app has never been lower.
3. **LLM-assisted development changes the game.** A solo founder can now build and maintain a product that previously required a team — including a backend processing pipeline. The extensible backend is only possible because of this shift.
4. **Subscription fatigue creates an opening.** Notability's pricing controversy, DEVONthink's new annual model, Adobe Scan's $120/year — users are actively looking for fair-priced alternatives. A one-time purchase or generous free tier is a competitive advantage right now.
5. **The product already exists and works.** This isn't a "should we build it?" question — it's a "does anyone else want it?" question. The cost of finding out is distribution effort, not development effort.

## Success Criteria

| Metric | Current Baseline | Target | Timeline |
|--------|-----------------|--------|----------|
| Active users (non-founder) | 0 | 100 (opened app in last 30 days, 5+ docs) | 6 months from public launch |
| Scan-to-searchable round-trip | Unmeasured | <5 minutes (95th percentile) | Before public launch |
| Append-pages task completion (usability) | Untested | >80% of test users complete without prompting | Before public launch |
| App Store rating | N/A (not launched) | 4.5+ stars | 3 months post-launch |
| Organic downloads (no paid marketing) | 0 | 500/month | 6 months post-launch |
| Documents per active user | ~1,400 (founder) | 20+ (indicating real adoption, not just a trial) | 6 months post-launch |

**Guardrail metrics (maintain, don't sacrifice):**

| Metric | Baseline | Maintain | Ongoing |
|--------|----------|----------|---------|
| iCloud sync reliability | Works for founder | No regressions for multi-user | Ongoing |
| App launch-to-scan time | ~3 seconds | <5 seconds | Ongoing |
| Founder's own workflow | Fully functional | No regressions from generalisation work | Ongoing |

## Constraints & Considerations

- **Solo founder** — all development, design, marketing, and support is one person. Features must be chosen ruthlessly. Anything that adds support burden without proportional value is a liability.
- **No marketing budget** — distribution must be organic: App Store SEO, community presence, word of mouth. The product must sell itself in the first session.
- **iCloud dependency** — sync relies on iCloud Drive, which is reliable but not under Yiana's control. Edge cases (large files, placeholder downloads, sync conflicts) must be handled gracefully.
- **OCR backend requires a Mac** — the server-side OCR runs on a Mac mini. For the founder this is fine; for other users, on-device OCR (Apple Vision) may need to be the default path, with the backend as a power-user option.
- **No user accounts or cloud service** — Yiana is local-first with iCloud sync. This is a feature (privacy, simplicity, no ongoing server costs) but means no usage analytics, no remote configuration, and no ability to push updates to user behaviour.
- **App Store review** — must comply with Apple's guidelines. Document handling apps are generally uncontroversial, but the app must handle entitlements (iCloud, file access) correctly.
- **Platform parity expectation** — users expect iOS and macOS to work together seamlessly. Any feature shipped on one platform creates an implicit expectation on the other.

## Open Questions

- [ ] **Does the append-pages workflow resonate with non-founder users?** The founder values it highly, but is "growing a document over time" a common need or a niche one? Test with 5-10 target users.
- [ ] **Is server-side OCR viable for other users, or must on-device be the default?** If on-device OCR (Apple Vision) is good enough, the Mac mini backend becomes optional and the app is self-contained. Test OCR quality: Apple Vision vs. server-side on 50 real documents.
- [ ] **What's the right pricing model?** One-time purchase (like Genius Scan's $25), low subscription (like Scanner Pro's $20/year), or freemium? The competitive analysis suggests subscription fatigue is real — but a one-time purchase limits ongoing revenue.
- [ ] **How important is existing-PDF import?** Do target users want to bring their backlog into Yiana, or will they start fresh? If import is critical, the first-run experience needs an import flow. If not, the empty-state experience needs to be compelling.
- [ ] **Is the "DEVONthink refugee" audience large enough to matter?** Search forums and Reddit for people who tried and abandoned DEVONthink. If there are hundreds of posts, it's a real acquisition channel. If there are tens, it's a nice story but not a strategy.
- [ ] **Does the positioning "more than a scanner, simpler than DEVONthink" land with people who don't know either product?** Test with users outside the Mac productivity community — do they understand the value proposition, or does it require too much context?

---

*This problem statement should be revisited after the first round of user testing. The most important open question is whether the founder's problem generalises — everything else follows from that answer.*
