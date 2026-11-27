#!/usr/bin/env bash
# Executor temporario, exclusivamente para a bancada local de homologacao.
# Nao gravar credenciais neste arquivo nem executa-lo fora do WSL Ubuntu-24.04.
set -Eeuo pipefail
umask 077

API_DIR="/mnt/e/Jorginho/AppMotorista/ApiMotoristaNuvem"
AGENT_DIR="/mnt/e/Jorginho/AppMotorista/AgenteMotoristaGramDecor"
VENV="$API_DIR/.venv-wsl-pg18"
RUNTIME_DIR=""
API_PID=""
PHASE="login"

if [[ $# -gt 1 ]]; then
  fail 'Uso: bash homologate_local_driver_login.sh [--phase=minhas-viagens]'
elif [[ $# -eq 1 ]]; then
  [[ "$1" == '--phase=minhas-viagens' ]] || fail 'Fase invalida.'
  PHASE='minhas-viagens'
fi

say() { printf '[homologacao] %s\n' "$*"; }
fail() { printf '[homologacao] ERRO: %s\n' "$*" >&2; exit 1; }
cleanup() {
  status=$?
  if [[ -n "$API_PID" ]] && kill -0 "$API_PID" 2>/dev/null; then
    kill "$API_PID" 2>/dev/null || true
    wait "$API_PID" 2>/dev/null || true
  fi
  [[ -n "$RUNTIME_DIR" ]] && rm -rf -- "$RUNTIME_DIR"
  unset DATABASE_URL MOTORISTA_TOKEN_HASH_SECRET MOTORISTA_AGENT_TOKEN LOCAL_AGENT_TOKEN FIREBIRD_PASSWORD PAULO_PASSWORD
  exit "$status"
}
trap cleanup EXIT INT TERM

[[ "${WSL_DISTRO_NAME:-}" == "Ubuntu-24.04" ]] || fail 'Execute somente em WSL Ubuntu-24.04.'
[[ -x "$VENV/bin/python" ]] || fail 'Virtualenv local da API nao encontrado.'
[[ -d "$AGENT_DIR" ]] || fail 'Diretorio do Agente nao encontrado.'
command -v curl >/dev/null || fail 'curl obrigatorio.'
"$VENV/bin/python" -c 'import fdb, flask, psycopg, requests, sqlalchemy' >/dev/null \
  || fail 'Dependencias API/Agente ausentes no virtualenv local.'

if [[ -z "${DATABASE_URL:-}" ]]; then
  read -r -s -p 'DATABASE_URL da bancada local: ' DATABASE_URL; printf '\n'
  export DATABASE_URL
fi
[[ "$DATABASE_URL" == postgresql+psycopg://* ]] || fail 'DATABASE_URL deve usar postgresql+psycopg://.'

if [[ -z "${FIREBIRD_DATABASE:-}" ]]; then read -r -p 'FIREBIRD_DATABASE piloto: ' FIREBIRD_DATABASE; export FIREBIRD_DATABASE; fi
if [[ -z "${FIREBIRD_USER:-}" ]]; then read -r -p 'FIREBIRD_USER somente leitura: ' FIREBIRD_USER; export FIREBIRD_USER; fi
if [[ -z "${FIREBIRD_PASSWORD:-}" ]]; then read -r -s -p 'FIREBIRD_PASSWORD somente leitura: ' FIREBIRD_PASSWORD; printf '\n'; export FIREBIRD_PASSWORD; fi
export FIREBIRD_HOST="${FIREBIRD_HOST:-127.0.0.1}"
export FIREBIRD_PORT="${FIREBIRD_PORT:-3050}"
export FIREBIRD_CHARSET="${FIREBIRD_CHARSET:-WIN1252}"
export MOTORISTA_CLOUD_URL='http://127.0.0.1:8091'
export MOTORISTA_ALLOW_HTTP='true'
export MOTORISTA_ALLOWED_SCOPES='10:652'
export LOCAL_TENANT_EXTERNAL_ID='GRAMDECOR-LOCAL-LOGIN-20260925'

RUNTIME_DIR="$(mktemp -d /tmp/app-motorista-login.XXXXXX)"
export MOTORISTA_AGENT_STATE_DATABASE="$RUNTIME_DIR/agent_state.sqlite3"
export MOTORISTA_TOKEN_HASH_SECRET="$($VENV/bin/python -c 'import secrets; print(secrets.token_urlsafe(48))')"
export LOCAL_AGENT_TOKEN="$($VENV/bin/python -c 'import secrets; print(secrets.token_urlsafe(48))')"
export LOCAL_AGENT_GUID="LOCAL-HOMOLOGACAO-PAULO-$($VENV/bin/python -c 'import uuid; print(uuid.uuid4())')"

say '1/7 Conferindo schema Alembic da bancada.'
(
  cd "$API_DIR"
  "$VENV/bin/alembic" current --check-heads >/dev/null
) || fail 'Bancada local nao esta no head Alembic; nenhuma credencial foi criada.'

say '2/7 Subindo API local em 127.0.0.1:8091.'
(
  cd "$API_DIR"
  exec "$VENV/bin/gunicorn" --workers 1 --bind 127.0.0.1:8091 \
    --access-logfile /dev/null --error-logfile "$RUNTIME_DIR/api.error.log" run:app
) &
API_PID=$!
for attempt in $(seq 1 30); do
  if curl --fail --silent --show-error http://127.0.0.1:8091/api/v1/health >/dev/null; then break; fi
  sleep 1
  [[ "$attempt" -eq 30 ]] && fail 'API local nao respondeu ao health.'
done
say '3/7 Health confirmado.'

say '4/7 Provisionando somente tenant local isolado e uma credencial tecnica efemera.'
(
  cd "$API_DIR"
  "$VENV/bin/python" - <<'PY'
import os
import unicodedata
from app import create_app
from app.provisioning import provision_agent, provision_tenant

app = create_app()
with app.app_context():
    tenant_id = provision_tenant(os.environ['LOCAL_TENANT_EXTERNAL_ID'], 'GramDecor - Homologacao Local')
    provision_agent(tenant_id, os.environ['LOCAL_AGENT_GUID'], os.environ['LOCAL_AGENT_TOKEN'])
PY
) || fail 'Provisionamento tecnico local falhou.'
export MOTORISTA_AGENT_TOKEN="$LOCAL_AGENT_TOKEN"

say 'FASE 1 — 5/7 Lendo Firebird em transacoes read-only e projetando somente Paulo.'
(
  cd "$AGENT_DIR"
  PYTHONPATH="$AGENT_DIR:$API_DIR" "$VENV/bin/python" - <<'PY'
import os
from agent.config import Config
from agent.publisher import CloudClient
from agent.read_source import FirebirdSnapshotSource

scope = ((10, 652),)
config = Config.from_environment()
source = FirebirdSnapshotSource(config)
client = CloudClient(config.cloud_url, config.agent_token)
def normalized(value):
    return ''.join(char for char in unicodedata.normalize('NFD', value.strip().upper())
                   if unicodedata.category(char) != 'Mn')

matches = [item for item in source.list_driver_identities(scope)
           if item['empresa'] == 10 and item['motorista_id'] == 1
           and item['transportador'] == 22
           and normalized(item['nome']) == 'PAULO HENRIQUE GONCALVES']
if len(matches) != 1:
    raise RuntimeError('Firebird nao retornou exatamente Paulo/Motorista App 1/Transportador 22.')
client.sync_driver_identities([10], matches)
PY
) || fail 'Projecao de identidade do Agente falhou; processos temporarios serao encerrados.'

say 'FASE 1 — 6/7 Verificando no PostgreSQL local identidade, vinculo e verifier.'
(
  cd "$API_DIR"
  "$VENV/bin/python" - <<'PY'
from sqlalchemy import and_, select
import unicodedata
from app import create_app
from app.database import get_engine
from app.tables import mobile_driver_company_access, mobile_driver_identity, tenant

app = create_app()
with app.app_context(), get_engine().connect() as connection:
    tenant_id = connection.execute(select(tenant.c.id).where(
        tenant.c.external_id == 'GRAMDECOR-LOCAL-LOGIN-20260925'
    )).scalar_one()
    identities = connection.execute(select(mobile_driver_identity).where(and_(
        mobile_driver_identity.c.tenant_id == tenant_id,
        mobile_driver_identity.c.driver_app_id == 1,
    ))).mappings().all()
    identity = next((item for item in identities if ''.join(char for char in
                    unicodedata.normalize('NFD', item['driver_name'].strip().upper())
                    if unicodedata.category(char) != 'Mn') == 'PAULO HENRIQUE GONCALVES'), None)
    if identity is None:
        raise RuntimeError('Identidade de Paulo nao encontrada no PostgreSQL.')
    access = connection.execute(select(mobile_driver_company_access.c.active).where(and_(
        mobile_driver_company_access.c.tenant_id == tenant_id,
        mobile_driver_company_access.c.company_id == 10,
        mobile_driver_company_access.c.driver_guid == identity['driver_guid'],
        mobile_driver_company_access.c.transporter_id == 22,
    ))).scalar_one()
    if not identity['password_verifier'] or not access:
        raise RuntimeError('Verificacao da bancada falhou.')
print('VERIFICADO: identidade, vinculo Empresa 10 e verifier.')
PY
)

if [[ "$PHASE" == 'minhas-viagens' ]]; then
  say 'FASE 2 — Publicando somente Carga 652 / Manifesto 73 apos a fase de identidade.'
  (
    cd "$AGENT_DIR"
    PYTHONPATH="$AGENT_DIR:$API_DIR" "$VENV/bin/python" - <<'PY'
import unicodedata
from agent.config import Config
from agent.publisher import CloudClient, SnapshotSynchronizer
from agent.read_source import FirebirdSnapshotSource
from agent.state import AgentState

scope = ((10, 652),)
config = Config.from_environment()
source = FirebirdSnapshotSource(config)
client = CloudClient(config.cloud_url, config.agent_token)
state = AgentState(config.state_database)
state.initialize()
manifests = source.list_released_manifest_guids(scope)
if len(manifests) != 1:
    raise RuntimeError('O escopo 10:652 nao retornou exatamente um manifesto liberado.')
detail = source.read_manifest(manifests[0])
name = ''.join(char for char in unicodedata.normalize('NFD', detail['motorista']['nome'].strip().upper())
               if unicodedata.category(char) != 'Mn')
if (detail['manifesto']['id'], detail['carga']['id'], detail['origem']['empresa'], name) != (73, 652, 10, 'PAULO HENRIQUE GONCALVES'):
    raise RuntimeError('Manifesto/Carga/Motorista do Firebird diverge do cenario autorizado.')
synchronizer = SnapshotSynchronizer(source, client, state, scope)
lease = synchronizer._acquire(manifests[0])
pending = state.create_pending(lease['tenant_key'], manifests[0], detail,
                               lease['current_revision'], lease['fencing_token'])
if pending is not None:
    synchronizer._publish_pending(pending, lease)
PY
  ) || fail 'Publicacao de Minhas Viagens falhou; processos temporarios serao encerrados.'
  say 'FASE 2 — Verificando a projecao local de Carga 652 / Manifesto 73.'
  (
    cd "$API_DIR"
    "$VENV/bin/python" - <<'PY'
from sqlalchemy import and_, select
from app import create_app
from app.database import get_engine
from app.tables import manifest_projection, mobile_driver_identity, tenant

app = create_app()
with app.app_context(), get_engine().connect() as connection:
    tenant_id = connection.execute(select(tenant.c.id).where(
        tenant.c.external_id == 'GRAMDECOR-LOCAL-LOGIN-20260925'
    )).scalar_one()
    driver_guid = connection.execute(select(mobile_driver_identity.c.driver_guid).where(and_(
        mobile_driver_identity.c.tenant_id == tenant_id,
        mobile_driver_identity.c.driver_app_id == 1,
    ))).scalar_one()
    manifest_id = connection.execute(select(manifest_projection.c.manifest_id).where(and_(
        manifest_projection.c.tenant_id == tenant_id,
        manifest_projection.c.company_id == 10,
        manifest_projection.c.load_number == 652,
        manifest_projection.c.driver_guid == driver_guid,
    ))).scalar_one()
    if manifest_id != 73:
        raise RuntimeError('Projecao de Minhas Viagens diverge do cenario autorizado.')
print('VERIFICADO: Carga 652 / Manifesto 73.')
PY
  )
fi

say 'FASE 1 — 7/7 Bancada apta. Informe a senha de Paulo para executar o POST de homologacao, ou pressione Enter para encerrar sem o POST.'
read -r -s -p 'Senha de Paulo: ' PAULO_PASSWORD; printf '\n'
if [[ -n "$PAULO_PASSWORD" ]]; then
  export PAULO_PASSWORD
  export HOMOLOGATE_TRIPS="$PHASE"
  "$VENV/bin/python" - <<'PY'
import os
import requests

response = requests.post('http://127.0.0.1:8091/api/v1/motorista/sessoes', json={
    'login': 'PAULO', 'senha': os.environ['PAULO_PASSWORD'], 'dispositivo': 'homologacao-local',
}, timeout=15)
if response.status_code != 201:
    raise SystemExit(f'Login normal retornou HTTP {response.status_code}.')
body = response.json()
access = body.get('access_token')
if not access:
    raise SystemExit('Login normal nao retornou access token.')
print('HOMOLOGADO: login normal de Paulo; sessao local valida.')
if os.environ['HOMOLOGATE_TRIPS'] == 'minhas-viagens':
    trips = requests.get('http://127.0.0.1:8091/api/v1/motorista/viagens',
                         headers={'Authorization': f'Bearer {access}'}, timeout=15)
    if trips.status_code != 200:
        raise SystemExit(f'Minhas Viagens retornou HTTP {trips.status_code}.')
    if not any(item.get('carga') == 652 and item.get('manifesto') == 73
               for item in trips.json().get('viagens', [])):
        raise SystemExit('Minhas Viagens nao retornou Carga 652 / Manifesto 73.')
    print('HOMOLOGADO: Minhas Viagens (Carga 652 / Manifesto 73).')
PY
else
  say 'POST de login nao executado por opcao; a bancada foi verificada e os processos temporarios serao encerrados.'
fi
