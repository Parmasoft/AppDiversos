"""S20: sessao QR renovavel e ledger transacional delivery_read.

Revision ID: 20260907_0002
Revises: 20260904_0001
Create Date: 2026-09-07
"""
from typing import Optional, Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "20260907_0002"
down_revision: Optional[str] = "20260904_0001"
branch_labels: Optional[Union[str, Sequence[str]]] = None
depends_on: Optional[Union[str, Sequence[str]]] = None


def upgrade() -> None:
    op.add_column("mobile_session", sa.Column("refresh_token_digest", sa.String(64)))
    op.create_unique_constraint("uq_mobile_session_refresh_token_digest", "mobile_session", ["refresh_token_digest"])
    op.create_table(
        "delivery_read_operation",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), nullable=False),
        sa.Column("operation_guid", postgresql.UUID(as_uuid=False), nullable=False),
        sa.Column("driver_guid", sa.String(100), nullable=False),
        sa.Column("manifest_guid", sa.String(36), nullable=False),
        sa.Column("stop_id", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=False),
        sa.Column("request_hash", sa.String(64), nullable=False),
        sa.Column("request_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("response_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("length(request_hash) = 64", name="delivery_read_request_hash_length"),
        sa.UniqueConstraint("tenant_id", "operation_guid", name="uq_delivery_read_tenant_operation"),
    )


def downgrade() -> None:
    op.drop_table("delivery_read_operation")
    op.drop_constraint("uq_mobile_session_refresh_token_digest", "mobile_session", type_="unique")
    op.drop_column("mobile_session", "refresh_token_digest")
