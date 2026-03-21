use chrono::{Datelike, Local};
use typst::diag::{FileError, FileResult};
use typst::foundations::{Bytes, Datetime, Dict, Value};
use typst::layout::PagedDocument;
use typst::syntax::{FileId, Source};
use typst::text::{Font, FontBook};
use typst::{Library, World};
use typst_kit::fonts::{FontSearcher, FontSlot, Fonts};
use typst_pdf::PdfOptions;
use typst_utils::LazyHash;

// ============================================================
// World implementation for in-memory compilation
// ============================================================

struct LetterWorld {
    library: LazyHash<Library>,
    book: LazyHash<FontBook>,
    fonts: Vec<FontSlot>,
    source: Source,
}

impl LetterWorld {
    fn new(template: &str, inputs: Dict) -> Self {
        // Load embedded fonts only (no system fonts — reproducible output)
        let fonts: Fonts = FontSearcher::new()
            .include_system_fonts(false)
            .search();

        let library = Library::builder().with_inputs(inputs).build();
        let source = Source::detached(template);

        LetterWorld {
            library: LazyHash::new(library),
            book: LazyHash::new(fonts.book),
            fonts: fonts.fonts,
            source,
        }
    }
}

impl World for LetterWorld {
    fn library(&self) -> &LazyHash<Library> {
        &self.library
    }

    fn book(&self) -> &LazyHash<FontBook> {
        &self.book
    }

    fn main(&self) -> FileId {
        self.source.id()
    }

    fn source(&self, id: FileId) -> FileResult<Source> {
        if id == self.source.id() {
            Ok(self.source.clone())
        } else {
            Err(FileError::NotFound(id.vpath().as_rootless_path().into()))
        }
    }

    fn file(&self, _id: FileId) -> FileResult<Bytes> {
        Err(FileError::Other(Some(
            "File access not supported in embedded mode".into(),
        )))
    }

    fn font(&self, index: usize) -> Option<Font> {
        self.fonts.get(index)?.get()
    }

    fn today(&self, _offset: Option<i64>) -> Option<Datetime> {
        let now = Local::now();
        Datetime::from_ymd(
            now.year(),
            now.month().try_into().ok()?,
            now.day().try_into().ok()?,
        )
    }
}

// ============================================================
// C-compatible FFI
// ============================================================

/// Compile a Typst template with JSON inputs to PDF.
///
/// # Safety
/// All pointer parameters must be valid for the given lengths.
/// The caller must free output buffers with `typst_free_buffer`.
///
/// Returns 0 on success, 1 on error.
#[no_mangle]
pub unsafe extern "C" fn typst_compile_to_pdf(
    template: *const u8,
    template_len: usize,
    inputs_json: *const u8,
    inputs_len: usize,
    out_pdf: *mut *mut u8,
    out_pdf_len: *mut usize,
    out_error: *mut *mut u8,
    out_error_len: *mut usize,
) -> i32 {
    *out_pdf = std::ptr::null_mut();
    *out_pdf_len = 0;
    *out_error = std::ptr::null_mut();
    *out_error_len = 0;

    let template_str =
        match std::str::from_utf8(std::slice::from_raw_parts(template, template_len)) {
            Ok(s) => s,
            Err(e) => {
                return set_error(out_error, out_error_len, &format!("Invalid template UTF-8: {e}"))
            }
        };

    let inputs_str =
        match std::str::from_utf8(std::slice::from_raw_parts(inputs_json, inputs_len)) {
            Ok(s) => s,
            Err(e) => {
                return set_error(out_error, out_error_len, &format!("Invalid inputs UTF-8: {e}"))
            }
        };

    let inputs_dict = match parse_json_to_dict(inputs_str) {
        Ok(d) => d,
        Err(e) => return set_error(out_error, out_error_len, &format!("JSON parse error: {e}")),
    };

    let world = LetterWorld::new(template_str, inputs_dict);

    let warned = typst::compile::<PagedDocument>(&world);
    let document = match warned.output {
        Ok(doc) => doc,
        Err(diagnostics) => {
            let msg = diagnostics
                .iter()
                .map(|d| d.message.to_string())
                .collect::<Vec<_>>()
                .join("\n");
            return set_error(
                out_error,
                out_error_len,
                &format!("Compilation error: {msg}"),
            );
        }
    };

    let options = PdfOptions::default();
    let pdf_bytes = match typst_pdf::pdf(&document, &options) {
        Ok(bytes) => bytes,
        Err(diagnostics) => {
            let msg = diagnostics
                .iter()
                .map(|d| d.message.to_string())
                .collect::<Vec<_>>()
                .join("\n");
            return set_error(
                out_error,
                out_error_len,
                &format!("PDF export error: {msg}"),
            );
        }
    };

    let len = pdf_bytes.len();
    let ptr = Box::into_raw(pdf_bytes.into_boxed_slice()) as *mut u8;
    *out_pdf = ptr;
    *out_pdf_len = len;

    0
}

/// Free a buffer allocated by typst_compile_to_pdf.
///
/// # Safety
/// ptr must have been returned by typst_compile_to_pdf, and len must match.
#[no_mangle]
pub unsafe extern "C" fn typst_free_buffer(ptr: *mut u8, len: usize) {
    if !ptr.is_null() && len > 0 {
        let _ = Box::from_raw(std::slice::from_raw_parts_mut(ptr, len));
    }
}

// ============================================================
// Helpers
// ============================================================

unsafe fn set_error(out_error: *mut *mut u8, out_error_len: *mut usize, msg: &str) -> i32 {
    let bytes = msg.as_bytes().to_vec();
    let len = bytes.len();
    let ptr = Box::into_raw(bytes.into_boxed_slice()) as *mut u8;
    *out_error = ptr;
    *out_error_len = len;
    1
}

fn parse_json_to_dict(json_str: &str) -> Result<Dict, String> {
    let value: serde_json::Value = serde_json::from_str(json_str).map_err(|e| format!("{e}"))?;

    match value {
        serde_json::Value::Object(map) => {
            let mut dict = Dict::new();
            for (key, val) in map {
                dict.insert(key.as_str().into(), json_to_typst_value(&val));
            }
            Ok(dict)
        }
        _ => Err("Top-level JSON must be an object".to_string()),
    }
}

fn json_to_typst_value(val: &serde_json::Value) -> Value {
    match val {
        serde_json::Value::Null => Value::None,
        serde_json::Value::Bool(b) => Value::Bool(*b),
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                Value::Int(i)
            } else if let Some(f) = n.as_f64() {
                Value::Float(f)
            } else {
                Value::None
            }
        }
        serde_json::Value::String(s) => Value::Str(s.as_str().into()),
        // Pass arrays and objects as JSON strings — template parses them with json()
        serde_json::Value::Array(_) | serde_json::Value::Object(_) => {
            Value::Str(val.to_string().as_str().into())
        }
    }
}

// ============================================================
// Tests
// ============================================================

#[cfg(test)]
mod tests {
    use super::*;

    const SIMPLE_TEMPLATE: &str = r#"
#set text(font: "New Computer Modern", size: 11pt)
#set page(paper: "a4")

Hello from Typst. Name: #sys.inputs.name
"#;

    const DATA_TEMPLATE: &str = r#"
#let data = json(bytes(sys.inputs.data))
#let sender = data.sender
#let patient = data.patient

#set text(font: "New Computer Modern", size: 11pt)
#set page(paper: "a4")

*#sender.name*

Re: #patient.name. DOB: #patient.dob.

#data.body
"#;

    fn simple_inputs_json() -> String {
        serde_json::json!({
            "name": "World"
        })
        .to_string()
    }

    fn data_inputs_json() -> String {
        serde_json::json!({
            "data": serde_json::json!({
                "sender": {"name": "Mr Luke Herbert"},
                "patient": {"name": "Mr Fiction Fictional", "dob": "20/05/1960"},
                "body": "This is a test letter body."
            }).to_string()
        })
        .to_string()
    }

    #[test]
    fn compiles_simple_template() {
        let template = SIMPLE_TEMPLATE.as_bytes();
        let inputs = simple_inputs_json();
        let inputs_bytes = inputs.as_bytes();

        let mut pdf_ptr: *mut u8 = std::ptr::null_mut();
        let mut pdf_len: usize = 0;
        let mut err_ptr: *mut u8 = std::ptr::null_mut();
        let mut err_len: usize = 0;

        let result = unsafe {
            typst_compile_to_pdf(
                template.as_ptr(),
                template.len(),
                inputs_bytes.as_ptr(),
                inputs_bytes.len(),
                &mut pdf_ptr,
                &mut pdf_len,
                &mut err_ptr,
                &mut err_len,
            )
        };

        if result != 0 && !err_ptr.is_null() {
            let err = unsafe {
                std::str::from_utf8(std::slice::from_raw_parts(err_ptr, err_len)).unwrap()
            };
            unsafe { typst_free_buffer(err_ptr, err_len) };
            panic!("Compilation failed: {err}");
        }

        assert_eq!(result, 0, "Expected success");
        assert!(pdf_len > 1000, "PDF should be > 1KB, got {pdf_len}");
        let pdf_slice = unsafe { std::slice::from_raw_parts(pdf_ptr, pdf_len) };
        assert!(pdf_slice.starts_with(b"%PDF-"));
        unsafe { typst_free_buffer(pdf_ptr, pdf_len) };
    }

    #[test]
    fn compiles_to_valid_pdf() {
        let template = DATA_TEMPLATE.as_bytes();
        let inputs = data_inputs_json();
        let inputs_bytes = inputs.as_bytes();

        let mut pdf_ptr: *mut u8 = std::ptr::null_mut();
        let mut pdf_len: usize = 0;
        let mut err_ptr: *mut u8 = std::ptr::null_mut();
        let mut err_len: usize = 0;

        let result = unsafe {
            typst_compile_to_pdf(
                template.as_ptr(),
                template.len(),
                inputs_bytes.as_ptr(),
                inputs_bytes.len(),
                &mut pdf_ptr,
                &mut pdf_len,
                &mut err_ptr,
                &mut err_len,
            )
        };

        if result != 0 && !err_ptr.is_null() {
            let err = unsafe {
                std::str::from_utf8(std::slice::from_raw_parts(err_ptr, err_len)).unwrap()
            };
            unsafe { typst_free_buffer(err_ptr, err_len) };
            panic!("Compilation failed: {err}");
        }

        assert_eq!(result, 0, "Expected success");
        assert!(pdf_len > 1000, "PDF should be > 1KB, got {pdf_len}");

        let pdf_slice = unsafe { std::slice::from_raw_parts(pdf_ptr, pdf_len) };
        assert!(
            pdf_slice.starts_with(b"%PDF-"),
            "Output should be valid PDF"
        );

        unsafe { typst_free_buffer(pdf_ptr, pdf_len) };
    }

    #[test]
    fn returns_error_for_bad_template() {
        let template = b"#let x = invalid_function()";
        let inputs = b"{}";

        let mut pdf_ptr: *mut u8 = std::ptr::null_mut();
        let mut pdf_len: usize = 0;
        let mut err_ptr: *mut u8 = std::ptr::null_mut();
        let mut err_len: usize = 0;

        let result = unsafe {
            typst_compile_to_pdf(
                template.as_ptr(),
                template.len(),
                inputs.as_ptr(),
                inputs.len(),
                &mut pdf_ptr,
                &mut pdf_len,
                &mut err_ptr,
                &mut err_len,
            )
        };

        assert_eq!(result, 1, "Expected error");
        assert!(err_len > 0, "Error message should be non-empty");

        unsafe {
            if !err_ptr.is_null() {
                typst_free_buffer(err_ptr, err_len);
            }
        }
    }
}
