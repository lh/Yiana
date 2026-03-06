"""Tests for letter_renderer.py — LaTeX escaping, template filling, compilation."""

import shutil
import subprocess

import pytest

from letter_models import Patient, Recipient, SenderConfig
from letter_renderer import LetterRenderer


@pytest.fixture
def renderer(template_path):
    return LetterRenderer(template_path)


class TestEscapeLatex:
    """LaTeX special character escaping."""

    def test_escape_ampersand(self, renderer):
        assert renderer.escape_latex("A & B") == r"A \& B"

    def test_escape_percent(self, renderer):
        assert renderer.escape_latex("50%") == r"50\%"

    def test_escape_dollar(self, renderer):
        assert renderer.escape_latex("$100") == r"\$100"

    def test_escape_hash(self, renderer):
        assert renderer.escape_latex("#1") == r"\#1"

    def test_escape_underscore(self, renderer):
        assert renderer.escape_latex("a_b") == r"a\_b"

    def test_escape_braces(self, renderer):
        assert renderer.escape_latex("{test}") == r"\{test\}"

    def test_escape_tilde(self, renderer):
        assert renderer.escape_latex("~") == r"\textasciitilde{}"

    def test_escape_caret(self, renderer):
        assert renderer.escape_latex("^") == r"\textasciicircum{}"

    def test_escape_backslash(self, renderer):
        assert renderer.escape_latex("a\\b") == r"a\textbackslash{}b"

    def test_escape_all_special_chars(self, renderer):
        text = "Cost: $100 & 50% off #1 item_sale {now} ~today ^note"
        result = renderer.escape_latex(text)
        assert r"\$" in result
        assert r"\&" in result
        assert r"\%" in result
        assert r"\#" in result
        assert r"\_" in result
        assert r"\{" in result
        assert r"\}" in result
        assert r"\textasciitilde{}" in result
        assert r"\textasciicircum{}" in result

    def test_escape_preserves_normal_text(self, renderer):
        text = "The patient was seen in clinic today. Visual acuity was 6/6."
        assert renderer.escape_latex(text) == text

    def test_escape_empty_string(self, renderer):
        assert renderer.escape_latex("") == ""

    def test_escape_none(self, renderer):
        assert renderer.escape_latex(None) == ""

    def test_escape_medical_text(self, renderer):
        text = "Dexamethasone 0.1% drops & Cyclopentolate 1%"
        result = renderer.escape_latex(text)
        assert r"0.1\%" in result
        assert r"\&" in result
        assert r"1\%" in result


class TestFormatBody:
    """Body text conversion to LaTeX."""

    def test_format_body_paragraphs(self, renderer):
        body = "First paragraph.\n\nSecond paragraph."
        result = renderer.format_body(body)
        assert "First paragraph." in result
        assert "Second paragraph." in result
        assert r"\vspace{10pt}" in result

    def test_format_body_bullets(self, renderer):
        body = "- item one\n- item two\n- item three"
        result = renderer.format_body(body)
        assert r"\begin{itemize}" in result
        assert r"\item item one" in result
        assert r"\item item two" in result
        assert r"\item item three" in result
        assert r"\end{itemize}" in result

    def test_format_body_mixed(self, renderer):
        body = (
            "The findings were as follows:\n\n"
            "- Right eye: normal\n"
            "- Left eye: uveitis\n\n"
            "I have commenced treatment."
        )
        result = renderer.format_body(body)
        assert "findings" in result
        assert r"\begin{itemize}" in result
        assert r"\item" in result
        assert r"\end{itemize}" in result
        assert "commenced treatment" in result

    def test_format_body_empty(self, renderer):
        assert renderer.format_body("") == ""

    def test_format_body_escapes_special_chars(self, renderer):
        body = "Drug: 50% concentration & saline"
        result = renderer.format_body(body)
        assert r"50\%" in result
        assert r"\&" in result

    def test_format_body_bold(self, renderer):
        body = "The patient has **significant** symptoms."
        result = renderer.format_body(body)
        assert r"\textbf{significant}" in result

    def test_format_body_italic(self, renderer):
        body = "Diagnosis: *probable* glaucoma."
        result = renderer.format_body(body)
        assert r"\textit{probable}" in result

    def test_format_body_bold_and_italic_same_line(self, renderer):
        body = "VA was **6/6** in the *right* eye."
        result = renderer.format_body(body)
        assert r"\textbf{6/6}" in result
        assert r"\textit{right}" in result

    def test_format_body_numbered_list(self, renderer):
        body = "1. First finding\n2. Second finding\n3. Third finding"
        result = renderer.format_body(body)
        assert r"\begin{enumerate}" in result
        assert r"\item First finding" in result
        assert r"\item Second finding" in result
        assert r"\item Third finding" in result
        assert r"\end{enumerate}" in result

    def test_format_body_numbered_list_with_bullets(self, renderer):
        body = (
            "Findings:\n\n"
            "1. Right eye normal\n"
            "2. Left eye abnormal\n\n"
            "Medications:\n\n"
            "- Dexamethasone\n"
            "- Cyclopentolate"
        )
        result = renderer.format_body(body)
        assert r"\begin{enumerate}" in result
        assert r"\end{enumerate}" in result
        assert r"\begin{itemize}" in result
        assert r"\end{itemize}" in result

    def test_format_body_bold_in_list_item(self, renderer):
        body = "- **Important**: take medication"
        result = renderer.format_body(body)
        assert r"\textbf{Important}" in result
        assert r"\item" in result

    def test_format_body_inline_formatting_with_special_chars(self, renderer):
        body = "Use **50%** concentration."
        result = renderer.format_body(body)
        assert r"\textbf{50\%}" in result

    def test_format_body_horizontal_rule(self, renderer):
        body = "Above the rule.\n\n---\n\nBelow the rule."
        result = renderer.format_body(body)
        assert r"\hrule" in result
        assert "Above the rule." in result
        assert "Below the rule." in result

    def test_format_body_long_horizontal_rule(self, renderer):
        body = "Before.\n\n-----\n\nAfter."
        result = renderer.format_body(body)
        assert r"\hrule" in result

    def test_format_body_heading(self, renderer):
        body = "## IOL Exchange Surgery\n\nSome text."
        result = renderer.format_body(body)
        assert r"\bfseries" in result
        assert "IOL Exchange Surgery" in result

    def test_format_body_bold_italic(self, renderer):
        body = "This is ***very important***."
        result = renderer.format_body(body)
        assert r"\textbf" in result or r"\textit" in result
        assert "very important" in result

    def test_format_body_table(self, renderer):
        body = "| Eye | VA |\n|-----|----|\n| Right | 6/6 |\n| Left | 6/9 |"
        result = renderer.format_body(body)
        assert r"\begin{tabular}" in result
        assert r"\end{tabular}" in result
        assert "Right" in result
        assert "6/6" in result

    def test_format_body_strikethrough(self, renderer):
        body = "The ~~old~~ new treatment."
        result = renderer.format_body(body)
        assert r"\sout{old}" in result


class TestBuildCCLine:
    """CC line construction."""

    def test_build_cc_line_excludes_current(self, renderer, sample_recipients):
        patient = sample_recipients[0]
        result = renderer.build_cc_line(sample_recipients, patient)
        assert "Mrs Jane Smith" not in result
        assert "Dr A Patel" in result
        assert "Hospital Records" in result

    def test_build_cc_line_with_practice(self, renderer, sample_recipients):
        gp = sample_recipients[1]
        result = renderer.build_cc_line(sample_recipients, gp)
        assert "Mrs Jane Smith" in result
        assert "Dr A Patel" not in result

    def test_build_cc_line_includes_practice_and_address(self, renderer, sample_recipients):
        hospital = sample_recipients[2]
        result = renderer.build_cc_line(sample_recipients, hospital)
        assert "Reigate Medical Centre" in result

    def test_build_cc_line_four_recipients(self, renderer):
        recipients = [
            Recipient(role="patient", source="database", name="Mrs Smith",
                      address=["1 High St"]),
            Recipient(role="gp", source="database", name="Dr Patel",
                      practice="Med Centre", address=["2 Low St"]),
            Recipient(role="optician", source="ad_hoc", name="Mr Jones",
                      practice="Eye Care", address=["3 Mid St"]),
            Recipient(role="hospital_records", source="implicit",
                      name="Hospital Records", address=[]),
        ]
        result = renderer.build_cc_line(recipients, recipients[0])
        assert "Dr Patel" in result
        assert "Mr Jones" in result
        assert "Hospital Records" in result
        assert "Mrs Smith" not in result


class TestFillTemplate:
    """Template filling and placeholder replacement."""

    def test_hospital_records_no_address_block(self, renderer, sender, sample_patient):
        hospital_rec = Recipient(
            role="hospital_records", source="implicit",
            name="Hospital Records", address=[],
        )
        result = renderer.fill_template(
            sender=sender, patient=sample_patient,
            recipient=hospital_rec, body="Test body.",
            cc_line="", is_patient_copy=False,
            include_address=False, letter_date="2026-03-03T09:00:00Z",
        )
        assert r"\vspace*{35mm}" not in result
        assert "\\begin{flushleft}" not in result or "Hospital Records" not in result.split("flushleft")[1] if "flushleft" in result else True

    def test_patient_copy_font_size(self, renderer, sender, sample_patient, sample_recipients):
        patient_rec = sample_recipients[0]
        result = renderer.fill_template(
            sender=sender, patient=sample_patient,
            recipient=patient_rec, body="Test.",
            cc_line="", is_patient_copy=True,
            include_address=True, letter_date="2026-03-03T09:00:00Z",
        )
        assert r"\fontsize{14}{19.6}" in result
        assert r"\selectfont" in result

    def test_professional_copy_font_size(self, renderer, sender, sample_patient, sample_recipients):
        gp_rec = sample_recipients[1]
        result = renderer.fill_template(
            sender=sender, patient=sample_patient,
            recipient=gp_rec, body="Test.",
            cc_line="", is_patient_copy=False,
            include_address=True, letter_date="2026-03-03T09:00:00Z",
        )
        assert r"\fontsize{14}" not in result

    def test_fill_template_all_placeholders_replaced(self, renderer, sender, sample_patient, sample_recipients):
        gp_rec = sample_recipients[1]
        cc = renderer.build_cc_line(sample_recipients, gp_rec)
        result = renderer.fill_template(
            sender=sender, patient=sample_patient,
            recipient=gp_rec, body="Clinical content here.",
            cc_line=cc, is_patient_copy=False,
            include_address=True, letter_date="2026-03-03T09:00:00Z",
        )
        import re
        placeholders = re.findall(r"<[A-Z_]+>", result)
        assert placeholders == [], f"Unfilled placeholders: {placeholders}"

    def test_re_line_includes_dob(self, renderer, sender, sample_patient, sample_recipients):
        result = renderer.fill_template(
            sender=sender, patient=sample_patient,
            recipient=sample_recipients[1], body="Test.",
            cc_line="", is_patient_copy=False,
            include_address=True, letter_date="2026-03-03T09:00:00Z",
        )
        assert "DOB" in result
        assert "12/03/1945" in result

    def test_sender_details_in_header(self, renderer, sender, sample_patient, sample_recipients):
        result = renderer.fill_template(
            sender=sender, patient=sample_patient,
            recipient=sample_recipients[0], body="Test.",
            cc_line="", is_patient_copy=True,
            include_address=True, letter_date="2026-03-03T09:00:00Z",
        )
        assert "Arblaster" in result
        assert "Consultant Ophthalmologist" in result
        assert "FRCOphth" in result
        assert "East Surrey Hospital" in result


class TestSalutation:
    """Salutation construction from patient title and name."""

    def test_salutation_with_title(self, renderer):
        patient = Patient(name="Marc Green", dob="1980-01-01", mrn="X123",
                          title="Mr")
        result = renderer._build_salutation(patient)
        assert result == "Mr Green"

    def test_salutation_without_title(self, renderer):
        patient = Patient(name="Marc Green", dob="1980-01-01", mrn="X123")
        result = renderer._build_salutation(patient)
        assert result == "Marc Green"

    def test_salutation_multi_word_surname(self, renderer):
        patient = Patient(name="Jane van der Berg", dob="1980-01-01",
                          mrn="X456", title="Mrs")
        result = renderer._build_salutation(patient)
        assert result == "Mrs Berg"

    def test_salutation_in_template(self, renderer, sender):
        patient = Patient(name="Marc Green", dob="1980-01-01", mrn="X123",
                          title="Mr")
        recipient = Recipient(role="gp", source="database", name="Dr Smith",
                              address=["1 High St"])
        result = renderer.fill_template(
            sender=sender, patient=patient,
            recipient=recipient, body="Test.",
            cc_line="", is_patient_copy=False,
            include_address=True, letter_date="2026-03-03T09:00:00Z",
        )
        assert "Mr Green" in result
        assert "Dear Marc Green" not in result


class TestCompileLatex:
    """Integration test: actual lualatex compilation."""

    @pytest.mark.skipif(
        not shutil.which("lualatex"),
        reason="lualatex not installed",
    )
    def test_compile_pdf(self, renderer, sender, sample_patient, sample_recipients, tmp_path):
        gp_rec = sample_recipients[1]
        cc = renderer.build_cc_line(sample_recipients, gp_rec)

        pdf_path = renderer.render_pdf(
            sender=sender,
            patient=sample_patient,
            recipient=gp_rec,
            body="Thank you for referring this patient.",
            all_recipients=sample_recipients,
            is_patient_copy=False,
            include_address=True,
            letter_date="2026-03-03T09:00:00Z",
            output_dir=tmp_path,
            output_filename="test_output.pdf",
        )

        assert pdf_path is not None
        assert pdf_path.exists()
        assert pdf_path.stat().st_size > 0
        assert pdf_path.name == "test_output.pdf"
