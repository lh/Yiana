# OCR Fallback Evaluation (Nice-to-have)

**Status:** Parked until post-MVP  
**Primary goal:** Decide whether a secondary OCR engine adds enough value to justify ongoing cost and complexity.

---

## Background

Today the macOS/iOS app relies on Apple’s Vision OCR (via the shared OCR service). For camera-based documents Vision usually delivers clean results, and our recent fixes ensure:

- Embedded PDF text (e.g., VisionKit scans) is captured and surfaced in the app.
- The OCR service logs provenance (`embedded` vs `service`) and keeps metadata `.fullText`, confidence, and timestamps in sync.

Earlier issues—false “embedded text” detections and missing OCR artefacts—are resolved, so we now always store the best text we have. That gives us a solid baseline to measure any alternative engine against.

---

## Why Revisit Additional OCR?

A second engine can help when:

- Vision fails completely (empty text, low confidence).
- Documents use non-Latin scripts or specialist fonts Vision does not support.
- Image quality is poor (heavy noise, skew, low contrast) and another engine’s preprocessing recovers text.

If those cases are rare, the extra code path offers little benefit. If they are common, even a slow fallback can be worthwhile—the OCR service runs off-device, so latency is acceptable.

---

## Candidate Engines (Local Execution Only)

| Engine | Pros | Cons |
| --- | --- | --- |
| **Tesseract 5.x** | Open source, broad language support, easy CLI integration. | Slow, single-threaded, needs preprocessing (deskew, threshold). |
| **PaddleOCR** | Good accuracy on multi-lingual/curved text, CPU or GPU. | Python stack; heavier dependencies and deployment footprint. |
| **ABBYY FineReader Engine** | Industry-grade accuracy, handles complex layouts. | Commercial license, large binaries. |
| **Vision + Preprocessing Layer** | Keep Vision, but add custom preprocessing (deskew, denoise). | Might not fix the hardest cases; still limited to languages Vision supports. |

Local LLMs are not OCR engines. However, lightweight models running via `llama.cpp`, CoreML, or similar could sit *after* OCR to normalise spacing, fix obvious typos, apply domain-specific corrections (e.g., `lO` → `10`), or flag low-confidence passages for manual review. They only help when the OCR layer produced text; they cannot recover missing characters.

---

## Critique of Earlier Ideas

- *“Always run two engines in parallel.”*  
  Adds cost without evidence it improves output. Better to run a fallback selectively and gather statistics first.

- *“Treat embedded text as ‘OCR complete’ without saving the text.”*  
  Already fixed—embedded text is now captured and packaged as a normal OCR result. No further action needed.

- *“Use LLMs for OCR.”*  
  LLMs can’t read pixels. Where they *can* help is post-processing: smoothing OCR output, enforcing domain terminology, or spotting low-confidence passages. Any experiment should log both raw and LLM-corrected text so we can decide if the cleanup is worth the extra CPU.

---

## Proposed Experiment (Post-MVP)

1. **Instrument Vision output**
   - Record per-page confidence, empty text flags, and language hints in the OCR service logs.
   - Mark documents with `confidence < threshold` or `fullText.isEmpty` as “fallback candidates.”

2. **Add an optional fallback runner**
   - New CLI command (`swift run yiana-ocr fallback --engine tesseract`) that processes only the candidate set.
   - Store results in a parallel directory (e.g., `.ocr_results_experimental`) without touching the primary metadata.

3. **Collect metrics**
   - Compare Vision vs fallback character counts, unique tokens, and (optional) heuristics like Levenshtein distance.
   - Aggregate per language, per confidence bucket, and per document type (camera vs PDF import).

4. **Decide**
   - If fallback recovers significant additional text on a meaningful portion of documents, consider integrating it.
   - If gains are negligible, document the findings and keep the fallback disabled by default.

---

## Implementation Notes (When Scheduled)

| Task | Detail |
| --- | --- |
| Fallback queue | Store candidate document URLs + metadata (confidence, language). |
| CLI integration | Add `cleanup`, `fallback`, and `stats` subcommands to `yiana-ocr`. |
| Engine wrapper | Preferred first step: Tesseract 5.x via CLI for simplest deployment. |
| Metrics | Extend log format and/or write JSON summaries for downstream analysis. |
| Safety | Never overwrite the primary `.yianazip`; keep experiments isolated. |

---

## Next Steps (Deferred)

1. Ship MVP and observe real-world OCR metrics.
2. Build the fallback experiment on the OCR service (no app changes initially).
3. Review results; only integrate fallback into production pipeline if clear benefits appear.

Until then, Vision remains the sole engine. This document serves as a bookmark and initial blueprint for future investigation.
