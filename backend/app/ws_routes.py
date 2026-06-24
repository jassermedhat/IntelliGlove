"""
WebSocket endpoint for the live translation feed (§3.4, §8).

  WS /ws/translation/{uid}

Authentication protocol:
  1. Client connects.
  2. Server sends {"type": "ready"} to prompt authentication.
  3. Client sends its Firebase ID token as a plain-text message within 10 s.
  4. Server verifies the token and checks that the UID matches the path parameter.
  5. On success, connection is kept open; server pushes translation entries as
     they are ingested from the per-session JSON file.
  6. Client may send any text (e.g. "ping") to keep the connection alive;
     the server responds with {"type": "pong"}.
"""

from __future__ import annotations

import asyncio
import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from .ingestion import ws_hub
from .development_auth import verify_identity_token

log = logging.getLogger("intelliglove.ws")

router = APIRouter(tags=["websocket"])


@router.websocket("/ws/translation/{uid}")
async def ws_translation(uid: str, websocket: WebSocket) -> None:
    """
    Live WebSocket relay (§3.4, §8).

    The Flutter app opens this connection immediately after POST /sessions/start
    succeeds.  The backend's per-session ingestion watcher pushes new
    translation entries here as they are detected in the JSON file.

    Close codes used:
      4401 — no token received within the handshake window, or invalid token
      4403 — token UID does not match the requested uid path parameter
    """
    await websocket.accept()

    # ── Step 1: prompt the client ─────────────────────────────────────────────
    await websocket.send_json({"type": "ready"})

    # ── Step 2: receive Firebase ID token (within 10 s) ───────────────────────
    try:
        token_msg: str = await asyncio.wait_for(websocket.receive_text(), timeout=10.0)
    except (asyncio.TimeoutError, WebSocketDisconnect, Exception):
        await websocket.close(code=4401)
        return

    # ── Step 3: verify token ──────────────────────────────────────────────────
    try:
        claims = verify_identity_token(websocket.app, token_msg.strip())
        token_uid = str(claims.get("uid") or claims.get("sub") or "").strip()
    except Exception as exc:
        log.debug("WS token verification failed uid=%s: %s", uid, exc)
        await websocket.close(code=4401)
        return

    if not token_uid or token_uid != uid:
        log.debug("WS UID mismatch path=%s token=%s", uid, token_uid)
        await websocket.close(code=4403)
        return

    # ── Step 4: register with the hub ─────────────────────────────────────────
    # ws_hub.register() displaces any previous connection for this uid and
    # stores the new authenticated socket.
    await ws_hub.register(uid, websocket)
    log.info("WS authenticated uid=%s", uid)

    await websocket.send_json({"type": "connected", "uid": uid})

    # ── Step 5: keep-alive loop ───────────────────────────────────────────────
    # The server pushes; the client may send keep-alive text (any value).
    try:
        while True:
            try:
                msg = await asyncio.wait_for(websocket.receive_text(), timeout=30.0)
                # Respond to any client ping
                if msg.strip().lower() == "ping":
                    await websocket.send_json({"type": "pong"})
            except asyncio.TimeoutError:
                # Send a server-side ping to detect dead connections
                try:
                    await websocket.send_json({"type": "ping"})
                except Exception:
                    break
    except WebSocketDisconnect:
        log.info("WS disconnected uid=%s", uid)
    except Exception as exc:
        log.debug("WS session error uid=%s: %s", uid, exc)
    finally:
        ws_hub.disconnect(uid)
