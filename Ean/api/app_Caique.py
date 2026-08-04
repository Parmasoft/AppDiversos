from flask import Flask, request, jsonify
import fdb
import unicodedata

app = Flask(__name__)

# ==============================================================
# CONEXÃO FIREBIRD
# ==============================================================
def get_connection():
    return fdb.connect(
        # ------------------------------------------------------
        # USO NORMAL QUANDO A API ESTIVER RODANDO NO SERVIDOR:
        host="localhost",
        #
        # USO TEMPORÁRIO QUANDO A API ESTIVER RODANDO EM UMA ESTAÇÃO
        # E O BANCO CONTINUAR NO SERVIDOR:
        #host="192.168.0.250",
        # ------------------------------------------------------

        database=r"D:\Dados\DADOS.FDB",
        user="SYSDBA",
        password="masterkey",
        charset="ISO8859_1"
    )
    
# ==============================================================
# UTIL: NORMALIZAR TEXTO PARA BUSCA
# ==============================================================
def normalizar_texto(txt):
    if txt is None:
        return ""

    txt = str(txt).upper().strip()
    txt = unicodedata.normalize("NFD", txt)
    txt = "".join(c for c in txt if unicodedata.category(c) != "Mn")

    for ch in [".", ",", "-", "_", "/", "\\", "(", ")", "%", ":", ";"]:
        txt = txt.replace(ch, " ")

    while "  " in txt:
        txt = txt.replace("  ", " ")

    return txt.strip()


def quebrar_termos(termo):
    texto = normalizar_texto(termo)

    ignorar = {
        "DE", "DA", "DO", "DAS", "DOS",
        "COM", "PARA", "POR", "EM",
        "PRODUTO", "PROD", "UNIDADE",
        "INTEGRAL", "ORIGINAL"
    }

    termos = []
    for p in texto.split(" "):
        p = p.strip()
        if len(p) < 2:
            continue
        if p in ignorar:
            continue
        if p not in termos:
            termos.append(p)

    return termos


def calcular_score(descricao, termos):
    desc = normalizar_texto(descricao)
    score = 0

    for termo in termos:
        if termo in desc:
            # número, volume, amperagem, medida etc. valem mais
            if any(ch.isdigit() for ch in termo):
                score += 30
            elif len(termo) >= 5:
                score += 18
            else:
                score += 12

    return score
    

# ==============================================================
# ROTA: CONSULTAR PRODUTO
# ==============================================================
@app.route("/produto", methods=["GET"])
def produto():
    codigo = request.args.get("cod")

    if not codigo:
        return jsonify({"erro": "Código não informado"}), 400

    try:
        con = get_connection()
        cur = con.cursor()

        # 1) BUSCAR PRODUTO PELO CÓDIGO DE BARRAS
        sql_cod = """
            SELECT PRDC_PRODUTO
            FROM TB_PROD_CODIGO_BARRAS
            WHERE PRDC_COD_BARRAS = ?
            ORDER BY
                CASE WHEN PRDC_PRINCIPAL = 'S' THEN 0 ELSE 1 END,
                PRDC_SEQUENCIA
        """
        cur.execute(sql_cod, (codigo,))
        row = cur.fetchone()

        if not row:
            return jsonify({"encontrado": False})

        produto_id = row[0]

        # 2) BUSCAR DADOS DO PRODUTO
        sql_prod = """
            SELECT
                PRD_EMPRESA,
                PRD_COD_BARRAS,
                PRD_DESCRICAO,
                PRD_UN_COMPRA,
                PRD_PRECO_VENDA
            FROM TB_PRODUTO
            WHERE PRD_ID = ?
              AND PRD_STATUS = 'A'
        """
        cur.execute(sql_prod, (produto_id,))
        prod = cur.fetchone()

        if not prod:
            return jsonify({"encontrado": False})

        empresa, barras, desc, un, preco = prod

        con.close()

        return jsonify({
            "encontrado": True,
            "empresa": empresa,
            "codigo": codigo,
            "descricao": desc,
            "unidade": un,
            "preco": float(preco) if preco is not None else 0.0,
            "produto_id": produto_id
        })

    except Exception as e:
        return jsonify({"erro": str(e)}), 500


# ==============================================================
# ROTA: INSERIR NA GÔNDOLA (COM PREÇO)
# ==============================================================
@app.route("/gondola", methods=["POST"])
def inserir_gondola():
    try:
        dados = request.get_json()

        produto_id = dados.get("produto_id")
        descricao = dados.get("descricao")
        un = dados.get("un")
        codigo_barras = dados.get("codigo_barras")
        valor = dados.get("preco")  # <-- PREÇO VINDO DO APP

        if not produto_id:
            return jsonify({"status": "erro", "mensagem": "produto_id inválido"}), 400

        if valor is None:
            valor = 0.0

        con = get_connection()
        cur = con.cursor()

        # PRÓXIMO ID
        cur.execute("SELECT COALESCE(MAX(GDL_ID), 0) + 1 FROM TB_GONDOLA")
        novo_id = cur.fetchone()[0]

        # INSERT COM GDL_VALOR
        sql = """
            INSERT INTO TB_GONDOLA
            (
                GDL_ID,
                GDL_EMPRESA,
                GDL_PRODUTO,
                GDL_QUANTIDADE,
                GDL_SELECIONADO,
                GDL_USUARIO,
                GDL_DESCRICAO,
                GDL_UN,
                GDL_CODIGO_BARRAS,
                GDL_VALOR
            )
            VALUES
            (?, 1, ?, 1, 'S', 1, ?, ?, ?, ?)
        """

        cur.execute(
            sql,
            (
                novo_id,
                produto_id,
                descricao,
                un,
                codigo_barras,
                float(valor)
            )
        )

        con.commit()
        con.close()

        return jsonify({
            "status": "ok",
            "mensagem": "Produto enviado para gôndola com valor!"
        })

    except Exception as e:
        print("\n========== ERRO NA ROTA /gondola ==========")
        print(e)
        print("===========================================\n")
        return jsonify({"status": "erro", "mensagem": str(e)}), 500

# ==============================================================
# ROTA: BUSCAR PRODUTOS POR DESCRIÇÃO PARA VINCULAR CÓDIGO
# ==============================================================
@app.route("/produto/buscar-descricao", methods=["GET"])
def buscar_produto_descricao():
    termo = request.args.get("termo", "").strip()
    empresa = request.args.get("empresa", "1").strip()

    if not termo:
        return jsonify({
            "status": "erro",
            "mensagem": "Termo de busca não informado",
            "produtos": []
        }), 400

    try:
        empresa = int(empresa)
    except:
        empresa = 1

    termos = quebrar_termos(termo)

    if not termos:
        return jsonify({
            "status": "ok",
            "termos": [],
            "produtos": []
        })

    try:
        con = get_connection()
        cur = con.cursor()

        # Busca inicial simples. A pontuação fina é feita em Python.
        where_or = []
        params = [empresa]

        for t in termos:
            where_or.append("UPPER(PRD_DESCRICAO) LIKE ?")
            params.append(f"%{t}%")

        sql = f"""
            SELECT
                PRD_EMPRESA,
                PRD_ID,
                PRD_DESCRICAO,
                PRD_UN_COMPRA,
                PRD_PRECO_VENDA,
                PRD_COD_BARRAS
            FROM TB_PRODUTO
            WHERE PRD_EMPRESA = ?
              AND PRD_STATUS = 'A'
              AND ({' OR '.join(where_or)})
        """

        cur.execute(sql, params)
        rows = cur.fetchall()
        con.close()

        produtos = []

        for r in rows:
            prd_empresa, prd_id, descricao, un, preco, cod_barras = r

            score = calcular_score(descricao, termos)

            if score <= 0:
                continue

            produtos.append({
                "empresa": prd_empresa,
                "produto_id": prd_id,
                "descricao": descricao or "",
                "unidade": un or "",
                "preco": float(preco) if preco is not None else 0.0,
                "codigo_barras_atual": cod_barras or "",
                "score": score
            })

        produtos.sort(key=lambda x: x["score"], reverse=True)
        produtos = produtos[:50]

        return jsonify({
            "status": "ok",
            "termos": termos,
            "produtos": produtos
        })

    except Exception as e:
        print("\n========== ERRO NA ROTA /produto/buscar-descricao ==========")
        print(e)
        print("============================================================\n")
        return jsonify({
            "status": "erro",
            "mensagem": str(e),
            "produtos": []
        }), 500


# ==============================================================
# ROTA: VINCULAR CÓDIGO DE BARRAS AO PRODUTO ESCOLHIDO
# ==============================================================
@app.route("/produto/vincular-codigo", methods=["POST"])
def vincular_codigo_produto():
    try:
        dados = request.get_json()

        empresa = int(dados.get("empresa", 1))
        produto_id = int(dados.get("produto_id", 0))
        codigo_barras = str(dados.get("codigo_barras", "")).strip()

        if produto_id <= 0:
            return jsonify({
                "status": "erro",
                "mensagem": "Produto inválido"
            }), 400

        if not codigo_barras:
            return jsonify({
                "status": "erro",
                "mensagem": "Código de barras não informado"
            }), 400

        con = get_connection()
        cur = con.cursor()

        # Verifica se esse código já existe em qualquer produto da empresa
        cur.execute("""
            SELECT PRDC_PRODUTO
            FROM TB_PROD_CODIGO_BARRAS
            WHERE PRDC_EMPRESA = ?
              AND PRDC_COD_BARRAS = ?
        """, (empresa, codigo_barras))

        row_codigo = cur.fetchone()

        if row_codigo:
            con.close()
            return jsonify({
                "status": "erro",
                "mensagem": f"Este código de barras já está vinculado ao produto {row_codigo[0]}."
            }), 409

        # Confere se produto existe e está ativo
        cur.execute("""
            SELECT PRD_COD_BARRAS
            FROM TB_PRODUTO
            WHERE PRD_EMPRESA = ?
              AND PRD_ID = ?
              AND PRD_STATUS = 'A'
        """, (empresa, produto_id))

        row_prod = cur.fetchone()

        if not row_prod:
            con.close()
            return jsonify({
                "status": "erro",
                "mensagem": "Produto não encontrado ou inativo"
            }), 404

        prd_cod_barras_atual = row_prod[0]

        # Próxima sequência do produto
        cur.execute("""
            SELECT COALESCE(MAX(PRDC_SEQUENCIA), 0) + 1
            FROM TB_PROD_CODIGO_BARRAS
            WHERE PRDC_EMPRESA = ?
              AND PRDC_PRODUTO = ?
        """, (empresa, produto_id))

        sequencia = cur.fetchone()[0]

        # Se for o primeiro código do produto, marca como principal
        cur.execute("""
            SELECT COUNT(*)
            FROM TB_PROD_CODIGO_BARRAS
            WHERE PRDC_EMPRESA = ?
              AND PRDC_PRODUTO = ?
        """, (empresa, produto_id))

        qtd_codigos = cur.fetchone()[0]
        principal = "S" if qtd_codigos == 0 else "N"

        cur.execute("""
            INSERT INTO TB_PROD_CODIGO_BARRAS
            (
                PRDC_EMPRESA,
                PRDC_PRODUTO,
                PRDC_COD_BARRAS,
                PRDC_SEQUENCIA,
                PRDC_PRINCIPAL,
                PRDC_CONVERSAO,
                PRDC_VALIDO
            )
            VALUES
            (?, ?, ?, ?, ?, 'N', 'S')
        """, (
            empresa,
            produto_id,
            codigo_barras,
            sequencia,
            principal
        ))

        # Mantém o campo direto da TB_PRODUTO preenchido se estiver vazio
        if prd_cod_barras_atual is None or str(prd_cod_barras_atual).strip() == "":
            cur.execute("""
                UPDATE TB_PRODUTO
                SET PRD_COD_BARRAS = ?,
                    PRD_EDITADO = 'S'
                WHERE PRD_EMPRESA = ?
                  AND PRD_ID = ?
            """, (codigo_barras, empresa, produto_id))
        else:
            cur.execute("""
                UPDATE TB_PRODUTO
                SET PRD_EDITADO = 'S'
                WHERE PRD_EMPRESA = ?
                  AND PRD_ID = ?
            """, (empresa, produto_id))

        con.commit()
        con.close()

        return jsonify({
            "status": "ok",
            "mensagem": "Código de barras vinculado com sucesso"
        })

    except Exception as e:
        print("\n========== ERRO NA ROTA /produto/vincular-codigo ==========")
        print(e)
        print("===========================================================\n")
        return jsonify({
            "status": "erro",
            "mensagem": str(e)
        }), 500



# ==============================================================
# INICIAR SERVIDOR
# ==============================================================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=False)