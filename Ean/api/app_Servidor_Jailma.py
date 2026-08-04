from flask import Flask, request, jsonify
import fdb

app = Flask(__name__)

# ==============================================================
# CONEXÃO FIREBIRD
# ==============================================================
def get_connection():
    return fdb.connect(
        host="localhost",
        database=r"E:\Dados Clientes\Casa Nova\Dados.FDB",
        user="SYSDBA",
        password="masterkey",
        charset="ISO8859_1"
    )

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
# INICIAR SERVIDOR
# ==============================================================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)
