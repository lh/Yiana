"""Tests for letter_html_renderer.py — HTML output structure and content."""

import re

import pytest

from letter_html_renderer import HTMLRenderer
from letter_models import Patient, Recipient, SenderConfig


@pytest.fixture
def html_renderer():
    return HTMLRenderer()


@pytest.fixture
def rendered_html(html_renderer, sender, sample_patient, sample_recipients):
    return html_renderer.render(
        sender=sender,
        patient=sample_patient,
        recipients=sample_recipients,
        body="Thank you for referring this patient.\n\nShe has good vision.",
        letter_date="2026-03-03T09:00:00Z",
    )


class TestHTMLStructure:
    """HTML semantic structure."""

    def test_html_has_semantic_structure(self, rendered_html):
        assert "<address" in rendered_html
        assert "<p" in rendered_html
        assert "<header" in rendered_html
        assert "<footer" in rendered_html

    def test_html_is_valid_doctype(self, rendered_html):
        assert rendered_html.strip().startswith("<!DOCTYPE html>")

    def test_html_has_charset(self, rendered_html):
        assert 'charset="utf-8"' in rendered_html

    def test_html_no_fixed_font_sizes(self, rendered_html):
        # No px or pt font sizes in inline styles (relative sizing only)
        # Border widths in px are fine (1px solid is standard CSS)
        style_blocks = re.findall(r'style="[^"]*"', rendered_html)
        for style in style_blocks:
            # Check for font-size with px or pt units
            font_sizes = re.findall(r"font-size:\s*[\d.]+(?:px|pt)", style)
            assert font_sizes == [], f"Fixed font size found in: {style}"

    def test_html_valid_markup_tags_closed(self, rendered_html):
        # Basic check: all opened tags are closed
        for tag in ["header", "footer", "address", "ul"]:
            if f"<{tag}" in rendered_html:
                assert f"</{tag}>" in rendered_html, f"Unclosed <{tag}> tag"


class TestHTMLContent:
    """HTML content correctness."""

    def test_html_includes_re_line(self, rendered_html):
        assert "Mrs Jane Smith" in rendered_html
        assert "H123456" in rendered_html  # MRN
        assert "DOB" in rendered_html

    def test_html_includes_dob(self, rendered_html):
        assert "12/03/1945" in rendered_html

    def test_html_includes_sender_details(self, rendered_html):
        assert "Arblaster" in rendered_html
        assert "Consultant Ophthalmologist" in rendered_html
        assert "FRCOphth" in rendered_html
        assert "01737 768511" in rendered_html
        assert "l.arblaster@nhs.net" in rendered_html

    def test_html_includes_secretary(self, rendered_html):
        assert "Mrs J Davies" in rendered_html

    def test_html_includes_cc(self, rendered_html):
        assert "Cc:" in rendered_html
        assert "Dr A Patel" in rendered_html


class TestHTMLBulletList:
    """Bullet list rendering in HTML."""

    def test_html_bullet_list(self, html_renderer, sender, sample_patient, sample_recipients):
        body = "Findings:\n\n- Right eye: normal\n- Left eye: uveitis"
        html = html_renderer.render(
            sender=sender,
            patient=sample_patient,
            recipients=sample_recipients,
            body=body,
            letter_date="2026-03-03T09:00:00Z",
        )
        assert "<ul>" in html
        assert "<li>" in html
        assert "Right eye: normal" in html
        assert "Left eye: uveitis" in html

    def test_html_paragraphs(self, html_renderer, sender, sample_patient, sample_recipients):
        body = "First paragraph.\n\nSecond paragraph."
        html = html_renderer.render(
            sender=sender,
            patient=sample_patient,
            recipients=sample_recipients,
            body=body,
            letter_date="2026-03-03T09:00:00Z",
        )
        assert "<p>First paragraph.</p>" in html
        assert "<p>Second paragraph.</p>" in html

    def test_html_escapes_special_chars(self, html_renderer, sender, sample_patient, sample_recipients):
        body = "Drug: 50% & saline <IV>"
        html = html_renderer.render(
            sender=sender,
            patient=sample_patient,
            recipients=sample_recipients,
            body=body,
            letter_date="2026-03-03T09:00:00Z",
        )
        assert "&amp;" in html
        assert "&lt;IV&gt;" in html
