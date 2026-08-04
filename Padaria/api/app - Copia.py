from flask import Flask, request, jsonify
import os
import fdb
import win32print
from datetime import datetime, date, time
from werkzeug.utils import secure_filename

app = Flask(__name__)

# ==================================================
# CONFIG – PASTA DE IMAGENS (FOTO DO BOLO)
# ==================================================
BASE_IMG_DIR = r"C:\Parmasoft\Padaria\imagens"
PASTA_PEDIDOS = os.path.join(BASE_IMG_DIR, "pedidos")
os.makedirs(PASTA_PEDIDOS, exist_ok=True)

ALLOWED_EXT = {"jpg", "jpeg", "png"}
MAX_MB = 8

# ==================================================
# PING
# ==================================================
@app.get("/ping")
def ping():
    return {"ok": True}  
    
# ==================================================
# BUSCAR RECHEIOS
# ==================================================
@app.get("/recheios/busca")
def buscar_recheios():
    descricao = request.args.get("descricao", "").strip()

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        sql = """
            SELECT
                REC_ID,
                REC_DESCRICAO,
                REC_PRECO_KG
            FROM TB_RECHEIO
            WHERE REC_DESCRICAO LIKE ?
            ORDER BY REC_DESCRICAO
        """
        param = f"%{descricao}%"
        cur.execute(sql, (param,))
        rows = cur.fetchall()

        return jsonify([
            {
                "id": r[0],
                "descricao": r[1],
                "preco_kg": float(r[2] or 0)
            }
            for r in rows
        ])

    except Exception as e:
        return jsonify({"erro": str(e)}), 500
    finally:
        if con:
            con.close()
    
    # ==================================================
# BUSCAR PRODUTOS
# ==================================================
@app.get("/produtos/busca")
def buscar_produtos():
    descricao = request.args.get("descricao", "").strip()

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        sql = """
            SELECT
                PRO_ID,
                PRO_DESCRICAO,
                PRO_PRECO
            FROM TB_PRODUTO
            WHERE PRO_DESCRICAO LIKE ?
            ORDER BY PRO_DESCRICAO
        """
        param = f"%{descricao}%"
        cur.execute(sql, (param,))
        rows = cur.fetchall()

        return jsonify([
            {
                "id": r[0],
                "descricao": r[1],
                "preco": float(r[2] or 0)
            }
            for r in rows
        ])

    except Exception as e:
        return jsonify({"erro": str(e)}), 500
    finally:
        if con:
            con.close()

    
    
    

# ==================================================
# CONEXÃO FIREBIRD
# ==================================================
def get_connection():
    return fdb.connect(
        host="localhost",
        database=r"E:\Dados Clientes\Jailma\Dados.FDB",
        user="SYSDBA",
        password="masterkey",
        charset="ISO8859_1"
    )

# ==================================================
# UTIL
# ==================================================
def round_money(value):
    try:
        return round(float(value), 2)
    except Exception:
        return 0.00

def parse_float(value, default=0.0):
    try:
        return float(value)
    except Exception:
        return default

def parse_date(value):
    if not value:
        return None
    if isinstance(value, date):
        return value

    value = str(value)

    formatos = [
        "%d/%m/%Y",
        "%Y-%m-%d",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d %H:%M:%S",
    ]

    for fmt in formatos:
        try:
            return datetime.strptime(value[:19], fmt).date()
        except Exception:
            pass

    return None


def parse_time(value):
    if not value:
        return None
    if isinstance(value, time):
        return value

    value = str(value)

    formatos = [
        "%H:%M",
        "%H:%M:%S",
    ]

    for fmt in formatos:
        try:
            return datetime.strptime(value[:8], fmt).time()
        except Exception:
            pass

    return None


# ==================================================
# SALVAR PEDIDO
# ==================================================
@app.route("/pedidos", methods=["POST"])
def salvar_pedido():
    data = request.json or {}
    pedido = data.get("pedido")
    itens = data.get("itens")

    if not pedido or not itens:
        return jsonify({"erro": "Pedido ou itens não informados"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("SELECT NEXT VALUE FOR GEN_TB_PEDIDO_PADARIA FROM RDB$DATABASE")
        pedido_id = cur.fetchone()[0]

        cur.execute("""
            INSERT INTO TB_PEDIDO_PADARIA (
                PED_ID,
                PED_CLIENTE,
                PED_CONTATO,
                PED_PAGAMENTO,
                PED_DATA_ENT,
                PED_HORA_ENT,
                PED_OBS,
                PED_TOTAL,
                PED_STATUS,
                PED_DATA_INC
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        """, (
            pedido_id,
            pedido.get("cliente"),
            pedido.get("contato"),
            pedido.get("forma_pagamento"),            
            parse_date(
                pedido.get("data_entrega") or pedido.get("dataEntrega")
            ),
            parse_time(
                pedido.get("hora_entrega") or pedido.get("horaEntrega")
            ),
            pedido.get("observacoes"),
            round_money(pedido.get("total")),
            "ENVIADO"
        ))

        for item in itens:
            cur.execute("SELECT NEXT VALUE FOR GEN_TB_PEDIDO_PADARIA_ITEM FROM RDB$DATABASE")
            item_id = cur.fetchone()[0]

            item_tipo = (item.get("item_tipo") or "").strip().upper()

            cur.execute("""
                INSERT INTO TB_PEDIDO_PADARIA_ITEM (
                    ITEM_ID,
                    PED_ID,
                    ITEM_DESC1,
                    ITEM_DESC2,
                    ITEM_DESC3,
                    ITEM_UNIDADE,
                    ITEM_QTD,
                    ITEM_PRECO,
                    ITEM_SUBTOTAL,
                    ITEM_TIPO,
                    REC_ID
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                item_id,
                pedido_id,
                item.get("descricao1"),
                item.get("descricao2"),
                item.get("descricao3"),
                item.get("unidade"),
                parse_float(item.get("quantidade")),
                round_money(item.get("preco_unitario")),
                round_money(item.get("subtotal")),
                item_tipo,
                item.get("rec_id") if item_tipo == "B" else None,
            ))

        con.commit()
        return jsonify({"status": "ok", "pedido_id": pedido_id})

    except Exception as e:
        if con:
            con.rollback()
        return jsonify({"erro": str(e)}), 500
    finally:
        if con:
            con.close()

# ==================================================
# CONFIG IMPRESSORA
# ==================================================
LARGURA_LINHA = 42
LARGURA_TRACEJADO = LARGURA_LINHA + 5
COL_VALOR = 12
NOME_IMPRESSORA = "ELGIN i9(USB)"

BOLD_ON = "\x1b\x45\x01"
BOLD_OFF = "\x1b\x45\x00"

def centralizar(txt):
    return str(txt).center(LARGURA_LINHA)

def money(v):
    try:
        return (
            f"{float(v):,.2f}"
            .replace(",", "X")
            .replace(".", ",")
            .replace("X", ".")
        )
    except Exception:
        return "0,00"

def formatar_data_br(value):
    if not value:
        return ""
    try:
        return datetime.strptime(str(value), "%Y-%m-%d").strftime("%d/%m/%Y")
    except Exception:
        return str(value)

def get_val(d, *keys):
    for k in keys:
        v = d.get(k)
        if v not in (None, "", " "):
            return v
    return ""

# ==================================================
# IMPRESSÃO TÉRMICA
# ==================================================
@app.post("/imprimir/termico")
def imprimir_termico():
    data = request.json or {}
    cabecalho = data.get("cabecalho")
    itens = data.get("itens")

    if not cabecalho or not itens:
        return jsonify({"erro": "Dados do pedido não informados"}), 400

    try:
        linhas = []

        linhas.append(f"{BOLD_ON}{centralizar('PADARIA PARMASOFT')}{BOLD_OFF}")
        linhas.append("-" * LARGURA_TRACEJADO)

        linhas.append(f"{BOLD_ON}CLIENTE:{BOLD_OFF} {cabecalho.get('cliente','')}")

        pagamento = get_val(cabecalho, "forma_pagamento", "pagamento")
        data_entrega = get_val(cabecalho, "data_entrega", "dataEntrega")
        hora_entrega = get_val(cabecalho, "hora_entrega", "horaEntrega")

        linhas.append(f"{BOLD_ON}PAGAMENTO:{BOLD_OFF} {pagamento}")
        linhas.append(
            f"{BOLD_ON}ENTREGA:{BOLD_OFF} "
            f"{formatar_data_br(data_entrega):<{LARGURA_LINHA - 15}}"
            f"{BOLD_ON}HORA:{BOLD_OFF} {hora_entrega}"
        )

        if cabecalho.get("contato"):
            linhas.append(f"{BOLD_ON}TELEFONE:{BOLD_OFF} {cabecalho['contato']}")

        if cabecalho.get("observacoes"):
            linhas.append(f"{BOLD_ON}OBS:{BOLD_OFF} {cabecalho['observacoes']}")

        linhas.append("-" * LARGURA_TRACEJADO)

        for item in itens:
            linhas.append(item.get("descricao1", ""))

            if item.get("item_tipo") == "B":
                if item.get("descricao2"):
                    linhas.append(f"  Recheio 1: {item.get('descricao2')}")
                if item.get("descricao3"):
                    linhas.append(f"  Recheio 2: {item.get('descricao3')}")

            qtd = str(item.get("quantidade", ""))
            unit = money(item.get("preco_unitario", 0))
            sub = money(item.get("subtotal", 0))

            linhas.append(
                f"{f'{qtd} X {unit} =':>{LARGURA_LINHA - COL_VALOR}}{sub:>{COL_VALOR}}"
            )

        linhas.append("-" * LARGURA_TRACEJADO)
        linhas.append(centralizar("Obrigado pela preferência"))
        linhas.extend([""] * 12)

        texto = "\n".join(linhas)

        hPrinter = win32print.OpenPrinter(NOME_IMPRESSORA)
        try:
            win32print.StartDocPrinter(hPrinter, 1, ("Pedido Padaria", None, "RAW"))
            win32print.StartPagePrinter(hPrinter)
            win32print.WritePrinter(hPrinter, texto.encode("cp860", errors="ignore"))
            win32print.EndPagePrinter(hPrinter)
            win32print.EndDocPrinter(hPrinter)
        finally:
            win32print.ClosePrinter(hPrinter)

        return jsonify({"status": "ok"})

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

# ==================================================
# START
# ==================================================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002, debug=True)
