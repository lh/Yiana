"""
HTML email renderer for the Yiale render service.

Generates semantic HTML with inline CSS and relative font sizes for
clinical correspondence. No external dependencies.
"""

import re
from html import escape as html_escape

from letter_models import Patient, Recipient, SenderConfig


class HTMLRenderer:
    """Renders a letter as HTML for email."""

    def _build_salutation(self, patient: Patient) -> str:
        """Build the salutation name from patient title and surname.

        If a title is present, uses "{title} {surname}" (e.g. "Mr Green").
        Otherwise falls back to the full name.
        """
        if patient.title:
            surname = patient.name.rsplit(None, 1)[-1] if patient.name else ""
            return f"{patient.title} {surname}"
        return patient.name

    def render(self, sender: SenderConfig, patient: Patient,
               recipients: list[Recipient], body: str,
               letter_date: str) -> str:
        """Render a complete HTML letter.

        The HTML uses semantic elements, inline CSS with relative font sizes,
        and no external resources.
        """
        date_display = self._format_letter_date(letter_date)
        dob_display = self._format_date_for_display(patient.dob)
        body_html = self._format_body(body)
        cc_html = self._format_cc(recipients)
        sender_address = ", ".join(sender.address) if sender.address else ""

        secretary_html = ""
        if sender.secretary:
            secretary_html = (
                f'<p style="margin: 0;">'
                f"Secretary: {html_escape(sender.secretary.name)}"
            )
            if sender.secretary.phone:
                secretary_html += f" | Tel: {html_escape(sender.secretary.phone)}"
            if sender.secretary.email:
                secretary_html += (
                    f' | <a href="mailto:{html_escape(sender.secretary.email)}">'
                    f"{html_escape(sender.secretary.email)}</a>"
                )
            secretary_html += "</p>"

        return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Letter - {html_escape(patient.name)}</title>
</head>
<body style="font-family: Helvetica, Arial, sans-serif; max-width: 42em; margin: 2em auto; line-height: 1.5; color: #222;">

<header style="text-align: right; margin-bottom: 2em;">
  <p style="margin: 0;"><strong>{html_escape(sender.name)}</strong></p>
  <p style="margin: 0;">{html_escape(sender.role)}</p>
  <p style="margin: 0;">{html_escape(sender.credentials)}</p>
  <p style="margin: 0.5em 0 0 0;">{html_escape(sender.department)}</p>
  <p style="margin: 0;">{html_escape(sender.hospital)}</p>
  <p style="margin: 0.5em 0 0 0;">{html_escape(date_display)}</p>
</header>

<p style="margin: 1.5em 0;"><strong>Re: {html_escape(patient.name)}, DOB {html_escape(dob_display)}, MRN {html_escape(patient.mrn)}</strong></p>

<p>Dear {html_escape(self._build_salutation(patient))},</p>

{body_html}

<p style="margin-top: 2em;">Yours sincerely,</p>

<p style="margin-top: 3em;">
  <strong>{html_escape(sender.name)}</strong><br>
  {html_escape(sender.role)}<br>
  {html_escape(sender.credentials)}
</p>

{cc_html}

<footer style="margin-top: 3em; border-top: 1px solid #ccc; padding-top: 1em; font-size: 0.85em; color: #666;">
  <address style="font-style: normal;">
    <p style="margin: 0;">{html_escape(sender.name)} | {html_escape(sender.role)}</p>
    <p style="margin: 0;">{html_escape(sender.department)}, {html_escape(sender.hospital)}</p>
    <p style="margin: 0;">{html_escape(sender_address)}</p>
    <p style="margin: 0;">Tel: {html_escape(sender.phone)} | <a href="mailto:{html_escape(sender.email)}">{html_escape(sender.email)}</a></p>
    {secretary_html}
  </address>
</footer>

</body>
</html>"""

    def _apply_inline_formatting(self, text: str) -> str:
        """Convert markdown-style inline formatting to HTML.

        Processes **bold** and *italic* markers. Must be called after
        html_escape since * is not a special HTML character.
        Bold is processed first to avoid ** being consumed as two italics.
        """
        # **bold** -> <strong>bold</strong>
        text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
        # *italic* -> <em>italic</em>
        text = re.sub(r"\*(.+?)\*", r"<em>\1</em>", text)
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
        """Detect list type: 'ul' for bullets, 'ol' for numbered, None otherwise."""
        non_empty = [l.strip() for l in lines if l.strip()]
        if not non_empty:
            return None
        if all(l.startswith("- ") for l in non_empty):
            return "ul"
        if all(self._is_numbered_item(l) for l in non_empty):
            return "ol"
        return None

    def _format_body(self, body: str) -> str:
        """Convert plain text body to HTML paragraphs, lists, and inline formatting."""
        if not body:
            return ""

        paragraphs = re.split(r"\n\n+", body)
        html_parts = []

        for para in paragraphs:
            lines = para.split("\n")

            # All-list paragraph
            list_type = self._detect_list_type(lines)
            if list_type:
                items = []
                for line in lines:
                    stripped = line.strip()
                    if self._is_list_item(stripped):
                        item_text = self._apply_inline_formatting(
                            html_escape(self._format_list_item(stripped))
                        )
                        items.append(f"  <li>{item_text}</li>")
                html_parts.append(f"<{list_type}>\n" + "\n".join(items) + f"\n</{list_type}>")
            else:
                # Mixed content
                prose_lines = []
                current_list_items = []
                current_list_type = None

                def flush_list():
                    nonlocal current_list_items, current_list_type
                    if current_list_items:
                        items = [
                            f"  <li>{self._apply_inline_formatting(html_escape(b))}</li>"
                            for b in current_list_items
                        ]
                        html_parts.append(
                            f"<{current_list_type}>\n" + "\n".join(items) + f"\n</{current_list_type}>"
                        )
                        current_list_items = []
                        current_list_type = None

                def flush_prose():
                    nonlocal prose_lines
                    if prose_lines:
                        text = " ".join(prose_lines)
                        html_parts.append(
                            f"<p>{self._apply_inline_formatting(html_escape(text))}</p>"
                        )
                        prose_lines = []

                for line in lines:
                    stripped = line.strip()
                    if stripped.startswith("- "):
                        flush_prose()
                        if current_list_type and current_list_type != "ul":
                            flush_list()
                        current_list_type = "ul"
                        current_list_items.append(stripped[2:])
                    elif self._is_numbered_item(stripped):
                        flush_prose()
                        if current_list_type and current_list_type != "ol":
                            flush_list()
                        current_list_type = "ol"
                        current_list_items.append(self._numbered_item_text(stripped))
                    else:
                        flush_list()
                        if stripped:
                            prose_lines.append(stripped)

                # Flush remaining
                flush_list()
                flush_prose()

        return "\n\n".join(html_parts)

    def _format_cc(self, recipients: list[Recipient]) -> str:
        """Format all recipients as a cc block."""
        entries = []
        for r in recipients:
            parts = [r.name]
            if r.practice:
                parts.append(r.practice)
            if r.address:
                parts.append(", ".join(r.address))
            entries.append(", ".join(parts))

        if not entries:
            return ""

        lines = "<br>\n".join(
            f"Cc: {html_escape(entry)}" for entry in entries
        )
        return f'<p style="margin-top: 2em; font-size: 0.9em;">\n{lines}\n</p>'

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
