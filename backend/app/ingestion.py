"""
Translation ingestion service — Phase 2 (§4.3, §7).

Responsibilities:
  - WebSocket hub: maintains open WS connections keyed by firebase_uid.
  - Per-session JSON file watcher: polls TRANSLATION_JSON_DIR/{session_id}.json
    at ~1 s intervals (configurable via TRANSLATION_POLL_INTERVAL), detects
    newly appended entries, inserts them into translation_history, and pushes
    the latest entry to the matching WebSocket subscriber.
  - Watcher lifecycle: starts on POST /sessions/start, stops on
    POST /sessions/{id}/stop or when the system is toggled off.
  - System-off guard: when system_status = 'off' the ingestion watcher
    pauses (stops processing new entries) without losing any file content.
"""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

from fastapi import WebSocket

from .models import AdminConfig, TranslationHistory, TranslationSession, User

log = logging.getLogger("intelliglove.ingestion")


# ─────────────────────────────────────────────────────────────────────────────
# WebSocket hub
# ─────────────────────────────────────────────────────────────────────────────

class WebSocketHub:
    """Keeps track of one active WS connection per firebase_uid."""

    def __init__(self) -> None:
        self._connections: dict[str, WebSocket] = {}

    async def connect(self, uid: str, websocket: WebSocket) -> None:
        await websocket.accept()
        old = self._connections.pop(uid, None)
        if old is not None:
            try:
                await old.close(code=1001)
            except Exception:
                pass
        self._connections[uid] = websocket
        log.info("WS connected uid=%s total=%d", uid, len(self._connections))

    async def register(self, uid: str, websocket: WebSocket) -> None:
        """Register an already-accepted WebSocket (e.g. after an auth handshake)."""
        old = self._connections.pop(uid, None)
        if old is not None:
            try:
                await old.close(code=1001)
            except Exception:
                pass
        self._connections[uid] = websocket
        log.info("WS registered uid=%s total=%d", uid, len(self._connections))

    def disconnect(self, uid: str) -> None:
        self._connections.pop(uid, None)
        log.info("WS disconnected uid=%s remaining=%d", uid, len(self._connections))

    async def send(self, uid: str, payload: dict[str, Any]) -> bool:
        """Send a JSON payload to the subscriber for uid.  Returns True if sent."""
        ws = self._connections.get(uid)
        if ws is None:
            return False
        try:
            await ws.send_json(payload)
            return True
        except Exception as exc:
            log.warning("WS send failed uid=%s: %s", uid, exc)
            self._connections.pop(uid, None)
            return False


# Singleton used by the whole application.
ws_hub = WebSocketHub()


# ─────────────────────────────────────────────────────────────────────────────
# Per-session file watcher
# ─────────────────────────────────────────────────────────────────────────────

class SessionWatcher:
    """
    Polls TRANSLATION_JSON_DIR/{session_id}.json for newly appended entries
    (§7.5) and drives the WebSocket hub + database inserts.

    The watcher runs as an asyncio Task.  Call start() after the session row
    is committed and the JSON file has been created.  Call stop() when the
    session ends.
    """

    def __init__(
        self,
        *,
        session_db_id: Any,      # UUID of sessions.id
        session_public_id: str,  # sessions.session_id (human-readable)
        user_db_id: Any,         # UUID of users.id
        firebase_uid: str,
        json_path: Path,
        poll_interval: float,
        session_factory: Any,    # SQLAlchemy sessionmaker
    ) -> None:
        self._session_db_id = session_db_id
        self._session_public_id = session_public_id
        self._user_db_id = user_db_id
        self._firebase_uid = firebase_uid
        self._json_path = json_path
        self._poll_interval = poll_interval
        self._session_factory = session_factory
        self._processed = 0          # how many entries have been ingested so far
        self._task: asyncio.Task | None = None
        self._stop_event = asyncio.Event()

    # ── lifecycle ─────────────────────────────────────────────────────────────

    def start(self) -> None:
        if self._task is None or self._task.done():
            self._stop_event.clear()
            try:
                self._task = asyncio.create_task(
                    self._run(), name=f"watcher-{self._session_public_id}"
                )
            except RuntimeError:
                # No running event loop (e.g. sync test environment).
                # Watcher will not run — callers must use the async test path.
                log.debug(
                    "Watcher not started (no event loop) session=%s",
                    self._session_public_id,
                )

    def stop(self) -> None:
        self._stop_event.set()
        if self._task is not None:
            self._task.cancel()

    # ── main loop ─────────────────────────────────────────────────────────────

    async def _run(self) -> None:
        log.info(
            "Watcher started session=%s uid=%s path=%s",
            self._session_public_id,
            self._firebase_uid,
            self._json_path,
        )
        try:
            while not self._stop_event.is_set():
                await self._poll()
                try:
                    await asyncio.wait_for(
                        asyncio.shield(self._stop_event.wait()),
                        timeout=self._poll_interval,
                    )
                except asyncio.TimeoutError:
                    pass  # normal — keep polling
        except asyncio.CancelledError:
            pass
        finally:
            log.info("Watcher stopped session=%s", self._session_public_id)

    async def _poll(self) -> None:
        """Read the JSON file, process new entries if system is 'on'."""
        if not self._json_path.exists():
            return

        # ── check system status ───────────────────────────────────────────────
        db = self._session_factory()
        try:
            from sqlalchemy import select as sa_select
            config = db.scalar(
                sa_select(AdminConfig).where(AdminConfig.singleton_key == "default")
            )
            if config is not None and config.system_status != "on":
                return  # system off — pause, don't consume entries (§5.2)
        finally:
            db.close()

        # ── read JSON file ────────────────────────────────────────────────────
        try:
            raw = self._json_path.read_text(encoding="utf-8")
            entries: list[dict[str, Any]] = json.loads(raw)
        except Exception as exc:
            log.warning("Watcher cannot read %s: %s", self._json_path, exc)
            return

        if not isinstance(entries, list):
            log.warning("Watcher: %s is not a JSON array", self._json_path)
            return

        new_entries = entries[self._processed:]
        if not new_entries:
            return

        # ── insert new rows ───────────────────────────────────────────────────
        db = self._session_factory()
        try:
            inserted: list[TranslationHistory] = []
            for entry in new_entries:
                text = str(entry.get("text") or "").strip()
                ts_raw = entry.get("timestamp") or ""
                try:
                    ts = datetime.fromisoformat(
                        ts_raw.replace("Z", "+00:00")
                    )
                except (ValueError, TypeError):
                    ts = datetime.now(timezone.utc)

                row = TranslationHistory(
                    entry_id=f"trn_{uuid4().hex}",
                    session_id=self._session_db_id,
                    user_id=self._user_db_id,
                    timestamp=ts,
                    raw_input={},           # §3.4 note: null/empty this phase
                    translated_text=text,
                    source="live",
                )
                db.add(row)
                inserted.append(row)
            db.commit()
            for row in inserted:
                db.refresh(row)
            self._processed += len(new_entries)
        except Exception as exc:
            log.error("Watcher DB insert failed session=%s: %s", self._session_public_id, exc)
            db.rollback()
            return
        finally:
            db.close()

        # ── push latest entry over WebSocket (§7.5) ───────────────────────────
        # Only the most-recent of the newly found entries is pushed to the live
        # display — the spec says the screen shows only the latest entry.
        latest = inserted[-1]
        await ws_hub.send(
            self._firebase_uid,
            {
                "type": "translation",
                "sessionId": self._session_public_id,
                "entry": {
                    "entryId": latest.entry_id,
                    "translatedText": latest.translated_text,
                    "timestamp": latest.timestamp.isoformat(),
                    "confidence": latest.confidence,   # null this phase; Flutter defaults to 0
                    "source": latest.source,
                },
            },
        )
        log.debug(
            "Watcher ingested %d new entries session=%s",
            len(inserted),
            self._session_public_id,
        )


# ─────────────────────────────────────────────────────────────────────────────
# Ingestion manager (one instance per app lifetime)
# ─────────────────────────────────────────────────────────────────────────────

class IngestionManager:
    """
    Owns all running SessionWatchers.  One SessionWatcher per active session.
    """

    def __init__(self) -> None:
        self._watchers: dict[str, SessionWatcher] = {}  # session_public_id → watcher

    def start_session(
        self,
        *,
        session_db_id: Any,
        session_public_id: str,
        user_db_id: Any,
        firebase_uid: str,
        json_path: Path,
        poll_interval: float,
        session_factory: Any,
    ) -> None:
        self.stop_session(session_public_id)  # safety: shouldn't be running
        watcher = SessionWatcher(
            session_db_id=session_db_id,
            session_public_id=session_public_id,
            user_db_id=user_db_id,
            firebase_uid=firebase_uid,
            json_path=json_path,
            poll_interval=poll_interval,
            session_factory=session_factory,
        )
        self._watchers[session_public_id] = watcher
        watcher.start()
        log.info("IngestionManager started watcher session=%s", session_public_id)

    def stop_session(self, session_public_id: str) -> None:
        watcher = self._watchers.pop(session_public_id, None)
        if watcher is not None:
            watcher.stop()
            log.info("IngestionManager stopped watcher session=%s", session_public_id)

    def has_session(self, session_public_id: str) -> bool:
        """Return True if a live watcher is running for this session."""
        return session_public_id in self._watchers

    def stop_all(self) -> None:
        for watcher in list(self._watchers.values()):
            watcher.stop()
        self._watchers.clear()


# Singleton used by the whole application.
ingestion_manager = IngestionManager()
