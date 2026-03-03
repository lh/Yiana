"""Tests for letter_models.py — schema validation, serialisation, round-trips."""

import json

import pytest

from letter_models import LetterDraft, LetterStatus, SenderConfig


class TestLetterDraftLoading:
    """Load each sample JSON and verify all fields."""

    def test_load_simple_letter(self, simple_draft):
        assert simple_draft.letter_id == "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        assert simple_draft.status == LetterStatus.RENDER_REQUESTED
        assert simple_draft.yiana_target == "Smith_Jane_120345"
        assert simple_draft.patient.name == "Mrs Jane Smith"
        assert simple_draft.patient.dob == "1945-03-12"
        assert simple_draft.patient.mrn == "H123456"
        assert len(simple_draft.patient.address) == 4
        assert len(simple_draft.recipients) == 3
        assert simple_draft.recipients[0].role == "patient"
        assert simple_draft.recipients[1].role == "gp"
        assert simple_draft.recipients[1].practice == "Reigate Medical Centre"
        assert simple_draft.recipients[2].role == "hospital_records"
        assert simple_draft.recipients[2].address == []
        assert "epiretinal membrane" in simple_draft.body
        assert simple_draft.render_request is not None

    def test_load_multi_recipient(self, multi_draft):
        assert multi_draft.patient.name == "Mr Robert Williams"
        assert len(multi_draft.recipients) == 4
        roles = [r.role for r in multi_draft.recipients]
        assert roles == ["patient", "gp", "optician", "hospital_records"]
        assert multi_draft.recipients[2].practice == "Horley Eyecare"
        assert multi_draft.recipients[2].source == "ad_hoc"
        assert len(multi_draft.patient.phones) == 2

    def test_load_bullet_list(self, bullet_draft):
        assert bullet_draft.status == LetterStatus.DRAFT
        assert bullet_draft.render_request is None
        assert "- Right eye:" in bullet_draft.body
        assert "- Dexamethasone" in bullet_draft.body


class TestLetterDraftRoundTrip:
    """Load, serialise, reload, verify equality."""

    def test_round_trip_simple(self, simple_draft, tmp_path):
        out_path = tmp_path / "round_trip.json"
        simple_draft.to_json(out_path)
        reloaded = LetterDraft.from_json(out_path)

        assert reloaded.letter_id == simple_draft.letter_id
        assert reloaded.status == simple_draft.status
        assert reloaded.patient.name == simple_draft.patient.name
        assert reloaded.patient.dob == simple_draft.patient.dob
        assert reloaded.patient.mrn == simple_draft.patient.mrn
        assert reloaded.patient.address == simple_draft.patient.address
        assert len(reloaded.recipients) == len(simple_draft.recipients)
        assert reloaded.body == simple_draft.body
        assert reloaded.render_request == simple_draft.render_request

    def test_round_trip_multi(self, multi_draft, tmp_path):
        out_path = tmp_path / "round_trip_multi.json"
        multi_draft.to_json(out_path)
        reloaded = LetterDraft.from_json(out_path)

        for orig, loaded in zip(multi_draft.recipients, reloaded.recipients):
            assert orig.role == loaded.role
            assert orig.name == loaded.name
            assert orig.practice == loaded.practice
            assert orig.address == loaded.address

    def test_round_trip_preserves_status_as_string(self, simple_draft, tmp_path):
        out_path = tmp_path / "status_check.json"
        simple_draft.to_json(out_path)

        with open(out_path) as f:
            raw = json.load(f)
        assert raw["status"] == "render_requested"
        assert isinstance(raw["status"], str)


class TestLetterDraftValidation:
    """Reject invalid JSON."""

    def test_missing_required_field_letter_id(self, tmp_path):
        data = {
            "created": "2026-01-01T00:00:00Z",
            "modified": "2026-01-01T00:00:00Z",
            "status": "draft",
            "yiana_target": "test",
            "patient": {"name": "Test", "dob": "2000-01-01", "mrn": "X1"},
            "recipients": [],
            "body": "test",
        }
        path = tmp_path / "bad.json"
        with open(path, "w") as f:
            json.dump(data, f)

        with pytest.raises(KeyError):
            LetterDraft.from_json(path)

    def test_invalid_status_value(self, tmp_path):
        data = {
            "letter_id": "test-id",
            "created": "2026-01-01T00:00:00Z",
            "modified": "2026-01-01T00:00:00Z",
            "status": "invalid_status",
            "yiana_target": "test",
            "patient": {"name": "Test", "dob": "2000-01-01", "mrn": "X1"},
            "recipients": [],
            "body": "test",
        }
        path = tmp_path / "bad_status.json"
        with open(path, "w") as f:
            json.dump(data, f)

        with pytest.raises(ValueError):
            LetterDraft.from_json(path)

    def test_missing_patient_name(self, tmp_path):
        data = {
            "letter_id": "test-id",
            "created": "2026-01-01T00:00:00Z",
            "modified": "2026-01-01T00:00:00Z",
            "status": "draft",
            "yiana_target": "test",
            "patient": {"dob": "2000-01-01", "mrn": "X1"},
            "recipients": [],
            "body": "test",
        }
        path = tmp_path / "bad_patient.json"
        with open(path, "w") as f:
            json.dump(data, f)

        with pytest.raises(KeyError):
            LetterDraft.from_json(path)


class TestSenderConfig:
    """Verify sender.json loading."""

    def test_load_sender(self, sender):
        assert sender.name == "Mr L Arblaster"
        assert sender.credentials == "FRCOphth"
        assert sender.role == "Consultant Ophthalmologist"
        assert sender.department == "Ophthalmology Department"
        assert sender.hospital == "East Surrey Hospital"
        assert len(sender.address) == 4
        assert sender.phone == "01737 768511"
        assert sender.email == "l.arblaster@nhs.net"
        assert sender.secretary is not None
        assert sender.secretary.name == "Mrs J Davies"
        assert "ext 1234" in sender.secretary.phone

    def test_sender_round_trip(self, sender, tmp_path):
        out_path = tmp_path / "sender_rt.json"
        sender.to_json(out_path)
        reloaded = SenderConfig.from_json(out_path)
        assert reloaded.name == sender.name
        assert reloaded.secretary.email == sender.secretary.email
