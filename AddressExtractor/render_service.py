#!/usr/bin/env python3
"""
Yiale Render Service

Watches .letters/drafts/ for letter drafts with status 'render_requested',
renders PDFs (one per recipient) and HTML, places hospital records in inject/,
and updates draft status to 'rendered'.

Follows the same watcher pattern as extraction_service.py.
"""

import json
import logging
import os
import re
import shutil
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

from letter_models import LetterDraft, LetterStatus, SenderConfig
from letter_renderer import LetterRenderer
from letter_html_renderer import HTMLRenderer

# Configuration
_default_icloud = os.path.expanduser(
    "~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents"
)
ICLOUD_CONTAINER = os.getenv("YIANA_DATA_DIR", _default_icloud)
LETTERS_DIR = os.getenv("LETTERS_DIR", os.path.join(ICLOUD_CONTAINER, ".letters"))

DRAFTS_DIR = os.path.join(LETTERS_DIR, "drafts")
RENDERED_DIR = os.path.join(LETTERS_DIR, "rendered")
INJECT_DIR = os.path.join(LETTERS_DIR, "inject")
UNMATCHED_DIR = os.path.join(LETTERS_DIR, "unmatched")
CONFIG_DIR = os.path.join(LETTERS_DIR, "config")

POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "30"))

TEMPLATE_PATH = os.getenv(
    "TEMPLATE_PATH",
    os.path.join(os.path.dirname(__file__), "letter_template_yiale.tex"),
)

# Health monitoring
HEALTH_DIR = os.path.join(
    os.path.expanduser("~/Library/Application Support"),
    "YianaRender", "health",
)

# Logging
log_level = os.getenv("LOG_LEVEL", "INFO")
logging.basicConfig(
    level=getattr(logging, log_level),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


def write_heartbeat(note: str = "scan"):
    """Write heartbeat JSON for external watchdog (atomic write)."""
    os.makedirs(HEALTH_DIR, exist_ok=True)
    payload = json.dumps({
        "timestamp": datetime.now().astimezone().isoformat(),
        "note": note,
    })
    tmp = os.path.join(HEALTH_DIR, "heartbeat.json.tmp")
    dst = os.path.join(HEALTH_DIR, "heartbeat.json")
    try:
        with open(tmp, "w") as f:
            f.write(payload)
        os.replace(tmp, dst)
    except OSError as e:
        logger.warning(f"Failed to write heartbeat: {e}")


def write_health_error(msg: str):
    """Record last error for external watchdog (atomic write)."""
    os.makedirs(HEALTH_DIR, exist_ok=True)
    payload = json.dumps({
        "timestamp": datetime.now().astimezone().isoformat(),
        "error": msg,
    })
    tmp = os.path.join(HEALTH_DIR, "last_error.json.tmp")
    dst = os.path.join(HEALTH_DIR, "last_error.json")
    try:
        with open(tmp, "w") as f:
            f.write(payload)
        os.replace(tmp, dst)
    except OSError as e:
        logger.warning(f"Failed to write health error: {e}")


def _sanitise_filename(name: str) -> str:
    """Remove or replace characters unsafe for filenames."""
    # Remove common prefixes (Mr, Mrs, Dr, etc.) but keep the name
    sanitised = re.sub(r"[^\w\s-]", "", name)
    sanitised = re.sub(r"\s+", "_", sanitised.strip())
    return sanitised


def _build_pdf_filename(patient_name: str, mrn: str,
                        recipient_role: str, recipient_name: str) -> str:
    """Build a PDF filename following the spec naming convention.

    Pattern: {Surname}_{First}_{MRN}_to_{recipient}.pdf
    or: {Surname}_{First}_{MRN}_patient_copy.pdf
    or: {Surname}_{First}_{MRN}_hospital_records.pdf
    """
    # Parse patient name: "Mrs Jane Smith" -> "Smith_Jane"
    parts = patient_name.split()
    # Strip titles
    titles = {"mr", "mrs", "ms", "miss", "dr", "prof", "professor"}
    name_parts = [p for p in parts if p.lower().rstrip(".") not in titles]
    if len(name_parts) >= 2:
        surname = name_parts[-1]
        first = name_parts[0]
    elif name_parts:
        surname = name_parts[0]
        first = ""
    else:
        surname = "Unknown"
        first = ""

    base = f"{_sanitise_filename(surname)}_{_sanitise_filename(first)}_{mrn}"

    if recipient_role == "patient":
        return f"{base}_patient_copy.pdf"
    elif recipient_role == "hospital_records":
        return f"{base}_hospital_records.pdf"
    else:
        return f"{base}_to_{_sanitise_filename(recipient_name)}.pdf"


class RenderService:
    """Watches for render-requested drafts and produces PDFs + HTML."""

    def __init__(self, letters_dir: Optional[str] = None):
        self.letters_dir = Path(letters_dir or LETTERS_DIR)
        self.drafts_dir = self.letters_dir / "drafts"
        self.rendered_dir = self.letters_dir / "rendered"
        self.inject_dir = self.letters_dir / "inject"
        self.unmatched_dir = self.letters_dir / "unmatched"
        self.config_dir = self.letters_dir / "config"

        self.renderer = LetterRenderer(Path(TEMPLATE_PATH))
        self.html_renderer = HTMLRenderer()

        # Ensure directories exist
        for d in [self.drafts_dir, self.rendered_dir, self.inject_dir,
                  self.unmatched_dir, self.config_dir]:
            d.mkdir(parents=True, exist_ok=True)

    def run(self):
        """Main loop: scan, render, sleep."""
        logger.info(f"Render service starting. Letters dir: {self.letters_dir}")
        logger.info(f"Poll interval: {POLL_INTERVAL}s")

        write_heartbeat("start")

        # Process any pending drafts on startup
        self.process_pending()

        tick = 0
        try:
            while True:
                time.sleep(1)
                tick += 1
                if tick >= POLL_INTERVAL:
                    self.process_pending()
                    write_heartbeat()
                    tick = 0
        except KeyboardInterrupt:
            logger.info("Render service stopping")

    def process_pending(self):
        """Scan for and process all render-requested drafts."""
        pending = self.scan_for_pending()
        for draft_path in pending:
            try:
                self.process_draft(draft_path)
            except Exception as e:
                logger.error(f"Failed to process {draft_path.name}: {e}")
                write_health_error(f"{draft_path.name}: {e}")

    def scan_for_pending(self) -> list[Path]:
        """Find all drafts with status=render_requested."""
        pending = []
        if not self.drafts_dir.exists():
            return pending

        for json_file in self.drafts_dir.glob("*.json"):
            try:
                with open(json_file, "r") as f:
                    data = json.load(f)
                if data.get("status") == "render_requested":
                    pending.append(json_file)
            except (json.JSONDecodeError, OSError) as e:
                logger.warning(f"Could not read {json_file.name}: {e}")

        return pending

    def process_draft(self, draft_path: Path):
        """Render a single draft: PDFs + HTML, inject, update status."""
        logger.info(f"Processing draft: {draft_path.name}")

        draft = LetterDraft.from_json(draft_path)

        # Load sender config
        sender_path = self.config_dir / "sender.json"
        if not sender_path.exists():
            raise FileNotFoundError(
                f"Sender config not found at {sender_path}. "
                "Create .letters/config/sender.json first."
            )
        sender = SenderConfig.from_json(sender_path)

        # Create output directory
        output_dir = self.rendered_dir / draft.letter_id
        output_dir.mkdir(parents=True, exist_ok=True)

        letter_date = draft.render_request or draft.modified
        hospital_records_pdf = None

        # Render one PDF per recipient
        for recipient in draft.recipients:
            is_patient_copy = recipient.role == "patient"
            include_address = recipient.role != "hospital_records" and bool(recipient.address)

            filename = _build_pdf_filename(
                draft.patient.name, draft.patient.mrn,
                recipient.role, recipient.name,
            )

            pdf_path = self.renderer.render_pdf(
                sender=sender,
                patient=draft.patient,
                recipient=recipient,
                body=draft.body,
                all_recipients=draft.recipients,
                is_patient_copy=is_patient_copy,
                include_address=include_address,
                letter_date=letter_date,
                output_dir=output_dir,
                output_filename=filename,
            )

            if pdf_path:
                logger.info(f"  Rendered: {filename}")
                if recipient.role == "hospital_records":
                    hospital_records_pdf = pdf_path
            else:
                logger.error(f"  Failed to render: {filename}")
                raise RuntimeError(f"PDF compilation failed for {filename}")

        # Render HTML
        html_content = self.html_renderer.render(
            sender=sender,
            patient=draft.patient,
            recipients=draft.recipients,
            body=draft.body,
            letter_date=letter_date,
        )

        # Build HTML filename to match PDF pattern
        parts = draft.patient.name.split()
        titles = {"mr", "mrs", "ms", "miss", "dr", "prof", "professor"}
        name_parts = [p for p in parts if p.lower().rstrip(".") not in titles]
        if len(name_parts) >= 2:
            html_base = f"{_sanitise_filename(name_parts[-1])}_{_sanitise_filename(name_parts[0])}_{draft.patient.mrn}"
        else:
            html_base = f"{_sanitise_filename(draft.patient.name)}_{draft.patient.mrn}"

        html_path = output_dir / f"{html_base}_email.html"
        with open(html_path, "w") as f:
            f.write(html_content)
        logger.info(f"  Rendered: {html_path.name}")

        # Place hospital records PDF in inject directory
        if hospital_records_pdf and hospital_records_pdf.exists():
            inject_filename = f"{draft.yiana_target}_{draft.letter_id}.pdf"
            inject_path = self.inject_dir / inject_filename
            shutil.copy2(hospital_records_pdf, inject_path)
            logger.info(f"  Injected: {inject_filename}")

        # Update draft status to rendered
        draft.status = LetterStatus.RENDERED
        draft.modified = datetime.now().astimezone().isoformat()
        draft.to_json(draft_path)
        logger.info(f"  Status updated to rendered")


def main():
    """Entry point for the render service."""
    import argparse

    parser = argparse.ArgumentParser(description="Yiale Render Service")
    parser.add_argument(
        "--letters-dir",
        help="Override .letters/ directory path",
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="Process pending drafts once and exit (no watch loop)",
    )

    args = parser.parse_args()

    service = RenderService(letters_dir=args.letters_dir)

    if args.once:
        service.process_pending()
    else:
        service.run()


if __name__ == "__main__":
    main()
