#!/usr/bin/env bash
# Executar somente como root, uma vez, em servidor previamente aprovado.
# Recebe: arquivo-tar-da-release e identificador imutavel da release.
set -euo pipefail

archive=${1:?arquivo da release obrigatorio}
release_id=${2:?identificador da release obrigatorio}
root=/opt/api-malhas-nuvem
release="$root/releases/$release_id"
env_file=/etc/api-malhas-nuvem.env

test -f "$archive"
case "$release_id" in *[!A-Za-z0-9._-]*|'') echo 'identificador de release invalido' >&2; exit 2;; esac

if sudo -u postgres psql -d postgres -Atqc "SELECT 1 FROM pg_database WHERE datname='malhas_nuvem'" | grep -qx 1; then
  echo 'Banco malhas_nuvem ja existe; instalacao inicial interrompida.' >&2
  exit 3
fi
if sudo -u postgres psql -d postgres -Atqc "SELECT 1 FROM pg_roles WHERE rolname='malhas_nuvem'" | grep -qx 1; then
  echo 'Role malhas_nuvem ja existe; instalacao inicial interrompida.' >&2
  exit 3
fi

db_password=$(openssl rand -hex 32)
token_secret=$(openssl rand -hex 32)
printf "CREATE ROLE malhas_nuvem LOGIN PASSWORD '%s';\n" "$db_password" | sudo -u postgres psql -d postgres -v ON_ERROR_STOP=1 >/dev/null
sudo -u postgres createdb --owner=malhas_nuvem malhas_nuvem

install -d -m 0755 "$root/releases" /var/log/api-malhas-nuvem
install -d -m 0700 /var/lib/api-malhas-nuvem
install -d -m 0755 "$release"
tar -xzf "$archive" -C "$release"
chown -R root:root "$release"
chmod -R go-w "$release"

python3 -m venv "$root/.venv"
"$root/.venv/bin/pip" install --no-cache-dir -r "$release/requirements.txt"

umask 077
cat > "$env_file" <<EOF
DATABASE_URL=postgresql+psycopg://malhas_nuvem:${db_password}@127.0.0.1:5432/malhas_nuvem
MALHAS_TOKEN_HASH_SECRET=${token_secret}
ACCESS_TOKEN_SECONDS=900
SESSION_SECONDS=2592000
AGENT_CLAIM_SECONDS=120
EOF
chown root:root "$env_file"
chmod 0600 "$env_file"

set -a
. "$env_file"
set +a
cd "$release"
"$root/.venv/bin/alembic" upgrade head

ln -sfn "releases/$release_id" "$root/current"
ln -sfn current/app "$root/app"

cat > /etc/systemd/system/api-malhas-nuvem.service <<'EOF'
[Unit]
Description=API Malhas Nuvem (Gunicorn)
After=network.target postgresql@18-main.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/api-malhas-nuvem
EnvironmentFile=/etc/api-malhas-nuvem.env
ExecStart=/opt/api-malhas-nuvem/.venv/bin/gunicorn --workers 2 --bind 127.0.0.1:8092 --access-logfile - --error-logfile - 'app:create_app()'
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/var/log/api-malhas-nuvem

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now api-malhas-nuvem.service
curl --fail --silent --show-error http://127.0.0.1:8092/api/v1/health
