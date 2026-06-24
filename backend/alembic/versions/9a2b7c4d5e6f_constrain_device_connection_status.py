"""constrain device connection status

Revision ID: 9a2b7c4d5e6f
Revises: 563c5de3b860
Create Date: 2026-06-20 21:17:56
"""

from typing import Sequence, Union

from alembic import op


revision: str = "9a2b7c4d5e6f"
down_revision: Union[str, None] = "563c5de3b860"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_check_constraint(
        op.f("ck_devices_connection_status"),
        "devices",
        "connection_status IN ('disconnected', 'scanning', 'connecting', 'connected', 'error')",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_devices_connection_status"),
        "devices",
        type_="check",
    )
