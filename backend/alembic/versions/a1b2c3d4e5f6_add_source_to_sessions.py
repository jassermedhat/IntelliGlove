"""add source column to sessions table

Revision ID: a1b2c3d4e5f6
Revises: 9a2b7c4d5e6f
Create Date: 2026-06-23 00:00:00.000000
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = "9a2b7c4d5e6f"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "sessions",
        sa.Column("source", sa.String(length=30), nullable=True),
    )
    # Back-fill sessions whose session_id starts with 'seed_' — these were
    # created by the admin seed tool before this column existed.
    op.execute(
        "UPDATE sessions SET source = 'mock_seed' WHERE session_id LIKE 'seed_%'"
    )


def downgrade() -> None:
    op.drop_column("sessions", "source")
