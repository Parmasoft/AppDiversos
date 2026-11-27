"""Add derived cloud delivery confirmations without mutating snapshots."""
from typing import Optional, Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "20261123_0005"
down_revision: Optional[str] = "20260925_0004"
branch_labels: Optional[Union[str, Sequence[str]]] = None
depends_on: Optional[Union[str, Sequence[str]]] = None


def upgrade() -> None:
    op.create_table(
        "delivery_confirmation_projection",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), nullable=False),
        sa.Column("manifest_guid", sa.String(36), nullable=False),
        sa.Column("occurrence_guid", postgresql.UUID(as_uuid=False), nullable=False),
        sa.Column("operation_guid", postgresql.UUID(as_uuid=False), nullable=False),
        sa.Column("stop_id", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=False),
        sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("tenant_id", "manifest_guid", "occurrence_guid", name="uq_delivery_confirmation_occurrence"),
        sa.UniqueConstraint("tenant_id", "operation_guid", name="uq_delivery_confirmation_operation"),
    )


def downgrade() -> None:
    op.drop_table("delivery_confirmation_projection")
