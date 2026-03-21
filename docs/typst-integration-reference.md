# Typst Integration Reference

> **Created:** 2026-03-21
> **Purpose:** Technical reference for integrating Typst letter rendering into Yiana
> **Status:** Research complete, implementation not started

---

## 1. What is Typst?

Typst is a modern typesetting system (like LaTeX but simpler). Written in Rust,
Apache 2.0 licensed. Produces PDF with professional typography: justified text,
hyphenation, ligatures, kerning. Single binary (~30MB), no installation ceremony.

**Current version:** 0.14.2 (installed via Homebrew on dev machine)

**Fonts bundled in the Typst binary:**
- New Computer Modern (text) — the same font family as LaTeX's default
- New Computer Modern Math
- Libertinus Serif
- DejaVu Sans Mono

New Computer Modern is embedded by default — no font files to ship separately.
Note: only the Regular weight (wght=400) is embedded, not Book (wght=450).
For our use case (bold, italic, bold-italic, regular) this is sufficient.

---

## 2. Integration Options

### Option A: Bundle CLI binary (subprocess)

**How:** Ship the `typst` binary inside the macOS app bundle. Call it as a
subprocess with `Process()` (Swift's `NSTask` equivalent).

```swift
let process = Process()
process.executableURL = Bundle.main.url(forResource: "typst", withExtension: nil)
process.arguments = ["compile", templatePath, outputPath,
                     "--input", "data=\(jsonPath)",
                     "--ignore-system-fonts"]
try process.run()
process.waitUntilExit()
```

**Pros:**
- Simplest to implement (hours, not days)
- No Rust toolchain needed in the build
- Easy to update Typst (replace binary)
- Proven approach (many apps bundle CLI tools)

**Cons:**
- macOS only (iOS prohibits spawning subprocesses)
- ~30MB added to app bundle
- 5-100ms startup overhead per compilation (font discovery)
- Use `--ignore-system-fonts` to reduce startup to ~5ms (use embedded fonts only)

**Verdict:** Good starting point. Gets us off Python/LaTeX immediately.

### Option B: Typst as Rust library via FFI (static library)

**How:** Compile the `typst` Rust crate (or `typst-as-lib` wrapper) as a static
library (`.a` file). Create a C header with the compilation API. Call from Swift
via a bridging header. Package as an XCFramework for both iOS and macOS.

**Build targets needed:**
- `aarch64-apple-darwin` (macOS Apple Silicon)
- `x86_64-apple-darwin` (macOS Intel)
- `aarch64-apple-ios` (iOS device)
- `aarch64-apple-ios-sim` (iOS simulator)

**Rust API surface (minimal):**

```rust
// C-compatible function exposed via FFI
#[no_mangle]
pub extern "C" fn typst_render_letter(
    template_ptr: *const u8, template_len: usize,
    data_json_ptr: *const u8, data_json_len: usize,
    font_data_ptr: *const u8, font_data_len: usize,
    output_ptr: *mut *mut u8, output_len: *mut usize,
) -> i32;
```

Or use **UniFFI** (Mozilla's Rust binding generator) for safer, auto-generated
Swift bindings without manual C headers.

**Pros:**
- Works on both iOS and macOS
- No subprocess, no startup overhead
- Compilations complete in milliseconds
- Truly "just install the app"
- Fonts can be embedded in the Rust binary at compile time (`typst-kit-embed-fonts`)

**Cons:**
- Requires Rust toolchain in the build pipeline
- Cross-compilation setup for 4 targets
- `typst-as-lib` API is "not really stable" (community wrapper, not official)
- More complex build system (Cargo + Xcode)
- Typst version updates require recompilation

**Verdict:** The right long-term solution. More upfront work but delivers the
"just install the app" goal on all platforms.

### Option C: Hybrid (CLI now, library later)

Start with Option A (bundle CLI, macOS only). Migrate to Option B when iOS
rendering is needed. The template is the same either way — only the
compilation invocation changes.

**Verdict:** Recommended approach. Ship value now, invest in library later.

---

## 3. Template Architecture

### Data flow

```
ComposeViewModel
    → builds LetterDraft (JSON)
    → passes to LetterRenderer
        → loads sender.json
        → for each recipient:
            → sets template variables (is_patient_copy, postal_address, etc.)
            → compiles template → PDF
        → generates HTML (separate template or Typst → HTML?)
        → writes PDFs to .letters/rendered/{letter_id}/
        → copies hospital_records PDF to .letters/inject/
```

### Template variables (passed via `sys.inputs`)

| Variable | Type | Description |
|----------|------|-------------|
| `data` | JSON string | Full draft JSON (patient, recipients, body, etc.) |
| `sender` | JSON string | Sender config (name, credentials, address, etc.) |
| `recipient_index` | Integer | Which recipient this PDF is for |
| `is_patient_copy` | Boolean | Patient copy uses 14pt, wider spacing |

### Template features used

- **New Computer Modern** font (embedded in Typst)
- Bold italic header block (sender details)
- Bold Re: line (patient demographics)
- Justified body text with hyphenation
- Conditional header on pages 2+ (name + MRN for non-patient copies)
- Conditional font size (14pt patient, 11pt others)
- Conditional postal address block (omitted for hospital records)
- CC lines at the end
- Page numbers on pages 2+ (all copies)

### Prototype

Working prototype at `docs/typst-prototype/letter.typ`. Tested with Typst 0.14.2.
Reproduces the existing LaTeX letter format using New Computer Modern.

---

## 4. Font Considerations

**Embedded fonts (no files to ship):**
- New Computer Modern Regular, Bold, Italic, Bold Italic — all embedded in Typst binary
- Sufficient for our letter template

**`--ignore-system-fonts` flag (CLI mode):**
- Skips system font discovery (saves 5-100ms per compilation)
- Only uses embedded fonts — ensures reproducibility across machines
- Letters will look identical on every Mac

**Library mode:**
- Fonts embedded at compile time via `typst-kit-embed-fonts` Cargo feature
- Zero runtime font discovery

---

## 5. Performance

From Typst's official blog (2025):
- Compilations commonly complete in **milliseconds**
- Library mode saves 5-100ms per job vs CLI (font discovery overhead)
- Suitable for "thousands to millions of PDFs per day"

For our use case (one letter at a time, ~1-3 pages):
- CLI mode: ~50-100ms total (acceptable, user won't notice)
- Library mode: ~5-10ms (instant)

---

## 6. HTML Generation

The current render service produces HTML alongside PDFs (for emailing).
Options for Typst:

1. **Typst → HTML:** Typst has experimental HTML output (`typst compile --format html`).
   Added in recent versions. Quality and feature completeness TBD.
2. **Separate HTML template:** Simple string interpolation (current Python approach).
   HTML is just sender header + Re: line + body paragraphs + CC. No complex layout.
3. **Defer HTML:** Letters are printed/posted. Email is a nice-to-have, not essential.

Recommendation: Start without HTML. Add later if needed.

---

## 7. Integration with Existing Code

### What changes in Yiana

| Component | Current | After Typst |
|-----------|---------|-------------|
| `ComposeViewModel.sendToPrint()` | Sets `render_requested` status, waits for Devon | Calls `LetterRenderer.render()` directly, PDF available immediately |
| `LetterRepository` | Stores drafts, checks for rendered PDFs | Unchanged — still manages draft CRUD and rendered directory |
| `ComposeTab` | Shows "Sending..." while waiting for Devon | Shows "Rendering..." briefly, then "Ready" with PDF actions |
| `InjectWatcher` | Picks up PDFs from `.letters/inject/` | Unchanged — renderer places hospital records PDF there |
| Devon render service | Watches `.letters/drafts/`, renders via Python+LaTeX | **Retired** |

### New code needed

| Component | Est. LOC | Description |
|-----------|----------|-------------|
| `LetterRenderer` | ~150 | Service that invokes Typst (CLI or library) with template + data |
| `letter.typ` | ~100 | Typst template (already prototyped) |
| Xcode build phase (CLI) | ~10 | Copy `typst` binary into app bundle |
| OR Rust bridge (library) | ~200 | Cargo build + C header + Swift wrapper |

---

## 8. Risks

- **`typst-as-lib` instability:** Community wrapper, not official. API may change.
  Mitigation: use minimal API surface (compile template → PDF bytes). Or use
  the official `typst` crate directly with our own thin wrapper.

- **iOS App Store review:** Bundling a CLI binary is fine for macOS but not
  allowed on iOS. Library approach (Option B) is required for iOS.
  Mitigation: start with CLI (macOS), add library for iOS later.

- **Typst version updates:** New Typst versions may change template behaviour.
  Mitigation: pin Typst version, test templates before updating.

- **Font rendering differences:** Embedded New Computer Modern may render
  slightly differently from system-installed LaTeX fonts.
  Mitigation: prototype validated — output matches expectations.

---

## Sources

- [typst-as-lib on crates.io](https://crates.io/crates/typst-as-lib)
- [typst-as-lib GitHub](https://github.com/Relacibo/typst-as-lib)
- [Typst: Automated PDF Generation blog post](https://typst.app/blog/2025/automated-generation/)
- [Typst Open Source page (licensing)](https://typst.app/open-source/)
- [UniFFI — Mozilla's Rust binding generator](https://github.com/mozilla/uniffi-rs)
- [Calling Rust from Swift (Strathweb)](https://www.strathweb.com/2023/07/calling-rust-code-from-swift/)
- [Building iOS apps with Rust and UniFFI](https://dev.to/almaju/building-an-ios-app-with-rust-using-uniffi-200a)
- [Integrating UniFFI with Xcode](https://mozilla.github.io/uniffi-rs/latest/swift/xcode.html)
- [Typst embedded fonts discussion](https://github.com/typst/typst/issues/7045)
- [Typst forum: using compiler as library](https://forum.typst.app/t/how-do-i-use-the-typst-compiler-in-rust-as-a-library/6859)
