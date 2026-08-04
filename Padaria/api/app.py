from flask import Flask, request, jsonify
import os
import fdb
import win32print

from datetime import datetime, date, time
from werkzeug.utils import secure_filename

app = Flask(__name__)

import sys
sys.stdout.reconfigure(line_buffering=True)

# ==================================================
# CONFIG – PASTA DE IMAGENS (FOTO DO BOLO)
# ==================================================
BASE_IMG_DIR = r"C:\Parmasoft\Padaria\imagens"
PASTA_PEDIDOS = os.path.join(BASE_IMG_DIR, "pedidos")
os.makedirs(PASTA_PEDIDOS, exist_ok=True)

ALLOWED_EXT = {"jpg", "jpeg", "png"}
MAX_MB = 8  # limite de upload

@app.get("/ping")
def ping():
    return {"ok": True}
    
@app.get("/health")
def health():
    return {
        "status": "ok",
        "time": datetime.now().isoformat()
    }

# ==================================================
# CONEXÃO FIREBIRD/
# ==================================================
def get_connection():
    return fdb.connect(
        host="localhost",
        database=r"E:\Dados Clientes\Jailma\Dados.FDB",
        # database=r"C:\Parmasoft\Dados\Dados.FDB",
        user="SYSDBA",
        password="masterkey",
        charset="ISO8859_1"
    )



# ==================================================
# ATUALIZA CAMINHO DA FOTO NO PEDIDO
# ==================================================
def atualizar_foto_path(ped_id: int, rel_path: str):
    con = None
    try:
        con = get_connection()
        cur = con.cursor()
        cur.execute("""
            UPDATE TB_PEDIDO_PADARIA
               SET PED_FOTO_PATH = ?
             WHERE PED_ID = ?
        """, (rel_path, ped_id))
        con.commit()
    finally:
        if con:
            con.close()

# ==================================================
# UTIL – ARREDONDAMENTO / PARSE
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
    """
    Aceita:
      - 'YYYY-MM-DD' (padrão comum do Flutter)
      - 'DD/MM/YYYY' (padrão BR)
      - date (já convertido)
    """
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

    # Se não conseguir converter, retorna como string mesmo (Firebird às vezes aceita),
    # mas é melhor mandar no formato 'YYYY-MM-DD' do app.
    return s


def parse_time(value):
    """
    Aceita:
      - 'HH:MM'
      - 'HH:MM:SS'
      - 'HH:MM AM/PM' ou 'HH:MM PM'
      - time (já convertido)
    """
    if value is None:
        return None
    if isinstance(value, time):
        return value

    s = str(value).strip()
    if not s:
        return None

    for fmt in ("%H:%M", "%H:%M:%S", "%I:%M %p"):
        try:
            return datetime.strptime(s, fmt).time()
        except Exception:
            pass

    return None


# ==================================================
# BUSCA DE PRODUTOS
# ==================================================
@app.route("/produtos/busca", methods=["GET"])
def buscar_produtos():
    descricao = request.args.get("descricao", "").strip()

    if len(descricao) < 3:
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
            WHERE PRD_DESCRICAO CONTAINING ?
            ORDER BY PRD_DESCRICAO
            ROWS 20
        """, (descricao,))

        return jsonify([
            {
                "id": r[0],
                "descricao": r[1],
                "unidade": r[2],
                "preco": round_money(r[3])
            }
            for r in cur.fetchall()
        ])

    except Exception as e:
        print("Erro produtos:", e)
        return jsonify({"erro": "Erro ao buscar produtos"}), 500
    finally:
        if con:
            con.close()


# ==================================================
# BUSCA DE RECHEIOS
# ==================================================
@app.route("/recheios/busca", methods=["GET"])
def buscar_recheios():
    descricao = request.args.get("descricao", "").strip()

    if len(descricao) < 3:
        return jsonify([])

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT
                REC_ID,
                REC_DESCRICAO,
                REC_PRECO_KG
            FROM TB_RECHEIO_BOLO
            WHERE REC_ATIVO = 'S'
              AND REC_DESCRICAO CONTAINING ?
            ORDER BY REC_DESCRICAO
            ROWS 20
        """, (descricao,))

        return jsonify([
            {
                "id": r[0],
                "descricao": r[1],
                "preco_kg": round_money(r[2])
            }
            for r in cur.fetchall()
        ])

    except Exception as e:
        print("Erro recheios:", e)
        return jsonify({"erro": "Erro ao buscar recheios"}), 500
    finally:
        if con:
            con.close()


# ==================================================
# SALVAR PEDIDO (CABEÇALHO + ITENS)
# ==================================================
@app.route("/pedidos", methods=["POST"])
def salvar_pedido():
    data = request.json or {}

    pedido = data.get("pedido")
    itens = data.get("itens", [])

    if not pedido or not itens:
        return jsonify({"erro": "Pedido ou itens não informados"}), 400

    con = None
    try:
        con = get_connection()
        cur = con.cursor()

        # =============================
        # GERA PED_ID
        # =============================
        cur.execute("SELECT NEXT VALUE FOR GEN_TB_PEDIDO_PADARIA FROM RDB$DATABASE")
        pedido_id = cur.fetchone()[0]

        # =============================
        # DATA / HORA
        # =============================
        data_entrega = parse_date(pedido.get("data_entrega"))
        hora_entrega = parse_time(pedido.get("hora_entrega"))

        # =============================
        # INSERE CABEÇALHO
        # =============================
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
            data_entrega,
            hora_entrega,
            pedido.get("observacoes"),
            round_money(pedido.get("total")),
            "ENVIADO"
        ))

        # =============================
        # INSERE ITENS (PRODUTOS + BOLOS)
        #  - BOLO:
        #      ITEM_DESC1 = descrição do bolo
        #      ITEM_DESC2 = recheio 1
        #      ITEM_DESC3 = recheio 2 (opcional)  <-- AQUI
        #      ITEM_OBS   = observação do bolo
        # =============================
        for item in itens:
            cur.execute("SELECT NEXT VALUE FOR GEN_TB_PEDIDO_PADARIA_ITEM FROM RDB$DATABASE")
            item_id = cur.fetchone()[0]

            item_tipo = (item.get("item_tipo") or "").strip().upper()  # 'P' ou 'B'

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
                    REC_ID ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                item_id,
                pedido_id,
                item.get("descricao1"),
                item.get("descricao2"),
                item.get("descricao3"),  # <- recheio 2 (quando bolo)
                item.get("unidade"),
                parse_float(item.get("quantidade")),
                round_money(item.get("preco_unitario")),
                round_money(item.get("subtotal")),
                item_tipo,
                item.get("rec_id") if item_tipo == "B" else None,
))

        con.commit()

        return jsonify({
            "status": "ok",
            "pedido_id": pedido_id
        })

    except Exception as e:
        if con:
            con.rollback()
        print("Erro salvar pedido:", e)
        return jsonify({"erro": "Erro ao salvar pedido"}), 500
    finally:
        if con:
            con.close()



# ==================================================
# UPLOAD DA FOTO DO BOLO (SALVA EM PASTA + GRAVA PATH NO BANCO)
# ==================================================
@app.route("/upload/pedido-foto", methods=["POST"])
def upload_pedido_foto():
    ped_id = request.form.get("ped_id")
    file = request.files.get("foto")

    if not ped_id:
        return jsonify({"ok": False, "msg": "ped_id não informado"}), 400
    if not file:
        return jsonify({"ok": False, "msg": "arquivo 'foto' não enviado"}), 400

    # valida extensão
    original = (file.filename or "").strip()
    ext = original.rsplit(".", 1)[-1].lower() if "." in original else ""
    if ext not in ALLOWED_EXT:
        return jsonify({"ok": False, "msg": "Extensão inválida. Use jpg/jpeg/png"}), 400

    # limite simples de tamanho (para evitar travar o servidor)
    file.stream.seek(0, os.SEEK_END)
    size = file.stream.tell()
    file.stream.seek(0)
    if size > (MAX_MB * 1024 * 1024):
        return jsonify({"ok": False, "msg": f"Arquivo muito grande (> {MAX_MB}MB)"}), 400

    try:
        ped_id_int = int(ped_id)
    except Exception:
        return jsonify({"ok": False, "msg": "ped_id inválido"}), 400

    # salva com nome fixo {PED_ID}.jpg (padronizado)
    filename = secure_filename(f"{ped_id_int}.jpg")
    abs_path = os.path.join(PASTA_PEDIDOS, filename)

    # salva arquivo
    file.save(abs_path)

    # grava caminho relativo no banco
    rel_path = f"pedidos/{ped_id_int}.jpg"
    try:
        atualizar_foto_path(ped_id_int, rel_path)
    except Exception as e:
        # se der erro no banco, apaga o arquivo para não ficar lixo
        try:
            if os.path.exists(abs_path):
                os.remove(abs_path)
        except Exception:
            pass
        print("Erro ao atualizar foto path:", e)
        return jsonify({"ok": False, "msg": "Erro ao gravar caminho da foto no banco"}), 500

    return jsonify({"ok": True, "path": rel_path})

# ==================================================
# CONFIG IMPRESSORA TÉRMICA
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
        linhas.append(f"{BOLD_ON}PAGAMENTO:{BOLD_OFF} {cabecalho.get('forma_pagamento','')}")

        linhas.append(
            f"{BOLD_ON}ENTREGA:{BOLD_OFF} "
            f"{formatar_data_br(cabecalho.get('data_entrega')):<{LARGURA_LINHA - 15}}"
            f"{BOLD_ON}HORA:{BOLD_OFF} {cabecalho.get('hora_entrega','')}"
        )

        if cabecalho.get("contato"):
            linhas.append(f"{BOLD_ON}TELEFONE:{BOLD_OFF} {cabecalho['contato']}")

        if cabecalho.get("observacoes"):
            linhas.append(f"{BOLD_ON}OBS:{BOLD_OFF} {cabecalho['observacoes']}")

        linhas.append("-" * LARGURA_TRACEJADO)

        # ---------- ITENS ----------
        for item in itens:
            linhas.append(item.get("descricao1", ""))

            # 🔥 RECHEIOS (PADRÃO FINAL)
            if item.get("item_tipo") == "B":
                recheio1 = item.get("descricao2")
                recheio2 = item.get("descricao3")
            else:
                recheio1 = None
                recheio2 = None

            if recheio1:
                linhas.append(f"  Recheio 1: {recheio1}")
            if recheio2:
                linhas.append(f"  Recheio 2: {recheio2}")

            qtd = str(item.get("quantidade", ""))
            unit = money(item.get("preco_unitario", 0))
            sub = money(item.get("subtotal", 0))

            linhas.append(
                f"{f'{qtd} X {unit} =':>{LARGURA_LINHA - COL_VALOR}}{sub:>{COL_VALOR}}"
            )

        linhas.append("-" * LARGURA_TRACEJADO)

        total_valor = f"{money(cabecalho.get('total', 0)):>{COL_VALOR}}"
        linhas.append(
            f"{BOLD_ON}{'TOTAL:':>{LARGURA_LINHA - COL_VALOR}}{total_valor}{BOLD_OFF}"
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

# START
if __name__ == "__main__":    
    app.run(
    host="0.0.0.0",
    port=5002,
    debug=True,
    threaded=True
)

