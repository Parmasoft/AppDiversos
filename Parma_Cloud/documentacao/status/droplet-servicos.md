# Droplet — serviços em produção

Droplet único hospeda 3 sites — não mexer nos outros ao alterar um deles.

| Site | Serviço systemd | Porta interna | Porta pública (Nginx) | Pasta | Stack |
|---|---|---|---|---|---|
| **ParmaCloudSync** (pré-existente) | `parmasoft-portal.service` | — | **80** (`/etc/nginx/sites-available/default`) | `/var/www/cotacao` | — |
| **Financeiro App** | `financeiro.service` | 8001 (uvicorn) | **8081** (`deploy/nginx_financeiro.conf`) | `/financeiro` | FastAPI (Python) |
| **Nutrição** | `nutricao.service` | 8000 (gunicorn) | **8080** (`sites-available/nutricao`) | `/nutricao` | Django |

## Regras de ouro ao alterar qualquer um dos três

- Nunca editar `/etc/nginx/sites-available/default`, `parmasoft-portal.service` nem `/var/www/cotacao` (isso é do ParmaCloudSync, o site que já existia antes).
- Cada projeto vive isolado na própria pasta (`/financeiro`, `/nutricao`) com a própria venv e o próprio `.service` — reiniciar um (`sudo systemctl restart <nome>.service`) não afeta os outros dois, desde que você restrinja o restart ao serviço certo.
- **Financeiro App**: deploy = `git pull` em `/financeiro` + `sudo systemctl restart financeiro.service` (só precisa `pip install -r requirements-web.txt` se alguma dependência nova entrar no requirements).
- **Nutrição**: deploy envolve `pip install -r requirements.txt`, `migrate`, `collectstatic` dentro de `/nutricao`, depois `sudo systemctl restart nutricao.service`.
- Antes de reiniciar qualquer serviço, confira o nome exato com `systemctl status <nome>.service` — restart errado é o jeito mais fácil de derrubar o site errado.
