"""Admin API hub — assembles sub-routers by concern (Issue 15).

Sub-modules:
  admin_config_routes     — system config and ML-model management
  admin_seed_routes       — seed data and development demo-glove
  admin_translation_routes — live-translation session management
  admin_user_routes        — user listing, device assignment, audit log

Shared utilities (audit helper, JSON-file locks) live in admin_shared.py.
"""
from __future__ import annotations

from fastapi import APIRouter

from .admin_config_routes import _router as _config_router
from .admin_seed_routes import _router as _seed_router
from .admin_translation_routes import _router as _translation_router
from .admin_user_routes import _router as _user_router

router = APIRouter(prefix="/admin", tags=["admin"])

router.include_router(_config_router)
router.include_router(_seed_router)
router.include_router(_translation_router)
router.include_router(_user_router)
