from contextlib import contextmanager

from flask import current_app


class DatabaseConfigurationError(RuntimeError):
    pass


class DatabaseConnectionError(RuntimeError):
    pass


def _driver():
    try:
        import fdb
    except ImportError as error:
        raise DatabaseConnectionError(
            "Driver Firebird indisponivel. Instale as dependencias da API."
        ) from error
    return fdb


def missing_database_settings(config=None):
    config = config or current_app.config
    required = ("FB_DATABASE", "FB_USER", "FB_PASSWORD")
    return [name for name in required if not str(config.get(name, "")).strip()]


def readonly_tpb(fdb):
    return bytes((
        fdb.isc_tpb_version3,
        fdb.isc_tpb_read,
        fdb.isc_tpb_read_committed,
        fdb.isc_tpb_rec_version,
        fdb.isc_tpb_wait,
    ))


def write_tpb(fdb):
    return bytes((
        fdb.isc_tpb_version3,
        fdb.isc_tpb_write,
        fdb.isc_tpb_read_committed,
        fdb.isc_tpb_rec_version,
        fdb.isc_tpb_wait,
    ))


def connect_readonly():
    missing = missing_database_settings()
    if missing:
        raise DatabaseConfigurationError(
            "Configuracao Firebird ausente: " + ", ".join(missing) + "."
        )

    fdb = _driver()
    try:
        return fdb.connect(
            host=current_app.config["FB_HOST"],
            port=current_app.config["FB_PORT"],
            database=current_app.config["FB_DATABASE"],
            user=current_app.config["FB_USER"],
            password=current_app.config["FB_PASSWORD"],
            charset=current_app.config["FB_CHARSET"],
        )
    except Exception as error:
        raise DatabaseConnectionError(
            "Nao foi possivel abrir a conexao Firebird de teste. "
            "Verifique driver, rede local, caminho, charset e credenciais."
        ) from error


@contextmanager
def read_connection():
    connection = connect_readonly()
    try:
        connection.begin(tpb=readonly_tpb(_driver()))
        yield connection
        connection.commit()
    except Exception:
        try:
            connection.rollback()
        finally:
            raise
    finally:
        connection.close()


@contextmanager
def write_connection():
    """Conexao exclusiva da recepcao; nunca reutiliza o contexto read-only."""
    connection = connect_readonly()
    try:
        connection.begin(tpb=write_tpb(_driver()))
        yield connection
        connection.commit()
    except Exception:
        try:
            connection.rollback()
        finally:
            raise
    finally:
        connection.close()


def check_connectivity():
    """Executa somente uma leitura de metadados Firebird e encerra recursos."""
    with read_connection() as connection:
        cursor = connection.cursor()
        try:
            cursor.execute("SELECT 1 FROM RDB$DATABASE")
            return cursor.fetchone()[0] == 1
        finally:
            cursor.close()
