"""Project driver credentials for normal mobile login.

Revision ID: 20260924_0003
Revises: 20260907_0002
Create Date: 2026-09-24
"""
from typing import Optional, Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260924_0003"
down_revision: Optional[str] = "20260907_0002"
branch_labels: Optional[Union[str, Sequence[str]]] = None
depends_on: Optional[Union[str, Sequence[str]]] = None


def upgrade() -> None:
    op.create_table(
        "mobile_driver_identity",
        sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenant.id"), primary_key=True),
        sa.Column("driver_guid", sa.String(100), primary_key=True),
        sa.Column("driver_app_id", sa.Integer(), nullable=False),
        sa.Column("driver_name", sa.String(200), nullable=False),
        sa.Column("login_normalized", sa.String(80), nullable=False),
        sa.Column("password_verifier", sa.String(255), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("tenant_id", "login_normalized", name="uq_mobile_driver_tenant_login"),
    )
    op.create_table(
        "mobile_driver_company_access",
        sa.Column("tenant_id", sa.Integer(), nullable=False),
        sa.Column("company_id", sa.Integer(), nullable=False),
        sa.Column("driver_guid", sa.String(100), nullable=False),
        sa.Column("transporter_id", sa.Integer()),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("tenant_id", "company_id", "driver_guid"),
        sa.ForeignKeyConstraint(["tenant_id", "driver_guid"], ["mobile_driver_identity.tenant_id", "mobile_driver_identity.driver_guid"], name="fk_mobile_driver_company_identity"),
    )


def downgrade() -> None:
    op.drop_table("mobile_driver_company_access")
    op.drop_table("mobile_driver_identity")
