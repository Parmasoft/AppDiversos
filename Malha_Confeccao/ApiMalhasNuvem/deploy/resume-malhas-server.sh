#!/usr/bin/env bash
# Retoma uma instalacao inicial interrompida somente se o banco Malhas estiver vazio.
set -euo pipefail

archive=${1:?arquivo da release obrigatorio}
release_id=${2:?identificador da release obrigatorio}
root=/opt/api-malhas-nuvem
release="$root/releases/$release_id"
env_file=/etc/api-malhas-nuvem.env

test -f "$archive"
test -f "$env_file"
case "$release_id" in *[!A-Za-z0-9._-]*|'') echo 'identificador de release invalido' >&2; exit 2;; esac
if sudo -u postgres psql -d malhas_nuvem -Atqc "SELECT count(*) FROM pg_tables WHERE schemaname='public'" | grep -qv '^0$'; then
  echo 'Banco malhas_nuvem nao esta vazio; retomada interrompida.' >&2
  exit 3
fi

install -d -m 0755 "$release"
tar -xzf "$archive" -C "$release"
chown -R root:root "$release"
chmod -R go-w "$release"
"$root/.venv/bin/pip" install --no-cache-dir -r "$release/requirements.txt"

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
