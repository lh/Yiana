"""Tests for render_service.py — watcher logic, status transitions, file placement."""

import json
import shutil
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

from letter_models import LetterDraft, LetterStatus
from render_service import RenderService, _build_pdf_filename


SAMPLE_DIR = Path(__file__).parent.parent / "sample_drafts"


def _place_draft(letters_dir: Path, sample_name: str) -> Path:
    """Copy a sample draft into the drafts directory."""
    src = SAMPLE_DIR / sample_name
    dst = letters_dir / "drafts" / sample_name
    shutil.copy2(src, dst)
    return dst


class TestScanForPending:
    """Draft scanning logic."""

    def test_scan_finds_render_requested(self, tmp_letters_dir):
        _place_draft(tmp_letters_dir, "simple_letter.json")
        service = RenderService(letters_dir=str(tmp_letters_dir))
        pending = service.scan_for_pending()
        assert len(pending) == 1
        assert pending[0].name == "simple_letter.json"

    def test_scan_skips_draft_status(self, tmp_letters_dir):
        _place_draft(tmp_letters_dir, "bullet_list.json")
        service = RenderService(letters_dir=str(tmp_letters_dir))
        pending = service.scan_for_pending()
        assert len(pending) == 0

    def test_scan_skips_rendered_status(self, tmp_letters_dir):
        draft_path = _place_draft(tmp_letters_dir, "simple_letter.json")
        # Manually set status to rendered
        with open(draft_path) as f:
            data = json.load(f)
        data["status"] = "rendered"
        with open(draft_path, "w") as f:
            json.dump(data, f)

        service = RenderService(letters_dir=str(tmp_letters_dir))
        pending = service.scan_for_pending()
        assert len(pending) == 0

    def test_scan_empty_directory(self, tmp_letters_dir):
        service = RenderService(letters_dir=str(tmp_letters_dir))
        pending = service.scan_for_pending()
        assert len(pending) == 0

    def test_scan_handles_corrupt_json(self, tmp_letters_dir):
        bad_file = tmp_letters_dir / "drafts" / "corrupt.json"
        bad_file.write_text("not valid json {{{")
        service = RenderService(letters_dir=str(tmp_letters_dir))
        pending = service.scan_for_pending()
        assert len(pending) == 0


class TestRenderOutput:
    """Rendering output: directories, files, status updates."""

    @pytest.fixture
    def mock_renderer(self):
        """Patch lualatex compilation to produce a dummy PDF."""
        with patch("letter_renderer.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            yield mock_run

    def _mock_compile(self, service):
        """Replace compile_latex with a method that creates a dummy PDF."""
        original_compile = service.renderer.compile_latex

        def fake_compile(tex_content, output_dir, output_filename):
            output_dir.mkdir(parents=True, exist_ok=True)
            pdf_path = output_dir / output_filename
            pdf_path.write_bytes(b"%PDF-1.4 fake content")
            return pdf_path

        service.renderer.compile_latex = fake_compile

    def test_render_creates_output_directory(self, tmp_letters_dir):
        _place_draft(tmp_letters_dir, "simple_letter.json")
        service = RenderService(letters_dir=str(tmp_letters_dir))
        self._mock_compile(service)

        service.process_pending()

        letter_id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        output_dir = tmp_letters_dir / "rendered" / letter_id
        assert output_dir.exists()
        assert output_dir.is_dir()

    def test_render_produces_all_pdfs(self, tmp_letters_dir):
        _place_draft(tmp_letters_dir, "simple_letter.json")
        service = RenderService(letters_dir=str(tmp_letters_dir))
        self._mock_compile(service)

        service.process_pending()

        letter_id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        output_dir = tmp_letters_dir / "rendered" / letter_id
        pdfs = list(output_dir.glob("*.pdf"))
        # simple_letter has 3 recipients: patient, gp, hospital_records
        assert len(pdfs) == 3

    def test_render_produces_html(self, tmp_letters_dir):
        _place_draft(tmp_letters_dir, "simple_letter.json")
        service = RenderService(letters_dir=str(tmp_letters_dir))
        self._mock_compile(service)

        service.process_pending()

        letter_id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        output_dir = tmp_letters_dir / "rendered" / letter_id
        htmls = list(output_dir.glob("*.html"))
        assert len(htmls) == 1
        assert "email" in htmls[0].name

    def test_render_places_inject_file(self, tmp_letters_dir):
        _place_draft(tmp_letters_dir, "simple_letter.json")
        service = RenderService(letters_dir=str(tmp_letters_dir))
        self._mock_compile(service)

        service.process_pending()

        inject_files = list((tmp_letters_dir / "inject").glob("*.pdf"))
        assert len(inject_files) == 1
        assert "Smith_Jane_120345" in inject_files[0].name
        assert "a1b2c3d4-e5f6-7890-abcd-ef1234567890" in inject_files[0].name

    def test_render_updates_status(self, tmp_letters_dir):
        draft_path = _place_draft(tmp_letters_dir, "simple_letter.json")
        service = RenderService(letters_dir=str(tmp_letters_dir))
        self._mock_compile(service)

        service.process_pending()

        updated = LetterDraft.from_json(draft_path)
        assert updated.status == LetterStatus.RENDERED

    def test_render_idempotent(self, tmp_letters_dir):
        _place_draft(tmp_letters_dir, "simple_letter.json")
        service = RenderService(letters_dir=str(tmp_letters_dir))
        self._mock_compile(service)

        # First render
        service.process_pending()

        # Record state after first render
        letter_id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        output_dir = tmp_letters_dir / "rendered" / letter_id
        files_after_first = set(f.name for f in output_dir.iterdir())

        # Second scan should find nothing (status is now 'rendered')
        pending = service.scan_for_pending()
        assert len(pending) == 0

    def test_render_multi_recipient(self, tmp_letters_dir):
        _place_draft(tmp_letters_dir, "multi_recipient.json")
        service = RenderService(letters_dir=str(tmp_letters_dir))
        self._mock_compile(service)

        service.process_pending()

        letter_id = "b2c3d4e5-f6a7-8901-bcde-f12345678901"
        output_dir = tmp_letters_dir / "rendered" / letter_id
        pdfs = list(output_dir.glob("*.pdf"))
        # 4 recipients: patient, gp, optician, hospital_records
        assert len(pdfs) == 4


class TestPDFFilenames:
    """PDF filename conventions."""

    def test_patient_copy_filename(self):
        name = _build_pdf_filename("Mrs Jane Smith", "H123456", "patient", "Mrs Jane Smith")
        assert name == "Smith_Jane_H123456_patient_copy.pdf"

    def test_gp_copy_filename(self):
        name = _build_pdf_filename("Mrs Jane Smith", "H123456", "gp", "Dr A Patel")
        assert name == "Smith_Jane_H123456_to_Dr_A_Patel.pdf"

    def test_hospital_records_filename(self):
        name = _build_pdf_filename("Mrs Jane Smith", "H123456", "hospital_records", "Hospital Records")
        assert name == "Smith_Jane_H123456_hospital_records.pdf"

    def test_filename_with_title(self):
        name = _build_pdf_filename("Mr Robert Williams", "H987654", "patient", "Mr Robert Williams")
        assert name == "Williams_Robert_H987654_patient_copy.pdf"
