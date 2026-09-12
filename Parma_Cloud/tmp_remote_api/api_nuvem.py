from flask import Flask, request, jsonify, redirect, session, send_from_directory
import fdb
import secrets
import os
from datetime import datetime, date, timedelta
from decimal import Decimal, InvalidOperation

app = Flask(__name__)

# =========================================================
# CONFIG
# =========================================================
PORTAL_SECRET_KEY_FILE = os.getenv(
    "PORTAL_SECRET_KEY_FILE",
    "/var/www/cotacao/.portal_secret_key"
)

with open(
    PORTAL_SECRET_KEY_FILE,
    "r",
    encoding="utf-8"
) as arquivo_chave:
    PORTAL_SECRET_KEY = arquivo_chave.read().strip()

if not PORTAL_SECRET_KEY:
    raise RuntimeError(
        "A chave secreta do portal está vazia."
    )

app.config.update(
    SECRET_KEY=PORTAL_SECRET_KEY,
    PERMANENT_SESSION_LIFETIME=timedelta(hours=8),
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
    SESSION_COOKIE_SECURE=(
        os.getenv("PORTAL_COOKIE_SECURE", "N")
        .strip()
        .upper() == "S"
    )
)

FB_HOST = os.getenv("FB_HOST", "localhost")
FB_DATABASE = os.getenv("FB_DATABASE", "/var/lib/firebird/cotacao.fdb")
FB_USER = os.getenv("FB_USER", "SYSDBA")
FB_PASSWORD = os.getenv("FB_PASSWORD", "masterkey")
FB_CHARSET = os.getenv("FB_CHARSET", "UTF8")

#BASE_LINK = os.getenv("BASE_LINK", "https://cotacao.parmasoft.com.br")
BASE_LINK = os.getenv("BASE_LINK", "http://165.227.77.226:5000")

# =========================================================
# CONEXÃO
# ===================================================


# =========================================================
# UTILS
def get_connection():
    return fdb.connect(
        dsn=f"{FB_HOST}/3050:{FB_DATABASE}",
        user=FB_USER,
        password=FB_PASSWORD,
        charset=FB_CHARSET,
    )

#=========================================================
def gerar_token() -> str:
    return secrets.token_urlsafe(32)


def parse_date(value):
    if value is None:
        return None

    if isinstance(value, date):
        return value

    s = str(value).strip()
    if not s:
        return None

    for fmt in ("%Y-%m-%d", "%d/%m/%Y"):
        try:
            return datetime.strptime(s, fmt).date()
        except ValueError:
            pass

    return None


def timestamp_to_str(value):
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.isoformat()
    return str(value)


def parse_timestamp(value):
    if value is None:
        return None

    if isinstance(value, datetime):
        return value

    if isinstance(value, date):
        return datetime.combine(value, datetime.min.time())

    s = str(value).strip()
    if not s:
        return None

    try:
        data = datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None

    if data.tzinfo is not None:
        data = data.replace(tzinfo=None)

    return data


def converter_timestamp_opcional(valor, nome_campo, sequencia):
    if valor is None or valor == "":
        return None

    data = parse_timestamp(valor)

    if data is None:
        raise ValueError(
            f"{nome_campo} invalido no produto da sequencia {sequencia}"
        )

    return data


def texto_opcional(value):
    if value is None:
        return None

    texto = str(value).strip()
    return texto or None


def date_to_br(value):
    if value is None:
        return None
    if isinstance(value, (datetime, date)):
        return value.strftime("%d/%m/%Y")
    return str(value)


def token_expirado(expira_em):
    if expira_em is None:
        return True

    if isinstance(expira_em, date) and not isinstance(expira_em, datetime):
        expira_em = datetime.combine(expira_em, datetime.min.time())

    return expira_em < datetime.now()


def converter_decimal_opcional(valor, nome_campo, sequencia):
    if valor is None or valor == "":
        return None

    try:
        return Decimal(str(valor).replace(",", "."))
    except (InvalidOperation, ValueError, TypeError):
        raise ValueError(
            f"{nome_campo} invalido no produto da sequencia {sequencia}"
        )


# =========================================================
# PING
# =========================================================
@app.get("/ping")
def ping():
    return jsonify({
        "status": "ok",
        "service": "api-cotacao-nuvem",
        "time": datetime.now().isoformat(),
        "database": FB_DATABASE,
    })


# =========================================================
# ENVIAR COTAÇÃO COMPLETA PARA A NUVEM
# =========================================================
@app.post("/cotacoes/enviar")
def enviar_cotacao():
    """
    Payload esperado:
    {
      "empresa": 1,
      "cotacao": 102,
      "descricao": "Cotação semanal",
      "usuario": 10,
      "data_abertura": "2026-03-07",
      "data_fechamento": "2026-03-10",
      "itens": [
        {
          "produto_id": 123,
          "descricao": "ARROZ 5KG",
          "unidade": "FD",
          "quantidade": 10
        }
      ],
      "fornecedores": [
        {"id": 5},
        {"id": 7}
      ]
    }
    """

    data = request.json or {}

    empresa = int(data.get("empresa", 0))
    cotacao = data.get("cotacao")
    descricao = (data.get("descricao") or "").strip()
    usuario = data.get("usuario")
    data_abertura = parse_date(data.get("data_abertura")) or date.today()
    data_fechamento = parse_date(data.get("data_fechamento"))
    itens = data.get("itens") or []
    fornecedores = data.get("fornecedores") or []

    if not empresa or not cotacao:
        return jsonify({"ok": False, "message": "Empresa ou cotação não informada"}), 400

    if not itens:
        return jsonify({"ok": False, "message": "A cotação precisa ter ao menos 1 item"}), 400

    if not fornecedores:
        return jsonify({"ok": False, "message": "A cotação precisa ter ao menos 1 fornecedor"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        # Não deixa sobrescrever sem querer uma cotação já enviada
        cur.execute("""
            SELECT 1
            FROM TB_COTACAO
            WHERE COT_EMPRESA = ?
              AND COT_ID = ?
        """, (empresa, cotacao))

        if cur.fetchone():
            return jsonify({
                "ok": False,
                "message": "Esta cotação já existe na nuvem"
            }), 409

        # Cabeçalho
        cur.execute("""
            INSERT INTO TB_COTACAO (
                COT_EMPRESA,
                COT_ID,
                COT_STATUS,
                COT_DT_ABERTURA,
                COT_HORA_ABERTURA,
                COT_DT_FECHAMENTO,
                COT_DT_LANCAMENTO,
                COT_DESCRICAO,
                COT_USUARIO
            ) VALUES (?, ?, ?, ?, CURRENT_TIME, ?, CURRENT_DATE, ?, ?)
        """, (
            empresa,
            cotacao,
            'A',
            data_abertura,
            data_fechamento,
            descricao,
            usuario
        ))

        # Itens
        sequencia = 1
        for item in itens:
            produto_id = item.get("produto_id")
            item_descricao = (item.get("descricao") or "").strip()
            unidade = (item.get("unidade") or "").strip()
            quantidade = item.get("quantidade")

            if not produto_id or not item_descricao:
                con.rollback()
                return jsonify({
                    "ok": False,
                    "message": f"Item inválido na sequência {sequencia}"
                }), 400

            cur.execute("""
                INSERT INTO TB_COTACAO_ITEM (
                    COTI_EMPRESA,
                    COTI_COTACAO,
                    COTI_SEQUENCIA,
                    COTI_PRODUTO,
                    COTI_PRODUTO_DESCRICAO,
                    COTI_UNIDADE_COMPRA,
                    COTI_QUANTIDADE,
                    COTI_STATUS
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 'A')
            """, (
                empresa,
                cotacao,
                sequencia,
                produto_id,
                item_descricao,
                unidade,
                quantidade
            ))
            sequencia += 1

        # Lançamentos: 1 linha por fornecedor x item
        for fornecedor in fornecedores:
            fornecedor_id = fornecedor.get("id")
            if not fornecedor_id:
                con.rollback()
                return jsonify({
                    "ok": False,
                    "message": "Fornecedor inválido no payload"
                }), 400

            for item in itens:
                produto_id = item.get("produto_id")
                item_descricao = (item.get("descricao") or "").strip()
                unidade = (item.get("unidade") or "").strip()
                quantidade = item.get("quantidade")

                cur.execute("""
                    INSERT INTO TB_COTACAO_LANCAMENTO (
                        COTL_EMPRESA,
                        COTL_ID,
                        COTL_COTACAO,
                        COTL_FORNECEDOR,
                        COTL_PRODUTO,
                        COTL_PRECO_DIGITADO,
                        COTL_PRODUTO_DESCRICAO,
                        COTL_PRODUTO_UNIDADE,
                        COTL_QUANTIDADE
                    ) VALUES (
                        ?,
                        GEN_ID(GEN_TB_COTACAO_LANCAMENTO, 1),
                        ?, ?, ?, NULL, ?, ?, ?
                    )
                """, (
                    empresa,
                    cotacao,
                    fornecedor_id,
                    produto_id,
                    item_descricao,
                    unidade,
                    quantidade
                ))

        con.commit()

        return jsonify({
            "ok": True,
            "message": "Cotação enviada para a nuvem com sucesso",
            "empresa": empresa,
            "cotacao": cotacao,
            "itens": len(itens),
            "fornecedores": len(fornecedores),
        }), 201

    except Exception as e:
        if con:
            con.rollback()
        print("Erro enviar_cotacao:", e)
        return jsonify({
            "ok": False,
            "message": "Erro interno ao enviar cotação para a nuvem"
        }), 500
    finally:
        if con:
            con.close()


# =========================================================
# GERAR / REGERAR LINK INDIVIDUAL DO FORNECEDOR
# =========================================================
@app.post("/cotacoes/fornecedores/gerar_link")
def gerar_link_fornecedor():
    data = request.json or {}

    empresa = int(data.get("empresa", 0))
    cotacao = data.get("cotacao")
    fornecedor = data.get("fornecedor")

    if not all([empresa, cotacao, fornecedor]):
        return jsonify({
            "ok": False,
            "message": "Dados incompletos"
        }), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        # Verifica se existe lançamento para esse fornecedor nessa cotação
        cur.execute("""
            SELECT 1
            FROM TB_COTACAO_LANCAMENTO
            WHERE COTL_EMPRESA = ?
              AND COTL_COTACAO = ?
              AND COTL_FORNECEDOR = ?
            ROWS 1
        """, (empresa, cotacao, fornecedor))

        if not cur.fetchone():
            return jsonify({
                "ok": False,
                "message": "Fornecedor não está vinculado a esta cotação"
            }), 404

        # Reaproveita token ativo se houver
        cur.execute("""
            SELECT CTK_TOKEN, CTK_EXPIRA_EM, CTK_UTILIZADO
            FROM TB_COTACAO_TOKEN
            WHERE CTK_EMPRESA = ?
              AND CTK_COTACAO = ?
              AND CTK_FORNECEDOR = ?
        """, (empresa, cotacao, fornecedor))

        row = cur.fetchone()

        if row:
            token_atual, expira_em, utilizado = row
            if utilizado in ('N', 'E') and not token_expirado(expira_em):
                token = token_atual
            else:
                token = gerar_token()
                cur.execute("""
                    UPDATE TB_COTACAO_TOKEN
                    SET CTK_TOKEN = ?,
                        CTK_EXPIRA_EM = DATEADD(7 DAY TO CURRENT_TIMESTAMP),
                        CTK_UTILIZADO = 'N'
                    WHERE CTK_EMPRESA = ?
                      AND CTK_COTACAO = ?
                      AND CTK_FORNECEDOR = ?
                """, (token, empresa, cotacao, fornecedor))
        else:
            token = gerar_token()
            cur.execute("""
                INSERT INTO TB_COTACAO_TOKEN (
                    CTK_EMPRESA,
                    CTK_COTACAO,
                    CTK_FORNECEDOR,
                    CTK_TOKEN,
                    CTK_EXPIRA_EM,
                    CTK_UTILIZADO
                ) VALUES (?, ?, ?, ?, DATEADD(7 DAY TO CURRENT_TIMESTAMP), 'N')
            """, (
                empresa,
                cotacao,
                fornecedor,
                token
            ))

        con.commit()

        link = f"{BASE_LINK}/c/{token}"

        return jsonify({
            "ok": True,
            "empresa": empresa,
            "cotacao": cotacao,
            "fornecedor": fornecedor,
            "token": token,
            "link": link
        })

    except Exception as e:
        if con:
            con.rollback()
        print("Erro gerar_link_fornecedor:", e)
        return jsonify({
            "ok": False,
            "message": "Erro interno ao gerar link"
        }), 500
    finally:
        if con:
            con.close()


# =========================================================
# MARCAR LINK COMO ENVIADO
# =========================================================
@app.post("/cotacoes/fornecedor/marcar_enviado")
def marcar_fornecedor_enviado():
    data = request.json or {}

    empresa = data.get("empresa")
    cotacao = data.get("cotacao")
    fornecedor = data.get("fornecedor")

    if not all([empresa, cotacao, fornecedor]):
        return jsonify({
            "ok": False,
            "message": "Dados incompletos"
        }), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            UPDATE TB_COTACAO_TOKEN
            SET CTK_UTILIZADO = 'E'
            WHERE CTK_EMPRESA = ?
              AND CTK_COTACAO = ?
              AND CTK_FORNECEDOR = ?
              AND CTK_UTILIZADO = 'N'
        """, (empresa, cotacao, fornecedor))

        con.commit()

        return jsonify({
            "ok": True,
            "message": "Fornecedor marcado como enviado"
        })

    except Exception as e:
        if con:
            con.rollback()
        print("Erro marcar_fornecedor_enviado:", e)
        return jsonify({
            "ok": False,
            "message": "Erro interno"
        }), 500
    finally:
        if con:
            con.close()


# =========================================================
# VALIDAR TOKEN
# =========================================================
@app.get("/cotacoes/token/validar/<token>")
def validar_token(token):
    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                CTK_EMPRESA,
                CTK_COTACAO,
                CTK_FORNECEDOR,
                CTK_EXPIRA_EM,
                CTK_UTILIZADO
            FROM TB_COTACAO_TOKEN
            WHERE CTK_TOKEN = ?
        """, (token,))

        row = cur.fetchone()

        if not row:
            return jsonify({"ok": False, "message": "Token inválido"}), 404

        empresa, cotacao, fornecedor, expira_em, utilizado = row

        if utilizado == 'S':
            return jsonify({"ok": False, "message": "Token já utilizado"}), 403

        if token_expirado(expira_em):
            return jsonify({"ok": False, "message": "Token expirado"}), 403

        return jsonify({
            "ok": True,
            "empresa": empresa,
            "cotacao": cotacao,
            "fornecedor": fornecedor
        })

    except Exception as e:
        print("Erro validar_token:", e)
        return jsonify({"ok": False, "message": "Erro ao validar token"}), 500
    finally:
        if con:
            con.close()


# =========================================================
# DADOS DA COTAÇÃO PELO TOKEN
# =========================================================
@app.get("/cotacoes/token/dados/<token>")
def dados_cotacao_token(token):
    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                CTK_EMPRESA,
                CTK_COTACAO,
                CTK_FORNECEDOR,
                CTK_EXPIRA_EM,
                CTK_UTILIZADO
            FROM TB_COTACAO_TOKEN
            WHERE CTK_TOKEN = ?
        """, (token,))

        row = cur.fetchone()

        if not row:
            return jsonify({"ok": False, "message": "Token inválido"}), 404

        empresa, cotacao, fornecedor, expira_em, utilizado = row

        if utilizado == 'S':
            return jsonify({"ok": False, "message": "Token já utilizado"}), 403

        if token_expirado(expira_em):
            return jsonify({"ok": False, "message": "Token expirado"}), 403

        cur.execute("""
            SELECT
                COT_DESCRICAO,
                COT_DT_FECHAMENTO
            FROM TB_COTACAO
            WHERE COT_EMPRESA = ?
              AND COT_ID = ?
        """, (empresa, cotacao))

        cot = cur.fetchone()
        if not cot:
            return jsonify({"ok": False, "message": "Cotação não encontrada"}), 404

        descricao_cotacao, data_fechamento = cot

        cur.execute("""
            SELECT
                COTL_PRODUTO,
                COTL_PRODUTO_DESCRICAO,
                COTL_PRODUTO_UNIDADE,
                COTL_QUANTIDADE
            FROM TB_COTACAO_LANCAMENTO
            WHERE COTL_EMPRESA = ?
              AND COTL_COTACAO = ?
              AND COTL_FORNECEDOR = ?
            ORDER BY COTL_PRODUTO_DESCRICAO
        """, (empresa, cotacao, fornecedor))

        itens = []
        for row_item in cur.fetchall():
            itens.append({
                "produto_id": row_item[0],
                "descricao": row_item[1],
                "unidade": row_item[2],
                "quantidade": row_item[3],
            })

        return jsonify({
            "ok": True,
            "empresa": empresa,
            "cotacao": cotacao,
            "fornecedor": fornecedor,
            "descricao": descricao_cotacao,
            "validade": date_to_br(data_fechamento),
            "itens": itens
        })

    except Exception as e:
        print("Erro dados_cotacao_token:", e)
        return jsonify({"ok": False, "message": "Erro ao buscar dados da cotação"}), 500
    finally:
        if con:
            con.close()


# =========================================================
# FORNECEDOR RESPONDE A COTAÇÃO PELO TOKEN
# =========================================================
@app.post("/cotacoes/token/responder/<token>")
def responder_cotacao_token(token):
    data = request.json or {}
    itens = data.get("itens") or []

    if not itens:
        return jsonify({"ok": False, "message": "Nenhum item informado"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                CTK_EMPRESA,
                CTK_COTACAO,
                CTK_FORNECEDOR,
                CTK_EXPIRA_EM,
                CTK_UTILIZADO
            FROM TB_COTACAO_TOKEN
            WHERE CTK_TOKEN = ?
        """, (token,))

        row = cur.fetchone()
        if not row:
            return jsonify({"ok": False, "message": "Token inválido"}), 404

        empresa, cotacao, fornecedor, expira_em, utilizado = row

        if utilizado == 'S':
            return jsonify({"ok": False, "message": "Token já utilizado"}), 403

        if token_expirado(expira_em):
            return jsonify({"ok": False, "message": "Token expirado"}), 403

        atualizados = 0

        for item in itens:
            produto_id = item.get("produto_id")
            preco = item.get("preco")

            if produto_id is None or preco in (None, ""):
                continue

            cur.execute("""
                UPDATE TB_COTACAO_LANCAMENTO
                SET COTL_PRECO_DIGITADO = ?
                WHERE COTL_EMPRESA = ?
                  AND COTL_COTACAO = ?
                  AND COTL_FORNECEDOR = ?
                  AND COTL_PRODUTO = ?
            """, (
                preco,
                empresa,
                cotacao,
                fornecedor,
                produto_id
            ))

            atualizados += 1

        if atualizados == 0:
            con.rollback()
            return jsonify({
                "ok": False,
                "message": "Nenhum preço válido foi informado"
            }), 400

        cur.execute("""
            UPDATE TB_COTACAO_TOKEN
            SET CTK_UTILIZADO = 'S'
            WHERE CTK_TOKEN = ?
        """, (token,))

        con.commit()

        return jsonify({
            "ok": True,
            "message": "Cotação respondida com sucesso"
        })

    except Exception as e:
        if con:
            con.rollback()
        print("Erro responder_cotacao_token:", e)
        return jsonify({"ok": False, "message": "Erro ao gravar cotação"}), 500
    finally:
        if con:
            con.close()


# =========================================================
# LINK CURTO /c/<token>
# =========================================================
@app.get("/c/<token>")
def acesso_cotacao_por_token(token):
    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                CTK_UTILIZADO,
                CTK_EXPIRA_EM
            FROM TB_COTACAO_TOKEN
            WHERE CTK_TOKEN = ?
        """, (token,))

        row = cur.fetchone()
        if not row:
            return "Link inválido", 404

        utilizado, expira_em = row

        if utilizado == 'S':
            return "Este link já foi utilizado", 410

        if token_expirado(expira_em):
            return "Este link expirou", 410

        return redirect(f"/static/cotacao.html?token={token}")

    except Exception as e:
        print("Erro /c/<token>:", e)
        return "Erro interno", 500
    finally:
        if con:
            con.close()


# =========================================================
# ERP LOCAL BUSCA AS RESPOSTAS DA NUVEM
# =========================================================
@app.get("/cotacoes/<int:cot_id>/respostas")
def buscar_respostas_cotacao(cot_id):
    empresa = int(request.args.get("empresa", 0))

    if not empresa:
        return jsonify({"ok": False, "message": "Empresa não informada"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                COTL_FORNECEDOR,
                COTL_PRODUTO,
                COTL_PRODUTO_DESCRICAO,
                COTL_PRODUTO_UNIDADE,
                COTL_QUANTIDADE,
                COTL_PRECO_DIGITADO
            FROM TB_COTACAO_LANCAMENTO
            WHERE COTL_EMPRESA = ?
              AND COTL_COTACAO = ?
            ORDER BY COTL_FORNECEDOR, COTL_PRODUTO_DESCRICAO
        """, (empresa, cot_id))

        rows = cur.fetchall()

        return jsonify({
            "ok": True,
            "empresa": empresa,
            "cotacao": cot_id,
            "respostas": [
                {
                    "fornecedor": r[0],
                    "produto_id": r[1],
                    "descricao": r[2],
                    "unidade": r[3],
                    "quantidade": r[4],
                    "preco_digitado": float(r[5]) if r[5] is not None else None,
                }
                for r in rows
            ]
        })

    except Exception as e:
        print("Erro buscar_respostas_cotacao:", e)
        return jsonify({"ok": False, "message": "Erro ao buscar respostas"}), 500
    finally:
        if con:
            con.close()



# =========================================================
# PORTAL — SINCRONIZAÇÃO DE PRODUTOS
# =========================================================
@app.post("/portal/<identificador>/sincronizar-produtos")
def sincronizar_produtos_portal(identificador):
    """
    Envia produtos do ERP local para o cliente correspondente na nuvem.

    Cabeçalho:
        X-Portal-Token: token secreto do cliente

    Payload:
    {
      "produtos": [
        {
          "produto": 101,
          "descricao": "TECIDO OXFORD BRANCO",
          "unidade": "MT",
          "codigo_barras": "7890000000001",
          "estoque": 125.5000,
          "custo": 7.0000,
          "preco": 19.9000
        }
      ]
    }
    """

    identificador = (identificador or "").strip().lower()
    token = (request.headers.get("X-Portal-Token") or "").strip()
    data = request.get_json(silent=True) or {}
    produtos = data.get("produtos")

    if not identificador:
        return jsonify({
            "ok": False,
            "message": "Cliente não informado"
        }), 400

    if not token:
        return jsonify({
            "ok": False,
            "message": "Token de sincronização não informado"
        }), 401

    if not isinstance(produtos, list) or not produtos:
        return jsonify({
            "ok": False,
            "message": "Nenhum produto informado"
        }), 400

    if len(produtos) > 5000:
        return jsonify({
            "ok": False,
            "message": "O limite por envio é de 5000 produtos"
        }), 400

    def converter_decimal(valor, nome_campo, sequencia):
        if valor is None or valor == "":
            return Decimal("0")

        try:
            return Decimal(str(valor).replace(",", "."))
        except (InvalidOperation, ValueError, TypeError):
            raise ValueError(
                f"{nome_campo} inválido no produto da sequência {sequencia}"
            )

    con = None

    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                PCL_ID,
                PCL_NOME_FANTASIA
            FROM TB_PORTAL_CLIENTE
            WHERE LOWER(PCL_IDENTIFICADOR) = ?
              AND PCL_TOKEN = ?
              AND PCL_ATIVO = 'S'
        """, (identificador, token))

        cliente = cur.fetchone()

        if not cliente:
            return jsonify({
                "ok": False,
                "message": "Cliente ou token inválido"
            }), 401

        cliente_id = cliente[0]
        cliente_nome = cliente[1]
        processados = 0

        for sequencia, item in enumerate(produtos, start=1):
            if not isinstance(item, dict):
                con.rollback()
                return jsonify({
                    "ok": False,
                    "message": f"Produto inválido na sequência {sequencia}"
                }), 400

            try:
                produto_id = int(item.get("produto", 0))
            except (ValueError, TypeError):
                produto_id = 0

            descricao = (item.get("descricao") or "").strip()
            unidade = (item.get("unidade") or "").strip()
            codigo_barras = str(
                item.get("codigo_barras") or ""
            ).strip()

            if produto_id <= 0:
                con.rollback()
                return jsonify({
                    "ok": False,
                    "message": (
                        f"Código do produto inválido "
                        f"na sequência {sequencia}"
                    )
                }), 400

            if not descricao:
                con.rollback()
                return jsonify({
                    "ok": False,
                    "message": (
                        f"Descrição não informada "
                        f"no produto {produto_id}"
                    )
                }), 400

            if len(descricao) > 200:
                con.rollback()
                return jsonify({
                    "ok": False,
                    "message": (
                        f"Descrição excede 200 caracteres "
                        f"no produto {produto_id}"
                    )
                }), 400

            if len(unidade) > 20:
                con.rollback()
                return jsonify({
                    "ok": False,
                    "message": (
                        f"Unidade excede 20 caracteres "
                        f"no produto {produto_id}"
                    )
                }), 400

            if len(codigo_barras) > 50:
                con.rollback()
                return jsonify({
                    "ok": False,
                    "message": (
                        f"Código de barras excede 50 caracteres "
                        f"no produto {produto_id}"
                    )
                }), 400

            try:
                estoque = converter_decimal(
                    item.get("estoque"),
                    "Estoque",
                    sequencia
                )
                preco = converter_decimal(
                    item.get("preco"),
                    "Preço",
                    sequencia
                )
                custo_informado = "custo" in item
                custo = (
                    converter_decimal_opcional(
                        item.get("custo"),
                        "Custo",
                        sequencia
                    )
                    if custo_informado
                    else None
                )

                campos_ultima_compra = (
                    "data_ultima_compra",
                    "nota_ultima_compra",
                    "serie_ultima_compra"
                )
                ultima_compra_informada = any(
                    campo in item
                    for campo in campos_ultima_compra
                )
                data_ultima_compra = converter_timestamp_opcional(
                    item.get("data_ultima_compra"),
                    "Data da ultima compra",
                    sequencia
                )
                nota_ultima_compra = texto_opcional(
                    item.get("nota_ultima_compra")
                )
                serie_ultima_compra = texto_opcional(
                    item.get("serie_ultima_compra")
                )

                if nota_ultima_compra and len(nota_ultima_compra) > 30:
                    raise ValueError(
                        "Nota da ultima compra excede 30 caracteres "
                        f"no produto da sequencia {sequencia}"
                    )

                if serie_ultima_compra and len(serie_ultima_compra) > 10:
                    raise ValueError(
                        "Serie da ultima compra excede 10 caracteres "
                        f"no produto da sequencia {sequencia}"
                    )
            except ValueError as erro_validacao:
                con.rollback()
                return jsonify({
                    "ok": False,
                    "message": str(erro_validacao)
                }), 400

            colunas = [
                "PPR_CLIENTE",
                "PPR_PRODUTO",
                "PPR_DESCRICAO",
                "PPR_UNIDADE",
                "PPR_CODIGO_BARRAS",
                "PPR_ESTOQUE",
            ]
            valores = [
                cliente_id,
                produto_id,
                descricao,
                unidade or None,
                codigo_barras or None,
                estoque,
            ]

            if custo_informado:
                colunas.append("PPR_CUSTO")
                valores.append(custo)

            colunas.append("PPR_PRECO")
            valores.append(preco)

            if ultima_compra_informada:
                colunas.extend([
                    "PPR_DT_ULTIMA_COMPRA",
                    "PPR_NF_ULTIMA_COMPRA",
                    "PPR_SERIE_ULTIMA_COMPRA",
                ])
                valores.extend([
                    data_ultima_compra,
                    nota_ultima_compra,
                    serie_ultima_compra,
                ])

            colunas.append("PPR_DT_ATUALIZACAO")

            parametros = ", ".join("?" for _ in valores)
            valores_sql = f"{parametros}, CURRENT_TIMESTAMP"

            cur.execute(f"""
                UPDATE OR INSERT INTO TB_PORTAL_PRODUTO (
                    {", ".join(colunas)}
                )
                VALUES ({valores_sql})
                MATCHING (PPR_CLIENTE, PPR_PRODUTO)
            """, tuple(valores))

            processados += 1

        con.commit()

        return jsonify({
            "ok": True,
            "cliente": identificador,
            "nome_fantasia": cliente_nome,
            "produtos_processados": processados,
            "message": "Sincronização concluída com sucesso"
        })

    except Exception as e:
        if con:
            con.rollback()

        print("Erro sincronizar_produtos_portal:", e)

        return jsonify({
            "ok": False,
            "message": "Erro interno durante a sincronização"
        }), 500

    finally:
        if con:
            con.close()



# =========================================================
# PORTAL — TELA
# =========================================================
@app.get("/portal/<identificador>")
def tela_portal(identificador):
    return send_from_directory(
        os.path.join(app.root_path, "static", "portal"),
        "index.html"
    )


# =========================================================
# PORTAL — LOGIN
# =========================================================
@app.post("/portal/<identificador>/login")
def login_portal(identificador):
    from werkzeug.security import check_password_hash

    dados = request.get_json(silent=True) or {}

    usuario = str(dados.get("usuario") or "").strip()
    senha = str(dados.get("senha") or "")

    if not usuario or not senha:
        return jsonify({
            "ok": False,
            "message": "Usuário e senha são obrigatórios"
        }), 400

    con = get_connection()
    cur = con.cursor()

    try:
        cur.execute("""
            SELECT
                C.PCL_ID,
                C.PCL_NOME_FANTASIA,
                U.PUS_USUARIO,
                U.PUS_NOME,
                U.PUS_SENHA_HASH
            FROM TB_PORTAL_CLIENTE C
            JOIN TB_PORTAL_USUARIO U
              ON U.PUS_CLIENTE = C.PCL_ID
            WHERE C.PCL_IDENTIFICADOR = ?
              AND C.PCL_ATIVO = 'S'
              AND UPPER(U.PUS_USUARIO) = UPPER(?)
              AND U.PUS_ATIVO = 'S'
        """, (
            identificador,
            usuario
        ))

        registro = cur.fetchone()

        if not registro:
            return jsonify({
                "ok": False,
                "message": "Usuário ou senha inválidos"
            }), 401

        cliente_id = registro[0]
        cliente_nome = registro[1]
        usuario_banco = registro[2]
        usuario_nome = registro[3]
        senha_hash = registro[4]

        if not senha_hash or not check_password_hash(senha_hash, senha):
            return jsonify({
                "ok": False,
                "message": "Usuário ou senha inválidos"
            }), 401

        session.clear()
        session.permanent = True

        session["portal_cliente_id"] = cliente_id
        session["portal_identificador"] = identificador
        session["portal_nome_fantasia"] = cliente_nome
        session["portal_usuario"] = usuario_banco
        session["portal_nome_usuario"] = usuario_nome

        return jsonify({
            "ok": True,
            "message": "Login realizado com sucesso",
            "cliente": identificador,
            "cliente_id": cliente_id,
            "nome_fantasia": cliente_nome,
            "usuario": usuario_banco,
            "nome_usuario": usuario_nome
        }), 200

    except Exception as erro:
        print(
            "Erro no login do portal:",
            type(erro).__name__,
            str(erro)
        )

        return jsonify({
            "ok": False,
            "message": "Não foi possível realizar o login"
        }), 500

    finally:
        con.close()


# =========================================================
# PORTAL — LOGOUT
# =========================================================
@app.post("/portal/<identificador>/logout")
def logout_portal(identificador):
    session.clear()

    return jsonify({
        "ok": True,
        "message": "Sessão encerrada com sucesso",
        "cliente": identificador
    }), 200


# =========================================================
# PORTAL — CONSULTA DE PRODUTOS
# =========================================================
@app.get("/portal/<identificador>/produtos")
def consultar_produtos_portal(identificador):
    """
    Consulta os produtos sincronizados de um cliente.

    Autenticação aceita:
        - sessão válida do mesmo cliente; ou
        - X-Portal-Token válido.

    Parâmetros opcionais:
        limite: quantidade máxima de produtos, entre 1 e 100
        busca: descrição, código do produto ou código de barras
    """

    identificador = (identificador or "").strip().lower()
    token = (request.headers.get("X-Portal-Token") or "").strip()

    if not identificador:
        return jsonify({
            "ok": False,
            "message": "Cliente não informado"
        }), 400

    try:
        limite = int(request.args.get("limite", 100))
    except (ValueError, TypeError):
        return jsonify({
            "ok": False,
            "message": "Limite inválido"
        }), 400

    if limite < 1:
        limite = 1

    if limite > 100:
        limite = 100

    con = None

    try:
        con = get_connection()
        cur = con.cursor()

        # -----------------------------------------------------
        # IDENTIFICA O CLIENTE
        # -----------------------------------------------------
        cur.execute("""
            SELECT
                PCL_ID,
                PCL_NOME_FANTASIA,
                PCL_TOKEN
            FROM TB_PORTAL_CLIENTE
            WHERE LOWER(PCL_IDENTIFICADOR) = ?
              AND PCL_ATIVO = 'S'
        """, (identificador,))

        cliente = cur.fetchone()

        if not cliente:
            return jsonify({
                "ok": False,
                "message": "Acesso não autorizado"
            }), 401

        cliente_id = cliente[0]
        cliente_nome = cliente[1]
        cliente_token = str(cliente[2] or "")

        # -----------------------------------------------------
        # AUTORIZA POR SESSÃO DO MESMO CLIENTE OU POR TOKEN
        # -----------------------------------------------------
        sessao_cliente_id = session.get("portal_cliente_id")
        sessao_identificador = (
            session.get("portal_identificador") or ""
        ).strip().lower()

        sessao_valida = (
            sessao_cliente_id == cliente_id
            and sessao_identificador == identificador
        )

        token_valido = (
            bool(token)
            and bool(cliente_token)
            and secrets.compare_digest(token, cliente_token)
        )

        if not sessao_valida and not token_valido:
            return jsonify({
                "ok": False,
                "message": "Acesso não autorizado"
            }), 401

        busca = (request.args.get("busca") or "").strip()

        # O limite é convertido e controlado acima.
        # Por isso pode ser aplicado diretamente no FIRST.
        if busca:
            busca_like = f"%{busca.upper()}%"

            sql = f"""
                SELECT FIRST {limite}
                    PPR_PRODUTO,
                    PPR_DESCRICAO,
                    PPR_UNIDADE,
                    PPR_CODIGO_BARRAS,
                    PPR_ESTOQUE,
                    PPR_CUSTO,
                    PPR_PRECO,
                    PPR_DT_ATUALIZACAO,
                    PPR_DT_ULTIMA_COMPRA,
                    PPR_NF_ULTIMA_COMPRA,
                    PPR_SERIE_ULTIMA_COMPRA
                FROM TB_PORTAL_PRODUTO
                WHERE PPR_CLIENTE = ?
                  AND (
                        UPPER(PPR_DESCRICAO) LIKE ?
                     OR CAST(PPR_PRODUTO AS VARCHAR(20)) = ?
                     OR PPR_CODIGO_BARRAS = ?
                  )
                ORDER BY PPR_DESCRICAO, PPR_PRODUTO
            """

            cur.execute(sql, (
                cliente_id,
                busca_like,
                busca,
                busca
            ))
        else:
            sql = f"""
                SELECT FIRST {limite}
                    PPR_PRODUTO,
                    PPR_DESCRICAO,
                    PPR_UNIDADE,
                    PPR_CODIGO_BARRAS,
                    PPR_ESTOQUE,
                    PPR_CUSTO,
                    PPR_PRECO,
                    PPR_DT_ATUALIZACAO,
                    PPR_DT_ULTIMA_COMPRA,
                    PPR_NF_ULTIMA_COMPRA,
                    PPR_SERIE_ULTIMA_COMPRA
                FROM TB_PORTAL_PRODUTO
                WHERE PPR_CLIENTE = ?
                ORDER BY PPR_DESCRICAO, PPR_PRODUTO
            """

            cur.execute(sql, (cliente_id,))

        linhas = cur.fetchall()

        produtos = []

        for linha in linhas:
            produtos.append({
                "produto": linha[0],
                "descricao": linha[1],
                "unidade": linha[2],
                "codigo_barras": linha[3],
                "estoque": (
                    float(linha[4])
                    if linha[4] is not None
                    else 0
                ),
                "custo": (
                    float(linha[5])
                    if linha[5] is not None
                    else None
                ),
                "preco": (
                    float(linha[6])
                    if linha[6] is not None
                    else 0
                ),
                "data_atualizacao": timestamp_to_str(linha[7]),
                "data_ultima_compra": timestamp_to_str(linha[8]),
                "nota_ultima_compra": texto_opcional(linha[9]),
                "serie_ultima_compra": texto_opcional(linha[10])
            })

        return jsonify({
            "ok": True,
            "cliente": identificador,
            "nome_fantasia": cliente_nome,
            "quantidade": len(produtos),
            "limite": limite,
            "busca": busca or None,
            "produtos": produtos
        })

    except Exception as e:
        print("Erro consultar_produtos_portal:", e)

        return jsonify({
            "ok": False,
            "message": "Erro interno durante a consulta"
        }), 500

    finally:
        if con:
            con.close()


# =========================================================
# START
# =========================================================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
