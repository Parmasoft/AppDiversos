from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Identity,
    Index,
    Integer,
    JSON,
    MetaData,
    String,
    Table,
    Text,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.dialects import postgresql


metadata = MetaData(
    naming_convention={
        "ix": "ix_%(column_0_label)s",
        "uq": "uq_%(table_name)s_%(column_0_name)s",
        "ck": "ck_%(table_name)s_%(constraint_name)s",
        "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
        "pk": "pk_%(table_name)s",
    }
)

BIGINT_ID = BigInteger().with_variant(Integer, "sqlite")
JSON_DOCUMENT = JSON().with_variant(postgresql.JSONB(), "postgresql")


tenant = Table(
    "tenant",
    metadata,
    Column("id", Integer, Identity(), primary_key=True),
    Column("external_id", String(100), nullable=False, unique=True),
    Column("name", String(200), nullable=False),
    Column("tracking_activated_at", DateTime(timezone=True)),
    Column("created_at", DateTime(timezone=True), nullable=False, server_default=func.now()),
)

agent_credential = Table(
    "agent_credential",
    metadata,
    Column("id", Integer, Identity(), primary_key=True),
    Column("tenant_id", Integer, ForeignKey("tenant.id"), nullable=False),
    Column("agent_guid", String(100), nullable=False),
    Column("token_digest", String(64), nullable=False, unique=True),
    Column("active", Boolean, nullable=False, server_default="true"),
    Column("created_at", DateTime(timezone=True), nullable=False),
    Column("last_seen_at", DateTime(timezone=True)),
    UniqueConstraint("tenant_id", "agent_guid", name="uq_agent_credential_tenant_guid"),
)

mobile_session = Table(
    "mobile_session",
    metadata,
    Column("id", Integer, Identity(), primary_key=True),
    Column("tenant_id", Integer, ForeignKey("tenant.id"), nullable=False),
    Column("driver_guid", String(100), nullable=False),
    Column("token_digest", String(64), nullable=False, unique=True),
    Column("refresh_token_digest", String(64), unique=True),
    Column("expires_at", DateTime(timezone=True), nullable=False),
    Column("revoked_at", DateTime(timezone=True)),
    Column("created_at", DateTime(timezone=True), nullable=False),
)

# Credenciais verificaveis projetadas pelo Agente. Nunca recebem senha bruta.
mobile_driver_identity = Table(
    "mobile_driver_identity",
    metadata,
    Column("tenant_id", Integer, ForeignKey("tenant.id"), primary_key=True),
    Column("driver_guid", String(100), primary_key=True),
    Column("driver_app_id", Integer, nullable=False),
    Column("driver_name", String(200), nullable=False),
    Column("login_normalized", String(80), nullable=False),
    Column("password_verifier", String(255), nullable=False),
    Column("active", Boolean, nullable=False),
    Column("updated_at", DateTime(timezone=True), nullable=False, server_default=func.now()),
    UniqueConstraint("tenant_id", "login_normalized", name="uq_mobile_driver_tenant_login"),
)

mobile_driver_company_access = Table(
    "mobile_driver_company_access",
    metadata,
    Column("tenant_id", Integer, ForeignKey("tenant.id"), primary_key=True),
    Column("company_id", Integer, primary_key=True),
    Column("driver_guid", String(100), primary_key=True),
    Column("transporter_id", Integer),
    Column("active", Boolean, nullable=False),
    Column("updated_at", DateTime(timezone=True), nullable=False, server_default=func.now()),
    ForeignKeyConstraint(
        ["tenant_id", "driver_guid"],
        ["mobile_driver_identity.tenant_id", "mobile_driver_identity.driver_guid"],
        name="fk_mobile_driver_company_identity",
    ),
)

# Ledger da unica escrita aceita diretamente do aplicativo.  Nao ha FK, cliente
# ou chamada para Firebird neste fluxo: a identidade vem exclusivamente da sessao.
delivery_read_operation = Table(
    "delivery_read_operation",
    metadata,
    Column("id", BIGINT_ID, Identity(), primary_key=True),
    Column("tenant_id", Integer, ForeignKey("tenant.id"), nullable=False),
    Column("operation_guid", Uuid(as_uuid=False), nullable=False),
    Column("driver_guid", String(100), nullable=False),
    Column("manifest_guid", String(36), nullable=False),
    Column("stop_id", Integer, nullable=False),
    Column("order_id", Integer, nullable=False),
    Column("request_hash", String(64), nullable=False),
    Column("request_json", JSON_DOCUMENT, nullable=False),
    Column("response_json", JSON_DOCUMENT, nullable=False),
    Column("created_at", DateTime(timezone=True), nullable=False),
    # Lifecycle owned by the technical Agent.  The original mobile request and
    # response above are immutable and are never consumed or overwritten.
    Column("return_contract_version", Integer, nullable=False, server_default="1"),
    Column("return_payload_hash", String(64), nullable=False),
    Column("return_state", String(20), nullable=False, server_default="PENDING"),
    Column("claimed_by_agent_id", Integer, ForeignKey("agent_credential.id")),
    Column("claimed_instance_guid", Uuid(as_uuid=False)),
    Column("claim_expires_at", DateTime(timezone=True)),
    Column("return_attempt_count", Integer, nullable=False, server_default="0"),
    Column("return_result_json", JSON_DOCUMENT),
    Column("returned_at", DateTime(timezone=True)),
    CheckConstraint("length(request_hash) = 64", name="delivery_read_request_hash_length"),
    CheckConstraint("length(return_payload_hash) = 64", name="delivery_read_return_hash_length"),
    CheckConstraint("return_state IN ('PENDING', 'CLAIMED', 'APPLIED', 'REJECTED')", name="delivery_read_return_state"),
    UniqueConstraint("tenant_id", "operation_guid", name="uq_delivery_read_tenant_operation"),
)

delivery_confirmation_projection = Table(
    "delivery_confirmation_projection",
    metadata,
    Column("id", BIGINT_ID, Identity(), primary_key=True),
    Column("tenant_id", Integer, ForeignKey("tenant.id"), nullable=False),
    Column("manifest_guid", String(36), nullable=False),
    Column("occurrence_guid", Uuid(as_uuid=False), nullable=False),
    Column("operation_guid", Uuid(as_uuid=False), nullable=False),
    Column("stop_id", Integer, nullable=False),
    Column("order_id", Integer, nullable=False),
    Column("confirmed_at", DateTime(timezone=True), nullable=False),
    UniqueConstraint("tenant_id", "manifest_guid", "occurrence_guid", name="uq_delivery_confirmation_occurrence"),
    UniqueConstraint("tenant_id", "operation_guid", name="uq_delivery_confirmation_operation"),
)

snapshot_receipt = Table(
    "snapshot_receipt",
    metadata,
    Column("id", BIGINT_ID, Identity(), primary_key=True),
    Column("tenant_id", Integer, ForeignKey("tenant.id"), nullable=False),
    Column("manifesto_guid", String(36), nullable=False),
    Column("snapshot_id", Uuid(as_uuid=False), nullable=False),
    Column("snapshot_revision", BigInteger, nullable=False),
    Column("contract_version", Integer, nullable=False),
    Column("semantic_hash", String(64), nullable=False),
    Column("generated_at", DateTime(timezone=True), nullable=False),
    Column("received_at", DateTime(timezone=True), nullable=False),
    Column("agent_id", Integer, ForeignKey("agent_credential.id"), nullable=False),
    Column("accepted_fencing_token", BigInteger, nullable=False),
    Column("applied", Boolean, nullable=False),
    Column("reason", String(50)),
    CheckConstraint("snapshot_revision > 0", name="snapshot_revision_positive"),
    CheckConstraint("length(semantic_hash) = 64", name="semantic_hash_length"),
    UniqueConstraint("tenant_id", "snapshot_id", name="uq_snapshot_receipt_tenant_snapshot"),
    UniqueConstraint(
        "tenant_id",
        "manifesto_guid",
        "snapshot_revision",
        name="uq_snapshot_receipt_tenant_manifest_revision",
    ),
)

manifest_snapshot_state = Table(
    "manifest_snapshot_state",
    metadata,
    Column("tenant_id", Integer, ForeignKey("tenant.id"), primary_key=True),
    Column("manifesto_guid", String(36), primary_key=True),
    Column("current_revision", BigInteger, nullable=False, server_default="0"),
    Column("current_semantic_hash", String(64)),
    Column("current_snapshot_id", Uuid(as_uuid=False)),
    Column("updated_at", DateTime(timezone=True), nullable=False, server_default=func.now()),
    CheckConstraint("current_revision >= 0", name="current_revision_nonnegative"),
    CheckConstraint(
        "(current_revision = 0 AND current_semantic_hash IS NULL AND current_snapshot_id IS NULL) "
        "OR (current_revision > 0 AND current_semantic_hash IS NOT NULL AND current_snapshot_id IS NOT NULL)",
        name="current_snapshot_complete",
    ),
)

snapshot_publisher_lease = Table(
    "snapshot_publisher_lease",
    metadata,
    Column("tenant_id", Integer, ForeignKey("tenant.id"), primary_key=True),
    Column("manifesto_guid", String(36), primary_key=True),
    Column("agent_id", Integer, ForeignKey("agent_credential.id"), nullable=False),
    Column("agent_instance_guid", Uuid(as_uuid=False), nullable=False),
    Column("fencing_token", BigInteger, nullable=False),
    Column("expires_at", DateTime(timezone=True), nullable=False),
    Column("updated_at", DateTime(timezone=True), nullable=False),
    CheckConstraint("fencing_token > 0", name="fencing_token_positive"),
)

load_projection = Table(
    "load_projection",
    metadata,
    Column("tenant_id", Integer, ForeignKey("tenant.id"), primary_key=True),
    Column("load_guid", String(100), primary_key=True),
    Column("load_number", Integer, nullable=False),
    Column("company_id", Integer, nullable=False),
    Column("driver_guid", String(100), nullable=False),
    Column("driver_name", String(200), nullable=False),
    Column("technical_status", String(30), nullable=False),
    Column("tracking_status", String(30), nullable=False),
    Column("started_at", String(40)),
    Column("completed_at", String(40)),
    Column("snapshot_id", Uuid(as_uuid=False), nullable=False),
    Column("updated_at", DateTime(timezone=True), nullable=False),
)

manifest_projection = Table(
    "manifest_projection",
    metadata,
    Column("tenant_id", Integer, ForeignKey("tenant.id"), primary_key=True),
    Column("manifest_guid", String(36), primary_key=True),
    Column("manifest_id", Integer, nullable=False),
    Column("load_guid", String(100), nullable=False),
    Column("load_number", Integer, nullable=False),
    Column("company_id", Integer, nullable=False),
    Column("driver_guid", String(100), nullable=False),
    Column("technical_status", String(30), nullable=False),
    Column("tracking_status", String(30), nullable=False),
    Column("occurrence_count", Integer, nullable=False),
    Column("detail_json", JSON_DOCUMENT, nullable=False),
    Column("snapshot_id", Uuid(as_uuid=False), nullable=False),
    Column("updated_at", DateTime(timezone=True), nullable=False),
)

stop_projection = Table(
    "stop_projection",
    metadata,
    Column("tenant_id", Integer, ForeignKey("tenant.id"), primary_key=True),
    Column("stop_guid", String(100), primary_key=True),
    Column("manifest_guid", String(36), nullable=False),
    Column("stop_id", Integer, nullable=False),
    Column("sequence_number", Integer, nullable=False),
    Column("technical_status", String(30), nullable=False),
    Column("tracking_status", String(30), nullable=False),
    Column("completed_at", String(40)),
    Column("snapshot_id", Uuid(as_uuid=False), nullable=False),
    Column("updated_at", DateTime(timezone=True), nullable=False),
)

order_projection = Table(
    "order_projection",
    metadata,
    Column("tenant_id", Integer, ForeignKey("tenant.id"), primary_key=True),
    Column("order_guid", String(150), primary_key=True),
    Column("stop_guid", String(100), nullable=False),
    Column("manifest_guid", String(36), nullable=False),
    Column("order_id", Integer, nullable=False),
    Column("order_number", Integer, nullable=False),
    Column("customer_id", Integer, nullable=False),
    Column("customer_name", String(200), nullable=False),
    Column("notification_email", String(320)),
    Column("accepts_email", Boolean, nullable=False, server_default="false"),
    Column("technical_status", String(30), nullable=False),
    Column("tracking_status", String(30), nullable=False),
    Column("delivered_at", String(40)),
    Column("snapshot_id", Uuid(as_uuid=False), nullable=False),
    Column("updated_at", DateTime(timezone=True), nullable=False),
)

occurrence_projection = Table(
    "occurrence_projection",
    metadata,
    Column("tenant_id", Integer, ForeignKey("tenant.id"), primary_key=True),
    Column("occurrence_guid", String(100), primary_key=True),
    Column("order_guid", String(150), nullable=False),
    Column("occurrence_id", Integer, nullable=False),
    Column("occurrence_type", String(10), nullable=False),
    Column("technical_status", String(30), nullable=False),
    Column("version_number", Integer, nullable=False),
    Column("occurred_at", String(40)),
    Column("snapshot_id", Uuid(as_uuid=False), nullable=False),
    Column("updated_at", DateTime(timezone=True), nullable=False),
)

tracking_event = Table(
    "tracking_event",
    metadata,
    Column("id", BIGINT_ID, Identity(), primary_key=True),
    Column("tenant_id", Integer, ForeignKey("tenant.id"), nullable=False),
    Column("logical_key", String(64), nullable=False),
    Column("event_type", String(30), nullable=False),
    Column("event_version", Integer, nullable=False),
    Column("occurred_at", DateTime(timezone=True), nullable=False),
    Column("authoritative_source", String(20), nullable=False),
    Column("operation_guid", String(100)),
    Column("load_guid", String(100), nullable=False),
    Column("manifest_guid", String(100), nullable=False),
    Column("stop_guid", String(100)),
    Column("order_guid", String(150)),
    Column("payload_json", JSON_DOCUMENT, nullable=False),
    Column("created_at", DateTime(timezone=True), nullable=False),
    CheckConstraint(
        "event_type IN ('SAIU_PARA_ENTREGA', 'PEDIDO_ENTREGUE')",
        name="event_type_allowed",
    ),
    CheckConstraint("authoritative_source = 'FIREBIRD'", name="authoritative_source_firebird"),
    UniqueConstraint("tenant_id", "logical_key", name="uq_tracking_event_tenant_logical_key"),
)

notification_outbox = Table(
    "notification_outbox",
    metadata,
    Column("id", BIGINT_ID, Identity(), primary_key=True),
    Column("tenant_id", Integer, ForeignKey("tenant.id"), nullable=False),
    Column("tracking_event_id", BigInteger, ForeignKey("tracking_event.id"), nullable=False),
    Column("channel", String(20), nullable=False),
    Column("recipient", String(320), nullable=False),
    Column("idempotency_key", String(64), nullable=False),
    Column("status", String(20), nullable=False, server_default="PENDING"),
    Column("attempt_count", Integer, nullable=False, server_default="0"),
    Column("next_attempt_at", DateTime(timezone=True)),
    Column("sent_at", DateTime(timezone=True)),
    Column("last_error", Text),
    Column("created_at", DateTime(timezone=True), nullable=False),
    CheckConstraint("channel = 'EMAIL'", name="channel_email"),
    CheckConstraint(
        "status IN ('PENDING', 'SENDING', 'SENT', 'FAILED', 'SUPPRESSED')",
        name="status_allowed",
    ),
    UniqueConstraint("tenant_id", "idempotency_key", name="uq_outbox_tenant_idempotency"),
    UniqueConstraint(
        "tracking_event_id", "channel", "recipient", name="uq_outbox_event_channel_recipient"
    ),
)

Index("ix_manifest_driver", manifest_projection.c.tenant_id, manifest_projection.c.driver_guid, manifest_projection.c.technical_status)
Index("ix_order_tracking", order_projection.c.tenant_id, order_projection.c.tracking_status)
