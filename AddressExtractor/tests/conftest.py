"""Shared fixtures for Yiale render service tests."""

import json
import shutil
from pathlib import Path

import pytest

from letter_models import (
    LetterDraft, LetterStatus, Patient, Recipient, SenderConfig,
)

SAMPLE_DIR = Path(__file__).parent.parent / "sample_drafts"


@pytest.fixture
def sample_dir():
    return SAMPLE_DIR


@pytest.fixture
def sender_path():
    return SAMPLE_DIR / "sender.json"


@pytest.fixture
def simple_letter_path():
    return SAMPLE_DIR / "simple_letter.json"


@pytest.fixture
def multi_recipient_path():
    return SAMPLE_DIR / "multi_recipient.json"


@pytest.fixture
def bullet_list_path():
    return SAMPLE_DIR / "bullet_list.json"


@pytest.fixture
def sender(sender_path):
    return SenderConfig.from_json(sender_path)


@pytest.fixture
def simple_draft(simple_letter_path):
    return LetterDraft.from_json(simple_letter_path)


@pytest.fixture
def multi_draft(multi_recipient_path):
    return LetterDraft.from_json(multi_recipient_path)


@pytest.fixture
def bullet_draft(bullet_list_path):
    return LetterDraft.from_json(bullet_list_path)


@pytest.fixture
def template_path():
    return Path(__file__).parent.parent / "letter_template_yiale.tex"


@pytest.fixture
def tmp_letters_dir(tmp_path):
    """Create a temporary .letters/ directory structure."""
    letters_dir = tmp_path / ".letters"
    (letters_dir / "drafts").mkdir(parents=True)
    (letters_dir / "rendered").mkdir(parents=True)
    (letters_dir / "inject").mkdir(parents=True)
    (letters_dir / "unmatched").mkdir(parents=True)
    config_dir = letters_dir / "config"
    config_dir.mkdir(parents=True)

    # Copy sender config
    shutil.copy2(SAMPLE_DIR / "sender.json", config_dir / "sender.json")

    return letters_dir


@pytest.fixture
def sample_patient():
    return Patient(
        name="Mrs Jane Smith",
        dob="1945-03-12",
        mrn="H123456",
        address=["14 Oak Lane", "Reigate", "Surrey", "RH2 7AA"],
        phones=["01737 123456"],
    )


@pytest.fixture
def sample_recipients():
    return [
        Recipient(
            role="patient",
            source="database",
            name="Mrs Jane Smith",
            address=["14 Oak Lane", "Reigate", "Surrey", "RH2 7AA"],
        ),
        Recipient(
            role="gp",
            source="database",
            name="Dr A Patel",
            practice="Reigate Medical Centre",
            address=["12 High Street", "Reigate", "Surrey", "RH2 9AE"],
        ),
        Recipient(
            role="hospital_records",
            source="implicit",
            name="Hospital Records",
            address=[],
        ),
    ]
