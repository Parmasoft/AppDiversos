from sqlalchemy.dialects.postgresql import insert as postgresql_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert


def dialect_insert(connection, table):
    if connection.dialect.name == "postgresql":
        return postgresql_insert(table)
    if connection.dialect.name == "sqlite":
        return sqlite_insert(table)
    raise RuntimeError(f"Dialeto nao suportado: {connection.dialect.name}")
