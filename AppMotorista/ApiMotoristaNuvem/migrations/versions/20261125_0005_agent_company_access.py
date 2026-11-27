"""Add persistent company scopes for technical Agent credentials.

Revision ID: 20261125_0005
Revises: 20260925_0004
"""
from typing import Optional, Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20261125_0005"
down_revision: Optional[str] = "20260925_0004"
branch_labels: Optional[Union[str, Sequence[str]]] = None
depends_on: Optional[Union[str, Sequence[str]]] = None


def upgrade() -> None:
    op.create_table(
        "agent_credential_company_access",
        sa.Column(
            "agent_credential_id",
            sa.Integer(),
            sa.ForeignKey("agent_credential.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("company_id", sa.Integer(), primary_key=True),
        sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
    )


def downgrade() -> None:
    op.drop_table("agent_credential_company_access")
