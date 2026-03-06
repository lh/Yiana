"""
Letter renderer for the Yiale render service.

Fills a LaTeX template with letter data, handles LaTeX escaping and body
formatting (paragraphs + bullet lists), and compiles to PDF via lualatex.
"""

import logging
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Optional

from letter_models import Recipient, SenderConfig, Patient

logger = logging.getLogger(__name__)


class LetterRenderer:
    """Renders letter PDFs from a LaTeX template."""

    def __init__(self, template_path: Path):
        if not template_path.exists():
            raise FileNotFoundError(f"Template not found: {template_path}")
        with open(template_path, "r") as f:
            self.template = f.read()

    def escape_latex(self, text: str) -> str:
        """Escape special LaTeX characters in plain text.

        Handles the 10 special characters: \\ { } $ & % # _ ~ ^
        Backslash is replaced first to avoid double-escaping.
        """
        if not text:
            return ""

        # Two-pass approach: replace chars whose LaTeX equivalents contain
        # braces ({}) with sentinels first, then escape braces, then replace
        # sentinels with final values.
        _BACKSLASH = "\x00BACKSLASH\x00"
        _TILDE = "\x00TILDE\x00"
        _CARET = "\x00CARET\x00"

        text = text.replace("\\", _BACKSLASH)
        text = text.replace("~", _TILDE)
        text = text.replace("^", _CARET)

        # Escape braces and other simple chars
        simple = [
            ("{", r"\{"),
            ("}", r"\}"),
            ("$", r"\$"),
            ("&", r"\&"),
            ("%", r"\%"),
            ("#", r"\#"),
            ("_", r"\_"),
        ]
        for char, replacement in simple:
            text = text.replace(char, replacement)

        # Replace sentinels with final LaTeX commands
        text = text.replace(_BACKSLASH, r"\textbackslash{}")
        text = text.replace(_TILDE, r"\textasciitilde{}")
        text = text.replace(_CARET, r"\textasciicircum{}")

        return text

    def _apply_inline_formatting(self, text: str) -> str:
        """Convert markdown-style inline formatting to LaTeX.

        Processes **bold** and *italic* markers. Must be called after
        escape_latex since * is not a special LaTeX character.
        Bold is processed first to avoid ** being consumed as two italics.
        """
        # **bold** -> \textbf{bold}
        text = re.sub(r"\*\*(.+?)\*\*", r"\\textbf{\1}", text)
        # *italic* -> \textit{italic}
        text = re.sub(r"\*(.+?)\*", r"\\textit{\1}", text)
        return text

    def _is_numbered_item(self, line: str) -> bool:
        """Check if a line starts with a numbered list marker (e.g. '1. ')."""
        return bool(re.match(r"^\d+\.\s", line))

    def _numbered_item_text(self, line: str) -> str:
        """Extract the text after a numbered list marker."""
        return re.sub(r"^\d+\.\s", "", line)

    def _is_list_item(self, line: str) -> bool:
        """Check if a line is a bullet or numbered list item."""
        return line.startswith("- ") or self._is_numbered_item(line)

    def _format_list_item(self, line: str) -> str:
        """Extract text from a bullet or numbered list item."""
        if line.startswith("- "):
            return line[2:]
        return self._numbered_item_text(line)

    def _detect_list_type(self, lines: list[str]) -> str | None:
        """Detect the list type for a group of lines.

        Returns 'itemize' for bullets, 'enumerate' for numbered, or None.
        """
        non_empty = [l.strip() for l in lines if l.strip()]
        if not non_empty:
            return None
        if all(l.startswith("- ") for l in non_empty):
            return "itemize"
        if all(self._is_numbered_item(l) for l in non_empty):
            return "enumerate"
        return None

    def format_body(self, body: str) -> str:
        """Convert plain text body to LaTeX.

        - Paragraphs (separated by blank lines) become \\\\[10pt] breaks
        - Lines starting with '- ' are grouped into itemize environments
        - Lines starting with 'N. ' are grouped into enumerate environments
        - **bold** and *italic* inline formatting is supported
        - All text is LaTeX-escaped
        """
        if not body:
            return ""

        paragraphs = re.split(r"\n\n+", body)
        latex_parts = []

        for para in paragraphs:
            lines = para.split("\n")

            # Check if this paragraph is entirely list items (all same type)
            list_type = self._detect_list_type(lines)
            if list_type:
                items = []
                for line in lines:
                    stripped = line.strip()
                    if self._is_list_item(stripped):
                        item_text = self._apply_inline_formatting(
                            self.escape_latex(self._format_list_item(stripped))
                        )
                        items.append(f"  \\item {item_text}")
                latex_parts.append(
                    f"\\begin{{{list_type}}}[nosep]\n"
                    + "\n".join(items)
                    + f"\n\\end{{{list_type}}}"
                )
            else:
                # Mixed content: prose, bullets, numbered items
                prose_lines = []
                current_list_items = []
                current_list_type = None

                def flush_list():
                    nonlocal current_list_items, current_list_type
                    if current_list_items:
                        items = [
                            f"  \\item {self._apply_inline_formatting(self.escape_latex(b))}"
                            for b in current_list_items
                        ]
                        latex_parts.append(
                            f"\\begin{{{current_list_type}}}[nosep]\n"
                            + "\n".join(items)
                            + f"\n\\end{{{current_list_type}}}"
                        )
                        current_list_items = []
                        current_list_type = None

                def flush_prose():
                    nonlocal prose_lines
                    if prose_lines:
                        escaped = self._apply_inline_formatting(
                            self.escape_latex(" ".join(prose_lines))
                        )
                        latex_parts.append(escaped)
                        prose_lines = []

                for line in lines:
                    stripped = line.strip()
                    if stripped.startswith("- "):
                        flush_prose()
                        if current_list_type and current_list_type != "itemize":
                            flush_list()
                        current_list_type = "itemize"
                        current_list_items.append(stripped[2:])
                    elif self._is_numbered_item(stripped):
                        flush_prose()
                        if current_list_type and current_list_type != "enumerate":
                            flush_list()
                        current_list_type = "enumerate"
                        current_list_items.append(self._numbered_item_text(stripped))
                    else:
                        flush_list()
                        if stripped:
                            prose_lines.append(stripped)

                # Flush remaining
                flush_list()
                flush_prose()

        return "\n\n\\vspace{10pt}\n\n".join(latex_parts)

    def build_cc_line(self, all_recipients: list[Recipient],
                      current_recipient: Recipient) -> str:
        """Build the cc line for a letter copy.

        Lists all recipients except the current one. Includes practice name
        and address where available.
        """
        cc_entries = []
        for r in all_recipients:
            if r is current_recipient:
                continue
            if r.role == "hospital_records":
                cc_entries.append("Hospital Records")
                continue

            parts = [r.name]
            if r.practice:
                parts.append(r.practice)
            if r.address:
                parts.append(", ".join(r.address))

            cc_entries.append(", ".join(parts))

        if not cc_entries:
            return ""

        formatted = "\\\\".join(f"Cc: {entry}" for entry in cc_entries)
        return f"\\noindent\n{formatted}"

    def _build_address_block(self, recipient: Recipient,
                             include_address: bool) -> str:
        """Build the address block for the envelope window."""
        if not include_address or not recipient.address:
            return ""

        lines = [f"\\noindent", f"\\vspace*{{35mm}}"]
        lines.append("\\begin{flushleft}")
        lines.append(f"{self.escape_latex(recipient.name)}\\\\")
        if recipient.practice:
            lines.append(f"{self.escape_latex(recipient.practice)}\\\\")
        for i, addr_line in enumerate(recipient.address):
            escaped = self.escape_latex(addr_line)
            if i < len(recipient.address) - 1:
                lines.append(f"{escaped}\\\\")
            else:
                lines.append(escaped)
        lines.append("\\end{flushleft}")
        return "\n".join(lines)

    def _format_date_for_display(self, date_str: str) -> str:
        """Format ISO date (YYYY-MM-DD) to UK display format (DD/MM/YYYY)."""
        try:
            from datetime import datetime
            dt = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
            return dt.strftime("%d/%m/%Y")
        except (ValueError, AttributeError):
            return date_str

    def _format_letter_date(self, iso_timestamp: str) -> str:
        """Format ISO timestamp to letter date (e.g. '3 March 2026')."""
        try:
            from datetime import datetime
            dt = datetime.fromisoformat(iso_timestamp.replace("Z", "+00:00"))
            return dt.strftime("%-d %B %Y")
        except (ValueError, AttributeError):
            return iso_timestamp

    def _build_salutation(self, patient: Patient) -> str:
        """Build the salutation name from patient title and surname.

        If a title is present, uses "{title} {surname}" (e.g. "Mr Green").
        Otherwise falls back to the full name.
        """
        if patient.title:
            # Use last whitespace-separated word as surname
            surname = patient.name.rsplit(None, 1)[-1] if patient.name else ""
            return f"{patient.title} {surname}"
        return patient.name

    def fill_template(self, sender: SenderConfig, patient: Patient,
                      recipient: Recipient, body: str,
                      cc_line: str, is_patient_copy: bool,
                      include_address: bool,
                      letter_date: str) -> str:
        """Fill the LaTeX template with all variables."""
        content = self.template

        # Sender details
        variables = {
            "SENDER_NAME": self.escape_latex(sender.name),
            "SENDER_ROLE": self.escape_latex(sender.role),
            "SENDER_CREDENTIALS": self.escape_latex(sender.credentials),
            "SENDER_DEPARTMENT": self.escape_latex(sender.department),
            "SENDER_HOSPITAL": self.escape_latex(sender.hospital),
            "LETTER_DATE": self._format_letter_date(letter_date),
            "ADDRESS_BLOCK": self._build_address_block(recipient, include_address),
            "PATIENT_NAME": self.escape_latex(patient.name),
            "PATIENT_DOB": self._format_date_for_display(patient.dob),
            "PATIENT_MRN": self.escape_latex(patient.mrn),
            "SALUTATION": self.escape_latex(self._build_salutation(patient)),
            "CLINICAL_CONTENT": self.format_body(body),
            "COPY_LIST": cc_line,
        }

        # Body font size for patient copies
        # This is a declaration — persists until end of document.
        # Template places it immediately before \noindent + content
        # with no intervening blank line (which would create a paragraph
        # break and lose the font change).
        if is_patient_copy:
            # 14pt font with 19.6pt baseline skip (= 14 * 1.4)
            # Do NOT use \setstretch — it resets fontsize on paragraph breaks
            variables["BODY_FONT_SIZE"] = (
                "\\fontsize{14}{19.6}\\selectfont"
            )
        else:
            variables["BODY_FONT_SIZE"] = ""

        for key, value in variables.items():
            placeholder = f"<{key}>"
            content = content.replace(placeholder, value if value else "")

        return content

    def render_pdf(self, sender: SenderConfig, patient: Patient,
                   recipient: Recipient, body: str,
                   all_recipients: list[Recipient],
                   is_patient_copy: bool, include_address: bool,
                   letter_date: str,
                   output_dir: Path,
                   output_filename: str) -> Optional[Path]:
        """Render a single letter copy to PDF.

        Returns the path to the PDF file, or None if compilation failed.
        """
        cc_line = self.build_cc_line(all_recipients, recipient)
        tex_content = self.fill_template(
            sender, patient, recipient, body,
            cc_line, is_patient_copy, include_address, letter_date,
        )

        pdf_path = self.compile_latex(tex_content, output_dir, output_filename)
        return pdf_path

    def compile_latex(self, tex_content: str, output_dir: Path,
                      output_filename: str) -> Optional[Path]:
        """Compile LaTeX content to PDF using lualatex.

        Runs lualatex twice for page references. Returns path to PDF or None.
        """
        output_dir.mkdir(parents=True, exist_ok=True)

        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            tex_file = tmp_dir / "letter.tex"

            with open(tex_file, "w") as f:
                f.write(tex_content)

            try:
                for _ in range(2):
                    result = subprocess.run(
                        ["lualatex", "-interaction=nonstopmode", tex_file.name],
                        cwd=tmp_dir,
                        capture_output=True,
                        text=True,
                        timeout=30,
                    )

                    if result.returncode != 0:
                        logger.error("LaTeX compilation failed")
                        for line in result.stdout.split("\n"):
                            if "Error" in line or line.startswith("!"):
                                logger.error(f"  {line}")
                        return None

                pdf_source = tex_file.with_suffix(".pdf")
                if not pdf_source.exists():
                    logger.error("PDF file not created by lualatex")
                    return None

                pdf_dest = output_dir / output_filename
                shutil.copy2(pdf_source, pdf_dest)
                return pdf_dest

            except subprocess.TimeoutExpired:
                logger.error("LaTeX compilation timed out")
                return None
            except FileNotFoundError:
                logger.error(
                    "lualatex not found. Install LaTeX "
                    "(e.g. brew install --cask mactex-no-gui)"
                )
                return None
