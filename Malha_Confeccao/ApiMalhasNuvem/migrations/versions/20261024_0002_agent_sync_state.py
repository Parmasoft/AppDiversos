"""State by technical-agent resource, independently from orders."""
from alembic import op
from app.tables import agente_sync

revision="20261024_0002"
down_revision="20261024_0001"
branch_labels=None
depends_on=None

def upgrade(): agente_sync.create(op.get_bind())
def downgrade(): agent_sync.drop(op.get_bind())
