"""
Letter draft and sender configuration models for the Yiale render service.

Defines the JSON schema for letter drafts and sender configuration as Python
dataclasses. All JSON uses snake_case keys.
"""

import json
import uuid
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Optional


class LetterStatus(str, Enum):
    DRAFT = "draft"
    RENDER_REQUESTED = "render_requested"
    RENDERED = "rendered"


@dataclass
class Patient:
    name: str
    dob: str
    mrn: str
    address: list[str] = field(default_factory=list)
    phones: list[str] = field(default_factory=list)
    title: Optional[str] = None


@dataclass
class Recipient:
    role: str
    source: str
    name: str
    practice: Optional[str] = None
    address: list[str] = field(default_factory=list)


@dataclass
class LetterDraft:
    letter_id: str
    created: str
    modified: str
    status: LetterStatus
    yiana_target: str
    patient: Patient
    recipients: list[Recipient]
    body: str
    render_request: Optional[str] = None

    @classmethod
    def from_dict(cls, data: dict) -> "LetterDraft":
        patient_data = data["patient"]
        patient = Patient(
            name=patient_data["name"],
            dob=patient_data["dob"],
            mrn=patient_data["mrn"],
            address=patient_data.get("address", []),
            phones=patient_data.get("phones", []),
            title=patient_data.get("title"),
        )

        recipients = []
        for r in data["recipients"]:
            recipients.append(Recipient(
                role=r["role"],
                source=r["source"],
                name=r["name"],
                practice=r.get("practice"),
                address=r.get("address", []),
            ))

        status = LetterStatus(data["status"])

        return cls(
            letter_id=data["letter_id"],
            created=data["created"],
            modified=data["modified"],
            status=status,
            yiana_target=data["yiana_target"],
            patient=patient,
            recipients=recipients,
            body=data["body"],
            render_request=data.get("render_request"),
        )

    @classmethod
    def from_json(cls, path: Path) -> "LetterDraft":
        with open(path, "r") as f:
            data = json.load(f)
        return cls.from_dict(data)

    def to_dict(self) -> dict:
        d = asdict(self)
        d["status"] = self.status.value
        return d

    def to_json(self, path: Path) -> None:
        tmp = path.with_suffix(".json.tmp")
        with open(tmp, "w") as f:
            json.dump(self.to_dict(), f, indent=2)
        tmp.replace(path)

    @classmethod
    def new(cls, yiana_target: str, patient: Patient,
            recipients: list[Recipient], body: str) -> "LetterDraft":
        now = datetime.now(timezone.utc).isoformat()
        return cls(
            letter_id=str(uuid.uuid4()),
            created=now,
            modified=now,
            status=LetterStatus.DRAFT,
            yiana_target=yiana_target,
            patient=patient,
            recipients=recipients,
            body=body,
        )


@dataclass
class Secretary:
    name: str
    phone: str
    email: str


@dataclass
class SenderConfig:
    name: str
    credentials: str
    role: str
    department: str
    hospital: str
    address: list[str] = field(default_factory=list)
    phone: str = ""
    email: str = ""
    secretary: Optional[Secretary] = None

    @classmethod
    def from_dict(cls, data: dict) -> "SenderConfig":
        secretary = None
        if data.get("secretary"):
            s = data["secretary"]
            secretary = Secretary(
                name=s["name"],
                phone=s["phone"],
                email=s["email"],
            )
        return cls(
            name=data["name"],
            credentials=data["credentials"],
            role=data["role"],
            department=data["department"],
            hospital=data["hospital"],
            address=data.get("address", []),
            phone=data.get("phone", ""),
            email=data.get("email", ""),
            secretary=secretary,
        )

    @classmethod
    def from_json(cls, path: Path) -> "SenderConfig":
        with open(path, "r") as f:
            data = json.load(f)
        return cls.from_dict(data)

    def to_dict(self) -> dict:
        return asdict(self)

    def to_json(self, path: Path) -> None:
        tmp = path.with_suffix(".json.tmp")
        with open(tmp, "w") as f:
            json.dump(self.to_dict(), f, indent=2)
        tmp.replace(path)
