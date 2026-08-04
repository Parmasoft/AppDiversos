from flask import Flask, request, jsonify
import fdb
from datetime import datetime, date, time
import secrets
from datetime import timedelta
import fdb
from flask import redirect, abort
from flask import redirect
from datetime import datetime
import requests

def gerar_token():
    # token seguro, impossível de adivinhar
    return secrets.token_urlsafe(32)  
  
    
app = Flask(__name__)    

# ==================================================
# CONFIG NUVEM
# ==================================================
API_NUVEM_BASE = "http://165.227.77.226:5000"
#API_NUVEM_BASE = "https://cotacao.parmasoft.com.br"

# ==================================================
# PING
# ==================================================
@app.route("/ping")
def ping():
    return {
        "status": "ok",
        "service": "api-parmatechstore",
        "time": datetime.now().isoformat()
    }


# ==================================================
# CONEXÃO FIREBIRD
# ==================================================
def get_connection():
    return fdb.connect(
        host="localhost",
        database=r"E:\Dados Clientes\Horti Frutti Cohab\Dados.FDB",
        user="SYSDBA",
        password="masterkey",
        charset="ISO8859_1"
    )


# ==================================================
# UTIL – PARSE DE DATA (YYYY-MM-DD ou DD/MM/YYYY)
# ==================================================
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
        except Exception:
            pass

    return None


# ==================================================
# ABRIR NOVA COTAÇÃO
# ==================================================
@app.route("/cotacoes/abrir", methods=["POST"])
def abrir_cotacao():
    data = request.json or {}

    empresa = int(data.get("empresa", 0))
    usuario = data.get("usuario")

    if not empresa or not usuario:
        return jsonify({"erro": "Empresa ou usuário não informado"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            INSERT INTO TB_COTACAO (
                COT_EMPRESA,
                COT_STATUS,
                COT_DT_ABERTURA,
                COT_HORA_ABERTURA,
                COT_DT_LANCAMENTO,
                COT_USUARIO
            ) VALUES (?, ?, CURRENT_DATE, CURRENT_TIME, CURRENT_DATE, ?)
        """, (
            empresa,
            'A',
            usuario
        ))

        cur.execute("""
            SELECT COT_ID
            FROM TB_COTACAO
            WHERE COT_EMPRESA = ?
            ORDER BY COT_ID DESC
            ROWS 1
        """, (empresa,))

        row = cur.fetchone()
        cot_id = row[0] if row else None

        con.commit()

        return jsonify({
            "status": "ok",
            "cot_id": cot_id,
            "data_abertura": date.today().strftime("%d/%m/%Y")
        })

    except Exception as e:
        if con:
            con.rollback()
        print("Erro abrir cotação:", e)
        return jsonify({"erro": "Erro ao abrir cotação"}), 500
    finally:
        if con:
            con.close()


# ==================================================
# ATUALIZAR DATAS + DESCRIÇÃO
# ==================================================
@app.route("/cotacoes/atualizar-datas", methods=["POST"])
def atualizar_datas():
    data = request.json or {}

    empresa = int(data.get("empresa", 0))
    cot_id = data.get("cot_id")
    descricao = data.get("descricao")
    dt_abertura = parse_date(data.get("data_abertura"))
    dt_fechamento = parse_date(data.get("data_fechamento"))

    if not empresa or not cot_id:
        return jsonify({"erro": "Empresa ou cotação não informada"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            UPDATE TB_COTACAO
            SET
                COT_DT_ABERTURA = ?,
                COT_DT_FECHAMENTO = ?,
                COT_DESCRICAO = ?
            WHERE COT_EMPRESA = ?
              AND COT_ID = ?
        """, (
            dt_abertura,
            dt_fechamento,
            descricao,
            empresa,
            cot_id
        ))

        con.commit()
        return jsonify({"status": "ok"})

    except Exception as e:
        if con:
            con.rollback()
        print("Erro atualizar cotação:", e)
        return jsonify({"erro": "Erro ao atualizar cotação"}), 500
    finally:
        if con:
            con.close()


# ==================================================
# BUSCAR COTAÇÃO
# ==================================================
@app.route("/cotacoes/<int:cot_id>", methods=["GET"])
def buscar_cotacao(cot_id):
    empresa = int(request.args.get("empresa", 0))

    if not empresa:
        return jsonify({"erro": "Empresa não informada"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                COT_ID,
                COT_STATUS,
                COT_DT_ABERTURA,
                COT_DT_FECHAMENTO,
                COT_DESCRICAO
            FROM TB_COTACAO
            WHERE COT_EMPRESA = ?
              AND COT_ID = ?
        """, (empresa, cot_id))

        r = cur.fetchone()
        if not r:
            return jsonify({"erro": "Cotação não encontrada"}), 404

        return jsonify({
            "cot_id": r[0],
            "status": r[1],
            "data_abertura": r[2].strftime("%d/%m/%Y") if r[2] else None,
            "data_fechamento": r[3].strftime("%d/%m/%Y") if r[3] else None,
            "descricao": r[4],
        })

    except Exception as e:
        print("Erro buscar cotação:", e)
        return jsonify({"erro": "Erro ao buscar cotação"}), 500
    finally:
        if con:
            con.close()


# ==================================================
# LISTAR COTAÇÕES (GRID)
# ==================================================
@app.route("/cotacoes", methods=["GET"])
def listar_cotacoes():
    empresa = int(request.args.get("empresa", 0))

    if not empresa:
        return jsonify({"erro": "Empresa não informada"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                COT_ID,
                COT_DT_ABERTURA,
                COT_DT_FECHAMENTO,
                COT_STATUS,
                COT_DESCRICAO
            FROM TB_COTACAO
            WHERE COT_EMPRESA = ?
            ORDER BY COT_ID DESC
        """, (empresa,))

        rows = cur.fetchall()

        return jsonify([
            {
                "cot_id": r[0],
                "data_abertura": r[1].strftime("%d/%m/%Y") if r[1] else None,
                "data_fechamento": r[2].strftime("%d/%m/%Y") if r[2] else None,
                "status": r[3],
                "descricao": r[4],
            }
            for r in rows
        ])

    except Exception as e:
        print("Erro listar cotações:", e)
        return jsonify({"erro": "Erro ao listar cotações"}), 500
    finally:
        if con:
            con.close()


# ==================================================
# === COTAÇÃO ITENS – TB_COTACAO_ITEM (NOVO) ===
# ==================================================

# --------------------------------------------------
# BUSCAR PRODUTOS (AUTOCOMPLETE)
# --------------------------------------------------
@app.route("/produtos/busca", methods=["GET"])
def buscar_produtos():
    descricao = request.args.get("descricao", "").strip()
    empresa = int(request.args.get("empresa", 0))

    if not empresa or len(descricao) < 3:
        return jsonify([])

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                PRD_ID,
                PRD_DESCRICAO,
                PRD_UN_COMPRA,
                PRD_PRECO_VENDA
            FROM TB_PRODUTO
            WHERE PRD_EMPRESA = ?
              AND PRD_DESCRICAO CONTAINING ?
            ORDER BY PRD_DESCRICAO
            ROWS 20
        """, (empresa, descricao))

        return jsonify([
            {
                "id": r[0],
                "descricao": r[1],
                "unidade": r[2],
                "preco": float(r[3] or 0),
            }
            for r in cur.fetchall()
        ])

    except Exception as e:
        print("Erro buscar produtos:", e)
        return jsonify({"erro": str(e)}), 500
    finally:
        if con:
            con.close()

# --------------------------------------------------
# ALTERAR QUANTIDADE DO ITEM
# --------------------------------------------------
@app.route("/cotacoes/itens/alterar_quantidade", methods=["POST"])
def alterar_quantidade_item():
    data = request.json or {}

    empresa = int(data.get("empresa", 0))
    cotacao = data.get("cotacao")
    sequencia = data.get("sequencia")
    quantidade = data.get("quantidade")

    if not all([empresa, cotacao, sequencia, quantidade]):
        return jsonify({
            "ok": False,
            "message": "Dados incompletos para alterar quantidade"
        }), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            UPDATE TB_COTACAO_ITEM
               SET COTI_QUANTIDADE = ?
             WHERE COTI_EMPRESA = ?
               AND COTI_COTACAO = ?
               AND COTI_SEQUENCIA = ?
               AND COTI_STATUS = 'A'
        """, (
            quantidade,
            empresa,
            cotacao,
            sequencia
        ))

        # 🔒 BLINDAGEM: garante que algo foi alterado
        if cur.rowcount == 0:
            con.rollback()
            return jsonify({
                "ok": False,
                "message": "Item não encontrado ou já inativo"
            }), 404

        con.commit()
        return jsonify({
            "ok": True,
            "message": "Quantidade alterada com sucesso"
        }), 200

    except Exception as e:
        if con:
            con.rollback()
        print("Erro alterar quantidade:", e)
        return jsonify({
            "ok": False,
            "message": "Erro interno ao alterar quantidade"
        }), 500

    finally:
        if con:
            con.close()



# --------------------------------------------------
# LISTAR ITENS DA COTAÇÃO (GRID)
# --------------------------------------------------
@app.route("/cotacoes/<int:cot_id>/itens", methods=["GET"])
def listar_itens_cotacao(cot_id):
    empresa = int(request.args.get("empresa", 0))

    if not empresa:
        return jsonify({"erro": "Empresa não informada"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                COTI_SEQUENCIA,
                COTI_PRODUTO,
                COTI_PRODUTO_DESCRICAO,
                COTI_UNIDADE_COMPRA,
                COTI_QUANTIDADE
            FROM TB_COTACAO_ITEM
            WHERE COTI_EMPRESA = ?
              AND COTI_COTACAO = ?
              AND COTI_STATUS = 'A'
            ORDER BY COTI_SEQUENCIA DESC
        """, (empresa, cot_id))

        rows = cur.fetchall()

        return jsonify([
            {
                "sequencia": r[0],
                "produto": r[1],
                "descricao": r[2],
                "unidade": r[3],
                "quantidade": r[4],
            }
            for r in rows
        ])

    except Exception as e:
        print("Erro listar itens:", e)
        return jsonify({"erro": "Erro ao listar itens"}), 500
    finally:
        if con:
            con.close()



# --------------------------------------------------
# INCLUIR ITEM NA COTAÇÃO
# --------------------------------------------------
@app.route("/cotacoes/itens/incluir", methods=["POST"])
def incluir_item_cotacao():
    data = request.json or {}

    empresa = int(data.get("empresa", 0))
    cotacao = data.get("cotacao")
    produto = data.get("produto")
    descricao = data.get("descricao")
    unidade = data.get("unidade")
    quantidade = data.get("quantidade")

    if not all([empresa, cotacao, produto, quantidade]):
        return jsonify({"erro": "Dados incompletos"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        # Verifica duplicidade
        cur.execute("""
            SELECT 1
            FROM TB_COTACAO_ITEM
            WHERE COTI_EMPRESA = ?
              AND COTI_COTACAO = ?
              AND COTI_PRODUTO = ?
              AND COTI_STATUS = 'A'
        """, (empresa, cotacao, produto))

        if cur.fetchone():
            return jsonify({"erro": "Produto já existe na cotação"}), 409

        # Próxima sequência
        cur.execute("""
            SELECT COALESCE(MAX(COTI_SEQUENCIA), 0) + 1
            FROM TB_COTACAO_ITEM
            WHERE COTI_EMPRESA = ?
              AND COTI_COTACAO = ?
        """, (empresa, cotacao))

        sequencia = cur.fetchone()[0]

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
            produto,
            descricao,
            unidade,
            quantidade
        ))

        con.commit()
        return jsonify({"status": "ok", "sequencia": sequencia})

    except Exception as e:
        if con:
            con.rollback()
        print("Erro incluir item:", e)
        return jsonify({"erro": "Erro ao incluir item"}), 500
    finally:
        if con:
            con.close()



# --------------------------------------------------
# EXCLUIR ITEM (LÓGICO)
# --------------------------------------------------
@app.route("/cotacoes/itens/excluir", methods=["POST"])
def excluir_item_cotacao():
    data = request.json or {}

    empresa = int(data.get("empresa", 0))
    cotacao = data.get("cotacao")
    sequencia = data.get("sequencia")

    if not all([empresa, cotacao, sequencia]):
        return jsonify({"erro": "Dados incompletos"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            UPDATE TB_COTACAO_ITEM
            SET COTI_STATUS = 'C'
            WHERE COTI_EMPRESA = ?
              AND COTI_COTACAO = ?
              AND COTI_SEQUENCIA = ?
        """, (empresa, cotacao, sequencia))

        con.commit()
        return jsonify({"status": "ok"})

    except Exception as e:
        if con:
            con.rollback()
        print("Erro excluir item:", e)
        return jsonify({"erro": "Erro ao excluir item"}), 500
    finally:
        if con:
            con.close()

# --------------------------------------------------
# LISTAR FORNECEDORES
# --------------------------------------------------
@app.route("/fornecedores", methods=["GET"])
def listar_fornecedores():
    empresa = int(request.args.get("empresa", 0))

    if not empresa:
        return jsonify({"erro": "Empresa não informada"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                FOR_ID,
                FOR_RSOCIAL_NOME,
                FOR_FANTASIA_APELIDO,
                FOR_CNPJ_CPF,
                FOR_TELEFONE
            FROM TB_FORNECEDOR
            WHERE FOR_EMPRESA = ?
              AND FOR_STATUS = 'A'
            ORDER BY FOR_RSOCIAL_NOME
        """, (empresa,))

        return jsonify([
            {
                "id": r[0],
                "razao": r[1],
                "fantasia": r[2],
                "cnpj": r[3],
                "telefone": r[4],
            }
            for r in cur.fetchall()
        ])

    except Exception as e:
        print("Erro listar fornecedores:", e)
        return jsonify({"erro": "Erro ao listar fornecedores"}), 500
    finally:
        if con:
            con.close()

# --------------------------------------------------
# INCLUIR FORNECEDOR NA COTAÇÃO
# --------------------------------------------------
@app.route("/cotacoes/fornecedores/incluir", methods=["POST"])
def incluir_fornecedor_cotacao():
    data = request.json or {}

    empresa = int(data.get("empresa", 0))
    cotacao = data.get("cotacao")
    fornecedor = data.get("fornecedor")

    if not all([empresa, cotacao, fornecedor]):
        return jsonify({
            "ok": False,
            "message": "Dados incompletos para incluir fornecedor"
        }), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        # 🔒 Já existe fornecedor nessa cotação?
        # 🔍 Buscar dados de contato do fornecedor
        cur.execute("""
            SELECT
                FOR_TELEFONE,
                FOR_CELULAR,
                FOR_EMAIL
            FROM TB_FORNECEDOR
            WHERE FOR_EMPRESA = ?
              AND FOR_ID = ?
              AND FOR_STATUS = 'A'
        """, (empresa, fornecedor))

        row = cur.fetchone()

        if not row:
            return jsonify({
                "ok": False,
                "message": "Fornecedor não encontrado ou inativo"
            }), 404

        telefone, celular, email = row
        
        telefone = telefone.strip() if telefone else ''
        celular = celular.strip() if celular else ''
        email = email.strip() if email else ''
        

        # 🚫 Censura: precisa ter telefone (ou celular) E e-mail
        tem_telefone = bool(telefone)
        tem_celular = bool(celular)

        if not (tem_telefone or tem_celular):
            return jsonify({
                 "ok": False,
                 "message": "Fornecedor sem telefone ou WhatsApp cadastrado"
            }), 400

        if not email:
            return jsonify({
                 "ok": False,
                 "message": "Fornecedor sem e-mail cadastrado"
            }), 400            
            
        # 🔒 Já existe fornecedor nessa cotação?
        cur.execute("""
            SELECT 1
            FROM TB_COTACAO_LANCAMENTO
            WHERE COTL_EMPRESA = ?
              AND COTL_COTACAO = ?
              AND COTL_FORNECEDOR = ?
        """, (empresa, cotacao, fornecedor))            

        if cur.fetchone():
            return jsonify({
                "ok": False,
                "message": "Fornecedor já incluído nesta cotação"
            }), 409

        # 📦 Buscar produtos da cotação
        cur.execute("""
            SELECT
                COTI_PRODUTO,
                COTI_PRODUTO_DESCRICAO,
                COTI_UNIDADE_COMPRA,
                COTI_QUANTIDADE
            FROM TB_COTACAO_ITEM
            WHERE COTI_EMPRESA = ?
              AND COTI_COTACAO = ?
              AND COTI_STATUS = 'A'
        """, (empresa, cotacao))

        produtos = cur.fetchall()

        if not produtos:
            return jsonify({
                "ok": False,
                "message": "Cotação não possui produtos"
            }), 400

        # 🧾 Inserir lançamentos
        for p in produtos:
            cur.execute("""
                INSERT INTO TB_COTACAO_LANCAMENTO (
                    COTL_EMPRESA,
                    COTL_ID,
                    COTL_COTACAO,
                    COTL_PRODUTO,
                    COTL_FORNECEDOR,
                    COTL_PRODUTO_DESCRICAO,
                    COTL_PRODUTO_UNIDADE,
                    COTL_QUANTIDADE
                ) VALUES (
                    ?, GEN_ID(GEN_TB_COTACAO_LANCAMENTO, 1),
                    ?, ?, ?, ?, ?, ?
                )
            """, (
                empresa,
                cotacao,
                p[0],
                fornecedor,
                p[1],
                p[2],
                p[3]
            ))

        con.commit()
        return jsonify({
            "ok": True,
            "message": "Fornecedor incluído na cotação com sucesso"
        }), 200

    except Exception as e:
        if con:
            con.rollback()
        print("Erro incluir fornecedor:", e)
        return jsonify({
            "ok": False,
            "message": "Erro interno ao incluir fornecedor"
        }), 500
    finally:
        if con:
            con.close()


# --------------------------------------------------
# LISTAR FORNECEDORES DA COTAÇÃO
# --------------------------------------------------
@app.route("/cotacoes/<int:cot_id>/fornecedores", methods=["GET"])
def listar_fornecedores_cotacao(cot_id):
    empresa = int(request.args.get("empresa", 0))

    if not empresa:
        return jsonify({"erro": "Empresa não informada"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT DISTINCT
                F.FOR_ID,
                F.FOR_RSOCIAL_NOME,
                F.FOR_FANTASIA_APELIDO,
                F.FOR_CNPJ_CPF,
                F.FOR_TELEFONE,
                T.CTK_TOKEN,
                T.CTK_UTILIZADO
            FROM TB_COTACAO_LANCAMENTO L
            JOIN TB_FORNECEDOR F
              ON F.FOR_EMPRESA = L.COTL_EMPRESA
             AND F.FOR_ID      = L.COTL_FORNECEDOR
            LEFT JOIN TB_COTACAO_TOKEN T
              ON T.CTK_EMPRESA    = L.COTL_EMPRESA
             AND T.CTK_COTACAO    = L.COTL_COTACAO
             AND T.CTK_FORNECEDOR = L.COTL_FORNECEDOR
            WHERE L.COTL_EMPRESA = ?
              AND L.COTL_COTACAO = ?
            ORDER BY F.FOR_RSOCIAL_NOME
        """, (empresa, cot_id))

        return jsonify([
            {
                "id": r[0],
                "razao": r[1],
                "fantasia": r[2],
                "cnpj": r[3],
                "telefone": r[4],
                "token": r[5],
                "utilizado": r[6],   # 👈 ESTE É O CARA
            }
            for r in cur.fetchall()
        ])

    except Exception as e:
        print("Erro listar fornecedores da cotação:", e)
        return jsonify({"erro": "Erro ao listar fornecedores"}), 500
    finally:
        if con:
            con.close()

            
# --------------------------------------------------
# EXCLUIR FORNECEDORES DA COTAÇÃO
# --------------------------------------------------          
@app.post("/cotacoes/fornecedores/excluir")
def excluir_fornecedor_cotacao():
    data = request.json

    empresa = int(data.get("empresa", 0))
    cotacao = data.get("cotacao")
    fornecedor = data.get("fornecedor")

    if not empresa or not cotacao or not fornecedor:
        return jsonify({"erro": "Dados incompletos"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        # 🔥 Remove todos os lançamentos do fornecedor na cotação
        cur.execute("""
            DELETE FROM TB_COTACAO_LANCAMENTO
            WHERE COTL_EMPRESA = ?
              AND COTL_COTACAO = ?
              AND COTL_FORNECEDOR = ?
        """, (empresa, cotacao, fornecedor))

        con.commit()
        return jsonify({"ok": True})

    except Exception as e:
        print("Erro excluir fornecedor da cotação:", e)
        return jsonify({"erro": "Erro ao excluir fornecedor da cotação"}), 500
    finally:
        if con:
            con.close()
            


# --------------------------------------------------
# GERAR LINK DE COTAÇÃO PARA FORNECEDORES
# --------------------------------------------------
@app.post("/cotacoes/fornecedores/gerar_links")
def gerar_links_fornecedores():
    data = request.json or {}

    empresa = int(data.get("empresa", 0))
    cotacao = data.get("cotacao")

    if not empresa or not cotacao:
        return jsonify({"erro": "Dados incompletos"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        # 🔎 Buscar fornecedores da cotação (fonte única da verdade)
        cur.execute("""
            SELECT DISTINCT
                L.COTL_FORNECEDOR,
                F.FOR_RSOCIAL_NOME,
                F.FOR_FANTASIA_APELIDO,
                F.FOR_CNPJ_CPF,
                F.FOR_TELEFONE
            FROM TB_COTACAO_LANCAMENTO L
            JOIN TB_FORNECEDOR F
              ON F.FOR_EMPRESA = L.COTL_EMPRESA
             AND F.FOR_ID = L.COTL_FORNECEDOR
           WHERE L.COTL_EMPRESA = ?
             AND L.COTL_COTACAO = ?
           ORDER BY F.FOR_RSOCIAL_NOME
      """, (empresa, cotacao))

        fornecedores = cur.fetchall()
 
        if not fornecedores:
            return jsonify({"erro": "Nenhum fornecedor na cotação"}), 400

        links = []

        for row in fornecedores:
            fornecedor_id = row[0]
            nome = row[1]

            token = gerar_token()

            # 🔁 Remove token anterior (se existir)
            cur.execute("""
                DELETE FROM TB_COTACAO_TOKEN
                WHERE CTK_EMPRESA = ?
                  AND CTK_COTACAO = ?
                  AND CTK_FORNECEDOR = ?
            """, (empresa, cotacao, fornecedor_id))

            # 💾 Insere novo token
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
                fornecedor_id,
                token
            ))

            link = f"http://165.227.77.226:5000/c/{token}"

            links.append({
                "fornecedor": fornecedor_id,
                "nome": nome,
                "link": link
            })

        con.commit()

        return jsonify({
            "ok": True,
            "links": links
        })

    except Exception as e:
        if con:
            con.rollback()
        print("Erro gerar links:", e)
        return jsonify({"erro": "Erro ao gerar links"}), 500
    finally:
        if con:
            con.close()
            

# --------------------------------------------------
# GERAR / REENVIAR LINK DE COTAÇÃO (INDIVIDUAL)
# --------------------------------------------------
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

        # 1️⃣ Buscar fornecedor + contatos
        cur.execute("""
            SELECT
                FOR_TELEFONE,
                FOR_CELULAR,
                FOR_EMAIL
            FROM TB_FORNECEDOR
            WHERE FOR_EMPRESA = ?
              AND FOR_ID = ?
              AND FOR_STATUS = 'A'
        """, (empresa, fornecedor))

        row = cur.fetchone()
        if not row:
            return jsonify({
                "ok": False,
                "message": "Fornecedor não encontrado ou inativo"
            }), 404

        telefone, celular, email = row
        telefone = telefone.strip() if telefone else ''
        celular = celular.strip() if celular else ''
        email = email.strip() if email else ''

        if not (telefone or celular):
            return jsonify({
                "ok": False,
                "message": "Fornecedor sem telefone ou WhatsApp cadastrado"
            }), 400

        if not email:
            return jsonify({
                "ok": False,
                "message": "Fornecedor sem e-mail cadastrado"
            }), 400

        # 2️⃣ Verificar token válido
        cur.execute("""
            SELECT CTK_TOKEN
            FROM TB_COTACAO_TOKEN
            WHERE CTK_EMPRESA = ?
              AND CTK_COTACAO = ?
              AND CTK_FORNECEDOR = ?
              AND CTK_UTILIZADO = 'N'
              AND CTK_EXPIRA_EM >= CURRENT_DATE
        """, (empresa, cotacao, fornecedor))

        row = cur.fetchone()

        if row:
            token = row[0]
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
                ) VALUES (
                    ?, ?, ?, ?, DATEADD(7 DAY TO CURRENT_TIMESTAMP), 'N'
                )
            """, (empresa, cotacao, fornecedor, token))

        con.commit()

        zap = celular if celular else telefone
        link = f"http://165.227.77.226:5000/c/{token}"

        return jsonify({
            "ok": True,
            "link": link,
            "telefone": zap,
            "email": email
        })

    except Exception as e:
        if con:
            con.rollback()
        print("Erro gerar link fornecedor:", e)
        return jsonify({
            "ok": False,
            "message": "Erro interno ao gerar link"
        }), 500

    finally:
        if con:
            con.close()

            
            
            
            
# --------------------------------------------------
# VALIDAR TOKEN DE COTAÇÃO
# --------------------------------------------------
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
            return jsonify({"erro": "Token inválido"}), 404

        empresa, cotacao, fornecedor, expira_em, utilizado = row

        if utilizado == 'S':
            return jsonify({"erro": "Token já utilizado"}), 403

        # 🔐 Blindagem do campo de expiração
        if not expira_em:
            return jsonify({"erro": "Token inválido (sem expiração)"}), 403

        from datetime import datetime, date

        if isinstance(expira_em, date) and not isinstance(expira_em, datetime):
            expira_em = datetime.combine(expira_em, datetime.min.time())

        if expira_em < datetime.now():
            return jsonify({"erro": "Token expirado"}), 403

        return jsonify({
            "ok": True,
            "empresa": empresa,
            "cotacao": cotacao,
            "fornecedor": fornecedor
        })

    except Exception as e:
        print("Erro validar token:", e)
        return jsonify({"erro": "Erro ao validar token"}), 500
    finally:
        if con:
            con.close()
            
# --------------------------------------------------
# DADOS DA COTAÇÃO PELO TOKEN  (já é parte do HTML)
# --------------------------------------------------
@app.get("/cotacoes/token/dados/<token>")
def dados_cotacao_token(token):
    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        # 1️⃣ Buscar e validar token
        cur.execute("""
            SELECT DISTINCT 
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
            return jsonify({"erro": "Token inválido"}), 404

        empresa, cotacao, fornecedor, expira_em, utilizado = row

        if utilizado == 'S':
            return jsonify({"erro": "Token já utilizado"}), 403

        # 2️⃣ Buscar nome da empresa (mercado)
        cur.execute("""
            SELECT EMP_FANTASIA
            FROM TB_EMPRESA
            WHERE EMP_ID = ?
        """, (empresa,))

        row_emp = cur.fetchone()
        empresa_nome = row_emp[0] if row_emp else "Empresa"

        # 3️⃣ Buscar dados básicos da cotação
        cur.execute("""
            SELECT DISTINCT 
                C.COT_DESCRICAO,
                C.COT_DT_FECHAMENTO
            FROM TB_COTACAO C
            WHERE C.COT_EMPRESA = ?
              AND C.COT_ID = ?
        """, (empresa, cotacao))

        cot = cur.fetchone()
        if not cot:
            return jsonify({"erro": "Cotação não encontrada"}), 404

        descricao, data_fechamento = cot

        # 4️⃣ Buscar itens da cotação
        cur.execute("""
            SELECT DISTINCT 
                L.COTL_PRODUTO,
                P.PRD_DESCRICAO
            FROM TB_COTACAO_LANCAMENTO L
            JOIN TB_PRODUTO P
              ON P.PRD_EMPRESA = L.COTL_EMPRESA
             AND P.PRD_ID = L.COTL_PRODUTO
            WHERE L.COTL_EMPRESA = ?
              AND L.COTL_COTACAO = ?
            ORDER BY P.PRD_DESCRICAO
        """, (empresa, cotacao))

        itens = []
        for prod_id, descricao_prod in cur.fetchall():
            itens.append({
                "produto_id": prod_id,
                "descricao": descricao_prod
            })

        return jsonify({
            "ok": True,
            "empresa": empresa,
            "empresa_nome": empresa_nome,  # 👈 NOME DO MERCADO
            "cotacao": cotacao,
            "descricao": descricao,
            "validade": data_fechamento.strftime("%d/%m/%Y") if data_fechamento else None,
            "fornecedor": fornecedor,
            "itens": itens
        })

    except Exception as e:
        print("Erro dados cotacao token:", e)
        return jsonify({"erro": "Erro ao buscar dados da cotação"}), 500
    finally:
        if con:
            con.close()
            
# --------------------------------------------------
# RECEBER PREÇOS DO FORNECEDOR (PELO TOKEN)
# --------------------------------------------------
@app.post("/cotacoes/token/responder/<token>")
def responder_cotacao_token(token):
    data = request.json or {}

    itens = data.get("itens", [])

    if not itens:
        return jsonify({"erro": "Nenhum item informado"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        # 1️⃣ Validar token
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
            return jsonify({"erro": "Token inválido"}), 404

        empresa, cotacao, fornecedor, expira_em, utilizado = row

        if utilizado == 'S':
            return jsonify({"erro": "Token já utilizado"}), 403
        
        # 2️⃣ Gravar preços (UPDATE no lançamento existente)
        for item in itens:
            produto = item.get("produto_id")
            preco = item.get("preco")
 
            if produto is None or preco is None:
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
                produto
            ))        

        # 3️⃣ Marcar token como utilizado
        cur.execute("""
            UPDATE TB_COTACAO_TOKEN
            SET CTK_UTILIZADO = 'S'
            WHERE CTK_TOKEN = ?
        """, (token,))

        con.commit()

        return jsonify({"ok": True})

    except Exception as e:
        if con:
            con.rollback()
        print("Erro responder cotacao:", e)
        return jsonify({"erro": "Erro ao gravar cotação"}), 500
    finally:
        if con:
            con.close()     
            
            
# ==================================================
# LINK CURTO /c/<token>
# ==================================================
@app.get("/c/<token>")
def acesso_cotacao_por_token(token):
    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                CTK_EMPRESA,
                CTK_COTACAO,
                CTK_FORNECEDOR,
                CTK_UTILIZADO,
                CTK_EXPIRA_EM
            FROM TB_COTACAO_TOKEN
            WHERE CTK_TOKEN = ?
        """, (token,))

        row = cur.fetchone()

        # ❌ token não existe
        if not row:
            return "Link inválido", 404

        empresa, cotacao, fornecedor, utilizado, expira_em = row

        # ❌ token já utilizado
        if utilizado == 'S':
            return "Este link já foi utilizado", 410

        # ❌ token expirado
        if expira_em and expira_em < datetime.now().date():
            return "Este link expirou", 410

        # ✅ tudo certo → redireciona
        return redirect(f"/static/cotacao.html?token={token}")

    except Exception as e:
        print("ERRO /c/<token>:", e)
        return "Erro interno", 500

    finally:
        if con:
            con.close()
        
# ==================================================
# MARCAR LINK COMO ENVIADO (STATUS = 'E')
# ==================================================
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

        # Só marca como ENVIADO se ainda estiver N (não enviado)
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
        print("ERRO marcar_enviado:", e)
        return jsonify({
            "ok": False,
            "message": "Erro interno"
        }), 500

    finally:
        if con:
            con.close()
        
      
# ==================================================
# BUSCAR RESPOSTAS DA NUVEM
# ==================================================
@app.get("/cotacoes/<int:cot_id>/buscar_respostas_nuvem")
def buscar_respostas_nuvem_local(cot_id):
    empresa = int(request.args.get("empresa", 0))

    if not empresa:
        return jsonify({
            "ok": False,
            "message": "Empresa não informada"
        }), 400

    try:
        url = f"{API_NUVEM_BASE}/cotacoes/{cot_id}/respostas"
        
        print("API_NUVEM_BASE =", API_NUVEM_BASE)
        print("URL FINAL =", url)
        
        resp = requests.get(
            url,
            params={"empresa": empresa},
            timeout=20
        )

        # Se a nuvem devolveu erro, repassa de forma controlada
        if resp.status_code != 200:
            try:
                erro_json = resp.json()
            except Exception:
                erro_json = {"message": resp.text}

            return jsonify({
                "ok": False,
                "message": "Erro ao consultar a nuvem",
                "status_nuvem": resp.status_code,
                "retorno_nuvem": erro_json
            }), 502

        dados = resp.json()

        return jsonify({
            "ok": True,
            "origem": "nuvem",
            "dados": dados
        })

    except requests.exceptions.Timeout:
        return jsonify({
            "ok": False,
            "message": "Tempo esgotado ao consultar a nuvem"
        }), 504

    except requests.exceptions.ConnectionError:
        return jsonify({
            "ok": False,
            "message": "Não foi possível conectar na API da nuvem"
        }), 503

    except Exception as e:
        print("Erro buscar_respostas_nuvem_local:", e)
        return jsonify({
            "ok": False,
            "message": "Erro interno ao consultar respostas da nuvem"
        }), 500      
        
# ==================================================
# IMPORTAR RESPOSTAS DA NUVEM PARA O BANCO LOCAL
# ==================================================
@app.post("/cotacoes/<int:cot_id>/importar_respostas_nuvem")
def importar_respostas_nuvem(cot_id):
    empresa = int(request.args.get("empresa", 0))

    if not empresa:
        return jsonify({
            "ok": False,
            "message": "Empresa não informada"
        }), 400

    con = None
    try:
        # 1) Buscar respostas da nuvem
        url = f"{API_NUVEM_BASE}/cotacoes/{cot_id}/respostas"
        print("IMPORTAR_RESPOSTAS | API_NUVEM_BASE =", API_NUVEM_BASE)
        print("IMPORTAR_RESPOSTAS | URL FINAL =", url)

        resp = requests.get(
            url,
            params={"empresa": empresa},
            timeout=20
        )

        if resp.status_code != 200:
            try:
                erro_json = resp.json()
            except Exception:
                erro_json = {"message": resp.text}

            return jsonify({
                "ok": False,
                "message": "Erro ao consultar respostas na nuvem",
                "status_nuvem": resp.status_code,
                "retorno_nuvem": erro_json
            }), 502

        dados = resp.json()
        respostas = dados.get("respostas", [])

        # 2) Conectar no banco local
        con = get_connection()
        cur = con.cursor()

        total_respostas = len(respostas)
        total_com_preco = 0
        atualizados = 0
        nao_encontrados = 0

        for item in respostas:
            fornecedor = item.get("fornecedor")
            produto_id = item.get("produto_id")
            preco = item.get("preco_digitado")

            # Ignora itens ainda não respondidos
            if preco is None:
                continue

            total_com_preco += 1

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
                cot_id,
                fornecedor,
                produto_id
            ))

            if cur.rowcount and cur.rowcount > 0:
                atualizados += cur.rowcount
            else:
                nao_encontrados += 1

        con.commit()

        return jsonify({
            "ok": True,
            "message": "Importação concluída",
            "empresa": empresa,
            "cotacao": cot_id,
            "total_respostas_nuvem": total_respostas,
            "total_com_preco": total_com_preco,
            "atualizados_local": atualizados,
            "nao_encontrados_local": nao_encontrados
        })

    except requests.exceptions.Timeout:
        if con:
            con.rollback()
        return jsonify({
            "ok": False,
            "message": "Tempo esgotado ao consultar a nuvem"
        }), 504

    except requests.exceptions.ConnectionError:
        if con:
            con.rollback()
        return jsonify({
            "ok": False,
            "message": "Não foi possível conectar na API da nuvem"
        }), 503

    except Exception as e:
        if con:
            con.rollback()
        print("Erro importar_respostas_nuvem:", e)
        return jsonify({
            "ok": False,
            "message": "Erro interno ao importar respostas da nuvem"
        }), 500

    finally:
        if con:
            con.close()        
        
        
        
            
# ==================================================
# START
# ==================================================
if __name__ == "__main__":       
    #app.run(host="0.0.0.0", port=5003, debug=True)
    app.run(host="0.0.0.0", port=5000, debug=False)
