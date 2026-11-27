"""Add durable Agent return lifecycle without mutating mobile delivery ledger.

Revision ID: 20260925_0004
Revises: 20260924_0003
"""
from typing import Optional, Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "20260925_0004"
down_revision: Optional[str] = "20260924_0003"
branch_labels: Optional[Union[str, Sequence[str]]] = None
depends_on: Optional[Union[str, Sequence[str]]] = None


def upgrade() -> None:
    op.add_column("delivery_read_operation", sa.Column("return_contract_version", sa.Integer(), nullable=False, server_default="1"))
    op.add_column("delivery_read_operation", sa.Column("return_payload_hash", sa.String(64), nullable=True))
    op.execute("UPDATE delivery_read_operation SET return_payload_hash = request_hash WHERE return_payload_hash IS NULL")
    op.alter_column("delivery_read_operation", "return_payload_hash", nullable=False)
    op.add_column("delivery_read_operation", sa.Column("return_state", sa.String(20), nullable=False, server_default="PENDING"))
    op.add_column("delivery_read_operation", sa.Column("claimed_by_agent_id", sa.Integer(), sa.ForeignKey("agent_credential.id")))
    op.add_column("delivery_read_operation", sa.Column("claimed_instance_guid", postgresql.UUID(as_uuid=False)))
    op.add_column("delivery_read_operation", sa.Column("claim_expires_at", sa.DateTime(timezone=True)))
    op.add_column("delivery_read_operation", sa.Column("return_attempt_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("delivery_read_operation", sa.Column("return_result_json", postgresql.JSONB(astext_type=sa.Text())))
    op.add_column("delivery_read_operation", sa.Column("returned_at", sa.DateTime(timezone=True)))
    op.create_check_constraint("delivery_read_return_hash_length", "delivery_read_operation", "length(return_payload_hash) = 64")
    op.create_check_constraint("delivery_read_return_state", "delivery_read_operation", "return_state IN ('PENDING', 'CLAIMED', 'APPLIED', 'REJECTED')")
    op.create_index("ix_delivery_read_return_claim", "delivery_read_operation", ["tenant_id", "return_state", "claim_expires_at"])


def downgrade() -> None:
    op.drop_index("ix_delivery_read_return_claim", table_name="delivery_read_operation")
    op.drop_constraint("delivery_read_return_state", "delivery_read_operation", type_="check")
    op.drop_constraint("delivery_read_return_hash_length", "delivery_read_operation", type_="check")
    for name in ("returned_at", "return_result_json", "return_attempt_count", "claim_expires_at", "claimed_instance_guid", "claimed_by_agent_id", "return_state", "return_payload_hash", "return_contract_version"):
        op.drop_column("delivery_read_operation", name)
