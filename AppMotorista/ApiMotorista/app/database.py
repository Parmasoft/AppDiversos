from contextlib import contextmanager

import fdb
from flask import current_app


def connect():
    database = current_app.config["FB_DATABASE"]
    if not database:
        raise RuntimeError("FB_DATABASE não configurado.")

    return fdb.connect(
        host=current_app.config["FB_HOST"],
        port=current_app.config["FB_PORT"],
        database=database,
        user=current_app.config["FB_USER"],
        password=current_app.config["FB_PASSWORD"],
        charset=current_app.config["FB_CHARSET"],
    )


@contextmanager
def transaction():
    connection = connect()
    try:
        yield connection
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


@contextmanager
def read_connection():
    connection = connect()
    try:
        yield connection
    finally:
        connection.close()

