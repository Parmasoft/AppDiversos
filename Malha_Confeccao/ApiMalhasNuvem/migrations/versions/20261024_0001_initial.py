"""Initial independent Malhas cloud schema."""
from alembic import op
from app.tables import agente_sync, metadata
revision="20261024_0001"
down_revision=None
branch_labels=None
depends_on=None
def _initial_tables(): return [table for table in metadata.sorted_tables if table.name != agente_sync.name]
def upgrade(): metadata.create_all(op.get_bind(),tables=_initial_tables())
def downgrade(): metadata.drop_all(op.get_bind(),tables=_initial_tables())
