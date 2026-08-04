from flask import Flask, request, jsonify
import win32print
import fdb
import os
from datetime import datetime, date, time

app = Flask(__name__)

# ==================================================
# CONFIG GERAL
# ==================================================
BASE_IMG_DIR = r"C:\Parmasoft\Padaria\imagens"
PASTA_PEDIDOS = os.path.join(BASE_IMG_DIR, "pedidos")
os.makedirs(PASTA_PEDIDOS, exist_ok=True)

# ==================================================
# CONFIG FIREBIRD
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
# CONFIG IMPRESSORA TÉRMICA
# ==================================================
LARGURA_LINHA = 42
LARGURA_TRACEJADO = LARGURA_LINHA + 5
COL_VALOR = 12  # coluna fixa para alinhamento decimal
NOME_IMPRESSORA = "ELGIN i9(USB)"

# ESC/POS – NEGRITO
BOLD_ON = "\x1b\x45\x01"
BOLD_OFF = "\x1b\x45\x00"

# ==================================================
# UTIL
# ==================================================
def formatar_data_br(value):
    if not value:
        return ""
    try:
        return datetime.strptime(str(value), "%Y-%m-%d").strftime("%d/%m/%Y")
    except Exception:
        return str(value)

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

def parse_date(value):
    if not value:
        return None
    if isinstance(value, date):
        return value
    for fmt in ("%Y-%m-%d", "%d/%m/%Y"):
        try:
            return datetime.strptime(str(value), fmt).date()
        except Exception:
            pass
    return None

def parse_time(value):
    if not value:
        return None
    if isinstance(value, time):
        return value
    for fmt in ("%H:%M", "%H:%M:%S"):
        try:
            return datetime.strptime(str(value), fmt).time()
        except Exception:
            pass
    return None

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

        # ---------- CABEÇALHO ----------
        linhas.append(f"{BOLD_ON}{centralizar('PADARIA PARMASOFT')}{BOLD_OFF}")
        linhas.append("-" * LARGURA_TRACEJADO)

        linhas.append(f"{BOLD_ON}CLIENTE:{BOLD_OFF} {cabecalho.get('cliente','')}")
        linhas.append(f"{BOLD_ON}PAGAMENTO:{BOLD_OFF} {cabecalho.get('forma_pagamento','')}")

        linhas.append(
            f"{BOLD_ON}ENTREGA:{BOLD_OFF} "
            f"{formatar_data_br(cabecalho.get('data_entrega')):<{LARGURA_LINHA - 15}}"
            f"{BOLD_ON}HORA:{BOLD_OFF} {cabecalho.get('hora_entrega','')}"
        )

        contato = (cabecalho.get("contato") or "").strip()
        if contato:
            linhas.append(f"{BOLD_ON}TELEFONE:{BOLD_OFF} {contato}")

        obs = (cabecalho.get("observacoes") or "").strip()
        if obs:
            linhas.append(f"{BOLD_ON}OBS:{BOLD_OFF} {obs}")

        linhas.append("-" * LARGURA_TRACEJADO)

        # ---------- ITENS ----------
        for item in itens:
            linhas.append(item.get("descricao1", ""))

            qtd = str(item.get("quantidade", ""))
            unit = money(item.get("preco_unitario", 0))
            sub = money(item.get("subtotal", 0))

            linha_calc = f"{qtd} X {unit} ="
            linha_valor = f"{sub:>{COL_VALOR}}"

            linhas.append(
                f"{linha_calc:>{LARGURA_LINHA - COL_VALOR}}{linha_valor}"
            )

        # ---------- TOTAL ----------
        linhas.append("-" * LARGURA_TRACEJADO)

        total_valor = f"{money(cabecalho.get('total', 0)):>{COL_VALOR}}"
        linhas.append(
            f"{BOLD_ON}{'TOTAL:':>{LARGURA_LINHA - COL_VALOR}}{total_valor}{BOLD_OFF}"
        )

        linhas.append("-" * LARGURA_TRACEJADO)
        linhas.append(centralizar("Obrigado pela preferência"))

        linhas.extend(["", "", "", "", ""])
        linhas.extend(["", "", "", "", ""])

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
