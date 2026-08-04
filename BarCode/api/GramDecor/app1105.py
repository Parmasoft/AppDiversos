from flask import Flask, request, jsonify
import fdb
import os
from PIL import Image
import json
import socket
import traceback
from decimal import Decimal, ROUND_HALF_UP

app = Flask(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LOGO_ZEBRA_PATH = os.path.join(BASE_DIR, "logo_cliente.png")
CONFIG_IMPRESSAO_PATH = os.path.join(BASE_DIR, "config_impressao.json")

def inteiro_seguro(valor, padrao=0):
    try:
        if valor is None:
            return padrao

        if isinstance(valor, str) and valor.strip() == "":
            return padrao

        return int(valor)
    except:
        return padrao

# ==============================================================
# CONEXÃO FIREBIRD
# ==============================================================
def get_connection():
    return fdb.connect(
        host="localhost",
        database=r"E:\Dados Clientes\GramDecor\Dados.FDB",
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
# ROTA: PING / TESTE DE CONEXÃO
# ==============================================================
@app.route("/ping", methods=["GET"])
def ping():
    return jsonify({"status": "ok", "mensagem": "API online"})


# ==============================================================
# FUNÇÃO: FORMATAR CÓDIGO DO ROLO
# Regra: R + produto 6 dígitos + quantidade 6 dígitos
# Exemplo: produto 1549 / 67,30 => R001549006730
# ==============================================================
def montar_codigo_rolo(pror_id, produto_id, quantidade):
    # Novo padrão:
    # R + PROR_ID(6) + PRODUTO(7) + QTDE(4 com 1 decimal)
    # Exemplo: R00000710041460850 = rolo 7 / produto 1004146 / 85,0

    pror_fmt = str(int(pror_id)).zfill(6)
    produto_fmt = str(int(produto_id)).zfill(7)

    # quantidade com 1 casa decimal, sem vírgula/ponto
    # 85.0  => 0850
    # 85.5  => 0855
    # 200.0 => 2000
    quantidade_dec = int(round(float(quantidade) * 10))
    quantidade_fmt = str(quantidade_dec).zfill(4)

    return f"R{pror_fmt}{produto_fmt}{quantidade_fmt}"
    
# ==============================================================
# FUNÇÃO: QUEBRAR TEXTO EM LINHAS PARA ETIQUETA
# ==============================================================
def quebrar_texto(texto, tamanho=32, max_linhas=2):
    texto = (texto or "").strip()
    palavras = texto.split()
    linhas = []
    linha_atual = ""

    for palavra in palavras:
        teste = (linha_atual + " " + palavra).strip()

        if len(teste) <= tamanho:
            linha_atual = teste
        else:
            if linha_atual:
                linhas.append(linha_atual)
            linha_atual = palavra

        if len(linhas) >= max_linhas:
            break

    if linha_atual and len(linhas) < max_linhas:
        linhas.append(linha_atual)

    while len(linhas) < max_linhas:
        linhas.append("")

    return linhas  

# ==============================================================
# FUNÇÕES: CONVERTER LOGO PARA ZPL (^GFA)
# ==============================================================
def imagem_para_gfa(caminho, largura=170, altura_max=60, threshold=180):
    if not os.path.exists(caminho):
        return None

    img = Image.open(caminho).convert("L")

    # ----------------------------------------------------------
    # Recorta margens brancas para a logo aproveitar melhor o espaço
    # ----------------------------------------------------------
    mascara = img.point(lambda p: 255 if p < 245 else 0)
    bbox = mascara.getbbox()
    if bbox:
        img = img.crop(bbox)

    larg_orig, alt_orig = img.size    
    
    if larg_orig <= 0 or alt_orig <= 0:
        return None

    escala = min(largura / larg_orig, altura_max / alt_orig)
    nova_larg = max(1, int(larg_orig * escala))
    nova_alt = max(1, int(alt_orig * escala))

    try:
        resample = Image.Resampling.LANCZOS
    except:
        resample = Image.LANCZOS

    img = img.resize((nova_larg, nova_alt), resample)

    bytes_por_linha = (nova_larg + 7) // 8
    linhas_hex = []

    for y in range(nova_alt):
        linha_hex = []
        byte_atual = 0
        bits_no_byte = 0

        for x in range(bytes_por_linha * 8):
            bit = 0

            if x < nova_larg:
                pixel = img.getpixel((x, y))
                bit = 1 if pixel < threshold else 0

            byte_atual = (byte_atual << 1) | bit
            bits_no_byte += 1

            if bits_no_byte == 8:
                linha_hex.append(f"{byte_atual:02X}")
                byte_atual = 0
                bits_no_byte = 0

        linhas_hex.append("".join(linha_hex))

    dados_hex = "".join(linhas_hex)
    total_bytes = bytes_por_linha * nova_alt

    return {
        "largura": nova_larg,
        "altura": nova_alt,
        "bytes_por_linha": bytes_por_linha,
        "total_bytes": total_bytes,
        "dados_hex": dados_hex,
    }


def bloco_logo_zpl(caminho, x=None, y=20, largura=170, altura_max=60):
    info = imagem_para_gfa(caminho, largura=largura, altura_max=altura_max)

    if not info:
        return ""

    # ----------------------------------------------------------
    # Se não informar X, alinha automaticamente no canto direito
    # considerando largura da etiqueta = 800
    # ----------------------------------------------------------
    if x is None:
        x = 800 - info["largura"] - 15

    if x < 0:
        x = 0

    return (
        f"^FO{x},{y}"
        f"^GFA,{info['total_bytes']},{info['total_bytes']},{info['bytes_por_linha']},{info['dados_hex']}"
        f"^FS"
    )
    
  
# ==============================================================
# FUNÇÕES: CONFIGURAÇÃO DE IMPRESSÃO
# ==============================================================
def carregar_config_impressao():
    padrao = {
        "modo": "rede",
        "ip": "192.168.1.50",
        "porta": 9100,
        "nome_windows": "ZDesigner ZD220-203dpi ZPL"
    }

    if not os.path.exists(CONFIG_IMPRESSAO_PATH):
        with open(CONFIG_IMPRESSAO_PATH, "w", encoding="utf-8") as f:
            json.dump(padrao, f, ensure_ascii=False, indent=4)
        return padrao

    try:
        with open(CONFIG_IMPRESSAO_PATH, "r", encoding="utf-8") as f:
            dados = json.load(f)

        for chave, valor in padrao.items():
            if chave not in dados:
                dados[chave] = valor

        return dados

    except Exception as e:
        raise Exception(f"Erro ao ler config_impressao.json: {e}")


def salvar_config_impressao(dados):
    config = {
        "modo": (dados.get("modo", "rede") or "rede").lower().strip(),
        "ip": dados.get("ip", ""),
        "porta": int(dados.get("porta", 9100)),
        "nome_windows": dados.get("nome_windows", "")
    }

    if config["modo"] not in ["rede", "windows", "preview"]:
        raise Exception("Modo de impressão inválido. Use 'rede', 'windows' ou 'preview'.")

    with open(CONFIG_IMPRESSAO_PATH, "w", encoding="utf-8") as f:
        json.dump(config, f, ensure_ascii=False, indent=4)

    return config


# ==============================================================
# FUNÇÕES: ENVIAR ZPL PARA IMPRESSORA
# ==============================================================
def enviar_zpl_rede(zpl, ip, porta=9100):
    if not ip:
        raise Exception("IP da impressora não configurado.")

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(8)
        s.connect((ip, int(porta)))
        s.sendall(zpl.encode("utf-8"))


def enviar_zpl_windows(zpl, nome_impressora):
    if not nome_impressora:
        raise Exception("Nome da impressora Windows não configurado.")

    try:
        import win32print
    except Exception:
        raise Exception("Biblioteca pywin32 não instalada. Rode: pip install pywin32")

    hprinter = win32print.OpenPrinter(nome_impressora)

    try:
        win32print.StartDocPrinter(
            hprinter,
            1,
            ("Etiqueta Rolo ZPL", None, "RAW")
        )

        try:
            win32print.StartPagePrinter(hprinter)
            win32print.WritePrinter(hprinter, zpl.encode("utf-8"))
            win32print.EndPagePrinter(hprinter)
        finally:
            win32print.EndDocPrinter(hprinter)

    finally:
        win32print.ClosePrinter(hprinter)


def enviar_zpl_para_impressora(zpl):
    config = carregar_config_impressao()
    modo = (config.get("modo") or "rede").lower().strip()

    if modo == "preview":
        return "Modo preview: ZPL gerado sem envio para impressora"

    if modo == "rede":
        enviar_zpl_rede(
            zpl,
            config.get("ip", ""),
            int(config.get("porta", 9100))
        )
        return "Enviado por rede/IP"

    if modo == "windows":
        enviar_zpl_windows(
            zpl,
            config.get("nome_windows", "")
        )
        return "Enviado pela impressora do Windows"

    raise Exception("Modo de impressão inválido. Use 'rede' ou 'windows'.")   
    

# ==============================================================
# FUNÇÕES: IMPRESSÃO TÉRMICA ELGIN I9 / ESC-POS
# Usado apenas para teste das etiquetas de rolo em papel térmico
# ==============================================================
def enviar_escpos_windows(dados_bytes, nome_impressora):
    if not nome_impressora:
        raise Exception("Nome da impressora Windows da Elgin i9 não configurado.")

    try:
        import win32print
    except Exception:
        raise Exception("Biblioteca pywin32 não instalada. Rode: pip install pywin32")

    hprinter = win32print.OpenPrinter(nome_impressora)

    try:
        win32print.StartDocPrinter(
            hprinter,
            1,
            ("Etiqueta Rolo ESC-POS", None, "RAW")
        )

        try:
            win32print.StartPagePrinter(hprinter)
            win32print.WritePrinter(hprinter, dados_bytes)
            win32print.EndPagePrinter(hprinter)
        finally:
            win32print.EndDocPrinter(hprinter)

    finally:
        win32print.ClosePrinter(hprinter)


def escpos_texto(txt):
    return (txt or "").encode("cp850", errors="replace")


def escpos_linha(txt=""):
    return escpos_texto(txt + "\n")


def escpos_centralizado():
    return b"\x1b\x61\x01"


def escpos_esquerda():
    return b"\x1b\x61\x00"


def escpos_negrito(ligado=True):
    return b"\x1b\x45\x01" if ligado else b"\x1b\x45\x00"


def escpos_fonte_dupla(ligado=True):
    return b"\x1d\x21\x11" if ligado else b"\x1d\x21\x00"


def escpos_cortar():
    return b"\n\n\n\x1d\x56\x00"


def escpos_codigo_barras_code128(codigo):
    codigo = (codigo or "").strip()

    # ESC/POS Code128 Function B
    # {B força Code Set B em muitas impressoras ESC/POS.
    dados = ("{B" + codigo).encode("ascii", errors="ignore")

    cmd = b""
    cmd += b"\x1d\x48\x02"       # HRI abaixo do código
    cmd += b"\x1d\x68\x70"       # Altura do código de barras
    cmd += b"\x1d\x77\x02"       # Largura
    cmd += b"\x1d\x6b\x49"       # GS k 73 = CODE128
    cmd += bytes([len(dados)])
    cmd += dados

    return cmd + b"\n"
    
def escpos_qrcode(conteudo, tamanho=7):
    """
    Gera comandos ESC/POS para imprimir QR Code.
    Conteúdo exemplo: R00138100089451020
    tamanho: 4 a 8 normalmente fica bom na i9.
    """
    dados = conteudo.encode("utf-8")

    pL = (len(dados) + 3) % 256
    pH = (len(dados) + 3) // 256

    cmd = bytearray()

    # Seleciona modelo QR Code 2
    cmd += b'\x1d\x28\x6b\x04\x00\x31\x41\x32\x00'

    # Define tamanho do módulo
    cmd += b'\x1d\x28\x6b\x03\x00\x31\x43' + bytes([tamanho])

    # Define correção de erro: 49=M, 50=Q, 51=H
    cmd += b'\x1d\x28\x6b\x03\x00\x31\x45\x31'

    # Armazena dados do QR Code
    cmd += b'\x1d\x28\x6b' + bytes([pL, pH]) + b'\x31\x50\x30' + dados

    # Imprime QR Code
    cmd += b'\x1d\x28\x6b\x03\x00\x31\x51\x30'

    return bytes(cmd)    


def quebrar_texto_termico(texto, tamanho=32, max_linhas=2):
    texto = (texto or "").strip()
    palavras = texto.split()
    linhas = []
    atual = ""

    for palavra in palavras:
        teste = (atual + " " + palavra).strip()

        if len(teste) <= tamanho:
            atual = teste
        else:
            if atual:
                linhas.append(atual)
            atual = palavra

        if len(linhas) >= max_linhas:
            break

    if atual and len(linhas) < max_linhas:
        linhas.append(atual)

    return linhas


def gerar_escpos_rolo_i9(produto_id, descricao, quantidade, unidade, codigo_barras):
    qtd_txt = f"{float(quantidade):.1f}".replace(".", ",")
    unidade = unidade or ""

    linhas_desc = quebrar_texto_termico(descricao, tamanho=32, max_linhas=3)

    b = b""
    b += b"\x1b\x40"  # inicializa impressora

    b += escpos_centralizado()
    b += escpos_negrito(True)
    b += escpos_fonte_dupla(True)
    b += escpos_linha("ETIQUETA DE ROLO")
    b += escpos_fonte_dupla(False)
    b += escpos_negrito(False)

    b += escpos_linha("--------------------------------")
    b += escpos_esquerda()

    b += escpos_negrito(True)
    b += escpos_linha(f"COD: {produto_id}")
    b += escpos_negrito(False)

    for linha in linhas_desc:
        b += escpos_linha(linha)

    b += escpos_linha("--------------------------------")

    b += escpos_centralizado()
    b += escpos_negrito(True)
    b += escpos_fonte_dupla(True)
    b += escpos_linha(f"{qtd_txt} {unidade}")
    b += escpos_fonte_dupla(False)
    b += escpos_negrito(False)

    b += escpos_linha("")

    # ==========================================================
    # CODE128 ANTIGO - INIBIDO PARA TESTE COM QR CODE
    # Se precisar voltar, basta descomentar a linha abaixo
    # e comentar o bloco do QR Code.
    # ==========================================================
    # b += escpos_codigo_barras_code128(codigo_barras)

    # ==========================================================
    # QR CODE - TESTE
    # O conteúdo do QR é o mesmo código atual do rolo:
    # R + PROR_ID(6) + PRODUTO(7) + QTDE(4)
    # Exemplo: R00138100089451020
    # ==========================================================
    b += escpos_centralizado()
    b += escpos_qrcode(codigo_barras, tamanho=7)
    b += escpos_linha("")
    b += escpos_linha(codigo_barras)
    b += escpos_esquerda()

    b += escpos_linha("--------------------------------")
    
    
    b += escpos_linha("")

    b += escpos_cortar()

    return b    
    
    
    
# ==============================================================
# FUNÇÃO: GERAR ZPL DA ETIQUETA DE ROLO
# Etiqueta: 10cm x 5cm
# Base inicial: Zebra 203dpi => largura 800 dots / altura 400 dots
# ==============================================================
def gerar_zpl_rolo(produto_id, descricao, quantidade, unidade, codigo_barras):
    qtd_txt = f"{float(quantidade):.2f}".replace(".", ",")
    unidade = unidade or ""

    # Descrição maior para teste visual.
    # Como a fonte aumentou, reduzi um pouco a quantidade de caracteres por linha.
    linhas_desc = quebrar_texto(descricao, tamanho=27, max_linhas=2)
    
    logo_zpl = bloco_logo_zpl(
        LOGO_ZEBRA_PATH,
        x=None,
        y=18,
        largura=210,
        altura_max=80,
    )

    zpl = f"""
^XA
^PW800
^LL400
^CI28
{logo_zpl}

^FO30,25^A0N,30,30^FDCOD: {produto_id}^FS

^FO30,70^A0N,42,42^FD{linhas_desc[0]}^FS
^FO30,120^A0N,42,42^FD{linhas_desc[1]}^FS

^FO25,205^BY2,2,70
^BCN,80,Y,N,N
^FD{codigo_barras}^FS

^FO525,198^A0N,42,42^FB245,1,0,C,0^FDQTDE:^FS
^FO525,252^A0N,52,52^FB245,1,0,C,0^FD{qtd_txt} {unidade}^FS

^XZ
"""
    return zpl.strip()
    
def gerar_zpl_rolo_qrcode(produto_id, descricao, quantidade, unidade, codigo_barras):
    qtd_txt = f"{float(quantidade):.2f}".replace(".", ",")
    unidade = unidade or ""

    linhas_desc = quebrar_texto(descricao, tamanho=27, max_linhas=2)

    logo_zpl = bloco_logo_zpl(
        LOGO_ZEBRA_PATH,
        x=None,
        y=18,
        largura=210,
        altura_max=80,
    )

    zpl = f"""
^XA
^PW800
^LL400
^CI28
{logo_zpl}

^FO30,25^A0N,30,30^FDCOD: {produto_id}^FS

^FO30,70^A0N,42,42^FD{linhas_desc[0]}^FS
^FO30,120^A0N,42,42^FD{linhas_desc[1]}^FS

^FO55,170
^BQN,2,8
^FDLA,{codigo_barras}^FS

^FO300,208^A0N,28,28^FD{codigo_barras}^FS

^FO525,198^A0N,42,42^FB245,1,0,C,0^FDQTDE:^FS
^FO525,252^A0N,52,52^FB245,1,0,C,0^FD{qtd_txt} {unidade}^FS

^XZ
"""
    return zpl.strip()    
    

# ==============================================================
# ROTA: CONSULTAR CONFIGURAÇÃO DE IMPRESSÃO
# ==============================================================
@app.route("/impressao/config", methods=["GET"])
def impressao_config_get():
    return jsonify({
        "status": "ok",
        "arquivo": CONFIG_IMPRESSAO_PATH,
        "config": carregar_config_impressao()
    })


# ==============================================================
# ROTA: SALVAR CONFIGURAÇÃO DE IMPRESSÃO
# ==============================================================
@app.route("/impressao/config", methods=["POST"])
def impressao_config_post():
    try:
        dados = request.get_json() or {}
        config = salvar_config_impressao(dados)

        return jsonify({
            "status": "ok",
            "mensagem": "Configuração de impressão salva.",
            "config": config
        })

    except Exception as e:
        return jsonify({
            "status": "erro",
            "mensagem": str(e)
        }), 500

# ==============================================================
# ROTA: TESTE DE IMPRESSÃO ELGIN I9
# Exemplo:
# /impressao/teste-i9?impressora=ELGIN i9(USB)
# ==============================================================
@app.route("/impressao/teste-i9", methods=["GET", "POST"])
def impressao_teste_i9():
    try:
        nome_impressora = request.args.get("impressora", "").strip()

        if not nome_impressora:
            nome_impressora = "ELGIN i9(USB)"

        dados = gerar_escpos_rolo_i9(
            produto_id=1004146,
            descricao="LINHO CONFORT 05 CINZA",
            quantidade=85.0,
            unidade="MT",
            codigo_barras="R00000110041460850"
        )

        enviar_escpos_windows(dados, nome_impressora)

        return jsonify({
            "status": "ok",
            "mensagem": f"Teste enviado para {nome_impressora}."
        })

    except Exception as e:
        return jsonify({
            "status": "erro",
            "mensagem": str(e)
        }), 500


# ==============================================================
# ROTA: TESTE DE IMPRESSÃO ZEBRA
# ==============================================================
@app.route("/impressao/teste", methods=["GET", "POST"])
def impressao_teste():
    try:
        zpl = """
^XA
^PW800
^LL400
^CI28

^FO0,40^A0N,38,38^FB800,1,0,C,0^FDTESTE DE IMPRESSAO^FS
^FO0,95^A0N,30,30^FB800,1,0,C,0^FDZEBRA / ETIQUETA 10x5 CM^FS

^FO0,155^A0N,42,42^FB800,1,0,C,0^FDQTDE: 70,00 UN^FS

^FO170,220^BY2,2,80
^BCN,90,Y,N,N
^FDROLO01000739007000^FS

^XZ
""".strip()

        retorno = enviar_zpl_para_impressora(zpl)

        return jsonify({
            "status": "ok",
            "mensagem": f"Teste enviado com sucesso. {retorno}"
        })

    except Exception as e:
        return jsonify({
            "status": "erro",
            "mensagem": str(e)
        }), 500


# ==============================================================
# ROTA: BUSCAR PRODUTOS POR DESCRIÇÃO
# ==============================================================
@app.route("/produtos/buscar", methods=["GET"])
def buscar_produtos_descricao():
    descricao = request.args.get("descricao", "").strip()

    if len(descricao) < 3:
        return jsonify({
            "status": "erro",
            "mensagem": "Digite pelo menos 3 caracteres para buscar.",
            "produtos": []
        }), 400

    try:
        empresa = int(request.args.get("empresa", 1))
        con = get_connection()
        cur = con.cursor()

        sql = """
            SELECT FIRST 30
                PRD_EMPRESA,
                PRD_ID,
                PRD_COD_BARRAS,
                PRD_DESCRICAO,
                PRD_UN_COMPRA,
                PRD_PRECO_VENDA
            FROM TB_PRODUTO
            WHERE PRD_EMPRESA = ?
              AND PRD_STATUS = 'A'
              AND UPPER(PRD_DESCRICAO) LIKE ?              
            ORDER BY PRD_DESCRICAO
        """

        termo = f"%{descricao.upper()}%"
        cur.execute(sql, (empresa, termo,))

        produtos = []
        for row in cur.fetchall():
            empresa, produto_id, cod_barras, desc, un, preco = row

            produtos.append({
                "empresa": empresa,
                "produto_id": produto_id,
                "codigo": cod_barras,
                "descricao": desc,
                "unidade": un,
                "preco": float(preco) if preco is not None else 0.0
            })

        return jsonify({
            "status": "ok",
            "produtos": produtos
        })

    except Exception as e:
        print("\n========== ERRO NA ROTA /produtos/buscar ==========")
        print(e)
        print("===================================================\n")
        return jsonify({"status": "erro", "mensagem": str(e)}), 500

    finally:
        try:
            con.close()
        except:
            pass


# ==============================================================
# ROTA: SALVAR ROLOS / ETIQUETAS PENDENTES
# ==============================================================
@app.route("/rolos/salvar", methods=["POST"])
def salvar_rolos():
    try:
        dados = request.get_json()

        empresa = int(dados.get("empresa", 1))
        produto_id = dados.get("produto_id")
        un = dados.get("un")
        prateleira = dados.get("prateleira")
        usuario = int(dados.get("usuario", 1))
        rolos = dados.get("rolos", [])

        if not produto_id:
            return jsonify({
                "status": "erro",
                "mensagem": "produto_id não informado."
            }), 400

        if not rolos:
            return jsonify({
                "status": "erro",
                "mensagem": "Nenhum rolo informado."
            }), 400

        con = get_connection()
        cur = con.cursor()

        cur.execute("""
            SELECT COALESCE(MAX(PROR_LOTE), 0) + 1
            FROM TB_PRODUTO_ROLO
            WHERE PROR_EMPRESA = ?
        """, (empresa,))
        novo_lote = cur.fetchone()[0]

        inseridos = []

        for quantidade in rolos:
            qtd = float(quantidade)

            if qtd <= 0:
                continue

            cur.execute("""
                SELECT COALESCE(MAX(PROR_ID), 0) + 1
                FROM TB_PRODUTO_ROLO
                WHERE PROR_EMPRESA = ?
            """, (empresa,))
            novo_id = cur.fetchone()[0]

            codigo_rolo = montar_codigo_rolo(novo_id, produto_id, qtd)

            sql_insert = """
                INSERT INTO TB_PRODUTO_ROLO
                (
                    PROR_EMPRESA,
                    PROR_ID,
                    PROR_LOTE,
                    PROR_PRODUTO,
                    PROR_QUANTIDADE,
                    PROR_UN,
                    PROR_CODIGO_BARRAS,
                    PROR_STATUS,
                    PROR_IMPRESSO,
                    PROR_DT_CADASTRO,
                    PROR_USUARIO_CAD,
                    PROR_PRATELEIRA
                )
                VALUES
                (?, ?, ?, ?, ?, ?, ?, 'A', 'N', CURRENT_TIMESTAMP, ?, ?)
            """

            cur.execute(
                sql_insert,
                (
                    empresa,
                    novo_id,
                    novo_lote,
                    produto_id,
                    qtd,
                    un,
                    codigo_rolo,
                    usuario,
                    prateleira
                )
            )

            inseridos.append({
                "id": novo_id,
                "lote": novo_lote,
                "produto_id": produto_id,
                "quantidade": qtd,
                "codigo_barras": codigo_rolo
            })

        con.commit()

        return jsonify({
            "status": "ok",
            "mensagem": f"{len(inseridos)} rolo(s) salvo(s) com sucesso.",
            "rolos": inseridos
        })

    except Exception as e:
        try:
            con.rollback()
        except:
            pass

        print("\n========== ERRO NA ROTA /rolos/salvar ==========")
        print(e)
        print("===============================================\n")

        return jsonify({"status": "erro", "mensagem": str(e)}), 500

    finally:
        try:
            con.close()
        except:
            pass


# ==============================================================
# ROTA: LISTAR ETIQUETAS PENDENTES DE IMPRESSÃO
# ==============================================================
@app.route("/rolos/pendentes", methods=["GET"])
def rolos_pendentes():
    try:
        empresa = int(request.args.get("empresa", 1))

        con = get_connection()
        cur = con.cursor()

        sql = """
            SELECT
                R.PROR_ID,
                R.PROR_LOTE,
                R.PROR_PRODUTO,
                P.PRD_DESCRICAO,
                R.PROR_QUANTIDADE,
                R.PROR_UN,
                R.PROR_CODIGO_BARRAS,
                R.PROR_PRATELEIRA,
                R.PROR_DT_CADASTRO,
                R.PROR_IMPRESSO
            FROM TB_PRODUTO_ROLO R
            JOIN TB_PRODUTO P
              ON P.PRD_EMPRESA = R.PROR_EMPRESA
             AND P.PRD_ID = R.PROR_PRODUTO
            JOIN (
                SELECT FIRST 10
                    X.PROR_LOTE,
                    MAX(X.PROR_DT_CADASTRO) AS ULTIMA_DATA,
                    MAX(X.PROR_ID) AS ULTIMO_ID
                FROM TB_PRODUTO_ROLO X
                WHERE X.PROR_EMPRESA = ?
                  AND X.PROR_STATUS = 'A'
                  AND X.PROR_LOTE IS NOT NULL
                GROUP BY X.PROR_LOTE
                ORDER BY MAX(X.PROR_DT_CADASTRO) DESC, MAX(X.PROR_ID) DESC
            ) ULT
              ON ULT.PROR_LOTE = R.PROR_LOTE
            WHERE R.PROR_EMPRESA = ?
              AND R.PROR_STATUS = 'A'
            ORDER BY
                ULT.ULTIMA_DATA DESC,
                ULT.ULTIMO_ID DESC,
                R.PROR_ID
        """

        cur.execute(sql, (empresa, empresa,))

        rolos = []
        for row in cur.fetchall():
            (
                pror_id,
                pror_lote,
                produto_id,
                descricao,
                quantidade,
                un,
                codigo_barras,
                prateleira,
                dt_cadastro,
                impresso
            ) = row

            rolos.append({
                "id": pror_id,
                "lote": pror_lote,
                "produto_id": produto_id,
                "descricao": descricao,
                "quantidade": float(quantidade) if quantidade is not None else 0.0,
                "unidade": un,
                "codigo_barras": codigo_barras,
                "prateleira": prateleira,
                "dt_cadastro": str(dt_cadastro) if dt_cadastro is not None else "",
                "impresso": impresso,
            })

        return jsonify({
            "status": "ok",
            "rolos": rolos
        })

    except Exception as e:
        print("\n========== ERRO NA ROTA /rolos/pendentes ==========")
        print(e)
        print("===================================================\n")
        return jsonify({"status": "erro", "mensagem": str(e)}), 500

    finally:
        try:
            con.close()
        except:
            pass
            
# ==============================================================
# ROTA: IMPRIMIR / REIMPRIMIR UM LOTE DE ROLOS NA ELGIN I9
# Recebe:
# {
#   "empresa": 1,
#   "lote": 12,
#   "usuario": 1,
#   "impressora": "ELGIN i9(USB)"   # opcional
# }
#
# Observação:
# - Esta rota é para teste em papel térmico.
# - Não substitui a etiqueta adesiva Zebra/L42.
# ==============================================================
@app.route("/rolos/imprimir-lote-i9", methods=["POST"])
def imprimir_lote_rolos_i9():
    """
    ROTA REAPROVEITADA PARA TESTE DE QR CODE NA ZEBRA/ZD220.

    Observação:
    - O nome da rota continua /rolos/imprimir-lote-i9 para não precisar
      mexer agora no botão do Flutter.
    - Mas ela NÃO envia mais ESC/POS para Elgin i9.
    - Agora gera ZPL com QR Code e envia para a impressora configurada
      no config_impressao.json.
    - Não marca PROR_IMPRESSO = 'S', pois é impressão de teste.
    """
    con = None

    try:
        dados = request.get_json() or {}

        empresa = int(dados.get("empresa", 1))
        lote = dados.get("lote")

        if not lote:
            return jsonify({
                "status": "erro",
                "mensagem": "lote não informado."
            }), 400

        lote = int(lote)

        con = get_connection()
        cur = con.cursor()

        sql = """
            SELECT
                R.PROR_ID,
                R.PROR_PRODUTO,
                P.PRD_DESCRICAO,
                R.PROR_QUANTIDADE,
                R.PROR_UN,
                R.PROR_CODIGO_BARRAS
            FROM TB_PRODUTO_ROLO R
            JOIN TB_PRODUTO P
              ON P.PRD_EMPRESA = R.PROR_EMPRESA
             AND P.PRD_ID = R.PROR_PRODUTO
            WHERE R.PROR_EMPRESA = ?
              AND R.PROR_LOTE = ?
              AND R.PROR_STATUS = 'A'
            ORDER BY R.PROR_ID
        """

        cur.execute(sql, (empresa, lote))
        rows = cur.fetchall()

        if not rows:
            return jsonify({
                "status": "erro",
                "mensagem": "Nenhum rolo encontrado para este lote."
            }), 404

        ids_impressos = []
        zpl_total = ""

        for row in rows:
            (
                pror_id,
                produto_id,
                descricao,
                quantidade,
                unidade,
                codigo_barras
            ) = row

            zpl = gerar_zpl_rolo_qrcode(
                produto_id=produto_id,
                descricao=descricao,
                quantidade=quantidade,
                unidade=unidade,
                codigo_barras=codigo_barras
            )

            zpl_total += zpl + "\n"
            ids_impressos.append(pror_id)

        retorno = enviar_zpl_para_impressora(zpl_total)

        return jsonify({
            "status": "ok",
            "mensagem": f"Lote {lote} enviado em QR Code com {len(ids_impressos)} etiqueta(s).",
            "retorno": retorno,
            "lote": lote,
            "quantidade": len(ids_impressos),
            "ids": ids_impressos
        })

    except Exception as e:
        try:
            if con:
                con.rollback()
        except:
            pass

        print("\n========== ERRO NA ROTA /rolos/imprimir-lote-i9 QR ==========")
        print(e)
        print("=============================================================\n")

        return jsonify({
            "status": "erro",
            "mensagem": str(e)
        }), 500

    finally:
        try:
            if con:
                con.close()
        except:
            pass
            
            
@app.route("/rolos/imprimir-lote-i9-qr", methods=["POST"])
def imprimir_lote_rolos_i9_qr():
    """
    ROTA TEMPORÁRIA PARA TESTE NO ESCRITÓRIO.

    Imprime etiquetas de rolo na Elgin i9 usando QR Code.
    Não altera PROR_IMPRESSO.
    Não interfere na impressão oficial Zebra.
    """
    con = None

    try:
        dados = request.get_json() or {}

        empresa = int(dados.get("empresa", 1))
        lote = dados.get("lote")
        nome_impressora = (dados.get("impressora") or "ELGIN i9(USB)").strip()

        if not lote:
            return jsonify({
                "status": "erro",
                "mensagem": "lote não informado."
            }), 400

        lote = int(lote)

        con = get_connection()
        cur = con.cursor()

        sql = """
            SELECT
                R.PROR_ID,
                R.PROR_PRODUTO,
                P.PRD_DESCRICAO,
                R.PROR_QUANTIDADE,
                R.PROR_UN,
                R.PROR_CODIGO_BARRAS
            FROM TB_PRODUTO_ROLO R
            JOIN TB_PRODUTO P
              ON P.PRD_EMPRESA = R.PROR_EMPRESA
             AND P.PRD_ID = R.PROR_PRODUTO
            WHERE R.PROR_EMPRESA = ?
              AND R.PROR_LOTE = ?
              AND R.PROR_STATUS = 'A'
            ORDER BY R.PROR_ID
        """

        cur.execute(sql, (empresa, lote))
        rows = cur.fetchall()

        if not rows:
            return jsonify({
                "status": "erro",
                "mensagem": "Nenhum rolo encontrado para este lote."
            }), 404

        ids_impressos = []

        for row in rows:
            (
                pror_id,
                produto_id,
                descricao,
                quantidade,
                unidade,
                codigo_barras
            ) = row

            dados_escpos = gerar_escpos_rolo_i9(
                produto_id=produto_id,
                descricao=descricao,
                quantidade=quantidade,
                unidade=unidade,
                codigo_barras=codigo_barras
            )

            enviar_escpos_windows(dados_escpos, nome_impressora)

            ids_impressos.append(pror_id)

        return jsonify({
            "status": "ok",
            "mensagem": f"Lote {lote} enviado para Elgin i9 em QR Code com {len(ids_impressos)} etiqueta(s).",
            "impressora": nome_impressora,
            "lote": lote,
            "quantidade": len(ids_impressos),
            "ids": ids_impressos
        })

    except Exception as e:
        try:
            if con:
                con.rollback()
        except:
            pass

        print("\n========== ERRO NA ROTA /rolos/imprimir-lote-i9-qr ==========")
        print(e)
        print("=============================================================\n")

        return jsonify({
            "status": "erro",
            "mensagem": str(e)
        }), 500

    finally:
        try:
            if con:
                con.close()
        except:
            pass            
            
            
            
# ==============================================================
# ROTA: IMPRIMIR / REIMPRIMIR UM LOTE DE ROLOS
# Recebe:
# {
#   "empresa": 1,
#   "lote": 12,
#   "usuario": 1
# }
# ==============================================================
@app.route("/rolos/imprimir-lote", methods=["POST"])
def imprimir_lote_rolos():
    con = None

    try:
        dados = request.get_json() or {}

        empresa = int(dados.get("empresa", 1))
        lote = dados.get("lote")
        usuario = int(dados.get("usuario", 1))
        tipo_codigo = (dados.get("tipo_codigo") or "CODE128").strip().upper()

        if tipo_codigo not in ["CODE128", "QR"]:
            tipo_codigo = "CODE128"

        if not lote:
            return jsonify({
                "status": "erro",
                "mensagem": "lote não informado."
            }), 400

        lote = int(lote)

        con = get_connection()
        cur = con.cursor()

        sql = """
            SELECT
                R.PROR_ID,
                R.PROR_PRODUTO,
                P.PRD_DESCRICAO,
                R.PROR_QUANTIDADE,
                R.PROR_UN,
                R.PROR_CODIGO_BARRAS
            FROM TB_PRODUTO_ROLO R
            JOIN TB_PRODUTO P
              ON P.PRD_EMPRESA = R.PROR_EMPRESA
             AND P.PRD_ID = R.PROR_PRODUTO
            WHERE R.PROR_EMPRESA = ?
              AND R.PROR_LOTE = ?
              AND R.PROR_STATUS = 'A'
            ORDER BY R.PROR_ID
        """

        cur.execute(sql, (empresa, lote))
        rows = cur.fetchall()

        if not rows:
            return jsonify({
                "status": "erro",
                "mensagem": "Nenhum rolo encontrado para este lote."
            }), 404

        ids_impressos = []
        zpl_total = ""

        for row in rows:
            (
                pror_id,
                produto_id,
                descricao,
                quantidade,
                unidade,
                codigo_barras
            ) = row

            if tipo_codigo == "QR":
                zpl = gerar_zpl_rolo_qrcode(
                    produto_id=produto_id,
                    descricao=descricao,
                    quantidade=quantidade,
                    unidade=unidade,
                    codigo_barras=codigo_barras
                )
            else:
                zpl = gerar_zpl_rolo(
                    produto_id=produto_id,
                    descricao=descricao,
                    quantidade=quantidade,
                    unidade=unidade,
                    codigo_barras=codigo_barras
                )

            zpl_total += zpl + "\n"
            ids_impressos.append(pror_id)

        retorno = enviar_zpl_para_impressora(zpl_total)

        for pror_id in ids_impressos:
            cur.execute("""
                UPDATE TB_PRODUTO_ROLO
                   SET PROR_IMPRESSO = 'S',
                       PROR_DT_IMPRESSAO = CURRENT_TIMESTAMP,
                       PROR_USUARIO_IMP = ?
                 WHERE PROR_EMPRESA = ?
                   AND PROR_ID = ?
            """, (usuario, empresa, pror_id))

        con.commit()

        return jsonify({
            "status": "ok",
            "mensagem": f"Lote {lote} enviado em {tipo_codigo} com {len(ids_impressos)} etiqueta(s).",
            "retorno": retorno,
            "lote": lote,
            "quantidade": len(ids_impressos),
            "ids": ids_impressos
        })

    except Exception as e:
        try:
            if con:
                con.rollback()
        except:
            pass

        print("\n========== ERRO NA ROTA /rolos/imprimir-lote ==========")
        print(e)
        print("=======================================================\n")

        return jsonify({
            "status": "erro",
            "mensagem": str(e)
        }), 500

    finally:
        try:
            if con:
                con.close()
        except:
            pass            
            
# ==============================================================
# ROTA: IMPRIMIR ETIQUETAS PENDENTES DE UM PRODUTO
# Recebe:
# {
#   "empresa": 1,
#   "produto_id": 1002955,
#   "usuario": 1
# }
# ==============================================================
@app.route("/rolos/imprimir-produto", methods=["POST"])
def imprimir_rolos_produto():
    con = None

    try:
        dados = request.get_json() or {}

        empresa = int(dados.get("empresa", 1))
        produto_id = dados.get("produto_id")
        usuario = int(dados.get("usuario", 1))

        if not produto_id:
            return jsonify({
                "status": "erro",
                "mensagem": "produto_id não informado."
            }), 400

        produto_id = int(produto_id)

        con = get_connection()
        cur = con.cursor()

        sql = """
            SELECT
                R.PROR_ID,
                R.PROR_PRODUTO,
                P.PRD_DESCRICAO,
                R.PROR_QUANTIDADE,
                R.PROR_UN,
                R.PROR_CODIGO_BARRAS
            FROM TB_PRODUTO_ROLO R
            JOIN TB_PRODUTO P
              ON P.PRD_EMPRESA = R.PROR_EMPRESA
             AND P.PRD_ID = R.PROR_PRODUTO
            WHERE R.PROR_EMPRESA = ?
              AND R.PROR_PRODUTO = ?
              AND R.PROR_STATUS = 'A'
              AND R.PROR_IMPRESSO = 'N'
            ORDER BY R.PROR_ID
        """

        cur.execute(sql, (empresa, produto_id))
        rows = cur.fetchall()

        if not rows:
            return jsonify({
                "status": "erro",
                "mensagem": "Nenhuma etiqueta pendente encontrada para este produto."
            }), 404

        ids_impressos = []
        zpl_total = ""

        for row in rows:
            (
                pror_id,
                produto_id_row,
                descricao,
                quantidade,
                unidade,
                codigo_barras
            ) = row

            zpl = gerar_zpl_rolo(
                produto_id=produto_id_row,
                descricao=descricao,
                quantidade=quantidade,
                unidade=unidade,
                codigo_barras=codigo_barras
            )

            zpl_total += zpl + "\n"
            ids_impressos.append(pror_id)

        # Envia tudo em um único bloco para a impressora
        retorno = enviar_zpl_para_impressora(zpl_total)

        # Se não deu erro no envio, marca como impresso
        for pror_id in ids_impressos:
            cur.execute("""
                UPDATE TB_PRODUTO_ROLO
                   SET PROR_IMPRESSO = 'S',
                       PROR_DT_IMPRESSAO = CURRENT_TIMESTAMP,
                       PROR_USUARIO_IMP = ?
                 WHERE PROR_EMPRESA = ?
                   AND PROR_ID = ?
            """, (usuario, empresa, pror_id))

        con.commit()

        return jsonify({
            "status": "ok",
            "mensagem": f"{len(ids_impressos)} etiqueta(s) enviada(s) para impressão.",
            "retorno": retorno,
            "quantidade": len(ids_impressos),
            "ids": ids_impressos
        })

    except Exception as e:
        try:
            if con:
                con.rollback()
        except:
            pass

        print("\n========== ERRO NA ROTA /rolos/imprimir-produto ==========")
        print(e)
        print("==========================================================\n")

        return jsonify({
            "status": "erro",
            "mensagem": str(e)
        }), 500

    finally:
        try:
            if con:
                con.close()
        except:
            pass            
            
# ==============================================================
# ROTA: PREVIEW ZPL DE UM ROLO ESPECÍFICO
# Exemplo:
# /rolos/zpl-preview?id=1&empresa=1
# ==============================================================
@app.route("/rolos/zpl-preview", methods=["GET"])
def rolos_zpl_preview():
    try:
        empresa = int(request.args.get("empresa", 1))
        pror_id = request.args.get("id")

        if not pror_id:
            return "Informe o parâmetro id.", 400

        pror_id = int(pror_id)

        con = get_connection()
        cur = con.cursor()

        sql = """
            SELECT
                R.PROR_ID,
                R.PROR_PRODUTO,
                P.PRD_DESCRICAO,
                R.PROR_QUANTIDADE,
                R.PROR_UN,
                R.PROR_CODIGO_BARRAS
            FROM TB_PRODUTO_ROLO R
            JOIN TB_PRODUTO P
              ON P.PRD_EMPRESA = R.PROR_EMPRESA
             AND P.PRD_ID = R.PROR_PRODUTO
            WHERE R.PROR_EMPRESA = ?
              AND R.PROR_ID = ?
        """

        cur.execute(sql, (empresa, pror_id))
        row = cur.fetchone()

        if not row:
            return "Rolo não encontrado.", 404

        (
            _id,
            produto_id,
            descricao,
            quantidade,
            unidade,
            codigo_barras
        ) = row

        zpl = gerar_zpl_rolo(
            produto_id=produto_id,
            descricao=descricao,
            quantidade=quantidade,
            unidade=unidade,
            codigo_barras=codigo_barras
        )

        return zpl, 200, {"Content-Type": "text/plain; charset=utf-8"}

    except Exception as e:
        print("\n========== ERRO NA ROTA /rolos/zpl-preview ==========")
        print(e)
        print("=====================================================\n")
        return str(e), 500

    finally:
        try:
            con.close()
        except:
            pass
            
# ==============================================================
# ROTA: CONSULTAR ETIQUETA DE ROLO PELO CÓDIGO LIDO
# Exemplo:
# /rolos/consultar-codigo?empresa=1&codigo=ROLO01004146008500
# Regra:
# ROLO + produto 8 dígitos + quantidade 6 dígitos
# ==============================================================
@app.route("/rolos/consultar-codigo", methods=["GET"])
def consultar_codigo_rolo():
    con = None

    try:
        empresa = int(request.args.get("empresa", 1))
        codigo = (request.args.get("codigo", "") or "").strip().upper()

        if not codigo:
            return jsonify({
                "status": "erro",
                "mensagem": "Código não informado."
            }), 400

        if len(codigo) != 18 or not codigo.startswith("R") or not codigo[1:].isdigit():
            return jsonify({
                "status": "erro",
                "mensagem": "Código de rolo inválido."
            }), 400

        pror_id = int(codigo[1:7])
        produto_id_codigo = int(codigo[7:14])
        quantidade_dec = int(codigo[14:18])
        quantidade_codigo = quantidade_dec / 10.0
        

        con = get_connection()
        cur = con.cursor()

        sql = """
            SELECT
                R.PROR_EMPRESA,
                R.PROR_ID,
                R.PROR_PRODUTO,
                P.PRD_COD_BARRAS,
                P.PRD_DESCRICAO,
                R.PROR_QUANTIDADE,
                R.PROR_UN,
                R.PROR_STATUS,
                R.PROR_IMPRESSO
            FROM TB_PRODUTO_ROLO R
            JOIN TB_PRODUTO P
              ON P.PRD_EMPRESA = R.PROR_EMPRESA
             AND P.PRD_ID = R.PROR_PRODUTO
            WHERE R.PROR_EMPRESA = ?
              AND R.PROR_ID = ?
              AND R.PROR_STATUS = 'A'
        """

        cur.execute(sql, (empresa, pror_id))
        row = cur.fetchone()

        if not row:
            return jsonify({
                "status": "nao_encontrado",
                "mensagem": "Rolo não encontrado.",
                "codigo_lido": codigo,
                "pror_id": pror_id,
                "produto_id_codigo": produto_id_codigo,
                "quantidade_codigo": quantidade_codigo,
                "quantidade_formatada": f"{quantidade_codigo:.1f}".replace(".", ",")
            }), 404

        (
            pror_empresa,
            pror_id_db,
            produto_id,
            cod_barras,
            descricao,
            quantidade_banco,
            unidade,
            pror_status,
            pror_impresso
        ) = row

        quantidade_banco_float = float(quantidade_banco) if quantidade_banco is not None else 0.0

        produto_confere = int(produto_id) == int(produto_id_codigo)
        quantidade_confere = round(quantidade_banco_float, 1) == round(quantidade_codigo, 1)

        if not produto_confere or not quantidade_confere:
            return jsonify({
                "status": "erro",
                "mensagem": "Etiqueta inconsistente com o banco de dados.",
                "codigo_lido": codigo,
                "pror_id": pror_id,
                "produto_id_codigo": produto_id_codigo,
                "produto_id_banco": produto_id,
                "quantidade_codigo": quantidade_codigo,
                "quantidade_banco": quantidade_banco_float
            }), 409

        return jsonify({
            "status": "ok",
            "codigo_lido": codigo,
            "pror_id": pror_id_db,
            "produto_id": produto_id,
            "codigo_barras": cod_barras,
            "descricao": descricao or "",
            "unidade": unidade or "",
            "quantidade": quantidade_banco_float,
            "quantidade_formatada": f"{quantidade_banco_float:.1f}".replace(".", ","),
            "pror_status": pror_status,
            "pror_impresso": pror_impresso
        })

    except Exception as e:
        print("\n========== ERRO NA ROTA /rolos/consultar-codigo ==========")
        print(e)
        print("==========================================================\n")

        return jsonify({
            "status": "erro",
            "mensagem": str(e)
        }), 500

    finally:
        try:
            if con:
                con.close()
        except:
            pass   

# ==============================================================
# ROTA: BUSCAR PEDIDO PARA SEPARAÇÃO DE ROLOS
# Exemplo:
# /pedidos/separacao/buscar?empresa=1&pedido=9567
#
# Somente leitura:
# - busca cabeçalho do pedido
# - busca itens agrupados por produto
# - não grava nada no banco
# ==============================================================
@app.route("/pedidos/separacao/buscar", methods=["GET"])
def buscar_pedido_separacao():
    con = None

    try:
        empresa = int(request.args.get("empresa", 1))
        pedido = request.args.get("pedido")

        if not pedido:
            return jsonify({
                "status": "erro",
                "mensagem": "Número do pedido não informado."
            }), 400

        pedido = int(pedido)

        con = get_connection()
        cur = con.cursor()

        # ------------------------------------------------------
        # 1) Cabeçalho do pedido
        # ------------------------------------------------------
        sql_pedido = """
            SELECT
                PEV_EMPRESA,
                PEV_ID,
                PEV_DT_EMISSAO,
                PEV_DT_LANCAMENTO,
                PEV_CLIENTE,
                COALESCE(PEV_RSOCIAL_NOME, '') AS CLIENTE_NOME,
                COALESCE(PEV_FANTASIA_APELIDO, '') AS CLIENTE_FANTASIA,
                COALESCE(PEV_VALOR_TOTAL, 0) AS VALOR_TOTAL,
                COALESCE(PEV_TOTAL_GERAL, 0) AS TOTAL_GERAL,
                COALESCE(PEV_STATUS, '') AS STATUS
            FROM TB_PEDIDO_VENDA
            WHERE PEV_EMPRESA = ?
              AND PEV_ID = ?
        """

        cur.execute(sql_pedido, (empresa, pedido))
        row = cur.fetchone()

        if not row:
            return jsonify({
                "status": "nao_encontrado",
                "mensagem": f"Pedido {pedido} não encontrado.",
                "pedido": pedido,
                "itens": []
            }), 404
            
                # ------------------------------------------------------
        # 1.1) Bloqueia pedido que já teve separação aplicada
        # ------------------------------------------------------
        cur.execute("""
            SELECT FIRST 1
                PVSE_ID,
                PVSE_DT_APLICACAO_PEDIDO,
                PVSE_USUARIO_APLICACAO
            FROM TB_PEDIDO_VENDA_SEPARACAO
            WHERE PVSE_EMPRESA = ?
              AND PVSE_PEDIDO_VENDA = ?
              AND COALESCE(PVSE_APLICADA_PEDIDO, 'N') = 'S'
            ORDER BY PVSE_DT_APLICACAO_PEDIDO DESC, PVSE_ID DESC
        """, (empresa, pedido))

        row_sep_aplicada = cur.fetchone()

        if row_sep_aplicada:
            sep_id, dt_aplicacao, usuario_aplicacao = row_sep_aplicada

            if dt_aplicacao:
                try:
                    dt_txt = dt_aplicacao.strftime("%d/%m/%Y às %H:%M")
                except:
                    dt_txt = str(dt_aplicacao)
            else:
                dt_txt = "data não registrada"

            return jsonify({
                "status": "ja_separado",
                "mensagem": (
                    f"Este pedido já possui separação aplicada.\n"
                    f"Separação nº {sep_id} aplicada em {dt_txt}.\n"
                    f"Não é possível separar novamente."
                ),
                "pedido": pedido,
                "separacao_id": sep_id,
                "dt_aplicacao": str(dt_aplicacao) if dt_aplicacao else "",
                "usuario_aplicacao": usuario_aplicacao
            }), 409
        
        
        
        

        (
            pev_empresa,
            pev_id,
            dt_emissao,
            dt_lancamento,
            cliente_id,
            cliente_nome,
            cliente_fantasia,
            valor_total,
            total_geral,
            status
        ) = row

        cliente_nome = (cliente_nome or "").strip()
        cliente_fantasia = (cliente_fantasia or "").strip()

        cliente_exibicao = cliente_nome
        if not cliente_exibicao:
            cliente_exibicao = cliente_fantasia
        if not cliente_exibicao:
            cliente_exibicao = f"CLIENTE {cliente_id}" if cliente_id else "CLIENTE NÃO INFORMADO"

        valor_total_float = float(valor_total or 0)
        total_geral_float = float(total_geral or 0)

        # Se PEV_TOTAL_GERAL estiver preenchido, usamos ele como total exibido.
        valor_exibicao = total_geral_float if total_geral_float > 0 else valor_total_float

        # ------------------------------------------------------
        # 2) Itens agrupados por produto
        #    Isso resolve produto repetido em várias sequências.
        # ------------------------------------------------------
        sql_itens = """
            SELECT
                PEVI_PRODUTO,
                COALESCE(MAX(PEVI_DESCRICAO), '') AS DESCRICAO,
                COALESCE(MAX(PEVI_UN_VENDA), '') AS UNIDADE,
                SUM(COALESCE(PEVI_QUANTIDADE, 0)) AS QUANTIDADE_VENDIDA,
                COUNT(*) AS QTDE_LINHAS
            FROM TB_PEDIDO_VENDA_ITEM
            WHERE PEVI_EMPRESA = ?
              AND PEVI_PEDIDO_VENDA = ?
              AND PEVI_PRODUTO IS NOT NULL
              AND COALESCE(PEVI_STATUS, 'A') <> 'C'
            GROUP BY PEVI_PRODUTO
            ORDER BY PEVI_PRODUTO
        """

        cur.execute(sql_itens, (empresa, pedido))

        itens = []
        for item in cur.fetchall():
            (
                produto_id,
                descricao,
                unidade,
                quantidade_vendida,
                qtde_linhas
            ) = item

            itens.append({
                "produto": int(produto_id),
                "descricao": descricao or "",
                "unidade": unidade or "",
                "quantidade_vendida": float(quantidade_vendida or 0),
                "qtde_linhas": int(qtde_linhas or 0)
            })

        return jsonify({
            "status": "ok",
            "pedido": {
                "empresa": int(pev_empresa),
                "numero": int(pev_id),
                "cliente_id": int(cliente_id) if cliente_id is not None else None,
                "cliente": cliente_exibicao,
                "cliente_nome": cliente_nome,
                "cliente_fantasia": cliente_fantasia,
                "emissao": str(dt_emissao) if dt_emissao is not None else "",
                "lancamento": str(dt_lancamento) if dt_lancamento is not None else "",
                "valor_total": valor_exibicao,
                "status": status
            },
            "itens": itens
        })

    except Exception as e:
        print("\n========== ERRO NA ROTA /pedidos/separacao/buscar ==========")
        print(e)
        print("============================================================\n")

        return jsonify({
            "status": "erro",
            "mensagem": str(e)
        }), 500

    finally:
        try:
            if con:
                con.close()
        except:
            pass  

# ==============================================================
# FUNÇÃO: PRÓXIMO ID DA SEPARAÇÃO
# Usa TB_SEQUENCIAL para gerar PVSE_ID por empresa
# ==============================================================
def proximo_id_separacao(cur, empresa):
    tabela = "TB_PEDIDO_VENDA_SEPARACAO"

    cur.execute("""
        SELECT COALESCE(SEQ_SEQUENCIAL, 0)
        FROM TB_SEQUENCIAL
        WHERE SEQ_EMPRESA = ?
          AND SEQ_TABELA = ?
    """, (empresa, tabela))

    row = cur.fetchone()

    if row:
        atual = int(row[0] or 0)
        novo = atual + 1

        cur.execute("""
            UPDATE TB_SEQUENCIAL
               SET SEQ_SEQUENCIAL = ?
             WHERE SEQ_EMPRESA = ?
               AND SEQ_TABELA = ?
        """, (novo, empresa, tabela))

        return novo

    cur.execute("""
        INSERT INTO TB_SEQUENCIAL
        (
            SEQ_EMPRESA,
            SEQ_TABELA,
            SEQ_SEQUENCIAL
        )
        VALUES
        (?, ?, ?)
    """, (empresa, tabela, 1))

    return 1
    
# ==============================================================
# FUNÇÕES: APLICAR SEPARAÇÃO NO PEDIDO OFICIAL
# ==============================================================
def decimal_seguro(valor, padrao="0"):
    try:
        if valor is None:
            return Decimal(padrao)

        if isinstance(valor, Decimal):
            return valor

        if isinstance(valor, str):
            valor = valor.strip().replace(",", ".")
            if valor == "":
                return Decimal(padrao)

        return Decimal(str(valor))
    except:
        return Decimal(padrao)


def arredondar_moeda(valor):
    return decimal_seguro(valor).quantize(Decimal("0.001"), rounding=ROUND_HALF_UP)
    
def inteiro_firebird(valor, padrao=0):
    try:
        if valor is None:
            return padrao

        if isinstance(valor, Decimal):
            return int(valor.to_integral_value(rounding=ROUND_HALF_UP))

        return int(round(float(valor)))
    except:
        return padrao


def montar_observacao_rolos(cur, empresa, separacao_id, produto_id):
    cur.execute("""
        SELECT
            PVSR_PROR_ID,
            PVSR_QUANTIDADE,
            COALESCE(PVSR_UNIDADE, '')
        FROM TB_PEDIDO_VENDA_SEPARACAO_ROLO
        WHERE PVSR_EMPRESA = ?
          AND PVSR_SEPARACAO = ?
          AND PVSR_PRODUTO = ?
          AND COALESCE(PVSR_STATUS, 'A') = 'A'
        ORDER BY PVSR_SEQUENCIA
    """, (empresa, separacao_id, produto_id))

    linhas = []
    total = Decimal("0")

    for row in cur.fetchall():
        pror_id, quantidade, unidade = row

        qtd = decimal_seguro(quantidade)
        total += qtd

        qtd_txt = f"{float(qtd):.1f}".replace(".", ",")
        linhas.append(
            f"Rolo {str(int(pror_id)).zfill(6)} - {qtd_txt} {unidade}".strip()
        )

    total_txt = f"{float(total):.1f}".replace(".", ",")

    texto = "Separação por rolos: " + "; ".join(linhas)
    texto += f"; Total separado: {total_txt}"

    return texto[:1000]    


# ==============================================================
# ROTA: SALVAR SEPARAÇÃO DE PEDIDO
# Recebe do Flutter:
# {
#   "empresa": 10,
#   "pedido": 1930,
#   "cliente_id": 123,
#   "cliente": "CLIENTE TESTE",
#   "usuario": 1,
#   "produtos": [
#     {
#       "produto": 1002297,
#       "descricao": "TECIDO...",
#       "unidade": "MT",
#       "vendido": 650.0,
#       "separado": 665.0,
#       "rolos": [
#         {
#           "id": 26,
#           "codigo": "R00002610022970560",
#           "quantidade": 56.0,
#           "unidade": "MT"
#         }
#       ]
#     }
#   ]
# }
#
# Importante:
# - Não altera TB_PEDIDO_VENDA_ITEM
# - Não altera quantidade do pedido
# - Não fatura
# - Apenas registra a separação assistida
# ==============================================================
@app.route("/pedidos/separacao/salvar", methods=["POST"])
def salvar_separacao_pedido():
    con = None

    try:
        dados = request.get_json() or {}

        empresa = inteiro_seguro(dados.get("empresa"), 1)
        pedido = inteiro_seguro(dados.get("pedido"), 0)
        usuario = inteiro_seguro(dados.get("usuario"), 1)
        cliente_id = dados.get("cliente_id")
        cliente_nome = (dados.get("cliente") or dados.get("cliente_nome") or "").strip()
        produtos = dados.get("produtos", [])

        if pedido <= 0:
            return jsonify({
                "status": "erro",
                "mensagem": "Pedido não informado."
            }), 400

        if not produtos:
            return jsonify({
                "status": "erro",
                "mensagem": "Nenhum produto separado informado."
            }), 400

        if cliente_id is not None and str(cliente_id).strip() != "":
            cliente_id = inteiro_seguro(cliente_id, None)
        else:
            cliente_id = None

        con = get_connection()
        cur = con.cursor()

        # ------------------------------------------------------
        # 1) Valida se o pedido existe
        # ------------------------------------------------------
        cur.execute("""
            SELECT
                PEV_CLIENTE,
                COALESCE(PEV_RSOCIAL_NOME, ''),
                COALESCE(PEV_FANTASIA_APELIDO, '')
            FROM TB_PEDIDO_VENDA
            WHERE PEV_EMPRESA = ?
              AND PEV_ID = ?
        """, (empresa, pedido))

        row_pedido = cur.fetchone()

        if not row_pedido:
            return jsonify({
                "status": "erro",
                "mensagem": f"Pedido {pedido} não encontrado na empresa {empresa}."
            }), 404

        cliente_banco, cliente_nome_banco, cliente_fantasia_banco = row_pedido

        if cliente_id is None and cliente_banco is not None:
            cliente_id = inteiro_seguro(cliente_banco, None)

        if not cliente_nome:
            cliente_nome = (cliente_nome_banco or "").strip()
            if not cliente_nome:
                cliente_nome = (cliente_fantasia_banco or "").strip()

        # ------------------------------------------------------
        # 2) Valida duplicidade no próprio JSON
        # ------------------------------------------------------
        rolos_payload = set()

        for produto in produtos:
            rolos = produto.get("rolos", [])

            for rolo in rolos:
                pror_id = inteiro_seguro(rolo.get("id") or rolo.get("pror_id"), 0)

                if pror_id <= 0:
                    return jsonify({
                        "status": "erro",
                        "mensagem": "Existe rolo sem PROR_ID válido."
                    }), 400
                    

                chave = (empresa, pror_id)

                if chave in rolos_payload:
                    return jsonify({
                        "status": "erro",
                        "mensagem": f"Rolo {str(pror_id).zfill(6)} veio duplicado na separação."
                    }), 409

                rolos_payload.add(chave)

        # ------------------------------------------------------
        # 3) Valida cada rolo no banco e bloqueia rolo já usado
        # ------------------------------------------------------
        for produto in produtos:
            produto_id = inteiro_seguro(produto.get("produto"), 0)
            rolos = produto.get("rolos", [])

            if produto_id <= 0:
                return jsonify({
                    "status": "erro",
                    "mensagem": "Existe produto sem código válido."
                }), 400

            if not rolos:
                return jsonify({
                    "status": "erro",
                    "mensagem": f"Produto {produto_id} não possui rolos informados."
                }), 400

            for rolo in rolos:
                pror_id = inteiro_seguro(rolo.get("id") or rolo.get("pror_id"), 0)

                # Rolo existe e pertence ao produto?
                cur.execute("""
                    SELECT
                        PROR_PRODUTO,
                        PROR_QUANTIDADE,
                        COALESCE(PROR_STATUS, 'A')
                    FROM TB_PRODUTO_ROLO
                    WHERE PROR_EMPRESA = ?
                      AND PROR_ID = ?
                """, (empresa, pror_id))

                row_rolo = cur.fetchone()

                if not row_rolo:
                    return jsonify({
                        "status": "erro",
                        "mensagem": f"Rolo {str(pror_id).zfill(6)} não encontrado."
                    }), 404

                produto_rolo, quantidade_rolo, status_rolo = row_rolo

                if str(status_rolo).strip().upper() != "A":
                    return jsonify({
                        "status": "erro",
                        "mensagem": f"Rolo {str(pror_id).zfill(6)} não está ativo."
                    }), 409

                if int(produto_rolo) != int(produto_id):
                    return jsonify({
                        "status": "erro",
                        "mensagem": (
                            f"Rolo {str(pror_id).zfill(6)} pertence ao produto "
                            f"{produto_rolo}, mas foi enviado no produto {produto_id}."
                        )
                    }), 409

                # Rolo já usado em separação aberta/finalizada?
                cur.execute("""
                    SELECT FIRST 1
                        R.PVSR_SEPARACAO,
                        R.PVSR_PEDIDO_VENDA
                    FROM TB_PEDIDO_VENDA_SEPARACAO_ROLO R
                    JOIN TB_PEDIDO_VENDA_SEPARACAO S
                      ON S.PVSE_EMPRESA = R.PVSR_EMPRESA
                     AND S.PVSE_ID = R.PVSR_SEPARACAO
                    WHERE R.PVSR_EMPRESA = ?
                      AND R.PVSR_PROR_ID = ?
                      AND R.PVSR_STATUS = 'A'
                      AND S.PVSE_STATUS IN ('A', 'F')
                """, (empresa, pror_id))

                row_usado = cur.fetchone()

                if row_usado:
                    separacao_usada, pedido_usado = row_usado

                    return jsonify({
                        "status": "erro",
                        "mensagem": (
                            f"Rolo {str(pror_id).zfill(6)} já foi usado "
                            f"na separação {separacao_usada}, pedido {pedido_usado}."
                        )
                    }), 409

        # ------------------------------------------------------
        # 4) Calcula totais no servidor
        # ------------------------------------------------------
        total_vendido = 0.0
        total_separado = 0.0

        for produto in produtos:
            vendido = float(produto.get("vendido") or 0)
            separado = float(produto.get("separado") or 0)

            total_vendido += vendido
            total_separado += separado

        diferenca_total = total_separado - total_vendido

        # ------------------------------------------------------
        # 5) Gera ID e grava cabeçalho
        # ------------------------------------------------------
        separacao_id = proximo_id_separacao(cur, empresa)

        cur.execute("""
            INSERT INTO TB_PEDIDO_VENDA_SEPARACAO
            (
                PVSE_EMPRESA,
                PVSE_ID,
                PVSE_PEDIDO_VENDA,
                PVSE_CLIENTE,
                PVSE_CLIENTE_NOME,
                PVSE_STATUS,
                PVSE_DT_INICIO,
                PVSE_DT_FINALIZACAO,
                PVSE_USUARIO,
                PVSE_TOTAL_VENDIDO,
                PVSE_TOTAL_SEPARADO,
                PVSE_DIFERENCA,
                PVSE_OBSERVACAO
            )
            VALUES
            (?, ?, ?, ?, ?, 'F', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ?, ?, ?, ?, ?)
        """, (
            empresa,
            separacao_id,
            pedido,
            cliente_id,
            cliente_nome,
            usuario,
            total_vendido,
            total_separado,
            diferenca_total,
            "Separação salva pelo app de rolos. Não altera o pedido oficial."
        ))

        # ------------------------------------------------------
        # 6) Grava produtos e rolos
        # ------------------------------------------------------
        seq_item = 0
        total_rolos = 0

        for produto in produtos:
            seq_item += 1

            produto_id = inteiro_seguro(produto.get("produto"), 0)
            descricao = (produto.get("descricao") or "").strip()
            unidade = (produto.get("unidade") or "").strip() 
            vendido = float(produto.get("vendido") or 0)
            separado = float(produto.get("separado") or 0)
            diferenca = separado - vendido
            rolos = produto.get("rolos", [])

            cur.execute("""
                INSERT INTO TB_PEDIDO_VENDA_SEPARACAO_ITEM
                (
                    PVSI_EMPRESA,
                    PVSI_SEPARACAO,
                    PVSI_SEQUENCIA,
                    PVSI_PEDIDO_VENDA,
                    PVSI_PRODUTO,
                    PVSI_DESCRICAO,
                    PVSI_UNIDADE,
                    PVSI_QTDE_VENDIDA,
                    PVSI_QTDE_SEPARADA,
                    PVSI_DIFERENCA,
                    PVSI_STATUS,
                    PVSI_OBSERVACAO
                )
                VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'F', ?)
            """, (
                empresa,
                separacao_id,
                seq_item,
                pedido,
                produto_id,
                descricao,
                unidade,
                vendido,
                separado,
                diferenca,
                "Produto separado pelo app de rolos."
            ))

            seq_rolo = 0

            for rolo in rolos:
                seq_rolo += 1
                total_rolos += 1

                pror_id = inteiro_seguro(rolo.get("id") or rolo.get("pror_id"), 0)
                codigo = (rolo.get("codigo") or rolo.get("codigo_barras") or "").strip()
                quantidade = float(rolo.get("quantidade") or 0)
                unidade_rolo = (rolo.get("unidade") or unidade or "").strip()

                cur.execute("""
                    INSERT INTO TB_PEDIDO_VENDA_SEPARACAO_ROLO
                    (
                        PVSR_EMPRESA,
                        PVSR_SEPARACAO,
                        PVSR_ITEM,
                        PVSR_SEQUENCIA,
                        PVSR_PEDIDO_VENDA,
                        PVSR_PRODUTO,
                        PVSR_PROR_ID,
                        PVSR_CODIGO_BARRAS,
                        PVSR_QUANTIDADE,
                        PVSR_UNIDADE,
                        PVSR_DT_LEITURA,
                        PVSR_USUARIO,
                        PVSR_STATUS,
                        PVSR_OBSERVACAO
                    )
                    VALUES
                    (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?, 'A', ?)
                """, (
                    empresa,
                    separacao_id,
                    seq_item,
                    seq_rolo,
                    pedido,
                    produto_id,
                    pror_id,
                    codigo,
                    quantidade,
                    unidade_rolo,
                    usuario,
                    "Rolo lido na separação do pedido."
                ))

        con.commit()

        return jsonify({
            "status": "ok",
            "mensagem": "Separação salva com sucesso.",
            "empresa": empresa,
            "pedido": pedido,
            "separacao_id": separacao_id,
            "produtos": len(produtos),
            "rolos": total_rolos,
            "total_vendido": total_vendido,
            "total_separado": total_separado,
            "diferenca": diferenca_total
        })

    except Exception as e:
        try:
            if con:
                con.rollback()
        except:
            pass

        print("\n========== ERRO NA ROTA /pedidos/separacao/salvar ==========")
        print(e)
        traceback.print_exc()
        print("============================================================\n")

        return jsonify({
            "status": "erro",
            "mensagem": str(e)
        }), 500

    finally:
        try:
            if con:
                con.close()
        except:
            pass  

# ==============================================================
# ROTA: APLICAR SEPARAÇÃO NO PEDIDO OFICIAL
# Recebe:
# {
#   "empresa": 10,
#   "separacao_id": 1,
#   "usuario": 1
# }
#
# Importante:
# - Usa a separação já salva como fonte oficial
# - Atualiza TB_PEDIDO_VENDA_ITEM
# - Recalcula TB_PEDIDO_VENDA
# - Marca a separação como aplicada
# ==============================================================
@app.route("/pedidos/separacao/aplicar-no-pedido", methods=["POST"])
def aplicar_separacao_no_pedido():
    con = None

    try:
        dados = request.get_json() or {}

        empresa = inteiro_seguro(dados.get("empresa"), 1)
        separacao_id = inteiro_seguro(dados.get("separacao_id"), 0)
        usuario = inteiro_seguro(dados.get("usuario"), 1)

        if separacao_id <= 0:
            return jsonify({
                "status": "erro",
                "mensagem": "Separação não informada."
            }), 400

        con = get_connection()
        cur = con.cursor()

        # ------------------------------------------------------
        # 1) Busca cabeçalho da separação
        # ------------------------------------------------------
        cur.execute("""
            SELECT
                PVSE_PEDIDO_VENDA,
                COALESCE(PVSE_STATUS, ''),
                COALESCE(PVSE_APLICADA_PEDIDO, 'N')
            FROM TB_PEDIDO_VENDA_SEPARACAO
            WHERE PVSE_EMPRESA = ?
              AND PVSE_ID = ?
        """, (empresa, separacao_id))

        row_sep = cur.fetchone()

        if not row_sep:
            return jsonify({
                "status": "erro",
                "mensagem": f"Separação {separacao_id} não encontrada."
            }), 404

        pedido, status_sep, aplicada = row_sep

        pedido = inteiro_seguro(pedido, 0)
        status_sep = (status_sep or "").strip().upper()
        aplicada = (aplicada or "N").strip().upper()

        if status_sep != "F":
            return jsonify({
                "status": "erro",
                "mensagem": "Somente separação finalizada pode ser aplicada ao pedido."
            }), 409

        if aplicada == "S":
            return jsonify({
                "status": "erro",
                "mensagem": "Esta separação já foi aplicada ao pedido."
            }), 409

        # ------------------------------------------------------
        # 2) Confere se o pedido existe e está aberto
        # ------------------------------------------------------
        cur.execute("""
            SELECT COALESCE(PEV_STATUS, '')
            FROM TB_PEDIDO_VENDA
            WHERE PEV_EMPRESA = ?
              AND PEV_ID = ?
        """, (empresa, pedido))

        row_pedido = cur.fetchone()

        if not row_pedido:
            return jsonify({
                "status": "erro",
                "mensagem": f"Pedido {pedido} não encontrado."
            }), 404

        status_pedido = (row_pedido[0] or "").strip().upper()

        if status_pedido != "A":
            return jsonify({
                "status": "erro",
                "mensagem": "Somente pedido com status A pode ser alterado pela separação."
            }), 409

        # ------------------------------------------------------
        # 3) Busca produtos separados
        # ------------------------------------------------------
        cur.execute("""
            SELECT
                PVSI_PRODUTO,
                PVSI_QTDE_SEPARADA
            FROM TB_PEDIDO_VENDA_SEPARACAO_ITEM
            WHERE PVSI_EMPRESA = ?
              AND PVSI_SEPARACAO = ?
              AND PVSI_PEDIDO_VENDA = ?
              AND COALESCE(PVSI_STATUS, 'F') <> 'C'
            ORDER BY PVSI_SEQUENCIA
        """, (empresa, separacao_id, pedido))

        itens_sep = cur.fetchall()

        if not itens_sep:
            return jsonify({
                "status": "erro",
                "mensagem": "Nenhum item encontrado na separação."
            }), 400

        itens_atualizados = 0

        # ------------------------------------------------------
        # 4) Atualiza cada item do pedido
        # ------------------------------------------------------
        for item_sep in itens_sep:
            produto_id, qtde_separada = item_sep

            produto_id = inteiro_seguro(produto_id, 0)
            nova_quantidade = decimal_seguro(qtde_separada)
            volume_item = inteiro_firebird(nova_quantidade)

            # Censura simples: produto deve existir uma única vez no pedido.
            cur.execute("""
                SELECT COUNT(*)
                FROM TB_PEDIDO_VENDA_ITEM
                WHERE PEVI_EMPRESA = ?
                  AND PEVI_PEDIDO_VENDA = ?
                  AND PEVI_PRODUTO = ?
                  AND COALESCE(PEVI_STATUS, 'A') <> 'C'
            """, (empresa, pedido, produto_id))

            qtde_linhas = int(cur.fetchone()[0] or 0)

            if qtde_linhas == 0:
                raise Exception(
                    f"Produto {produto_id} não existe mais no pedido {pedido}."
                )

            if qtde_linhas > 1:
                raise Exception(
                    f"Produto {produto_id} aparece mais de uma vez no pedido {pedido}. "
                    "Ajuste manual necessário."
                )

            cur.execute("""
                SELECT
                    PEVI_SEQUENCIA,
                    COALESCE(PEVI_VALOR_UNITARIO, 0),
                    COALESCE(PEVI_DESCONTO, 0),
                    COALESCE(PEVI_ACRESCIMO, 0),
                    COALESCE(PEVI_VALOR_FRETE, 0),
                    COALESCE(PEVI_COMISSAO, 0),
                    COALESCE(PEVI_COMISSAO_SUPERVISOR, 0),
                    COALESCE(PEVI_OBSERVACAO, '')
                FROM TB_PEDIDO_VENDA_ITEM
                WHERE PEVI_EMPRESA = ?
                  AND PEVI_PEDIDO_VENDA = ?
                  AND PEVI_PRODUTO = ?
                  AND COALESCE(PEVI_STATUS, 'A') <> 'C'
            """, (empresa, pedido, produto_id))

            row_item = cur.fetchone()

            if not row_item:
                raise Exception(
                    f"Item do produto {produto_id} não localizado no pedido {pedido}."
                )

            (
                sequencia,
                valor_unitario,
                percentual_desconto,
                percentual_acrescimo,
                valor_frete,
                percentual_comissao,
                percentual_comissao_supervisor,
                observacao_atual
            ) = row_item

            sequencia = inteiro_seguro(sequencia, 0)

            valor_unitario = decimal_seguro(valor_unitario)
            percentual_desconto = decimal_seguro(percentual_desconto)
            percentual_acrescimo = decimal_seguro(percentual_acrescimo)
            valor_frete = decimal_seguro(valor_frete)
            percentual_comissao = decimal_seguro(percentual_comissao)
            percentual_comissao_supervisor = decimal_seguro(percentual_comissao_supervisor)

            sub_total = arredondar_moeda(nova_quantidade * valor_unitario)

            valor_desconto = arredondar_moeda(
                sub_total * percentual_desconto / Decimal("100")
            )

            valor_acrescimo = arredondar_moeda(
                sub_total * percentual_acrescimo / Decimal("100")
            )

            valor_total = arredondar_moeda(
                sub_total - valor_desconto + valor_acrescimo + valor_frete
            )

            valor_comissao = arredondar_moeda(
                valor_total * percentual_comissao / Decimal("100")
            )

            valor_comissao_supervisor = arredondar_moeda(
                valor_total * percentual_comissao_supervisor / Decimal("100")
            )

            observacao_rolos = montar_observacao_rolos(
                cur,
                empresa,
                separacao_id,
                produto_id
            )

            observacao_atual = (observacao_atual or "").strip()

            if observacao_atual:
                nova_observacao = observacao_atual + " | " + observacao_rolos
            else:
                nova_observacao = observacao_rolos

            nova_observacao = nova_observacao[:1000]

            cur.execute("""
                UPDATE TB_PEDIDO_VENDA_ITEM
                    SET PEVI_QUANTIDADE = ?,
                        PEVI_QTDE_ESTOQUE = ?,
                        PEVI_VOLUME_ITEM = ?,
                        PEVI_SUB_TOTAL = ?,
                        PEVI_VALOR_DESCONTO = ?,
                        PEVI_VALOR_ACRESCIMO = ?,
                        PEVI_VALOR_TOTAL = ?,
                        PEVI_VALOR_COMISSAO = ?,
                        PEVI_VALOR_COMISSAO_SUPERVISOR = ?,
                        PEVI_OBSERVACAO = ?
                WHERE PEVI_EMPRESA = ?
                    AND PEVI_PEDIDO_VENDA = ?
                    AND PEVI_SEQUENCIA = ?
            """, (
            nova_quantidade,
            nova_quantidade,
            volume_item,
            sub_total,
            valor_desconto,
            valor_acrescimo,
            valor_total,
            valor_comissao,
            valor_comissao_supervisor,
            nova_observacao,
            empresa,
            pedido,
            sequencia
        ))            

            itens_atualizados += 1

        # ------------------------------------------------------
        # 5) Recalcula cabeçalho do pedido somando itens ativos
        # ------------------------------------------------------
        cur.execute("""
            SELECT
                COALESCE(SUM(COALESCE(PEVI_SUB_TOTAL, 0)), 0),
                COALESCE(SUM(COALESCE(PEVI_VALOR_TOTAL, 0)), 0),
                COALESCE(SUM(COALESCE(PEVI_VALOR_DESCONTO, 0)), 0),
                COALESCE(SUM(COALESCE(PEVI_VALOR_COMISSAO, 0)), 0),
                COALESCE(SUM(COALESCE(PEVI_VOLUME_ITEM, 0)), 0),
                COALESCE(SUM(COALESCE(PEVI_VALOR_COMISSAO_SUPERVISOR, 0)), 0)
            FROM TB_PEDIDO_VENDA_ITEM
            WHERE PEVI_EMPRESA = ?
              AND PEVI_PEDIDO_VENDA = ?
              AND COALESCE(PEVI_STATUS, 'A') <> 'C'
        """, (empresa, pedido))

        (
            soma_sub_total,
            soma_valor_total,
            soma_valor_desconto,
            soma_valor_comissao,
            soma_volume,
            soma_comissao_supervisor
        ) = cur.fetchone()

        cur.execute("""
            UPDATE TB_PEDIDO_VENDA
               SET PEV_SUB_TOTAL = ?,
                   PEV_VALOR_TOTAL = ?,
                   PEV_VALOR_DESCONTO = ?,
                   PEV_VALOR_COMISSAO = ?,
                   PEV_VOLUME = ?,
                   PEV_VALOR_COMISSAO_SUPERVISOR = ?
             WHERE PEV_EMPRESA = ?
               AND PEV_ID = ?
        """, (
            soma_sub_total,
            soma_valor_total,
            soma_valor_desconto,
            soma_valor_comissao,
            soma_volume,
            soma_comissao_supervisor,
            empresa,
            pedido
        ))

        # ------------------------------------------------------
        # 6) Marca separação como aplicada ao pedido
        # ------------------------------------------------------
        cur.execute("""
            UPDATE TB_PEDIDO_VENDA_SEPARACAO
               SET PVSE_APLICADA_PEDIDO = 'S',
                   PVSE_DT_APLICACAO_PEDIDO = CURRENT_TIMESTAMP,
                   PVSE_USUARIO_APLICACAO = ?,
                   PVSE_OBSERVACAO = COALESCE(PVSE_OBSERVACAO, '') ||
                       ' | Separação aplicada ao pedido oficial.'
             WHERE PVSE_EMPRESA = ?
               AND PVSE_ID = ?
        """, (usuario, empresa, separacao_id))

        con.commit()

        return jsonify({
            "status": "ok",
            "mensagem": "Separação aplicada ao pedido com sucesso.",
            "empresa": empresa,
            "pedido": pedido,
            "separacao_id": separacao_id,
            "itens_atualizados": itens_atualizados,
            "total_pedido": float(soma_valor_total or 0),
            "volume": float(soma_volume or 0)
        })

    except Exception as e:
        try:
            if con:
                con.rollback()
        except:
            pass

        print("\n========== ERRO NA ROTA /pedidos/separacao/aplicar-no-pedido ==========")
        print(e)
        traceback.print_exc()
        print("=======================================================================\n")

        return jsonify({
            "status": "erro",
            "mensagem": str(e)
        }), 500

    finally:
        try:
            if con:
                con.close()
        except:
            pass
            


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
