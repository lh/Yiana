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

<p>Dear {html_escape(patient.name)},</p>

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

    def _format_body(self, body: str) -> str:
        """Convert plain text body to HTML paragraphs and bullet lists."""
        if not body:
            return ""

        paragraphs = re.split(r"\n\n+", body)
        html_parts = []

        for para in paragraphs:
            lines = para.split("\n")

            # All-bullet paragraph
            if all(line.strip().startswith("- ") for line in lines if line.strip()):
                items = []
                for line in lines:
                    stripped = line.strip()
                    if stripped.startswith("- "):
                        items.append(f"  <li>{html_escape(stripped[2:])}</li>")
                html_parts.append("<ul>\n" + "\n".join(items) + "\n</ul>")
            else:
                # Mixed content
                prose_lines = []
                current_bullets = []

                for line in lines:
                    stripped = line.strip()
                    if stripped.startswith("- "):
                        if prose_lines:
                            text = " ".join(prose_lines)
                            html_parts.append(f"<p>{html_escape(text)}</p>")
                            prose_lines = []
                        current_bullets.append(stripped[2:])
                    else:
                        if current_bullets:
                            items = [
                                f"  <li>{html_escape(b)}</li>"
                                for b in current_bullets
                            ]
                            html_parts.append(
                                "<ul>\n" + "\n".join(items) + "\n</ul>"
                            )
                            current_bullets = []
                        if stripped:
                            prose_lines.append(stripped)

                # Flush remaining
                if current_bullets:
                    items = [
                        f"  <li>{html_escape(b)}</li>"
                        for b in current_bullets
                    ]
                    html_parts.append("<ul>\n" + "\n".join(items) + "\n</ul>")
                if prose_lines:
                    text = " ".join(prose_lines)
                    html_parts.append(f"<p>{html_escape(text)}</p>")

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
