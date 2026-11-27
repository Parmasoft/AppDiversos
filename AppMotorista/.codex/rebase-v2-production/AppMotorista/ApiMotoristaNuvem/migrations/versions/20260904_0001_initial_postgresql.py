"""Initial PostgreSQL schema for ApiMotoristaNuvem.

Revision ID: 20260904_0001
Revises: None
Create Date: 2026-09-04
"""
from typing import Optional, Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "20260904_0001"
down_revision: Optional[str] = None
branch_labels: Optional[Union[str, Sequence[str]]] = None
depends_on: Optional[Union[str, Sequence[str]]] = None


def upgrade() -> None:
    op.create_table(
        "tenant",
        sa.Column("id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("external_id", sa.String(100), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("tracking_activated_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("external_id", name="uq_tenant_external_id"),
    )
    op.create_table(
        "agent_credential",
        sa.Column("id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), nullable=False),
        sa.Column("agent_guid", sa.String(100), nullable=False),
        sa.Column("token_digest", sa.String(64), nullable=False),
        sa.Column("active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True)),
        sa.UniqueConstraint("token_digest", name="uq_agent_credential_token_digest"),
        sa.UniqueConstraint("tenant_id", "agent_guid", name="uq_agent_credential_tenant_guid"),
    )
    op.create_table(
        "mobile_session",
        sa.Column("id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), nullable=False),
        sa.Column("driver_guid", sa.String(100), nullable=False),
        sa.Column("token_digest", sa.String(64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("token_digest", name="uq_mobile_session_token_digest"),
    )
    op.create_table(
        "manifest_snapshot_state",
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), primary_key=True),
        sa.Column("manifesto_guid", sa.String(36), primary_key=True),
        sa.Column("current_revision", sa.BigInteger(), server_default="0", nullable=False),
        sa.Column("current_semantic_hash", sa.String(64)),
        sa.Column("current_snapshot_id", postgresql.UUID(as_uuid=False)),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("current_revision >= 0", name="current_revision_nonnegative"),
        sa.CheckConstraint(
            "(current_revision = 0 AND current_semantic_hash IS NULL AND current_snapshot_id IS NULL) "
            "OR (current_revision > 0 AND current_semantic_hash IS NOT NULL AND current_snapshot_id IS NOT NULL)",
            name="current_snapshot_complete",
        ),
        sa.CheckConstraint(
            "current_semantic_hash IS NULL OR current_semantic_hash ~ '^[0-9a-f]{64}$'",
            name="semantic_hash_sha256",
        ),
    )
    op.create_table(
        "snapshot_publisher_lease",
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), primary_key=True),
        sa.Column("manifesto_guid", sa.String(36), primary_key=True),
        sa.Column("agent_id", sa.Integer(), sa.ForeignKey("agent_credential.id"), nullable=False),
        sa.Column("agent_instance_guid", postgresql.UUID(as_uuid=False), nullable=False),
        sa.Column("fencing_token", sa.BigInteger(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("fencing_token > 0", name="fencing_token_positive"),
    )
    op.create_table(
        "snapshot_receipt",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), nullable=False),
        sa.Column("manifesto_guid", sa.String(36), nullable=False),
        sa.Column("snapshot_id", postgresql.UUID(as_uuid=False), nullable=False),
        sa.Column("snapshot_revision", sa.BigInteger(), nullable=False),
        sa.Column("contract_version", sa.Integer(), nullable=False),
        sa.Column("semantic_hash", sa.String(64), nullable=False),
        sa.Column("generated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("agent_id", sa.Integer(), sa.ForeignKey("agent_credential.id"), nullable=False),
        sa.Column("accepted_fencing_token", sa.BigInteger(), nullable=False),
        sa.Column("applied", sa.Boolean(), nullable=False),
        sa.Column("reason", sa.String(50)),
        sa.CheckConstraint("snapshot_revision > 0", name="snapshot_revision_positive"),
        sa.CheckConstraint("semantic_hash ~ '^[0-9a-f]{64}$'", name="semantic_hash_sha256"),
        sa.UniqueConstraint("tenant_id", "snapshot_id", name="uq_snapshot_receipt_tenant_snapshot"),
        sa.UniqueConstraint(
            "tenant_id", "manifesto_guid", "snapshot_revision",
            name="uq_snapshot_receipt_tenant_manifest_revision",
        ),
    )
    op.create_table(
        "load_projection",
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), primary_key=True),
        sa.Column("load_guid", sa.String(100), primary_key=True),
        sa.Column("load_number", sa.Integer(), nullable=False),
        sa.Column("company_id", sa.Integer(), nullable=False),
        sa.Column("driver_guid", sa.String(100), nullable=False),
        sa.Column("driver_name", sa.String(200), nullable=False),
        sa.Column("technical_status", sa.String(30), nullable=False),
        sa.Column("tracking_status", sa.String(30), nullable=False),
        sa.Column("started_at", sa.String(40)),
        sa.Column("completed_at", sa.String(40)),
        sa.Column("snapshot_id", postgresql.UUID(as_uuid=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "manifest_projection",
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), primary_key=True),
        sa.Column("manifest_guid", sa.String(36), primary_key=True),
        sa.Column("manifest_id", sa.Integer(), nullable=False),
        sa.Column("load_guid", sa.String(100), nullable=False),
        sa.Column("load_number", sa.Integer(), nullable=False),
        sa.Column("company_id", sa.Integer(), nullable=False),
        sa.Column("driver_guid", sa.String(100), nullable=False),
        sa.Column("technical_status", sa.String(30), nullable=False),
        sa.Column("tracking_status", sa.String(30), nullable=False),
        sa.Column("occurrence_count", sa.Integer(), nullable=False),
        sa.Column("detail_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("snapshot_id", postgresql.UUID(as_uuid=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "stop_projection",
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), primary_key=True),
        sa.Column("stop_guid", sa.String(100), primary_key=True),
        sa.Column("manifest_guid", sa.String(36), nullable=False),
        sa.Column("stop_id", sa.Integer(), nullable=False),
        sa.Column("sequence_number", sa.Integer(), nullable=False),
        sa.Column("technical_status", sa.String(30), nullable=False),
        sa.Column("tracking_status", sa.String(30), nullable=False),
        sa.Column("completed_at", sa.String(40)),
        sa.Column("snapshot_id", postgresql.UUID(as_uuid=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "order_projection",
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), primary_key=True),
        sa.Column("order_guid", sa.String(150), primary_key=True),
        sa.Column("stop_guid", sa.String(100), nullable=False),
        sa.Column("manifest_guid", sa.String(36), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=False),
        sa.Column("order_number", sa.Integer(), nullable=False),
        sa.Column("customer_id", sa.Integer(), nullable=False),
        sa.Column("customer_name", sa.String(200), nullable=False),
        sa.Column("notification_email", sa.String(320)),
        sa.Column("accepts_email", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("technical_status", sa.String(30), nullable=False),
        sa.Column("tracking_status", sa.String(30), nullable=False),
        sa.Column("delivered_at", sa.String(40)),
        sa.Column("snapshot_id", postgresql.UUID(as_uuid=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "occurrence_projection",
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), primary_key=True),
        sa.Column("occurrence_guid", sa.String(100), primary_key=True),
        sa.Column("order_guid", sa.String(150), nullable=False),
        sa.Column("occurrence_id", sa.Integer(), nullable=False),
        sa.Column("occurrence_type", sa.String(10), nullable=False),
        sa.Column("technical_status", sa.String(30), nullable=False),
        sa.Column("version_number", sa.Integer(), nullable=False),
        sa.Column("occurred_at", sa.String(40)),
        sa.Column("snapshot_id", postgresql.UUID(as_uuid=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "tracking_event",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), nullable=False),
        sa.Column("logical_key", sa.String(64), nullable=False),
        sa.Column("event_type", sa.String(30), nullable=False),
        sa.Column("event_version", sa.Integer(), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("authoritative_source", sa.String(20), nullable=False),
        sa.Column("operation_guid", sa.String(100)),
        sa.Column("load_guid", sa.String(100), nullable=False),
        sa.Column("manifest_guid", sa.String(100), nullable=False),
        sa.Column("stop_guid", sa.String(100)),
        sa.Column("order_guid", sa.String(150)),
        sa.Column("payload_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "event_type IN ('SAIU_PARA_ENTREGA', 'PEDIDO_ENTREGUE')",
            name="event_type_allowed",
        ),
        sa.CheckConstraint(
            "authoritative_source = 'FIREBIRD'",
            name="authoritative_source_firebird",
        ),
        sa.UniqueConstraint("tenant_id", "logical_key", name="uq_tracking_event_tenant_logical_key"),
    )
    op.create_table(
        "notification_outbox",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), nullable=False),
        sa.Column("tracking_event_id", sa.BigInteger(), sa.ForeignKey("tracking_event.id"), nullable=False),
        sa.Column("channel", sa.String(20), nullable=False),
        sa.Column("recipient", sa.String(320), nullable=False),
        sa.Column("idempotency_key", sa.String(64), nullable=False),
        sa.Column("status", sa.String(20), server_default="PENDING", nullable=False),
        sa.Column("attempt_count", sa.Integer(), server_default="0", nullable=False),
        sa.Column("next_attempt_at", sa.DateTime(timezone=True)),
        sa.Column("sent_at", sa.DateTime(timezone=True)),
        sa.Column("last_error", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("channel = 'EMAIL'", name="channel_email"),
        sa.CheckConstraint(
            "status IN ('PENDING', 'SENDING', 'SENT', 'FAILED', 'SUPPRESSED')",
            name="status_allowed",
        ),
        sa.UniqueConstraint("tenant_id", "idempotency_key", name="uq_outbox_tenant_idempotency"),
        sa.UniqueConstraint(
            "tracking_event_id", "channel", "recipient", name="uq_outbox_event_channel_recipient"
        ),
    )
    op.create_index(
        "ix_manifest_driver", "manifest_projection",
        ["tenant_id", "driver_guid", "technical_status"],
    )
    op.create_index("ix_order_tracking", "order_projection", ["tenant_id", "tracking_status"])


def downgrade() -> None:
    op.drop_index("ix_order_tracking", table_name="order_projection")
    op.drop_index("ix_manifest_driver", table_name="manifest_projection")
    for table_name in (
        "notification_outbox", "tracking_event", "occurrence_projection",
        "order_projection", "stop_projection", "manifest_projection",
        "load_projection", "snapshot_receipt", "snapshot_publisher_lease",
        "manifest_snapshot_state", "mobile_session", "agent_credential", "tenant",
    ):
        op.drop_table(table_name)
