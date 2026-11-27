# Preparação de implantação — não executar ainda

Estes arquivos são templates locais para `malhas.parmatech.com.br`. Eles não
foram copiados ao droplet, não alteram Nginx, systemd, PostgreSQL, DNS ou
firewall.

## Pré-requisitos bloqueantes

1. Criar no DNS da zona `parmatech.com.br` o registro `A`:
   `malhas.parmatech.com.br → 165.227.77.226`.
2. Aguardar resolução pública e confirmar que o hostname chega ao droplet.
3. Aprovar um destino de backup fora do droplet, retenção e teste de restauração.

## Sequência autorizável futura

1. Criar role e banco `malhas_nuvem`, sem tocar em `motorista_nuvem`.
2. Copiar a aplicação para `/opt/api-malhas-nuvem`, criar venv e instalar requisitos.
3. Criar `/etc/api-malhas-nuvem.env` com permissões 0600 e segredos exclusivos.
4. Aplicar Alembic somente no banco Malhas.
5. Instalar o unit systemd, validar `/api/v1/health` em `127.0.0.1:8092`.
6. Instalar o vhost HTTP, emitir certificado Certbot após DNS válido e então ativar HTTPS.
7. Configurar backup Malhas separado, copiar externamente e restaurar em banco descartável.

Rollback: desabilitar/remover somente o unit e o vhost Malhas, mantendo banco e
dump para investigação. Não alterar recursos Motorista.
