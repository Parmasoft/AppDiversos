from flask import Flask, request, jsonify, send_from_directory, abort
from decimal import Decimal
from datetime import datetime
import os
import fdb
import socket
import win32print

app = Flask(__name__)

# ==================================================
# CONFIG IMPRESSÃO
# ==================================================
NOME_IMPRESSORA = "Elgin i9(USB)"
LARGURA_LINHA = 48
LARGURA_TRACEJADO = 48
CORTE_TOTAL = "\x1d\x56\x00"

BOLD_ON = "\x1b\x45\x01"
BOLD_OFF = "\x1b\x45\x00"

AVANCO_4_LINHAS = "\x1b\x64\x04"
AVANCO_6_LINHAS = "\x1b\x64\x06"
AVANCO_8_LINHAS = "\x1b\x64\x08"
AVANCO_10_LINHAS = "\x1b\x64\x10"

TXT_NORMAL = "\x1d\x21\x00"
TXT_DUPLO_ALTURA = "\x1d\x21\x01"
TXT_DUPLO_LARGURA = "\x1d\x21\x10"
TXT_DUPLO = "\x1d\x21\x11"

ALIGN_LEFT = "\x1b\x61\x00"
ALIGN_CENTER = "\x1b\x61\x01"
ALIGN_RIGHT = "\x1b\x61\x02"

# ==================================================
# FUNÇÕES AUXILIARES IMPRESSÃO
# ==================================================
def imprimir_ticket_cozinha(comanda, itens_cozinha):
    if not itens_cozinha:
        return

    comanda_fmt = str(comanda).zfill(2)

    linhas = []
    
    # Letra grande.
    linhas.append("")
    linhas.append(f"{ALIGN_CENTER}{TXT_DUPLO}{BOLD_ON} <<< COMANDA:{BOLD_OFF} {comanda_fmt} >>>{TXT_NORMAL}")
    linhas.append(f"{ALIGN_LEFT}")
    linhas.append("-" * LARGURA_TRACEJADO)
    
    # Letra média grande e muito junta.
      # {TXT_DUPLO_ALTURA}        
    # Letra média (ideal quando se quer algo maior que o normal).
      # {TXT_DUPLO_LARGURA}
      
    agora = datetime.now()
    data_fmt = agora.strftime('%d/%m/%y')
    hora_fmt = agora.strftime('%H:%M')

    parte_esquerda = f"{BOLD_ON}DATA:{BOLD_OFF} {data_fmt}"
    #parte_direita = f"HS- {hora_fmt}"
    parte_direita = f"{hora_fmt} hs "

    largura_dupla = LARGURA_LINHA // 2    
    #espacos = largura_dupla - len(f"DATA: {data_fmt}") - len(f"HS- {hora_fmt}")    
    espacos = largura_dupla - len(f"DATA: {data_fmt}") - len(f"{hora_fmt} hs")    
    if espacos < 1:
        espacos = 1

    linhas.append(f"{TXT_DUPLO_LARGURA}{parte_esquerda}{' ' * espacos}{parte_direita}{TXT_NORMAL}")
    
    linhas.append("=" * LARGURA_TRACEJADO)
    linhas.append("")

    for item in itens_cozinha:
        qtd_float = float(item["quantidade"])
        qtd = int(qtd_float) if qtd_float.is_integer() else qtd_float
        qtd_fmt = str(qtd).zfill(2)

        linhas.append(f"{TXT_DUPLO_LARGURA}{BOLD_ON}{qtd_fmt} X  {item['descricao']}{BOLD_OFF}{TXT_NORMAL}")
        linhas.append("")
        linhas.append("-" * LARGURA_TRACEJADO)
        linhas.append("")

    # espaço extra no final para o corte não pegar o último item            
    texto = "\n".join(linhas)    
    texto += AVANCO_8_LINHAS
    texto += CORTE_TOTAL
    #  até aqui.

    hPrinter = win32print.OpenPrinter(NOME_IMPRESSORA)
    try:
        win32print.StartDocPrinter(hPrinter, 1, ("Pedido Cozinha", None, "RAW"))
        win32print.StartPagePrinter(hPrinter)
        win32print.WritePrinter(hPrinter, texto.encode("cp860", errors="ignore"))
        win32print.EndPagePrinter(hPrinter)
        win32print.EndDocPrinter(hPrinter)
    finally:
        win32print.ClosePrinter(hPrinter)

@app.get("/ping")
def ping():
    return {"ok": True}

# ==================================================
# CONEXÃO FIREBIRD
# ==================================================
def get_connection():
    return fdb.connect(
        host="localhost",
        database=r"E:\Dados Clientes\Pastelaria Ta em Casa\DADOS.FDB",
        user="SYSDBA",
        password="masterkey",
        charset="ISO8859_1"
    )

# ==================================================
# TESTE BANCO
# ==================================================
@app.get("/teste-banco")
def teste_banco():
    con = None
    cur = None

    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("SELECT COUNT(*) FROM TB_PROD_GRUPO")
        total = cur.fetchone()[0]

        return {"ok": True, "total_grupos": total}

    except Exception as e:
        return {"ok": False, "erro": str(e)}, 500

    finally:
        try:
            if cur:
                cur.close()
            if con:
                con.close()
        except:
            pass

# ==================================================
# IMAGENS
# ==================================================
IMAGENS_PATH = r"C:\Parmatech\Imagens\Imagens"

@app.route("/pdv/imagens/<filename>")
def imagens(filename):
    if ".." in filename or "/" in filename or "\\" in filename:
        abort(400)

    file_path = os.path.join(IMAGENS_PATH, filename)

    if not os.path.exists(file_path):
        abort(404)

    return send_from_directory(IMAGENS_PATH, filename)

# ==================================================
# LISTAR GRUPOS
# ==================================================
@app.get("/pdv/grupos")
def listar_grupos_pdv():

    empresa = request.args.get("empresa")

    if not empresa:
        return {"ok": False, "message": "Empresa não informada"}, 400

    con = None
    cur = None

    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                PGRU_ID,
                PGRU_DESCRICAO,
                PGRU_FOTO
            FROM TB_PROD_GRUPO
            WHERE PGRU_EMPRESA = ?
              AND PGRU_MOSTRAR = 'S'
            ORDER BY PGRU_ORDEM
        """, (empresa,))

        grupos = []

        for row in cur.fetchall():
            foto = row[2]

            grupos.append({
                "id": row[0],
                "descricao": row[1],
                "foto_url": f"http://192.168.1.238:5000/pdv/imagens/{foto}" if foto else None
            })

        return {
            "ok": True,
            "total": len(grupos),
            "dados": grupos
        }

    except Exception as e:
        return {"ok": False, "erro": str(e)}, 500

    finally:
        try:
            if cur:
                cur.close()
            if con:
                con.close()
        except:
            pass

# ==================================================
# LISTAR PRODUTOS
# ==================================================
@app.get("/pdv/produtos")
def listar_produtos_pdv():

    empresa = request.args.get("empresa")
    grupo = request.args.get("grupo")

    if not empresa or not grupo:
        return {"ok": False, "message": "Empresa ou grupo não informado"}, 400

    con = None
    cur = None

    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                P.PRD_ID,
                P.PRD_DESCRICAO,
                P.PRD_PRECO_VENDA,
                P.PRD_FOTO
            FROM TB_PRODUTO P
            JOIN TB_PROD_GRUPO G
              ON G.PGRU_EMPRESA = P.PRD_EMPRESA
             AND G.PGRU_ID = P.PRD_GRUPO
            WHERE P.PRD_EMPRESA = ?
              AND P.PRD_GRUPO = ?
              AND P.PRD_STATUS = 'A'
              AND G.PGRU_MOSTRAR = 'S'
            ORDER BY P.PRD_DESCRICAO
        """, (empresa, grupo))

        produtos = []

        for row in cur.fetchall():
            foto = row[3]

            produtos.append({
                "id": row[0],
                "descricao": row[1],
                "preco": float(row[2]) if row[2] else 0,
                "foto_url": f"http://192.168.1.238:5000/pdv/imagens/{foto}" if foto else None
            })

        return {
            "ok": True,
            "total": len(produtos),
            "dados": produtos
        }

    except Exception as e:
        return {"ok": False, "erro": str(e)}, 500

    finally:
        try:
            if cur:
                cur.close()
            if con:
                con.close()
        except:
            pass

# ==================================================
# FINALIZAR PEDIDO
# ==================================================
@app.post("/pdv/finalizar")
def finalizar_pdv():

    dados = request.json or {}

    empresa = dados.get("empresa")
    comanda = dados.get("comanda")
    usuario = dados.get("usuario", 1)
    itens = dados.get("itens", [])

    if not empresa:
        return jsonify({"erro": "Empresa não informada"}), 400

    if not comanda:
        return jsonify({"erro": "Comanda não informada"}), 400

    if not itens:
        return jsonify({"erro": "Nenhum item enviado"}), 400

    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        # ------------------------------------------------
        # 1) Verifica se já existe orçamento aberto digitado
        # ------------------------------------------------
        cur.execute("""
            SELECT FIRST 1 ORC_ID
            FROM TB_ORCAMENTO
            WHERE ORC_EMPRESA = ?
              AND ORC_COMANDA = ?
              AND ORC_STATUS = 'D'
            ORDER BY ORC_ID DESC
        """, (empresa, comanda))

        orc = cur.fetchone()

        if orc:
            novo_orc_id = orc[0]
        else:
            # --------------------------------------------
            # 2) Gera novo ORC_ID em TB_SEQUENCIAL
            # --------------------------------------------
            cur.execute("""
                SELECT SEQ_SEQUENCIAL
                FROM TB_SEQUENCIAL
                WHERE SEQ_EMPRESA = ?
                  AND SEQ_TABELA = 'TB_ORCAMENTO'
                FOR UPDATE
            """, (empresa,))

            row = cur.fetchone()

            if not row:
                raise Exception("Sequencial TB_ORCAMENTO não encontrado")

            novo_orc_id = row[0] + 1

            cur.execute("""
                UPDATE TB_SEQUENCIAL
                SET SEQ_SEQUENCIAL = ?
                WHERE SEQ_EMPRESA = ?
                  AND SEQ_TABELA = 'TB_ORCAMENTO'
            """, (novo_orc_id, empresa))

            cur.execute("""
                INSERT INTO TB_ORCAMENTO (
                    ORC_EMPRESA,
                    ORC_ID,
                    ORC_STATUS,
                    ORC_NR_ITENS,
                    ORC_SUB_TOTAL,
                    ORC_VALOR_TOTAL,
                    ORC_DT_LANCAMENTO,
                    ORC_DT_EMISSAO,
                    ORC_COMANDA,
                    ORC_TIPO_MOVIMENTO,
                    ORC_TIPO_VENDA,
                    ORC_CLIENTE,
                    ORC_USUARIO
                )
                VALUES (?, ?, 'D', 0, 0, 0, CURRENT_TIMESTAMP, CURRENT_DATE, ?, 'O', 'N', 1, ?)
            """, (
                empresa,
                novo_orc_id,
                comanda,
                usuario
            ))

        # ------------------------------------------------
        # 3) Descobrir próximo sequencial do item
        # ------------------------------------------------
        cur.execute("""
            SELECT MAX(ORCI_SEQUENCIAL)
            FROM TB_ORCAMENTO_ITEM
            WHERE ORCI_EMPRESA = ?
              AND ORCI_ORCAMENTO = ?
        """, (empresa, novo_orc_id))

        row = cur.fetchone()
        sequencial_item = row[0] if row and row[0] else 0

        # ------------------------------------------------
        # 4) Preparar lista dos itens de cozinha da rodada
        # ------------------------------------------------
        itens_cozinha = []

        # ------------------------------------------------
        # 5) Inserir itens novos recebidos nesta finalização
        # ------------------------------------------------
        for item in itens:
            produto_id = item.get("produto_id")
            quantidade_raw = item.get("quantidade")

            if not produto_id:
                raise Exception("Produto não informado em um dos itens")

            if quantidade_raw is None:
                raise Exception(f"Quantidade não informada para o produto {produto_id}")

            quantidade = Decimal(str(quantidade_raw))

            if quantidade <= 0:
                raise Exception(f"Quantidade inválida para o produto {produto_id}")

            cur.execute("""
                SELECT
                    PRD_UN_VENDA,
                    PRD_PRECO_VENDA,
                    PRD_DESCRICAO,
                    PRD_TIPO_PRODUTO,
                    PRD_LOCAL_PREPARO
                FROM TB_PRODUTO
                WHERE PRD_EMPRESA = ?
                  AND PRD_ID = ?
                  AND PRD_STATUS = 'A'
            """, (empresa, produto_id))

            prod = cur.fetchone()

            if not prod:
                raise Exception(f"Produto {produto_id} inválido")

            unidade, valor_unitario, descricao, tipo_produto, local_preparo = prod

            valor_unitario = Decimal(str(valor_unitario))
            sub_total = quantidade * valor_unitario
            sequencial_item += 1

            # --------------------------------------------
            # Regra cozinha:
            # PRD_TIPO_PRODUTO = 'R'
            # PRD_LOCAL_PREPARO preenchido e válido
            # --------------------------------------------
            if str(tipo_produto).strip() == "R" and local_preparo not in (None, 0, ""):
                itens_cozinha.append({
                    "produto_id": produto_id,
                    "descricao": descricao,
                    "quantidade": float(quantidade),
                    "local_preparo": int(local_preparo),
                })

            cur.execute("""
                INSERT INTO TB_ORCAMENTO_ITEM (
                    ORCI_EMPRESA,
                    ORCI_ORCAMENTO,
                    ORCI_SEQUENCIAL,
                    ORCI_PRODUTO,
                    ORCI_UNIDADE,
                    ORCI_QUANTIDADE,
                    ORCI_VOLUMES,
                    ORCI_VALOR_UNITARIO,
                    ORCI_SUB_TOTAL,
                    ORCI_VALOR_TOTAL,
                    ORCI_STATUS,
                    ORCI_COMANDA
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'A', ?)
            """, (
                empresa,
                novo_orc_id,
                sequencial_item,
                produto_id,
                unidade,
                quantidade,
                1,
                valor_unitario,
                sub_total,
                sub_total,
                comanda
            ))

        # ------------------------------------------------
        # 6) Recalcular totais do orçamento
        # ------------------------------------------------
        cur.execute("""
            SELECT
                SUM(ORCI_QUANTIDADE),
                SUM(ORCI_VALOR_TOTAL)
            FROM TB_ORCAMENTO_ITEM
            WHERE ORCI_EMPRESA = ?
              AND ORCI_ORCAMENTO = ?
        """, (empresa, novo_orc_id))

        totais = cur.fetchone()

        total_itens = totais[0] or 0
        total_geral = totais[1] or 0

        cur.execute("""
            UPDATE TB_ORCAMENTO
            SET ORC_NR_ITENS = ?,
                ORC_SUB_TOTAL = ?,
                ORC_VALOR_TOTAL = ?
            WHERE ORC_EMPRESA = ?
              AND ORC_ID = ?
        """, (total_itens, total_geral, total_geral, empresa, novo_orc_id))

        # ------------------------------------------------
        # 7) Confirma o pedido no banco
        # ------------------------------------------------
        conn.commit()

        # ------------------------------------------------
        # 8) Tenta imprimir cozinha sem perder o pedido
        # ------------------------------------------------
        aviso = None

        if itens_cozinha:
            try:
                imprimir_ticket_cozinha(comanda, itens_cozinha)
            except Exception as e_impressao:
                aviso = f"Pedido gravado com sucesso, mas a impressão da cozinha falhou: {str(e_impressao)}"

        return jsonify({
            "sucesso": True,
            "orcamento_id": novo_orc_id,
            "aviso": aviso
        })

    except Exception as e:
        if conn:
            conn.rollback()

        return jsonify({"erro": str(e)}), 500

    finally:
        try:
            if cur:
                cur.close()
            if conn:
                conn.close()
        except:
            pass

# ==================================================
# BLOQUEIO DE COMANDA + CARREGAR ITENS
# ==================================================
@app.get("/pdv/comanda")
def buscar_comanda():

    conn = None
    cur = None

    try:
        empresa = int(request.args.get("empresa"))
        comanda = int(request.args.get("comanda"))

        conn = get_connection()
        cur = conn.cursor()

        # ------------------------------------------------
        # 1) Verificar se a comanda está em uso no balcão
        # ------------------------------------------------
        cur.execute("""
            SELECT FIRST 1 ORC_ID
            FROM TB_ORCAMENTO
            WHERE ORC_EMPRESA = ?
              AND ORC_COMANDA = ?
              AND ORC_STATUS = 'A'
        """, (empresa, comanda))

        orc = cur.fetchone()

        if orc:
            return jsonify({
                "erro": f"Comanda {comanda} está sendo utilizada no balcão."
            }), 409

        # ------------------------------------------------
        # 2) Procurar orçamento digitado
        # ------------------------------------------------
        cur.execute("""
            SELECT FIRST 1 ORC_ID
            FROM TB_ORCAMENTO
            WHERE ORC_EMPRESA = ?
              AND ORC_COMANDA = ?
              AND ORC_STATUS = 'D'
            ORDER BY ORC_ID DESC
        """, (empresa, comanda))

        orc = cur.fetchone()

        if not orc:
            return jsonify({
                "orc_id": None,
                "itens": []
            })

        orc_id = orc[0]

        # ------------------------------------------------
        # 3) Carregar itens do orçamento
        # ------------------------------------------------
        cur.execute("""
            SELECT
                I.ORCI_PRODUTO,
                P.PRD_DESCRICAO,
                P.PRD_PRECO_VENDA,
                I.ORCI_QUANTIDADE,
                I.ORCI_VALOR_TOTAL
            FROM TB_ORCAMENTO_ITEM I
            JOIN TB_PRODUTO P
              ON P.PRD_EMPRESA = I.ORCI_EMPRESA
             AND P.PRD_ID = I.ORCI_PRODUTO
            WHERE I.ORCI_EMPRESA = ?
              AND I.ORCI_ORCAMENTO = ?
            ORDER BY I.ORCI_SEQUENCIAL
        """, (empresa, orc_id))

        itens = []

        for row in cur.fetchall():
            itens.append({
                "produto_id": row[0],
                "descricao": row[1],
                "valor_unitario": float(row[2]) if row[2] else 0,
                "quantidade": float(row[3]) if row[3] else 0,
                "valor_total": float(row[4]) if row[4] else 0
            })

        return jsonify({
            "orc_id": orc_id,
            "itens": itens
        })

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

    finally:
        try:
            if cur:
                cur.close()
            if conn:
                conn.close()
        except:
            pass

# ==================================================
# BUSCAR PRODUTOS (PESQUISA)
# ==================================================
@app.get("/pdv/produtos/buscar")
def buscar_produtos():

    empresa = request.args.get("empresa")
    termo = request.args.get("q")

    if not empresa or not termo:
        return {"ok": False, "message": "Empresa ou termo não informado"}, 400

    if len(termo) < 3:
        return {
            "ok": True,
            "total": 0,
            "dados": []
        }

    con = None
    cur = None

    try:
        con = get_connection()
        cur = con.cursor()

        termo_busca = termo.upper() + "%"

        cur.execute("""
            SELECT
                PRD_ID,
                PRD_DESCRICAO,
                PRD_PRECO_VENDA,
                PRD_FOTO
            FROM TB_PRODUTO
            WHERE PRD_EMPRESA = ?
              AND PRD_STATUS = 'A'
              AND UPPER(PRD_DESCRICAO) LIKE ?
            ORDER BY PRD_DESCRICAO
        """, (empresa, termo_busca))

        produtos = []

        for row in cur.fetchall():
            foto = row[3]

            produtos.append({
                "id": row[0],
                "descricao": row[1],
                "preco": float(row[2]) if row[2] else 0,
                "foto_url": f"http://192.168.1.238:5000/pdv/imagens/{foto}" if foto else None
            })

        return {
            "ok": True,
            "total": len(produtos),
            "dados": produtos
        }

    except Exception as e:
        return {"ok": False, "erro": str(e)}, 500

    finally:
        try:
            if cur:
                cur.close()
            if con:
                con.close()
        except:
            pass

# ==================================================
# INFORMAÇÕES DE ACESSO
# ==================================================
def mostrar_ips():
    hostname = socket.gethostname()
    ip_local = socket.gethostbyname(hostname)

    print("=====================================")
    print("API PDV ParmaSoft")
    print("Servidor iniciado")
    print("")
    print(f"Acesso local : http://127.0.0.1:5000")
    print(f"Acesso rede  : http://{ip_local}:5000")
    print("=====================================")

# ==================================================
# INICIALIZAÇÃO
# ==================================================
from waitress import serve

if __name__ == "__main__":
    mostrar_ips()
    serve(app, host="0.0.0.0", port=5000)