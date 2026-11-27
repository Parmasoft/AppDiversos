import json
import os
import sqlite3
import stat
import uuid
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path

from .canonical import semantic_hash


SCHEMA_VERSION = 2
PUBLICATION_FIELDS = {"snapshot_id", "snapshot_revision", "semantic_hash", "gerado_em"}
FORBIDDEN_SECRET_NAMES = {"authorization", "password", "senha", "secret", "token"}


def utc_now_iso():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _assert_no_secrets(value, path="$"):
    if isinstance(value, dict):
        for key, item in value.items():
            if str(key).lower() in FORBIDDEN_SECRET_NAMES:
                raise ValueError(f"segredo nao permitido no payload: {path}.{key}")
            _assert_no_secrets(item, f"{path}.{key}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            _assert_no_secrets(item, f"{path}[{index}]")


class AgentState:
    def __init__(self, database_path):
        self.database_path = Path(database_path).resolve()

    def _connect(self):
        connection = sqlite3.connect(self.database_path)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        return connection

    def initialize(self):
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        connection = self._connect()
        try:
            connection.executescript(
                """
                PRAGMA journal_mode = WAL;
                CREATE TABLE IF NOT EXISTS agent_installation (
                    singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
                    schema_version INTEGER NOT NULL,
                    agent_instance_guid TEXT NOT NULL UNIQUE,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS manifest_sync_state (
                    tenant_key TEXT NOT NULL,
                    manifesto_guid TEXT NOT NULL,
                    last_known_revision INTEGER NOT NULL DEFAULT 0 CHECK (last_known_revision >= 0),
                    last_confirmed_revision INTEGER NOT NULL DEFAULT 0 CHECK (last_confirmed_revision >= 0),
                    last_confirmed_semantic_hash TEXT,
                    last_confirmed_snapshot_id TEXT,
                    fencing_token INTEGER,
                    lease_expires_at TEXT,
                    updated_at TEXT NOT NULL,
                    PRIMARY KEY (tenant_key, manifesto_guid)
                );
                CREATE TABLE IF NOT EXISTS pending_snapshot (
                    tenant_key TEXT NOT NULL,
                    manifesto_guid TEXT NOT NULL,
                    snapshot_id TEXT NOT NULL UNIQUE,
                    snapshot_revision INTEGER NOT NULL CHECK (snapshot_revision > 0),
                    semantic_hash TEXT NOT NULL CHECK (length(semantic_hash) = 64),
                    payload_json_literal TEXT NOT NULL,
                    fencing_token_used INTEGER NOT NULL CHECK (fencing_token_used > 0),
                    created_at TEXT NOT NULL,
                    attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
                    last_attempt_at TEXT,
                    last_error TEXT,
                    PRIMARY KEY (tenant_key, manifesto_guid),
                    UNIQUE (tenant_key, manifesto_guid, snapshot_revision),
                    FOREIGN KEY (tenant_key, manifesto_guid)
                      REFERENCES manifest_sync_state (tenant_key, manifesto_guid)
                      ON DELETE CASCADE
                );
                CREATE TABLE IF NOT EXISTS delivery_return_inbox (
                    operation_guid TEXT PRIMARY KEY,
                    payload_json TEXT NOT NULL,
                    state TEXT NOT NULL CHECK (state IN ('RECEIVED','APPLIED','ACKED')),
                    firebird_result_json TEXT,
                    received_at TEXT NOT NULL,
                    applied_at TEXT,
                    acked_at TEXT,
                    last_error TEXT
                );
                CREATE TABLE IF NOT EXISTS company_scope_activation (
                    company_id INTEGER PRIMARY KEY,
                    activated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS company_scope_baseline_manifest (
                    company_id INTEGER NOT NULL,
                    manifesto_guid TEXT NOT NULL,
                    manifesto_version INTEGER NOT NULL,
                    recorded_at TEXT NOT NULL,
                    PRIMARY KEY (company_id, manifesto_guid, manifesto_version)
                );
                """
            )
            connection.execute("BEGIN IMMEDIATE")
            row = connection.execute(
                "SELECT schema_version FROM agent_installation WHERE singleton_id = 1"
            ).fetchone()
            if row is None:
                connection.execute(
                    """INSERT INTO agent_installation
                           (singleton_id, schema_version, agent_instance_guid, created_at)
                       VALUES (1, ?, ?, ?)""",
                    (SCHEMA_VERSION, str(uuid.uuid4()), utc_now_iso()),
                )
            elif row["schema_version"] == 1:
                connection.execute(
                    "UPDATE agent_installation SET schema_version = ? WHERE singleton_id = 1",
                    (SCHEMA_VERSION,),
                )
            elif row["schema_version"] != SCHEMA_VERSION:
                raise RuntimeError(
                    f"Schema local {row['schema_version']} nao suportado; esperado {SCHEMA_VERSION}"
                )
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()
        try:
            os.chmod(self.database_path, stat.S_IRUSR | stat.S_IWUSR)
        except OSError:
            pass

    def installation_guid(self):
        with closing(self._connect()) as connection:
            return connection.execute(
                "SELECT agent_instance_guid FROM agent_installation WHERE singleton_id = 1"
            ).fetchone()["agent_instance_guid"]

    def activate_company_scopes(self, company_ids):
        """Returns company scopes first activated by this installation.

        Existing released manifests are baseline-only at first activation, so a
        company-wide scope cannot bulk-publish a historical backlog.
        """
        new_companies = set()
        with closing(self._connect()) as connection:
            connection.execute("BEGIN IMMEDIATE")
            for company_id in sorted(set(company_ids)):
                existing = connection.execute(
                    "SELECT 1 FROM company_scope_activation WHERE company_id = ?",
                    (company_id,),
                ).fetchone()
                if existing is None:
                    connection.execute(
                        "INSERT INTO company_scope_activation(company_id, activated_at) VALUES (?, ?)",
                        (company_id, utc_now_iso()),
                    )
                    new_companies.add(company_id)
            connection.commit()
        return new_companies

    def record_company_scope_baseline(self, company_id, manifesto_guid, manifesto_version):
        with closing(self._connect()) as connection:
            connection.execute(
                """INSERT OR IGNORE INTO company_scope_baseline_manifest
                   (company_id, manifesto_guid, manifesto_version, recorded_at)
                   VALUES (?, ?, ?, ?)""",
                (company_id, manifesto_guid, manifesto_version, utc_now_iso()),
            )
            connection.commit()

    def is_company_scope_baselined(self, company_id, manifesto_guid, manifesto_version):
        with closing(self._connect()) as connection:
            return connection.execute(
                """SELECT 1 FROM company_scope_baseline_manifest
                     WHERE company_id = ? AND manifesto_guid = ? AND manifesto_version = ?""",
                (company_id, manifesto_guid, manifesto_version),
            ).fetchone() is not None

    def discard_pending(self, pending, reason):
        """Drops an unsent technical snapshot after authoritative ineligibility."""
        with closing(self._connect()) as connection:
            connection.execute("BEGIN IMMEDIATE")
            connection.execute(
                """UPDATE manifest_sync_state SET updated_at = ?
                     WHERE tenant_key = ? AND manifesto_guid = ?""",
                (utc_now_iso(), pending["tenant_key"], pending["manifesto_guid"]),
            )
            connection.execute(
                """DELETE FROM pending_snapshot
                     WHERE tenant_key = ? AND manifesto_guid = ? AND snapshot_id = ?""",
                (pending["tenant_key"], pending["manifesto_guid"], pending["snapshot_id"]),
            )
            connection.commit()

    def receive_delivery_return(self, payload):
        literal = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        with closing(self._connect()) as connection:
            connection.execute("BEGIN IMMEDIATE")
            connection.execute(
                """INSERT INTO delivery_return_inbox(operation_guid, payload_json, state, received_at)
                   VALUES (?, ?, 'RECEIVED', ?)
                   ON CONFLICT(operation_guid) DO NOTHING""",
                (payload["operation_guid"], literal, utc_now_iso()),
            )
            connection.commit()

    def pending_delivery_returns(self):
        with closing(self._connect()) as connection:
            return [dict(row) for row in connection.execute(
                "SELECT * FROM delivery_return_inbox WHERE state <> 'ACKED' ORDER BY received_at"
            ).fetchall()]

    def mark_delivery_applied(self, operation_guid, result):
        with closing(self._connect()) as connection:
            connection.execute(
                """UPDATE delivery_return_inbox SET state='APPLIED', firebird_result_json=?,
                   applied_at=?, last_error=NULL WHERE operation_guid=?""",
                (json.dumps(result, ensure_ascii=False, sort_keys=True), utc_now_iso(), operation_guid),
            )
            connection.commit()

    def mark_delivery_acked(self, operation_guid):
        with closing(self._connect()) as connection:
            connection.execute(
                "UPDATE delivery_return_inbox SET state='ACKED', acked_at=? WHERE operation_guid=?",
                (utc_now_iso(), operation_guid),
            )
            connection.commit()

    def record_delivery_error(self, operation_guid, error):
        with closing(self._connect()) as connection:
            connection.execute(
                "UPDATE delivery_return_inbox SET last_error=? WHERE operation_guid=?",
                (str(error)[:1000], operation_guid),
            )
            connection.commit()

    def sync_lease(self, lease):
        now = utc_now_iso()
        connection = self._connect()
        try:
            connection.execute("BEGIN IMMEDIATE")
            existing = connection.execute(
                """SELECT last_known_revision
                     FROM manifest_sync_state
                    WHERE tenant_key = ? AND manifesto_guid = ?""",
                (lease["tenant_key"], lease["manifesto_guid"]),
            ).fetchone()
            last_known = max(
                existing["last_known_revision"] if existing else 0,
                lease["current_revision"],
            )
            connection.execute(
                """INSERT INTO manifest_sync_state
                       (tenant_key, manifesto_guid, last_known_revision,
                        last_confirmed_revision, last_confirmed_semantic_hash,
                        last_confirmed_snapshot_id, fencing_token,
                        lease_expires_at, updated_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                   ON CONFLICT(tenant_key, manifesto_guid) DO UPDATE SET
                       last_known_revision = excluded.last_known_revision,
                       last_confirmed_revision = excluded.last_confirmed_revision,
                       last_confirmed_semantic_hash = excluded.last_confirmed_semantic_hash,
                       last_confirmed_snapshot_id = excluded.last_confirmed_snapshot_id,
                       fencing_token = excluded.fencing_token,
                       lease_expires_at = excluded.lease_expires_at,
                       updated_at = excluded.updated_at""",
                (
                    lease["tenant_key"],
                    lease["manifesto_guid"],
                    last_known,
                    lease["current_revision"],
                    lease.get("current_semantic_hash"),
                    lease.get("current_snapshot_id"),
                    lease["fencing_token"],
                    lease["expires_at"],
                    now,
                ),
            )
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def create_pending(self, tenant_key, manifesto_guid, detail, cloud_revision, fencing_token):
        if PUBLICATION_FIELDS.intersection(detail):
            raise ValueError("detail contem metadados reservados de publicacao")
        _assert_no_secrets(detail)
        semantic_payload = {"contrato_versao": 1, **detail}
        content_hash = semantic_hash(semantic_payload)
        connection = self._connect()
        try:
            connection.execute("BEGIN IMMEDIATE")
            pending = connection.execute(
                """SELECT * FROM pending_snapshot
                    WHERE tenant_key = ? AND manifesto_guid = ?""",
                (tenant_key, manifesto_guid),
            ).fetchone()
            if pending:
                connection.commit()
                return dict(pending)
            state = connection.execute(
                """SELECT * FROM manifest_sync_state
                    WHERE tenant_key = ? AND manifesto_guid = ?""",
                (tenant_key, manifesto_guid),
            ).fetchone()
            if state is None:
                raise RuntimeError("Lease deve ser sincronizado antes de criar publicacao")
            if content_hash == state["last_confirmed_semantic_hash"]:
                connection.commit()
                return None
            revision = max(state["last_known_revision"], cloud_revision) + 1
            snapshot_id = str(uuid.uuid4())
            generated_at = utc_now_iso()
            payload = {
                "contrato_versao": 1,
                "snapshot_id": snapshot_id,
                "snapshot_revision": revision,
                "semantic_hash": content_hash,
                "gerado_em": generated_at,
                **detail,
            }
            payload_literal = json.dumps(
                payload,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
                allow_nan=False,
            )
            connection.execute(
                """UPDATE manifest_sync_state
                      SET last_known_revision = ?, updated_at = ?
                    WHERE tenant_key = ? AND manifesto_guid = ?""",
                (revision, generated_at, tenant_key, manifesto_guid),
            )
            connection.execute(
                """INSERT INTO pending_snapshot
                       (tenant_key, manifesto_guid, snapshot_id, snapshot_revision,
                        semantic_hash, payload_json_literal, fencing_token_used,
                        created_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    tenant_key,
                    manifesto_guid,
                    snapshot_id,
                    revision,
                    content_hash,
                    payload_literal,
                    fencing_token,
                    generated_at,
                ),
            )
            connection.commit()
            return self.get_pending(tenant_key, manifesto_guid)
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def get_pending(self, tenant_key, manifesto_guid):
        with closing(self._connect()) as connection:
            row = connection.execute(
                """SELECT * FROM pending_snapshot
                    WHERE tenant_key = ? AND manifesto_guid = ?""",
                (tenant_key, manifesto_guid),
            ).fetchone()
            return dict(row) if row else None

    def list_pending(self):
        with closing(self._connect()) as connection:
            return [
                dict(row)
                for row in connection.execute(
                    "SELECT * FROM pending_snapshot ORDER BY created_at, manifesto_guid"
                ).fetchall()
            ]

    def record_attempt(self, pending, fencing_token, error=None):
        with closing(self._connect()) as connection:
            connection.execute(
                """UPDATE pending_snapshot
                      SET fencing_token_used = ?,
                          attempt_count = attempt_count + 1,
                          last_attempt_at = ?,
                          last_error = ?
                    WHERE tenant_key = ? AND manifesto_guid = ?""",
                (
                    fencing_token,
                    utc_now_iso(),
                    str(error)[:1000] if error else None,
                    pending["tenant_key"],
                    pending["manifesto_guid"],
                ),
            )
            connection.commit()

    def confirm_pending(self, pending, response, fencing_token):
        now = utc_now_iso()
        connection = self._connect()
        try:
            connection.execute("BEGIN IMMEDIATE")
            connection.execute(
                """UPDATE manifest_sync_state
                      SET last_known_revision = CASE
                              WHEN last_known_revision > ? THEN last_known_revision ELSE ? END,
                          last_confirmed_revision = ?,
                          last_confirmed_semantic_hash = ?,
                          last_confirmed_snapshot_id = ?,
                          fencing_token = ?,
                          updated_at = ?
                    WHERE tenant_key = ? AND manifesto_guid = ?""",
                (
                    response["current_revision"],
                    response["current_revision"],
                    response["current_revision"],
                    response.get("current_semantic_hash"),
                    response.get("current_snapshot_id"),
                    fencing_token,
                    now,
                    pending["tenant_key"],
                    pending["manifesto_guid"],
                ),
            )
            connection.execute(
                """DELETE FROM pending_snapshot
                    WHERE tenant_key = ? AND manifesto_guid = ? AND snapshot_id = ?""",
                (pending["tenant_key"], pending["manifesto_guid"], pending["snapshot_id"]),
            )
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()
