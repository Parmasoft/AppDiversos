import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from werkzeug.security import generate_password_hash

from app import create_app
from app.database import dispose_database, initialize_database
from app.provisioning import (
    provision_agent,
    provision_agent_company_access,
    provision_tenant,
)


class MobileLoginTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        path = Path(self.temp_dir.name) / "login.sqlite3"
        self.app = create_app({
            "TESTING": True, "DATABASE_URL": f"sqlite+pysqlite:///{path.as_posix()}",
            "TOKEN_HASH_SECRET": "test-secret-with-enough-entropy", "SNAPSHOT_LEASE_SECONDS": 60,
        })
        with self.app.app_context():
            initialize_database()
            self.tenant = provision_tenant("GRAMDECOR", "GramDecor")
            agent_a = provision_agent(self.tenant, "AGENT-A", "agent-token-a")
            provision_agent_company_access(agent_a, 10)
        self.client = self.app.test_client()

    def tearDown(self):
        with self.app.app_context():
            dispose_database()
        self.temp_dir.cleanup()

    def sync(self, identities, companies=(10,), agent_token="agent-token-a"):
        return self.client.post("/api/v1/agente/motoristas", json={
            "contrato_versao": 1, "empresas": list(companies), "identidades": identities,
        }, headers={"Authorization": f"Bearer {agent_token}"})

    @staticmethod
    def identity(password="senha-sintetica", active=True, access=True, *, company=10,
                 driver_id=1, driver_guid="MOT-A", login="paulo"):
        return {
            "empresa": company, "motorista_id": driver_id, "motorista_guid": driver_guid,
            "nome": f"Motorista {driver_guid}", "login": login,
            "password_verifier": generate_password_hash(password, method="scrypt:32768:8:1"),
            "motorista_ativo": active, "vinculo_ativo": access, "transportador": 22,
        }

    def login(self, password="senha-sintetica"):
        return self.client.post("/api/v1/motorista/sessoes", json={
            "login": "Paulo", "senha": password, "dispositivo": "teste",
        })

    def test_sync_login_refresh_and_idempotence(self):
        identity = self.identity()
        self.assertEqual(200, self.sync([identity]).status_code)
        login = self.login()
        self.assertEqual(201, login.status_code, login.get_json())
        body = login.get_json()
        self.assertEqual("MOT-A", body["motorista"]["guid"])
        self.assertNotIn("password_verifier", str(body))
        self.assertEqual(200, self.sync([identity]).status_code)
        refreshed = self.client.post("/api/v1/motorista/sessoes/renovar", json={"refresh_token": body["refresh_token"]})
        self.assertEqual(200, refreshed.status_code, refreshed.get_json())

    def test_rejects_wrong_unknown_inactive_and_inactive_access(self):
        self.assertEqual(200, self.sync([self.identity()]).status_code)
        self.assertEqual(401, self.login("errada").status_code)
        missing = self.client.post("/api/v1/motorista/sessoes", json={"login": "ausente", "senha": "x"})
        self.assertEqual(401, missing.status_code)
        self.assertEqual(200, self.sync([self.identity(active=False)]).status_code)
        self.assertEqual(401, self.login().status_code)
        self.assertEqual(200, self.sync([self.identity(active=True, access=False)]).status_code)
        self.assertEqual(401, self.login().status_code)

    def test_credential_change_revokes_existing_session(self):
        self.assertEqual(200, self.sync([self.identity()]).status_code)
        session = self.login().get_json()
        self.assertEqual(200, self.sync([self.identity(password="nova-senha")]).status_code)
        response = self.client.get("/api/v1/motorista/viagens", headers={"Authorization": f"Bearer {session['access_token']}"})
        self.assertEqual(401, response.status_code)
        self.assertEqual(401, self.login().status_code)
        self.assertEqual(201, self.login("nova-senha").status_code)

    def test_two_drivers_receive_only_their_own_identity(self):
        self.assertEqual(200, self.sync([
            self.identity(driver_guid="MOT-A", login="paulo"),
            self.identity(driver_id=2, driver_guid="MOT-B", login="maria"),
        ]).status_code)
        paulo = self.login().get_json()
        maria = self.client.post("/api/v1/motorista/sessoes", json={
            "login": "maria", "senha": "senha-sintetica", "dispositivo": "teste",
        }).get_json()
        self.assertEqual("MOT-A", paulo["motorista"]["guid"])
        self.assertEqual("MOT-B", maria["motorista"]["guid"])

    def test_ambiguous_login_between_tenants_is_safely_rejected(self):
        with self.app.app_context():
            tenant_b = provision_tenant("OUTRO", "Outro")
            agent_b = provision_agent(tenant_b, "AGENT-B", "agent-token-b")
            provision_agent_company_access(agent_b, 10)
        self.assertEqual(200, self.sync([self.identity(login="comum")]).status_code)
        self.assertEqual(200, self.sync([
            self.identity(driver_guid="MOT-B", login="comum")
        ], agent_token="agent-token-b").status_code)
        response = self.client.post("/api/v1/motorista/sessoes", json={
            "login": "comum", "senha": "senha-sintetica", "dispositivo": "teste",
        })
        self.assertEqual(401, response.status_code)
