"""Shared utilities for admin route sub-modules (Issue 15)."""
from __future__ import annotations

import json
import threading
from pathlib import Path
from typing import Any

from sqlalchemy.orm import Session

from .models import AuditLog, User

# ── Constants ─────────────────────────────────────────────────────────────────
ALLOWED_SEED_TARGETS = {
    "healthMonitor",
    "smartHouse",
    "analytics",
    "practiceMode",
    "translationHistory",
}
DEMO_GLOVE_NAME = "INTELLIGLOVE DEMO"
DEMO_GLOVE_HARDWARE_ID = "INTELLIGLOVE-DEMO-001"

# ── Audit helper ──────────────────────────────────────────────────────────────

def _audit(
    db: Session,
    admin: User,
    action: str,
    *,
    target_type: str | None = None,
    target_id: str | None = None,
    details: dict[str, Any] | None = None,
) -> None:
    db.add(
        AuditLog(
            actor_user_id=admin.id,
            action=action,
            target_type=target_type,
            target_id=target_id,
            details=details or {},
        )
    )


# ── Thread-safe atomic JSON append (Issue 2) ─────────────────────────────────
_json_file_locks: dict[str, threading.Lock] = {}
_json_file_locks_guard = threading.Lock()


def _get_json_lock(path: Path) -> threading.Lock:
    key = str(path.resolve())
    with _json_file_locks_guard:
        if key not in _json_file_locks:
            _json_file_locks[key] = threading.Lock()
        return _json_file_locks[key]


def append_to_session_json(json_path: Path, entry: dict) -> None:
    """Atomically append an entry to the per-session JSON array."""
    lock = _get_json_lock(json_path)
    with lock:
        try:
            raw = json_path.read_text(encoding="utf-8") if json_path.exists() else "[]"
            entries: list = json.loads(raw)
            if not isinstance(entries, list):
                entries = []
        except Exception:
            entries = []
        entries.append(entry)
        tmp = json_path.with_suffix(".tmp")
        tmp.write_text(json.dumps(entries, ensure_ascii=False), encoding="utf-8")
        tmp.replace(json_path)
