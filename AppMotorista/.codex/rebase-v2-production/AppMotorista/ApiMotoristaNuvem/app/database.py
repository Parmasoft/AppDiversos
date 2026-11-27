from datetime import datetime, timezone

from flask import current_app
from sqlalchemy import create_engine, event, func, select
from sqlalchemy.pool import StaticPool

from .tables import metadata


def init_database(app):
    database_url = app.config["DATABASE_URL"]
    options = {"pool_pre_ping": True}
    if database_url.startswith("sqlite"):
        options["connect_args"] = {"check_same_thread": False}
        if database_url.endswith(":memory:"):
            options["poolclass"] = StaticPool
    engine = create_engine(database_url, **options)
    if engine.dialect.name == "sqlite":
        @event.listens_for(engine, "connect")
        def _enable_sqlite_foreign_keys(dbapi_connection, _connection_record):
            cursor = dbapi_connection.cursor()
            cursor.execute("PRAGMA foreign_keys = ON")
            cursor.close()
    app.extensions["motorista_engine"] = engine


def get_engine():
    return current_app.extensions["motorista_engine"]


def database_now(connection):
    if connection.dialect.name == "postgresql":
        return connection.execute(select(func.clock_timestamp())).scalar_one()
    return datetime.now(timezone.utc)


def initialize_database():
    """Creates only the disposable SQLite schema used by controlled tests."""
    engine = get_engine()
    if not current_app.config.get("TESTING") or engine.dialect.name != "sqlite":
        raise RuntimeError("Use Alembic para criar ou migrar o banco PostgreSQL")
    metadata.create_all(engine)


def dispose_database():
    get_engine().dispose()
