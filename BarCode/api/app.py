from flask import Flask, request, jsonify
import fdb
import os
from PIL import Image
import json
import hashlib
import socket
import traceback
import re
from decimal import Decimal, ROUND_HALF_UP
from threading import Lock

app = Flask(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LOGO_ZEBRA_PATH = os.path.join(BASE_DIR, "logo_cliente.png")
CONFIG_IMPRESSAO_PATH = os.path.join(BASE_DIR, "config_impressao.json")
REGULARIZACAO_ROLO_RE = re.compile(r"^R\d{17}$")
F22_ROLO_RE = re.compile(r"^F\d{21}$")
regularizacao_lock = Lock()
regularizacao_em_andamento = set()

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
        
        #database=r"C:\Parmasoft\Dados\Dados.FDB",        
        database=r"E:\Dados Clientes\GramDecor\Dados.FDB",  
        #database=r"E:\Dados Clientes\Tekno Prime\Dados.FDB",          
        user="SYSDBA",
        password="masterkey",
        charset="ISO8859_1"
    )


def consultar_empresa_atual(cur, empresa):
    cur.execute("""
        SELECT
            EMP_ID,
            COALESCE(EMP_FANTASIA, EMP_RAZAO_SOCIAL, ''),
            COALESCE(EMP_TIPO, '')
        FROM TB_EMPRESA
        WHERE EMP_ID = ?
    """, (empresa,))

    row = cur.fetchone()
    if not row:
        return None

    tipo = (row[2] or "").strip().upper()
    return {
        "empresa": int(row[0]),
        "nome": (row[1] or "").strip(),
        "tipo": tipo,
        "eh_filial": tipo == "F"
    }

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
              AND COALESCE(PRD_STATUS, 'A') <> 'I'
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
# ROTA: CONSULTAR EMPRESA ATUAL
# ==============================================================
@app.route("/empresas/atual", methods=["GET"])
def empresa_atual():
    con = None

    try:
        empresa_param = request.args.get("empresa")

        if not empresa_param:
            return jsonify({
                "status": "erro",
                "mensagem": "Empresa nÃ£o informada."
            }), 400

        empresa = int(empresa_param)
        if empresa <= 0:
            raise ValueError

        con = get_connection()
        cur = con.cursor()
        dados_empresa = consultar_empresa_atual(cur, empresa)

        if dados_empresa is None:
            return jsonify({
                "status": "nao_encontrado",
                "mensagem": f"Empresa {empresa} nÃ£o encontrada."
            }), 404

        return jsonify({
            "status": "ok",
            **dados_empresa
        })

    except (TypeError, ValueError):
        return jsonify({
            "status": "erro",
            "mensagem": "Empresa invÃ¡lida."
        }), 400
    except Exception as e:
        print("\n========== ERRO NA ROTA /empresas/atual ==========")
        print(e)
        traceback.print_exc()
        print("==================================================\n")
        return jsonify({"status": "erro", "mensagem": str(e)}), 500
    finally:
        try:
            if con:
                con.close()
        except:
            pass


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


def resolver_codigo_rolo(cur, empresa, codigo_lido):
    codigo_lido = (codigo_lido or "").strip().upper()
    cur.execute("""
        SELECT
            RETORNO,
            MENSAGEM,
            CODIGO_LIDO,
            CODIGO_CANONICO,
            PROR_ID_ANTIGO,
            PROR_ID_ATUAL,
            PRODUTO,
            QUANTIDADE,
            ORIGEM
        FROM SP_RESOLVE_CODIGO_ROLO(?, ?)
    """, (empresa, codigo_lido))

    row = cur.fetchone()
    if not row:
        raise ValueError("O resolvedor de rolos nao retornou resultado.")

    retorno = (row[0] or "").strip().upper()
    if retorno != "OK":
        raise ValueError((row[1] or "Codigo de rolo rejeitado.").strip())

    return {
        "mensagem": (row[1] or "").strip(),
        "codigo_lido": (row[2] or codigo_lido).strip().upper(),
        "codigo_canonico": (row[3] or "").strip().upper(),
        "pror_id_antigo": inteiro_seguro(row[4], 0),
        "pror_id_atual": inteiro_seguro(row[5], 0),
        "produto": inteiro_seguro(row[6], 0),
        "quantidade": decimal_seguro(row[7]),
        "origem": (row[8] or "").strip().upper(),
    }


def resolver_codigo_f22(cur, empresa, codigo_lido):
    """Resolve F22 pelo PROR_ID, sem alterar nem reutilizar o contrato R legado."""
    codigo_lido = (codigo_lido or "").strip().upper()

    if not F22_ROLO_RE.fullmatch(codigo_lido):
        raise ValueError(
            "Etiqueta F22 inválida. Informe F + PROR_ID(6) + PRODUTO(7) + QUANTIDADE(8)."
        )

    pror_id = int(codigo_lido[1:7])
    produto_codigo = int(codigo_lido[7:14])
    quantidade_codigo = Decimal(codigo_lido[14:22]) / Decimal("10000")

    cur.execute("""
        SELECT
            R.PROR_EMPRESA,
            R.PROR_ID,
            R.PROR_PRODUTO,
            R.PROR_QUANTIDADE,
            R.PROR_UN,
            R.PROR_STATUS,
            R.PROR_CODIGO_BARRAS,
            P.PRD_DESCRICAO
        FROM TB_PRODUTO_ROLO R
        JOIN TB_PRODUTO P
          ON P.PRD_EMPRESA = R.PROR_EMPRESA
         AND P.PRD_ID = R.PROR_PRODUTO
        WHERE R.PROR_EMPRESA = ?
          AND R.PROR_ID = ?
          AND R.PROR_STATUS = 'A'
          AND COALESCE(P.PRD_STATUS, 'A') <> 'I'
    """, (empresa, pror_id))

    row = cur.fetchone()
    if not row:
        raise ValueError("Rolo F22 não encontrado, inativo ou pertencente a outra empresa.")

    (
        empresa_banco,
        pror_id_banco,
        produto_banco,
        quantidade_banco,
        unidade,
        status,
        codigo_canonico,
        descricao,
    ) = row

    quantidade_banco = decimal_seguro(quantidade_banco).quantize(
        Decimal("0.0001"), rounding=ROUND_HALF_UP
    )

    if int(produto_banco) != produto_codigo:
        raise ValueError("Produto codificado na etiqueta F22 diverge do rolo físico.")

    if quantidade_banco != quantidade_codigo:
        raise ValueError("Quantidade codificada na etiqueta F22 diverge do rolo físico.")

    return {
        "codigo_lido": codigo_lido,
        "codigo_canonico": (codigo_canonico or "").strip().upper(),
        "pror_id_atual": inteiro_seguro(pror_id_banco, 0),
        "produto": inteiro_seguro(produto_banco, 0),
        "quantidade": quantidade_banco,
        "unidade": (unidade or "").strip(),
        "descricao": (descricao or "").strip(),
        "status": (status or "").strip().upper(),
        "empresa": inteiro_seguro(empresa_banco, 0),
    }


def auditar_uso_alias_rolo(cur, empresa, resolucao, usuario, origem, chave):
    if resolucao.get("origem") != "ALIAS":
        return

    cur.execute("""
        EXECUTE PROCEDURE SP_AUD_USO_ALIAS_ROLO(?, ?, ?, ?, ?, ?)
    """, (
        empresa,
        resolucao["codigo_lido"],
        resolucao["codigo_canonico"],
        usuario,
        origem,
        chave,
    ))
    
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

^FO115,180
^BQN,2,8
^FDLA,{codigo_barras}^FS

^FO430,180^A0N,42,42^FB330,1,0,C,0^FDQTDE:^FS
^FO430,232^A0N,52,52^FB330,1,0,C,0^FD{qtd_txt} {unidade}^FS
^FO430,300^A0N,28,28^FB330,1,0,C,0^FD{codigo_barras}^FS

^XZ
"""

    return zpl.strip()    

def gerar_zpl_rolo_separado_pedido(
    pedido,
    cliente,
    cidade,
    produto_id,
    descricao,
    quantidade,
    unidade,
    pror_id,
    codigo_barras
):
    """
    Etiqueta complementar impressa após salvar a separação.

    Objetivo:
    - identificar que o rolo já pertence a um pedido vendido
    - destacar pedido, cliente e cidade
    - NÃO imprimir QR Code
    - NÃO imprimir código de barras
    - NÃO repetir a etiqueta original do rolo
    """
    cliente = (cliente or "").strip()
    cidade = (cidade or "").strip()
    descricao = (descricao or "").strip()

    linhas_cliente = quebrar_texto(cliente, tamanho=36, max_linhas=1)
    linhas_cidade = quebrar_texto(cidade, tamanho=36, max_linhas=1)
    linhas_desc = quebrar_texto(descricao, tamanho=34, max_linhas=2)

    cidade_txt = linhas_cidade[0] if cidade else ""

    # Mantém logo pequena no canto direito.
    logo_zpl = bloco_logo_zpl(
        LOGO_ZEBRA_PATH,
        x=None,
        y=12,
        largura=135,
        altura_max=40,
    )

    # Etiqueta 10x5 cm - Zebra 203dpi
    # Largura 800 dots / altura 400 dots
    #
    # Layout baseado no teste do BAT aprovado:
    # PEDIDO grande no topo
    # CLIENTE e CIDADE em destaque
    # PRODUTO/DESCRIÇÃO no rodapé esquerdo
    # ROLO no rodapé direito
    zpl = f"""
^XA
^PW800
^LL400
^CI28
{logo_zpl}

^FO25,25^A0N,50,50^FDPEDIDO: {int(pedido)}^FS

^FO25,95^A0N,26,26^FDCLIENTE:^FS
^FO25,128^A0N,34,34^FD{linhas_cliente[0]}^FS

^FO25,185^A0N,26,26^FDCIDADE:^FS
^FO25,218^A0N,34,34^FD{cidade_txt}^FS

^FO555,65
^BQN,2,8
^FDLA,{codigo_barras}^FS

^FO25,292^A0N,26,26^FDPRODUTO: {produto_id}^FS
^FO25,325^A0N,30,30^FD{linhas_desc[0]}^FS
^FO25,360^A0N,30,30^FD{linhas_desc[1]}^FS

^FO565,292^A0N,26,26^FDROLO:^FS
^FO565,325^A0N,40,40^FD{str(int(pror_id)).zfill(6)}^FS

^XZ
"""
    return zpl.strip()



def imprimir_etiquetas_rolos_separados_pedido(rolos_para_imprimir):
    """
    Recebe uma lista de rolos R já salvos na separação e imprime em um único envio.
    Códigos C não entram nesta lista e nunca são impressos aqui.
    """
    if not rolos_para_imprimir:
        return {
            "status": "sem_rolos",
            "mensagem": "Nenhum rolo R para imprimir.",
            "quantidade": 0,
        }

    zpl_total = ""

    for rolo in rolos_para_imprimir:
        zpl_total += gerar_zpl_rolo_separado_pedido(
            pedido=rolo.get("pedido"),
            cliente=rolo.get("cliente"),
            cidade=rolo.get("cidade"),
            produto_id=rolo.get("produto_id"),
            descricao=rolo.get("descricao"),
            quantidade=rolo.get("quantidade"),
            unidade=rolo.get("unidade"),
            pror_id=rolo.get("pror_id"),
            codigo_barras=rolo.get("codigo_barras"),
        ) + "\n"

    retorno = enviar_zpl_para_impressora(zpl_total)

    return {
        "status": "ok",
        "mensagem": f"{len(rolos_para_imprimir)} etiqueta(s) de rolo separado enviada(s).",
        "retorno": retorno,
        "quantidade": len(rolos_para_imprimir),
    }
    

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
              AND COALESCE(PRD_STATUS, 'A') <> 'I'
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
            SELECT COUNT(*)
            FROM TB_PRODUTO
            WHERE PRD_EMPRESA = ?
              AND PRD_ID = ?
              AND COALESCE(PRD_STATUS, 'A') <> 'I'
        """, (empresa, produto_id))

        if inteiro_seguro(cur.fetchone()[0], 0) == 0:
            return jsonify({
                "status": "erro",
                "mensagem": "Produto não encontrado ou inativo."
            }), 400

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

            try:
                cur.execute("""
                    SELECT GEN_ID(GEN_PRODUTO_ROLO_ID, 1)
                    FROM RDB$DATABASE
                """)
                novo_id = int(cur.fetchone()[0])
            except Exception as erro_generator:
                raise RuntimeError(
                    "GEN_PRODUTO_ROLO_ID nao encontrado ou indisponivel. "
                    "Execute a atualizacao de banco 1.1.0.67z antes de salvar rolos."
                ) from erro_generator

            if novo_id < 1 or novo_id > 999999:
                raise ValueError(
                    "PROR_ID fora do limite suportado pela etiqueta R "
                    f"(1 a 999999): {novo_id}. Nenhum rolo do lote foi salvo."
                )

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
              AND COALESCE(P.PRD_STATUS, 'A') <> 'I'
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
              AND COALESCE(P.PRD_STATUS, 'A') <> 'I'
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
              AND COALESCE(P.PRD_STATUS, 'A') <> 'I'
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

        # QR é o padrão oficial atual.
        # Ignora qualquer solicitação antiga de CODE128 enviada pelo app.
        tipo_codigo = "QR"

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
              AND COALESCE(P.PRD_STATUS, 'A') <> 'I'
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
              AND COALESCE(P.PRD_STATUS, 'A') <> 'I'
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

            zpl = gerar_zpl_rolo_qrcode(
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
              AND COALESCE(P.PRD_STATUS, 'A') <> 'I'
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

        zpl = gerar_zpl_rolo_qrcode(
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
@app.route("/rolos/consultar-f22", methods=["GET"])
def consultar_codigo_f22():
    """Consulta isolada para F22 usada somente pela Separação de Pedidos."""
    con = None

    try:
        empresa = int(request.args.get("empresa", 1))
        codigo = (request.args.get("codigo", "") or "").strip().upper()

        con = get_connection()
        cur = con.cursor()
        resolucao = resolver_codigo_f22(cur, empresa, codigo)

        return jsonify({
            "status": "ok",
            "codigo_lido": resolucao["codigo_lido"],
            "pror_id": resolucao["pror_id_atual"],
            "produto_id": resolucao["produto"],
            "quantidade": float(resolucao["quantidade"]),
            "unidade": resolucao["unidade"],
            "descricao": resolucao["descricao"],
        })
    except ValueError as erro:
        return jsonify({
            "status": "erro",
            "mensagem": str(erro),
        }), 409
    except Exception as erro:
        print("\n========== ERRO NA ROTA /rolos/consultar-f22 ==========")
        print(erro)
        traceback.print_exc()
        print("=========================================================\n")
        return jsonify({"status": "erro", "mensagem": str(erro)}), 500
    finally:
        try:
            if con:
                con.close()
        except:
            pass


@app.route("/rolos/consultar-codigo", methods=["GET"])
def consultar_codigo_rolo():
    con = None

    try:
        empresa = int(request.args.get("empresa", 1))
        codigo = (request.args.get("codigo", "") or "").strip().upper()
        validar_recebimento_pedido_compra = (request.args.get("validar_recebimento_pedido_compra", "N") or "N").strip().upper() == "S"

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

        con = get_connection()
        cur = con.cursor()

        try:
            resolucao = resolver_codigo_rolo(cur, empresa, codigo)
        except ValueError as erro_resolucao:
            mensagem = str(erro_resolucao)
            status_http = 404 if "nao encontrado" in mensagem.lower() else 409
            return jsonify({
                "status": "nao_encontrado" if status_http == 404 else "erro",
                "mensagem": mensagem,
                "codigo_lido": codigo,
            }), status_http

        pror_id = resolucao["pror_id_atual"]
        produto_id_codigo = resolucao["produto"]
        quantidade_codigo = float(resolucao["quantidade"])
        codigo_canonico = resolucao["codigo_canonico"]

        if validar_recebimento_pedido_compra:
            cur.execute("""
                SELECT FIRST 1 PCRL_RECEBIMENTO
                FROM TB_PEDIDO_COMPRA_RECEB_ETIQUETA
                WHERE PCRL_EMPRESA = ?
                  AND PCRL_TIPO_ETIQUETA = 'R'
                  AND PCRL_PROR_ID = ?
                  AND PCRL_SITUACAO = 'A'
            """, (empresa, pror_id))
            if cur.fetchone():
                return jsonify({
                    "status": "erro",
                    "mensagem": "Etiqueta R ja recebida.",
                    "codigo_lido": codigo,
                    "codigo_canonico": codigo_canonico,
                    "pror_id": pror_id,
                }), 409

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
              AND R.PROR_CODIGO_BARRAS = ?
              AND R.PROR_STATUS = 'A'
              AND COALESCE(P.PRD_STATUS, 'A') <> 'I'
        """

        cur.execute(sql, (empresa, pror_id, codigo_canonico))
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
            "codigo_canonico": codigo_canonico,
            "pror_id": pror_id_db,
            "pror_id_antigo": resolucao["pror_id_antigo"],
            "origem": resolucao["origem"],
            "etiqueta_historica": resolucao["origem"] == "ALIAS",
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
# FUNCOES: REGULARIZACAO DE ROLOS ANTIGOS DAS FILIAIS
# ==============================================================
def interpretar_etiqueta_rolo_regularizacao(codigo):
    codigo = (codigo or "").strip().upper()

    if not REGULARIZACAO_ROLO_RE.match(codigo):
        raise ValueError("Etiqueta invalida.")

    return {
        "codigo": codigo,
        "pror_id": int(codigo[1:7]),
        "produto": int(codigo[7:14]),
        "quantidade": Decimal(codigo[14:18]) / Decimal("10")
    }


def quantidades_conferem(qtd_a, qtd_b):
    return abs(decimal_seguro(qtd_a) - decimal_seguro(qtd_b)) <= Decimal("0.0001")


def erro_regularizacao(mensagem, codigo=None, http_status=409):
    corpo = {
        "status": "erro",
        "mensagem": mensagem
    }

    if codigo:
        corpo["codigo"] = codigo

    return jsonify(corpo), http_status


def obter_empresa_filial_e_matriz(cur, empresa_filial):
    cur.execute("""
        SELECT
            F.EMP_ID,
            COALESCE(F.EMP_TIPO, ''),
            F.EMP_EMPRESA_MATRIZ,
            M.EMP_ID
        FROM TB_EMPRESA F
        LEFT JOIN TB_EMPRESA M
          ON M.EMP_ID = F.EMP_EMPRESA_MATRIZ
        WHERE F.EMP_ID = ?
    """, (empresa_filial,))

    row = cur.fetchone()
    if not row:
        return None, "Empresa destino nao encontrada."

    tipo_filial = (row[1] or "").strip().upper()
    if tipo_filial != "F":
        return None, "Esta operação é permitida somente para empresas filiais."

    empresa_matriz = inteiro_seguro(row[3], 0)
    if empresa_matriz <= 0:
        return None, "Empresa matriz da filial nao encontrada."

    return {
        "empresa_filial": int(row[0]),
        "empresa_matriz": empresa_matriz
    }, None


def validar_rolo_regularizacao(cur, empresa_filial, empresa_matriz, item):
    etiqueta = interpretar_etiqueta_rolo_regularizacao(item.get("codigo"))
    codigo_lido = etiqueta["codigo"]
    pror_id_lido = etiqueta["pror_id"]
    produto_lido = etiqueta["produto"]
    quantidade_lida = etiqueta["quantidade"]

    pror_payload = inteiro_seguro(item.get("pror_id", item.get("prorId")), pror_id_lido)
    produto_payload = inteiro_seguro(item.get("produto", item.get("produto_id")), produto_lido)
    quantidade_payload = decimal_seguro(item.get("quantidade"), quantidade_lida)

    if pror_payload != pror_id_lido:
        raise ValueError("PROR_ID da coleta diverge da etiqueta.")

    if produto_payload != produto_lido:
        raise ValueError("Produto da coleta diverge da etiqueta.")

    if not quantidades_conferem(quantidade_payload, quantidade_lida):
        raise ValueError("Quantidade da coleta diverge da etiqueta.")

    resolucao = resolver_codigo_rolo(cur, empresa_matriz, codigo_lido)
    codigo = resolucao["codigo_canonico"]
    pror_id = resolucao["pror_id_atual"]
    produto = resolucao["produto"]
    quantidade = resolucao["quantidade"]

    cur.execute("""
        SELECT
            PROR_PRODUTO,
            PROR_QUANTIDADE,
            PROR_UN,
            PROR_CODIGO_BARRAS,
            PROR_STATUS,
            PROR_IMPRESSO,
            PROR_DT_IMPRESSAO,
            PROR_USUARIO_IMP,
            PROR_LOTE
        FROM TB_PRODUTO_ROLO
        WHERE PROR_EMPRESA = ?
          AND PROR_ID = ?
    """, (empresa_matriz, pror_id))

    origem = cur.fetchone()
    if not origem:
        raise ValueError("Rolo original nao encontrado na matriz.")

    (
        produto_origem,
        quantidade_origem,
        unidade_origem,
        codigo_origem,
        status_origem,
        impresso_origem,
        dt_impressao_origem,
        usuario_imp_origem,
        lote_origem
    ) = origem

    codigo_origem = (codigo_origem or "").strip().upper()
    status_origem = (status_origem or "").strip().upper()

    if status_origem not in ("A", "T"):
        raise ValueError("Status do rolo original invalido para regularizacao. Apenas A ou T sao aceitos.")

    if int(produto_origem) != produto:
        raise ValueError("Produto do rolo original diverge da etiqueta.")

    if not quantidades_conferem(quantidade_origem, quantidade):
        raise ValueError("Quantidade do rolo original diverge da etiqueta.")

    if codigo_origem != codigo:
        raise ValueError("Codigo de barras do rolo original diverge da etiqueta.")

    cur.execute("""
        SELECT COUNT(*)
        FROM TB_PRODUTO
        WHERE PRD_EMPRESA = ?
          AND PRD_ID = ?
          AND COALESCE(PRD_STATUS, 'A') <> 'I'
    """, (empresa_filial, produto))

    if inteiro_seguro(cur.fetchone()[0], 0) == 0:
        raise ValueError("Produto do rolo nao encontrado ou inativo na filial.")

    cur.execute("""
        SELECT FIRST 1 PROR_ID, PROR_CODIGO_BARRAS
        FROM TB_PRODUTO_ROLO
        WHERE PROR_EMPRESA = ?
          AND (PROR_ID = ? OR PROR_CODIGO_BARRAS = ?)
    """, (empresa_filial, pror_id, codigo))

    filial = cur.fetchone()
    if filial:
        if int(filial[0]) == pror_id:
            raise ValueError("Este rolo ja esta cadastrado nesta filial.")
        raise ValueError("Codigo de barras ja cadastrado nesta filial com outro rolo.")

    cur.execute("""
        SELECT FIRST 1 PROR_EMPRESA, PROR_ID
        FROM TB_PRODUTO_ROLO
        WHERE PROR_EMPRESA <> ?
          AND PROR_EMPRESA <> ?
          AND (PROR_ID = ? OR PROR_CODIGO_BARRAS = ?)
    """, (empresa_matriz, empresa_filial, pror_id, codigo))

    outra_filial = cur.fetchone()
    if outra_filial:
        raise ValueError(
            f"Este rolo ja esta cadastrado em outra filial: empresa {int(outra_filial[0])}."
        )

    cur.execute("""
        SELECT FIRST 1 PROR_EMPRESA, PROR_ID
        FROM TB_PRODUTO_ROLO
        WHERE PROR_CODIGO_BARRAS = ?
          AND PROR_ID <> ?
    """, (codigo, pror_id))

    codigo_outro_id = cur.fetchone()
    if codigo_outro_id:
        raise ValueError("Codigo de barras associado a outro PROR_ID.")

    cur.execute("""
        SELECT FIRST 1 PROR_EMPRESA
        FROM TB_PRODUTO_ROLO
        WHERE PROR_ID = ?
          AND (
            PROR_PRODUTO <> ?
            OR ABS(COALESCE(PROR_QUANTIDADE, 0) - ?) > 0.0001
            OR COALESCE(PROR_CODIGO_BARRAS, '') <> ?
          )
    """, (pror_id, produto, quantidade, codigo))

    pror_incompativel = cur.fetchone()
    if pror_incompativel:
        raise ValueError("Mesmo PROR_ID encontrado com produto, quantidade ou codigo incompativel.")

    return {
        "codigo": codigo_lido,
        "codigo_canonico": codigo,
        "pror_id": pror_id,
        "produto": produto,
        "quantidade": quantidade_origem,
        "unidade": unidade_origem,
        "codigo_barras": codigo_origem,
        "dt_impressao": dt_impressao_origem,
        "usuario_imp": usuario_imp_origem,
        "lote": lote_origem,
        "impresso_origem": impresso_origem,
        "status_origem": status_origem,
        "resolucao": resolucao,
    }


# ==============================================================
# ROTA: CONFIRMAR REGULARIZACAO DE ROLOS ANTIGOS DA FILIAL
# ==============================================================
@app.route("/rolos/regularizacao/confirmar", methods=["POST"])
def confirmar_regularizacao_rolos():
    con = None
    chave_envio = None

    try:
        dados = request.get_json() or {}
        empresa = inteiro_seguro(dados.get("empresa"), 0)
        usuario = inteiro_seguro(dados.get("usuario"), 1)
        rolos = dados.get("rolos") or []

        if empresa <= 0:
            return erro_regularizacao("Empresa destino nao informada.", http_status=400)

        if usuario <= 0:
            return erro_regularizacao("Usuario nao informado.", http_status=400)

        if not isinstance(rolos, list) or len(rolos) == 0:
            return erro_regularizacao("Nenhum rolo informado.", http_status=400)

        codigos_envio = []
        for item in rolos:
            if not isinstance(item, dict):
                return erro_regularizacao("Item de rolo invalido.", http_status=400)
            codigos_envio.append((item.get("codigo") or "").strip().upper())

        chave_envio = (empresa, tuple(sorted(codigos_envio)))
        with regularizacao_lock:
            if chave_envio in regularizacao_em_andamento:
                return erro_regularizacao("Regularizacao ja esta em andamento para esta coleta.", http_status=409)
            regularizacao_em_andamento.add(chave_envio)

        con = get_connection()
        cur = con.cursor()

        empresas, erro_empresa = obter_empresa_filial_e_matriz(cur, empresa)
        if erro_empresa:
            con.rollback()
            http_status = 403 if "somente para empresas filiais" in erro_empresa else 400
            return erro_regularizacao(erro_empresa, http_status=http_status)

        empresa_filial = empresas["empresa_filial"]
        empresa_matriz = empresas["empresa_matriz"]

        codigos_lidos = set()
        pror_ids_lidos = set()
        validados = []

        for item in rolos:
            codigo_item = (item.get("codigo") or "").strip().upper()

            try:
                etiqueta_previa = interpretar_etiqueta_rolo_regularizacao(codigo_item)

                if etiqueta_previa["codigo"] in codigos_lidos:
                    raise ValueError("Esta etiqueta ja foi enviada mais de uma vez na coleta.")

                codigos_lidos.add(etiqueta_previa["codigo"])

                validado = validar_rolo_regularizacao(
                    cur,
                    empresa_filial,
                    empresa_matriz,
                    item
                )
                if validado["pror_id"] in pror_ids_lidos:
                    raise ValueError("Este rolo canonico ja foi enviado mais de uma vez na coleta.")

                pror_ids_lidos.add(validado["pror_id"])
                validados.append(validado)
            except ValueError as erro_item:
                con.rollback()
                return erro_regularizacao(str(erro_item), codigo=codigo_item)

        for rolo in validados:
            if rolo["status_origem"] == "A":
                cur.execute("""
                    UPDATE TB_PRODUTO_ROLO
                    SET PROR_STATUS = 'T'
                    WHERE PROR_EMPRESA = ?
                      AND PROR_ID = ?
                      AND PROR_STATUS = 'A'
                """, (
                    empresa_matriz,
                    rolo["pror_id"]
                ))

            cur.execute("""
                INSERT INTO TB_PRODUTO_ROLO (
                    PROR_EMPRESA,
                    PROR_ID,
                    PROR_PRODUTO,
                    PROR_QUANTIDADE,
                    PROR_UN,
                    PROR_CODIGO_BARRAS,
                    PROR_STATUS,
                    PROR_IMPRESSO,
                    PROR_DT_CADASTRO,
                    PROR_USUARIO_CAD,
                    PROR_PRATELEIRA,
                    PROR_DT_IMPRESSAO,
                    PROR_USUARIO_IMP,
                    PROR_OBSERVACAO,
                    PROR_LOTE
                )
                VALUES (?, ?, ?, ?, ?, ?, 'A', 'S', CURRENT_TIMESTAMP, ?, NULL, ?, ?, NULL, ?)
            """, (
                empresa_filial,
                rolo["pror_id"],
                rolo["produto"],
                rolo["quantidade"],
                rolo["unidade"],
                rolo["codigo_barras"],
                usuario,
                rolo["dt_impressao"],
                rolo["usuario_imp"],
                rolo["lote"]
            ))

            auditar_uso_alias_rolo(
                cur,
                empresa_matriz,
                rolo["resolucao"],
                usuario,
                "TB_PRODUTO_ROLO",
                f"EMPRESA_DESTINO={empresa_filial};PROR_ID={rolo['pror_id']}",
            )

        con.commit()

        total = len(validados)
        mensagem = (
            "Rolo regularizado com sucesso."
            if total == 1
            else f"{total} rolos regularizados com sucesso."
        )

        return jsonify({
            "status": "ok",
            "mensagem": mensagem,
            "total": total,
            "rolos": [
                {
                    "codigo": item["codigo"],
                    "pror_id": item["pror_id"],
                    "produto": item["produto"]
                }
                for item in validados
            ]
        })

    except Exception as e:
        try:
            if con:
                con.rollback()
        except:
            pass

        print("\n========== ERRO NA ROTA /rolos/regularizacao/confirmar ==========")
        print(e)
        traceback.print_exc()
        print("=================================================================\n")

        return erro_regularizacao(str(e), http_status=500)

    finally:
        if chave_envio is not None:
            try:
                with regularizacao_lock:
                    regularizacao_em_andamento.discard(chave_envio)
            except:
                pass

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


def texto_tipo_comercial(valor):
    return (valor or "").strip().upper()


def usa_valor_unitario_tablet(origem_desconto_item, versao_tablet):
    return (
        texto_tipo_comercial(origem_desconto_item) == "M"
        and texto_tipo_comercial(versao_tablet) != "N"
    )


def calcular_valor_desconto_item(
    tipo_desconto,
    desconto_informado,
    quantidade,
    valor_unitario,
    sub_total,
    origem_desconto_item,
    versao_tablet
):
    tipo = texto_tipo_comercial(tipo_desconto)
    desconto = decimal_seguro(desconto_informado)

    if desconto <= 0:
        return Decimal("0")

    if tipo == "V":
        if usa_valor_unitario_tablet(origem_desconto_item, versao_tablet):
            return arredondar_moeda(quantidade * (valor_unitario - desconto))
        return arredondar_moeda(desconto * quantidade)

    if tipo == "P":
        return arredondar_moeda(sub_total * desconto / Decimal("100"))

    if tipo == "T":
        return arredondar_moeda(sub_total - desconto)

    return Decimal("0")


def calcular_valor_acrescimo_item(
    tipo_acrescimo,
    acrescimo_informado,
    quantidade,
    valor_unitario,
    sub_total,
    origem_desconto_item,
    versao_tablet
):
    tipo = texto_tipo_comercial(tipo_acrescimo)
    acrescimo = decimal_seguro(acrescimo_informado)

    if acrescimo <= 0:
        return Decimal("0")

    if tipo == "V":
        if usa_valor_unitario_tablet(origem_desconto_item, versao_tablet):
            return arredondar_moeda(quantidade * (acrescimo - valor_unitario))
        return arredondar_moeda(acrescimo * quantidade)

    if tipo == "P":
        return arredondar_moeda(sub_total * acrescimo / Decimal("100"))

    if tipo == "T":
        return arredondar_moeda(acrescimo - sub_total)

    return Decimal("0")


def arredondar_decimal(valor, casas):
    mascara = Decimal("1").scaleb(-casas)
    return decimal_seguro(valor).quantize(mascara, rounding=ROUND_HALF_UP)


def recalcular_rateios_capa_pedido(
    itens,
    tipo_desconto,
    desconto_informado,
    tipo_acrescimo,
    acrescimo_informado,
    percentual_maximo_desconto=None
):
    """Reaplica somente os ajustes da capa sobre a fotografia final dos itens."""
    resultado = []
    campos_decimais = (
        "sub_total",
        "valor_desconto",
        "valor_acrescimo",
        "valor_total",
        "desc_rateado",
        "acresc_rateado"
    )

    for item in itens:
        item_calculado = dict(item)
        for campo in campos_decimais:
            item_calculado[campo] = decimal_seguro(item_calculado.get(campo))
        item_calculado["aplica_desconto"] = texto_tipo_comercial(
            item_calculado.get("aplica_desconto")
        )
        resultado.append(item_calculado)

    tipo_desc = texto_tipo_comercial(tipo_desconto)
    valor_desc = decimal_seguro(desconto_informado)

    if valor_desc > 0 and tipo_desc in ("P", "V", "T"):
        for item in resultado:
            item["valor_total"] += item["desc_rateado"]
            item["desc_rateado"] = Decimal("0")

        itens_aplicaveis = [
            item for item in resultado
            if item["aplica_desconto"] != "N"
        ]
        valor_aplicavel = sum(
            (
                item["valor_total"]
                for item in resultado
                if item["aplica_desconto"] not in ("", "N")
            ),
            Decimal("0")
        )

        if tipo_desc == "V":
            valor_desconto_capa = valor_desc
            if valor_desconto_capa > valor_aplicavel or valor_aplicavel == 0:
                raise ValueError("Valor do DESCONTO inválido.")
            percentual = arredondar_decimal(
                valor_desconto_capa * Decimal("100") / valor_aplicavel,
                4
            )
        elif tipo_desc == "P":
            if valor_desc > 100:
                raise ValueError("Valor do DESCONTO inválido.")
            percentual = arredondar_decimal(valor_desc, 4)
            valor_desconto_capa = None
        else:
            total_sem_desconto_capa = arredondar_decimal(
                sum((item["valor_total"] for item in resultado), Decimal("0")),
                2
            )
            valor_desconto_capa = total_sem_desconto_capa - valor_desc
            if valor_desconto_capa > valor_aplicavel or valor_aplicavel == 0:
                raise ValueError("Valor do DESCONTO inválido.")
            percentual = arredondar_decimal(
                valor_desconto_capa * Decimal("100") / valor_aplicavel,
                4
            )

        fator = arredondar_decimal(percentual / Decimal("100"), 4)

        if (
            percentual_maximo_desconto is not None
            and percentual > decimal_seguro(percentual_maximo_desconto)
        ):
            raise ValueError(
                "Valor de desconto extrapola % máxima da Tabela de Preço. Verifique!"
            )

        for item in itens_aplicaveis:
            base_rateio = (
                item["sub_total"]
                - item["valor_desconto"]
                + item["valor_acrescimo"]
            )
            item["desc_rateado"] = arredondar_decimal(base_rateio * fator, 2)
            item["valor_total"] -= item["desc_rateado"]

        if valor_desconto_capa is not None:
            diferenca = arredondar_decimal(
                valor_desconto_capa
                - sum(
                    (item["desc_rateado"] for item in resultado),
                    Decimal("0")
                ),
                2
            )
            if diferenca != 0 and itens_aplicaveis:
                maior_item = max(
                    itens_aplicaveis,
                    key=lambda item: item["sub_total"]
                )
                maior_item["desc_rateado"] += diferenca
                maior_item["valor_total"] -= diferenca

    tipo_acres = texto_tipo_comercial(tipo_acrescimo)
    valor_acres = decimal_seguro(acrescimo_informado)

    if valor_acres > 0 and tipo_acres in ("P", "V"):
        for item in resultado:
            item["valor_total"] -= item["acresc_rateado"]
            item["acresc_rateado"] = Decimal("0")

        if tipo_acres == "V":
            sub_total_pedido = arredondar_decimal(
                sum((item["sub_total"] for item in resultado), Decimal("0")),
                2
            )
            if sub_total_pedido == 0:
                raise ValueError("Valor do ACRÉSCIMO inválido.")
            percentual = arredondar_decimal(
                valor_acres * Decimal("100") / sub_total_pedido,
                4
            )
        else:
            if valor_acres > 100:
                raise ValueError(
                    "Valor do ACRÉSCIMO inválido - Acréscimo não pode ser maior que 100%."
                )
            percentual = arredondar_decimal(valor_acres, 4)

        fator = arredondar_decimal(percentual / Decimal("100"), 4)

        for item in resultado:
            base_rateio = (
                item["sub_total"]
                - item["valor_desconto"]
                - item["desc_rateado"]
                + item["valor_acrescimo"]
            )
            item["acresc_rateado"] = arredondar_decimal(base_rateio * fator, 4)
            item["valor_total"] += item["acresc_rateado"]

        if tipo_acres == "V":
            diferenca = arredondar_decimal(
                valor_acres
                - sum(
                    (item["acresc_rateado"] for item in resultado),
                    Decimal("0")
                ),
                4
            )
            if diferenca != 0 and resultado:
                maior_item = max(
                    resultado,
                    key=lambda item: item["sub_total"]
                )
                maior_item["acresc_rateado"] += diferenca
                maior_item["valor_total"] += diferenca

    return resultado
     
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
            COALESCE(PVSR_CODIGO_BARRAS, ''),
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
        pror_id, codigo, quantidade, unidade = row

        codigo = (codigo or "").strip().upper()
        qtd = decimal_seguro(quantidade)
        total += qtd

        qtd_txt = f"{float(qtd):.1f}".replace(".", ",")

        # Etiqueta C é item normal do pedido; não tem PROR_ID de rolo.
        if codigo.startswith("C") or pror_id is None or inteiro_seguro(pror_id, 0) <= 0:
            linhas.append(
                f"Item normal - {qtd_txt} {unidade}".strip()
            )
        else:
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
                COALESCE(PEV_FANTASIA_APELIDO, ''),
                COALESCE(PEV_CIDADE, ''),
                COALESCE(PEV_UF, '')
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

        (
            cliente_banco,
            cliente_nome_banco,
            cliente_fantasia_banco,
            cidade_pedido,
            uf_pedido
        ) = row_pedido

        if cliente_id is None and cliente_banco is not None:
            cliente_id = inteiro_seguro(cliente_banco, None)

        if not cliente_nome:
            cliente_nome = (cliente_nome_banco or "").strip()
            if not cliente_nome:
                cliente_nome = (cliente_fantasia_banco or "").strip()

        cidade_pedido = (cidade_pedido or "").strip()
        uf_pedido = (uf_pedido or "").strip()

        cidade_cliente = cidade_pedido

        if uf_pedido:
            if cidade_cliente:
                cidade_cliente = f"{cidade_cliente} - {uf_pedido}"
            else:
                cidade_cliente = uf_pedido

        # ------------------------------------------------------
        # 2) Valida duplicidade no próprio JSON
        # ------------------------------------------------------
        # Regra importante:
        # - R representa rolo físico e funciona como identidade do rolo;
        #   por isso não pode repetir na mesma separação.
        # - C representa etiqueta/volume do pedido; pode existir mais de uma
        #   etiqueta igual e deve ser gravada como histórico da leitura.
        rolos_payload = set()

        for produto in produtos:
            rolos = produto.get("rolos", [])

            for rolo in rolos:
                codigo = (rolo.get("codigo") or rolo.get("codigo_barras") or "").strip().upper()
                pror_id = inteiro_seguro(rolo.get("id") or rolo.get("pror_id"), 0)

                if codigo.startswith(("R", "F")):
                    if codigo.startswith("F"):
                        if not F22_ROLO_RE.fullmatch(codigo):
                            return jsonify({
                                "status": "erro",
                                "mensagem": "Etiqueta F22 inválida no salvamento."
                            }), 400
                        # Em F22 a identidade vem do próprio contrato lido,
                        # nunca do id auxiliar enviado pelo aplicativo.
                        pror_id = int(codigo[1:7])

                    if pror_id <= 0:
                        return jsonify({
                            "status": "erro",
                            "mensagem": "Existe rolo sem PROR_ID válido."
                        }), 400

                    chave = (empresa, codigo[0], codigo)

                    if chave in rolos_payload:
                        return jsonify({
                            "status": "erro",
                            "mensagem": f"Rolo {str(pror_id).zfill(6)} veio duplicado na separação."
                        }), 409

                    rolos_payload.add(chave)

        rolos_canonicos = set()

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
                codigo = (rolo.get("codigo") or rolo.get("codigo_barras") or "").strip().upper()

                # Etiqueta C não é rolo da TB_PRODUTO_ROLO.
                # Ela representa o item normal do pedido e não deve passar pelas validações de PROR_ID.
                if codigo.startswith("C"):
                    continue

                try:
                    if codigo.startswith("F"):
                        resolucao = resolver_codigo_f22(cur, empresa, codigo)
                    else:
                        resolucao = resolver_codigo_rolo(cur, empresa, codigo)
                except ValueError as erro_resolucao:
                    return jsonify({
                        "status": "erro",
                        "mensagem": str(erro_resolucao),
                        "codigo_lido": codigo,
                    }), 409

                pror_id = resolucao["pror_id_atual"]
                codigo = (
                    resolucao["codigo_lido"]
                    if codigo.startswith("F")
                    else resolucao["codigo_canonico"]
                )

                chave_canonica = (empresa, pror_id)
                if chave_canonica in rolos_canonicos:
                    return jsonify({
                        "status": "erro",
                        "mensagem": f"O rolo canonico {str(pror_id).zfill(6)} veio duplicado na separacao."
                    }), 409
                rolos_canonicos.add(chave_canonica)

                rolo["_resolucao_alias"] = resolucao
                rolo["id"] = pror_id
                rolo["pror_id"] = pror_id
                rolo["codigo"] = codigo
                rolo["codigo_barras"] = codigo
                rolo["quantidade"] = float(resolucao["quantidade"])

                # F22 mantém o código impresso F... no histórico e usa PROR_ID
                # como identidade soberana; R conserva a checagem pelo código
                # canônico/alias já existente.
                if codigo.startswith("F"):
                    cur.execute("""
                    SELECT
                        PROR_PRODUTO,
                        PROR_QUANTIDADE,
                        COALESCE(PROR_STATUS, 'A')
                    FROM TB_PRODUTO_ROLO
                    WHERE PROR_EMPRESA = ?
                      AND PROR_ID = ?
                    """, (empresa, pror_id))
                else:
                    cur.execute("""
                    SELECT
                        PROR_PRODUTO,
                        PROR_QUANTIDADE,
                        COALESCE(PROR_STATUS, 'A')
                    FROM TB_PRODUTO_ROLO
                    WHERE PROR_EMPRESA = ?
                      AND PROR_ID = ?
                      AND PROR_CODIGO_BARRAS = ?
                    """, (empresa, pror_id, codigo))

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

                if codigo.startswith("F"):
                    cur.execute("""
                        SELECT COUNT(*)
                        FROM TB_PEDIDO_VENDA_ITEM
                        WHERE PEVI_EMPRESA = ?
                          AND PEVI_PEDIDO_VENDA = ?
                          AND PEVI_PRODUTO = ?
                          AND COALESCE(PEVI_STATUS, 'A') <> 'C'
                    """, (empresa, pedido, produto_id))
                    if int(cur.fetchone()[0] or 0) == 0:
                        return jsonify({
                            "status": "erro",
                            "mensagem": (
                                f"Produto {produto_id} da etiqueta F22 não pertence "
                                f"ao pedido {pedido}."
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

        # Para qualquer produto com F22, o total separado é reconstruído das
        # leituras já revalidadas; assim PROR_QUANTIDADE é a fonte oficial.
        # Produtos sem F22 preservam integralmente o comportamento histórico.
        for produto in produtos:
            rolos = produto.get("rolos", [])
            if any(
                (rolo.get("codigo") or rolo.get("codigo_barras") or "")
                .strip().upper().startswith("F")
                for rolo in rolos
            ):
                produto["separado"] = float(sum(
                    (decimal_seguro(rolo.get("quantidade")) for rolo in rolos),
                    Decimal("0"),
                ))

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
        rolos_para_imprimir = []

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

                codigo = (rolo.get("codigo") or rolo.get("codigo_barras") or "").strip().upper()
                pror_id = inteiro_seguro(rolo.get("id") or rolo.get("pror_id"), 0)

                # Etiqueta C não possui PROR_ID na TB_PRODUTO_ROLO.
                # Como PVSR_PROR_ID é NOT NULL na tabela atual, gravamos 0.
                # O código completo C... continua salvo em PVSR_CODIGO_BARRAS.
                if codigo.startswith("C"):
                    pror_id_gravar = 0
                    observacao_rolo = "Item normal lido na separação do pedido."
                else:
                    pror_id_gravar = pror_id
                    observacao_rolo = "Rolo lido na separação do pedido."

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
                    pror_id_gravar,
                    codigo,
                    quantidade,
                    unidade_rolo,
                    usuario,
                    observacao_rolo
                ))

                if codigo.startswith("R"):
                    auditar_uso_alias_rolo(
                        cur,
                        empresa,
                        rolo.get("_resolucao_alias") or {},
                        usuario,
                        "TB_PEDIDO_VENDA_SEPARACAO_ROLO",
                        f"SEP={separacao_id};ITEM={seq_item};SEQ={seq_rolo}",
                    )

                # Impressão posterior: somente R gera nova etiqueta com dados do pedido.
                # C fica gravado para histórico/conferência, mas não imprime aqui.
                if codigo.startswith("R"):
                    rolos_para_imprimir.append({
                        "pedido": pedido,
                        "cliente": cliente_nome,
                        "cidade": cidade_cliente,
                        "produto_id": produto_id,
                        "descricao": descricao,
                        "quantidade": quantidade,
                        "unidade": unidade_rolo,
                        "pror_id": pror_id_gravar,
                        "codigo_barras": codigo,
                    })

        con.commit()

        impressao = {
            "status": "sem_rolos",
            "mensagem": "Separação sem rolos R para imprimir.",
            "quantidade": 0,
        }

        if rolos_para_imprimir:
            try:
                impressao = imprimir_etiquetas_rolos_separados_pedido(rolos_para_imprimir)
            except Exception as e_imp:
                # A separação já foi salva. Não desfazemos a gravação por falha de impressora.
                print("\n========== ERRO AO IMPRIMIR ETIQUETAS R DA SEPARAÇÃO ==========")
                print(e_imp)
                traceback.print_exc()
                print("===============================================================\n")
                impressao = {
                    "status": "erro",
                    "mensagem": str(e_imp),
                    "quantidade": len(rolos_para_imprimir),
                }

        mensagem_retorno = "Separação salva com sucesso."
        if impressao.get("status") == "ok":
            mensagem_retorno += " Etiqueta(s) R enviada(s) para impressão."
        elif impressao.get("status") == "erro":
            mensagem_retorno += " Atenção: houve erro ao imprimir etiqueta(s) R."

        return jsonify({
            "status": "ok",
            "mensagem": mensagem_retorno,
            "empresa": empresa,
            "pedido": pedido,
            "separacao_id": separacao_id,
            "produtos": len(produtos),
            "rolos": total_rolos,
            "rolos_impressos": impressao.get("quantidade", 0) if impressao.get("status") == "ok" else 0,
            "impressao": impressao,
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
            SELECT
                COALESCE(PEV_STATUS, ''),
                COALESCE(PEV_TIPO_DESCONTO, ''),
                COALESCE(PEV_DESCONTO, 0),
                COALESCE(PEV_TIPO_ACRESCIMO, ''),
                COALESCE(PEV_ACRESCIMO, 0),
                COALESCE(PEV_VALOR_ACRESCIMO, 0),
                COALESCE(PEV_TABELA_PRECO, 0)
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

        (
            status_pedido,
            tipo_desconto_capa,
            desconto_capa,
            tipo_acrescimo_capa,
            acrescimo_capa,
            valor_acrescimo_anterior,
            tabela_preco_pedido
        ) = row_pedido

        status_pedido = (status_pedido or "").strip().upper()

        if status_pedido != "A":
            return jsonify({
                "status": "erro",
                "mensagem": "Somente pedido com status A pode ser alterado pela separação."
            }), 409

        percentual_maximo_desconto = None
        if inteiro_seguro(tabela_preco_pedido, 0) > 0:
            cur.execute("""
                SELECT COALESCE(TBP_VALOR_EXCEDENTE, 0)
                FROM TB_TABELA_PRECO
                WHERE TBP_EMPRESA = ?
                  AND TBP_ID = ?
            """, (empresa, tabela_preco_pedido))
            row_tabela_preco = cur.fetchone()
            percentual_maximo_desconto = (
                row_tabela_preco[0] if row_tabela_preco else Decimal("0")
            )

        cur.execute("""
            SELECT
                COALESCE(PVC_OPCAO_DESCONTO_ITEM, ''),
                COALESCE(PVC_VERSAO_TABLET, '')
            FROM TB_PEDIDO_VENDA_CONFIG
            WHERE PVC_EMPRESA = ?
        """, (empresa,))

        row_config = cur.fetchone()
        if row_config:
            origem_desconto_item, versao_tablet = row_config
        else:
            origem_desconto_item, versao_tablet = "", "N"

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
            
            nova_quantidade = decimal_seguro(qtde_separada).quantize(
                Decimal("0.001"),
                rounding=ROUND_HALF_UP)
            
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
                    COALESCE(PEVI_TIPO_DESCONTO, ''),
                    COALESCE(PEVI_DESCONTO, 0),
                    COALESCE(PEVI_TIPO_ACRESCIMO, ''),
                    COALESCE(PEVI_ACRESCIMO, 0),
                    COALESCE(PEVI_VALOR_FRETE, 0),
                    COALESCE(PEVI_COMISSAO, 0),
                    COALESCE(PEVI_COMISSAO_SUPERVISOR, 0),
                    COALESCE(PEVI_OBSERVACAO, ''),
                    COALESCE(PEVI_DESC_RATEADO, 0),
                    COALESCE(PEVI_ACRESC_RATEADO, 0)
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
                tipo_desconto,
                desconto_informado,
                tipo_acrescimo,
                acrescimo_informado,
                valor_frete,
                percentual_comissao,
                percentual_comissao_supervisor,
                observacao_atual,
                desc_rateado_capa,
                acresc_rateado_capa
            ) = row_item

            sequencia = inteiro_seguro(sequencia, 0)

            valor_unitario = decimal_seguro(valor_unitario)
            desconto_informado = decimal_seguro(desconto_informado)
            acrescimo_informado = decimal_seguro(acrescimo_informado)
            valor_frete = decimal_seguro(valor_frete)
            percentual_comissao = decimal_seguro(percentual_comissao)
            percentual_comissao_supervisor = decimal_seguro(percentual_comissao_supervisor)
            desc_rateado_capa = decimal_seguro(desc_rateado_capa)
            acresc_rateado_capa = decimal_seguro(acresc_rateado_capa)

            sub_total = arredondar_moeda(nova_quantidade * valor_unitario)

            valor_desconto = calcular_valor_desconto_item(
                tipo_desconto,
                desconto_informado,
                nova_quantidade,
                valor_unitario,
                sub_total,
                origem_desconto_item,
                versao_tablet
            )

            valor_acrescimo = calcular_valor_acrescimo_item(
                tipo_acrescimo,
                acrescimo_informado,
                nova_quantidade,
                valor_unitario,
                sub_total,
                origem_desconto_item,
                versao_tablet
            )

            valor_total = arredondar_moeda(
                sub_total
                - valor_desconto
                - desc_rateado_capa
                + valor_acrescimo
                + acresc_rateado_capa
                + valor_frete
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

        # Reaplica somente os ajustes da capa sobre a fotografia final.
        cur.execute("""
            SELECT
                PEVI_SEQUENCIA,
                COALESCE(PEVI_SUB_TOTAL, 0),
                COALESCE(PEVI_VALOR_DESCONTO, 0),
                COALESCE(PEVI_VALOR_ACRESCIMO, 0),
                COALESCE(PEVI_VALOR_TOTAL, 0),
                COALESCE(PEVI_DESC_RATEADO, 0),
                COALESCE(PEVI_ACRESC_RATEADO, 0),
                COALESCE(PEVI_APLICA_DESCONTO, '')
            FROM TB_PEDIDO_VENDA_ITEM
            WHERE PEVI_EMPRESA = ?
              AND PEVI_PEDIDO_VENDA = ?
              AND COALESCE(PEVI_STATUS, 'A') <> 'C'
            ORDER BY PEVI_SEQUENCIA
        """, (empresa, pedido))

        itens_capa = []
        for row_capa in cur.fetchall():
            itens_capa.append({
                "sequencia": inteiro_seguro(row_capa[0], 0),
                "sub_total": row_capa[1],
                "valor_desconto": row_capa[2],
                "valor_acrescimo": row_capa[3],
                "valor_total": row_capa[4],
                "desc_rateado": row_capa[5],
                "acresc_rateado": row_capa[6],
                "aplica_desconto": row_capa[7]
            })

        itens_capa = recalcular_rateios_capa_pedido(
            itens_capa,
            tipo_desconto_capa,
            desconto_capa,
            tipo_acrescimo_capa,
            acrescimo_capa,
            percentual_maximo_desconto
        )

        for item_capa in itens_capa:
            cur.execute("""
                UPDATE TB_PEDIDO_VENDA_ITEM
                   SET PEVI_DESC_RATEADO = ?,
                       PEVI_ACRESC_RATEADO = ?,
                       PEVI_VALOR_TOTAL = ?
                 WHERE PEVI_EMPRESA = ?
                   AND PEVI_PEDIDO_VENDA = ?
                   AND PEVI_SEQUENCIA = ?
            """, (
                item_capa["desc_rateado"],
                item_capa["acresc_rateado"],
                item_capa["valor_total"],
                empresa,
                pedido,
                item_capa["sequencia"]
            ))

        # ------------------------------------------------------
        # 5) Recalcula cabeçalho do pedido somando itens ativos
        # ------------------------------------------------------
        cur.execute("""
            SELECT
                COALESCE(SUM(COALESCE(PEVI_SUB_TOTAL, 0)), 0),
                COALESCE(SUM(COALESCE(PEVI_VALOR_TOTAL, 0)), 0),
                COALESCE(SUM(
                    COALESCE(PEVI_VALOR_DESCONTO, 0)
                    + COALESCE(PEVI_DESC_RATEADO, 0)
                ), 0),
                COALESCE(SUM(
                    COALESCE(PEVI_VALOR_ACRESCIMO, 0)
                    + COALESCE(PEVI_ACRESC_RATEADO, 0)
                ), 0),
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
            soma_valor_acrescimo_itens,
            soma_valor_comissao,
            soma_volume,
            soma_comissao_supervisor
        ) = cur.fetchone()

        if (
            decimal_seguro(acrescimo_capa) > 0
            and texto_tipo_comercial(tipo_acrescimo_capa) in ("P", "V")
        ):
            valor_acrescimo_cabecalho = soma_valor_acrescimo_itens
        else:
            valor_acrescimo_cabecalho = valor_acrescimo_anterior

        cur.execute("""
            UPDATE TB_PEDIDO_VENDA
               SET PEV_SUB_TOTAL = ?,
                   PEV_VALOR_TOTAL = ?,
                   PEV_VALOR_DESCONTO = ?,
                   PEV_VALOR_ACRESCIMO = ?,
                   PEV_VALOR_COMISSAO = ?,
                   PEV_VOLUME = ?,
                   PEV_VALOR_COMISSAO_SUPERVISOR = ?
             WHERE PEV_EMPRESA = ?
               AND PEV_ID = ?
        """, (
            soma_sub_total,
            soma_valor_total,
            soma_valor_desconto,
            valor_acrescimo_cabecalho,
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

        cur.execute("""
            SELECT COUNT(*)
            FROM TB_PRODUTO
            WHERE PRD_EMPRESA = 1
              AND PRD_ID = ?
              AND COALESCE(PRD_STATUS, 'A') <> 'I'
        """, (produto_id,))

        if inteiro_seguro(cur.fetchone()[0], 0) == 0:
            return jsonify({
                "status": "erro",
                "mensagem": "Produto não encontrado ou inativo."
            }), 400

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
# ==============================================================
# REQUISIÇÕES DE TRANSFERÊNCIA - CONSULTAS SOMENTE DE LEITURA
# ==============================================================
def _formatar_data_transferencia(valor, com_hora=False):
    if valor is None:
        return ""

    try:
        formato = "%d/%m/%Y %H:%M" if com_hora else "%d/%m/%Y"
        return valor.strftime(formato)
    except:
        return str(valor)


def _requisicao_transferencia_json(row):
    (
        empresa_matriz,
        nome_matriz,
        requisicao,
        empresa_solicitante,
        nome_solicitante,
        emissao,
        lancamento,
        usuario,
        status,
        tipo,
        observacao,
        quantidade_itens,
        quantidade_total
    ) = row

    return {
        "empresa_matriz": int(empresa_matriz),
        "nome_matriz": (nome_matriz or "").strip(),
        "requisicao": int(requisicao),
        "empresa_solicitante": int(empresa_solicitante),
        "nome_solicitante": (nome_solicitante or "").strip(),
        "emissao": _formatar_data_transferencia(emissao),
        "lancamento": _formatar_data_transferencia(lancamento, True),
        "usuario": int(usuario or 0),
        "status": (status or "").strip(),
        "tipo": (tipo or "NR").strip(),
        "observacao": (observacao or "").strip(),
        "quantidade_itens": int(quantidade_itens or 0),
        "quantidade_total": float(quantidade_total or 0)
    }


QUANTIDADE_4_CASAS = Decimal("0.0001")
QUANTIDADE_ZERO = Decimal("0.0000")


def _quantidade_decimal(valor):
    if valor is None:
        return QUANTIDADE_ZERO

    return Decimal(str(valor)).quantize(
        QUANTIDADE_4_CASAS,
        rounding=ROUND_HALF_UP
    )


def _quantidade_json(valor):
    return float(_quantidade_decimal(valor))


def _situacao_atendimento_item(quantidade_solicitada, quantidade_separada):
    if quantidade_separada > quantidade_solicitada:
        return "EXCEDENTE"

    if quantidade_separada == quantidade_solicitada:
        return "TOTAL"

    if quantidade_separada > QUANTIDADE_ZERO:
        return "PARCIAL"

    return "NAO_ATENDIDO"


def _item_requisicao_transferencia_json(row):
    quantidade_solicitada = _quantidade_decimal(row[6])
    quantidade_separada = _quantidade_decimal(row[7])
    quantidade_faltante = quantidade_solicitada - quantidade_separada
    quantidade_excedente = quantidade_separada - quantidade_solicitada

    if quantidade_faltante < QUANTIDADE_ZERO:
        quantidade_faltante = QUANTIDADE_ZERO

    if quantidade_excedente < QUANTIDADE_ZERO:
        quantidade_excedente = QUANTIDADE_ZERO

    return {
        "empresa_matriz": int(row[0]),
        "requisicao": int(row[1]),
        "sequencia": int(row[2]),
        "produto": int(row[3]),
        "descricao": (row[4] or "").strip(),
        "unidade": (row[5] or "").strip(),
        "quantidade_solicitada": _quantidade_json(quantidade_solicitada),
        "quantidade_separada": _quantidade_json(quantidade_separada),
        "quantidade_restante": _quantidade_json(quantidade_faltante),
        "quantidade_faltante": _quantidade_json(quantidade_faltante),
        "quantidade_excedente": _quantidade_json(quantidade_excedente),
        "situacao_atendimento": _situacao_atendimento_item(
            quantidade_solicitada,
            quantidade_separada
        ),
        "quantidade_conferida": _quantidade_json(row[8]),
        "quantidade_recebida": _quantidade_json(row[9]),
        "status": (row[10] or "").strip(),
        "observacao": (row[11] or "").strip()
    }


def _consultar_item_separacao_transferencia(cur, empresa, requisicao, item):
    cur.execute("""
        SELECT
            I.TRQI_EMPRESA_MATRIZ,
            I.TRQI_REQUISICAO,
            I.TRQI_SEQUENCIA,
            I.TRQI_PRODUTO,
            I.TRQI_DESCRICAO,
            I.TRQI_UNIDADE,
            I.TRQI_QTDE_SOLICITADA,
            I.TRQI_QTDE_SEPARADA,
            I.TRQI_QTDE_CONFERIDA,
            I.TRQI_QTDE_RECEBIDA,
            I.TRQI_STATUS,
            I.TRQI_OBSERVACAO
        FROM TB_TRANSF_REQ R
        JOIN TB_TRANSF_REQ_SEPARACAO S
          ON S.TRQS_EMPRESA_MATRIZ = R.TRQ_EMPRESA_MATRIZ
         AND S.TRQS_REQUISICAO = R.TRQ_ID
         AND S.TRQS_STATUS = 'A'
        JOIN TB_TRANSF_REQ_ITEM I
          ON I.TRQI_EMPRESA_MATRIZ = R.TRQ_EMPRESA_MATRIZ
         AND I.TRQI_REQUISICAO = R.TRQ_ID
        WHERE R.TRQ_EMPRESA_MATRIZ = ?
          AND R.TRQ_ID = ?
          AND R.TRQ_STATUS = 'S'
          AND I.TRQI_SEQUENCIA = ?
          AND COALESCE(I.TRQI_STATUS, 'A') <> 'C'
          AND COALESCE(I.TRQI_SEPARAR, 'S') = 'S'
    """, (empresa, requisicao, item))

    item_row = cur.fetchone()
    if not item_row:
        return None

    cur.execute("""
        SELECT
            L.TRQL_EMPRESA_MATRIZ,
            L.TRQL_REQUISICAO,
            L.TRQL_SEQUENCIA,
            L.TRQL_ITEM_REQUISICAO,
            L.TRQL_PRODUTO,
            L.TRQL_CODIGO_LIDO,
            L.TRQL_TIPO_ETIQUETA,
            L.TRQL_ROLO_ID,
            L.TRQL_QUANTIDADE,
            L.TRQL_DT_INCLUSAO
        FROM TB_TRANSF_REQ_SEP_LEITURA L
        WHERE L.TRQL_EMPRESA_MATRIZ = ?
          AND L.TRQL_REQUISICAO = ?
          AND L.TRQL_ITEM_REQUISICAO = ?
          AND L.TRQL_STATUS = 'A'
        ORDER BY L.TRQL_SEQUENCIA
    """, (empresa, requisicao, item))

    leituras = []
    for row in cur.fetchall():
        leituras.append({
            "empresa_matriz": int(row[0]),
            "requisicao": int(row[1]),
            "sequencia": int(row[2]),
            "item_requisicao": int(row[3]),
            "produto": int(row[4]),
            "codigo_lido": (row[5] or "").strip(),
            "tipo_etiqueta": (row[6] or "").strip(),
            "rolo_id": int(row[7]) if row[7] is not None else None,
            "quantidade": float(row[8] or 0),
            "data_leitura": _formatar_data_transferencia(row[9], True)
        })

    return {
        "item": _item_requisicao_transferencia_json(item_row),
        "leituras": leituras
    }


# Exemplo: /transferencias/requisicoes?empresa=1
# Lista requisições L e requisições S ativas do operador informado.
@app.route("/transferencias/requisicoes", methods=["GET"])
def listar_requisicoes_transferencia():
    con = None

    try:
        empresa_param = request.args.get("empresa")
        if not empresa_param:
            return jsonify({
                "status": "erro",
                "mensagem": "Empresa matriz não informada."
            }), 400

        empresa = int(empresa_param)
        usuario = int(request.args.get("usuario") or 0)
        if empresa <= 0 or usuario < 0:
            raise ValueError

        con = get_connection()
        cur = con.cursor()
        if usuario > 0:
            filtro_status = """
                R.TRQ_STATUS = 'L'
                OR (
                    R.TRQ_STATUS = 'S'
                    AND EXISTS (
                        SELECT 1
                        FROM TB_TRANSF_REQ_SEPARACAO S
                        WHERE S.TRQS_EMPRESA_MATRIZ = R.TRQ_EMPRESA_MATRIZ
                          AND S.TRQS_REQUISICAO = R.TRQ_ID
                          AND S.TRQS_STATUS = 'A'
                          AND S.TRQS_USUARIO_INICIO = ?
                    )
                )
            """
            parametros = (empresa, usuario)
        else:
            filtro_status = "R.TRQ_STATUS = 'L'"
            parametros = (empresa,)

        cur.execute(f"""
            SELECT
                R.TRQ_EMPRESA_MATRIZ,
                COALESCE(EM.EMP_FANTASIA, EM.EMP_RAZAO_SOCIAL, ''),
                R.TRQ_ID,
                R.TRQ_EMPRESA_SOLICITANTE,
                COALESCE(ES.EMP_FANTASIA, ES.EMP_RAZAO_SOCIAL, ''),
                R.TRQ_DT_EMISSAO,
                R.TRQ_DT_LANCAMENTO,
                R.TRQ_USUARIO,
                R.TRQ_STATUS,
                COALESCE(R.TRQ_TIPO, 'NR'),
                R.TRQ_OBSERVACAO,
                R.TRQ_QTDE_ITENS,
                R.TRQ_QTDE_TOTAL
            FROM TB_TRANSF_REQ R
            LEFT JOIN TB_EMPRESA EM
              ON EM.EMP_ID = R.TRQ_EMPRESA_MATRIZ
            LEFT JOIN TB_EMPRESA ES
              ON ES.EMP_ID = R.TRQ_EMPRESA_SOLICITANTE
            WHERE R.TRQ_EMPRESA_MATRIZ = ?
              AND ({filtro_status})
            ORDER BY R.TRQ_DT_EMISSAO, R.TRQ_ID
        """, parametros)

        requisicoes = [
            _requisicao_transferencia_json(row)
            for row in cur.fetchall()
        ]

        return jsonify({
            "status": "ok",
            "empresa_matriz": empresa,
            "requisicoes": requisicoes
        })

    except ValueError:
        return jsonify({
            "status": "erro",
            "mensagem": "Empresa matriz inválida."
        }), 400
    except Exception as e:
        print("\n========== ERRO NA ROTA /transferencias/requisicoes ==========")
        print(e)
        traceback.print_exc()
        print("===============================================================\n")
        return jsonify({"status": "erro", "mensagem": str(e)}), 500
    finally:
        try:
            if con:
                con.close()
        except:
            pass


# Exemplo: /transferencias/requisicoes/detalhe?empresa=1&requisicao=11
# Consulta capa e itens ativos de requisição L ou separação S ativa.
@app.route("/transferencias/requisicoes/detalhe", methods=["GET"])
def detalhar_requisicao_transferencia():
    con = None

    try:
        empresa_param = request.args.get("empresa")
        requisicao_param = request.args.get("requisicao")

        if not empresa_param or not requisicao_param:
            return jsonify({
                "status": "erro",
                "mensagem": "Empresa matriz e requisição devem ser informadas."
            }), 400

        empresa = int(empresa_param)
        requisicao = int(requisicao_param)
        usuario = int(request.args.get("usuario") or 0)
        if empresa <= 0 or requisicao <= 0 or usuario < 0:
            raise ValueError

        con = get_connection()
        cur = con.cursor()
        filtro_usuario = ""
        parametros = [empresa, requisicao]
        if usuario > 0:
            filtro_usuario = "AND S.TRQS_USUARIO_INICIO = ?"
            parametros.append(usuario)

        cur.execute(f"""
            SELECT
                R.TRQ_EMPRESA_MATRIZ,
                COALESCE(EM.EMP_FANTASIA, EM.EMP_RAZAO_SOCIAL, ''),
                R.TRQ_ID,
                R.TRQ_EMPRESA_SOLICITANTE,
                COALESCE(ES.EMP_FANTASIA, ES.EMP_RAZAO_SOCIAL, ''),
                R.TRQ_DT_EMISSAO,
                R.TRQ_DT_LANCAMENTO,
                R.TRQ_USUARIO,
                R.TRQ_STATUS,
                COALESCE(R.TRQ_TIPO, 'NR'),
                R.TRQ_OBSERVACAO,
                R.TRQ_QTDE_ITENS,
                R.TRQ_QTDE_TOTAL
            FROM TB_TRANSF_REQ R
            LEFT JOIN TB_EMPRESA EM
              ON EM.EMP_ID = R.TRQ_EMPRESA_MATRIZ
            LEFT JOIN TB_EMPRESA ES
              ON ES.EMP_ID = R.TRQ_EMPRESA_SOLICITANTE
            WHERE R.TRQ_EMPRESA_MATRIZ = ?
              AND R.TRQ_ID = ?
              AND (
                    R.TRQ_STATUS = 'L'
                    OR (
                        R.TRQ_STATUS = 'S'
                        AND EXISTS (
                            SELECT 1
                            FROM TB_TRANSF_REQ_SEPARACAO S
                            WHERE S.TRQS_EMPRESA_MATRIZ = R.TRQ_EMPRESA_MATRIZ
                              AND S.TRQS_REQUISICAO = R.TRQ_ID
                              AND S.TRQS_STATUS = 'A'
                              {filtro_usuario}
                        )
                    )
                  )
        """, tuple(parametros))

        row = cur.fetchone()
        if not row:
            return jsonify({
                "status": "nao_encontrado",
                "mensagem": (
                    "Requisição não encontrada, não está liberada ou "
                    "não possui separação ativa para este operador."
                )
            }), 404

        capa = _requisicao_transferencia_json(row)

        cur.execute("""
            SELECT
                I.TRQI_EMPRESA_MATRIZ,
                I.TRQI_REQUISICAO,
                I.TRQI_SEQUENCIA,
                I.TRQI_PRODUTO,
                I.TRQI_DESCRICAO,
                I.TRQI_UNIDADE,
                I.TRQI_QTDE_SOLICITADA,
                I.TRQI_QTDE_SEPARADA,
                I.TRQI_QTDE_CONFERIDA,
                I.TRQI_QTDE_RECEBIDA,
                I.TRQI_STATUS,
                I.TRQI_OBSERVACAO
            FROM TB_TRANSF_REQ_ITEM I
            WHERE I.TRQI_EMPRESA_MATRIZ = ?
              AND I.TRQI_REQUISICAO = ?
              AND COALESCE(I.TRQI_STATUS, 'A') <> 'C'
              AND COALESCE(I.TRQI_SEPARAR, 'S') = 'S'
            ORDER BY I.TRQI_SEQUENCIA
        """, (empresa, requisicao))

        itens = [
            _item_requisicao_transferencia_json(item)
            for item in cur.fetchall()
        ]

        return jsonify({
            "status": "ok",
            "requisicao": capa,
            "itens": itens
        })

    except ValueError:
        return jsonify({
            "status": "erro",
            "mensagem": "Empresa matriz ou requisição inválida."
        }), 400
    except Exception as e:
        print("\n===== ERRO NA ROTA /transferencias/requisicoes/detalhe =====")
        print(e)
        traceback.print_exc()
        print("============================================================\n")
        return jsonify({"status": "erro", "mensagem": str(e)}), 500
    finally:
        try:
            if con:
                con.close()
        except:
            pass


@app.route("/transferencias/requisicoes/assumir", methods=["POST"])
def assumir_requisicao_transferencia():
    con = None

    try:
        dados = request.get_json(silent=True) or {}
        empresa = int(dados.get("empresa") or 0)
        requisicao = int(dados.get("requisicao") or 0)
        usuario = int(dados.get("usuario") or 0)

        if empresa <= 0 or requisicao <= 0 or usuario <= 0:
            return jsonify({
                "status": "erro",
                "retorno": "ERRO",
                "mensagem": (
                    "Empresa matriz, requisição e usuário devem ser "
                    "informados."
                )
            }), 400

        con = get_connection()
        con.begin()
        cur = con.cursor()
        cur.execute("""
            SELECT
                RETORNO,
                MENSAGEM,
                STATUS_REQUISICAO,
                USUARIO_SEPARACAO
            FROM SP_INICIA_SEP_TRANSF_REQ (?, ?, ?)
        """, (empresa, requisicao, usuario))

        row = cur.fetchone()
        if not row:
            con.rollback()
            return jsonify({
                "status": "erro",
                "retorno": "ERRO",
                "mensagem": "A procedure não retornou o resultado esperado."
            }), 500

        retorno = (row[0] or "").strip()
        mensagem = (row[1] or "").strip()
        status_requisicao = (row[2] or "").strip()
        usuario_separacao = int(row[3] or 0)

        if retorno.upper() != "OK":
            con.rollback()
            return jsonify({
                "status": "erro",
                "retorno": retorno or "ERRO",
                "mensagem": mensagem or "Não foi possível iniciar a separação.",
                "status_requisicao": status_requisicao,
                "usuario_separacao": usuario_separacao
            }), 409

        con.commit()
        return jsonify({
            "status": "ok",
            "retorno": retorno,
            "mensagem": mensagem,
            "status_requisicao": status_requisicao,
            "usuario_separacao": usuario_separacao
        })

    except (TypeError, ValueError):
        if con:
            try:
                con.rollback()
            except:
                pass
        return jsonify({
            "status": "erro",
            "retorno": "ERRO",
            "mensagem": "Parâmetros inválidos para iniciar a separação."
        }), 400
    except Exception as e:
        if con:
            try:
                con.rollback()
            except:
                pass
        print("\n===== ERRO NA ROTA /transferencias/requisicoes/assumir =====")
        print(e)
        traceback.print_exc()
        print("============================================================\n")
        return jsonify({
            "status": "erro",
            "retorno": "ERRO",
            "mensagem": str(e)
        }), 500
    finally:
        try:
            if con:
                con.close()
        except:
            pass


@app.route(
    "/transferencias/requisicoes/item-separacao",
    methods=["GET"]
)
def consultar_item_separacao_transferencia():
    con = None

    try:
        empresa = int(request.args.get("empresa") or 0)
        requisicao = int(request.args.get("requisicao") or 0)
        item = int(request.args.get("item") or 0)

        if empresa <= 0 or requisicao <= 0 or item <= 0:
            raise ValueError

        con = get_connection()
        cur = con.cursor()
        resultado = _consultar_item_separacao_transferencia(
            cur,
            empresa,
            requisicao,
            item
        )

        if resultado is None:
            return jsonify({
                "status": "nao_encontrado",
                "mensagem": (
                    "Item não encontrado, requisição não está em separação "
                    "ou o controle da separação não está ativo."
                )
            }), 404

        return jsonify({
            "status": "ok",
            **resultado
        })

    except (TypeError, ValueError):
        return jsonify({
            "status": "erro",
            "mensagem": "Empresa matriz, requisição ou item inválido."
        }), 400
    except Exception as e:
        print("\n===== ERRO NA CONSULTA DO ITEM DE SEPARAÇÃO =====")
        print(e)
        traceback.print_exc()
        print("=================================================\n")
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


@app.route(
    "/transferencias/requisicoes/item-separacao/salvar",
    methods=["POST"]
)
def salvar_item_separacao_transferencia():
    con = None

    try:
        dados = request.get_json(silent=True) or {}
        empresa = int(dados.get("empresa") or 0)
        requisicao = int(dados.get("requisicao") or 0)
        item = int(dados.get("item") or 0)
        usuario = int(dados.get("usuario") or 0)
        codigos_recebidos = dados.get("codigos_lidos")

        if empresa <= 0 or requisicao <= 0 or item <= 0 or usuario <= 0:
            return jsonify({
                "status": "erro",
                "retorno": "ERRO",
                "mensagem": (
                    "Empresa matriz, requisição, item e usuário devem ser "
                    "informados."
                )
            }), 400

        if not isinstance(codigos_recebidos, list):
            return jsonify({
                "status": "erro",
                "retorno": "ERRO",
                "mensagem": "A lista de códigos lidos deve ser informada."
            }), 400

        codigos = []
        for codigo in codigos_recebidos:
            if not isinstance(codigo, str) or not codigo.strip():
                return jsonify({
                    "status": "erro",
                    "retorno": "ERRO",
                    "mensagem": "A lista contém um código lido inválido."
                }), 400
            codigos.append(codigo.strip().upper())

        if not codigos:
            return jsonify({
                "status": "erro",
                "retorno": "ERRO",
                "mensagem": "Não há leituras pendentes para salvar."
            }), 400

        con = get_connection()
        con.begin()
        cur = con.cursor()

        resultado_atual = _consultar_item_separacao_transferencia(
            cur,
            empresa,
            requisicao,
            item
        )
        if resultado_atual is None:
            con.rollback()
            return jsonify({
                "status": "erro",
                "retorno": "ERRO",
                "mensagem": (
                    "Item nÃ£o encontrado, nÃ£o estÃ¡ habilitado para separaÃ§Ã£o "
                    "ou o controle da separaÃ§Ã£o nÃ£o estÃ¡ ativo."
                )
            }), 409

        leituras_salvas = []
        mensagem_sucesso = "Leituras gravadas com sucesso."

        for codigo in codigos:
            cur.execute("""
                SELECT
                    RETORNO,
                    MENSAGEM,
                    LEITURA_SEQUENCIA,
                    CODIGO_LIDO,
                    TIPO_ETIQUETA,
                    PRODUTO,
                    QUANTIDADE_LEITURA,
                    QTDE_SOLICITADA,
                    QTDE_SEPARADA_ITEM,
                    QTDE_RESTANTE_ITEM,
                    QTDE_SEPARADA_REQUISICAO
                FROM SP_SALVA_LEIT_TRANSF_ALIAS (?, ?, ?, ?, ?)
            """, (empresa, requisicao, item, codigo, usuario))

            row = cur.fetchone()
            if not row:
                con.rollback()
                return jsonify({
                    "status": "erro",
                    "retorno": "ERRO",
                    "mensagem": (
                        "A procedure não retornou o resultado esperado para "
                        f"o código {codigo}."
                    )
                }), 500

            retorno = (row[0] or "").strip()
            mensagem = (row[1] or "").strip()

            if retorno.upper() != "OK":
                con.rollback()
                return jsonify({
                    "status": "erro",
                    "retorno": retorno or "ERRO",
                    "mensagem": mensagem or "Leitura rejeitada.",
                    "codigo_lido": codigo
                }), 409

            mensagem_sucesso = mensagem or mensagem_sucesso
            leituras_salvas.append({
                "sequencia": int(row[2] or 0),
                "codigo_lido": (row[3] or codigo).strip(),
                "tipo_etiqueta": (row[4] or "").strip(),
                "produto": int(row[5] or 0),
                "quantidade": float(row[6] or 0),
                "quantidade_solicitada": float(row[7] or 0),
                "quantidade_separada": float(row[8] or 0),
                "quantidade_restante": float(row[9] or 0),
                "quantidade_separada_requisicao": float(row[10] or 0)
            })

        resultado = _consultar_item_separacao_transferencia(
            cur,
            empresa,
            requisicao,
            item
        )
        if resultado is None:
            con.rollback()
            return jsonify({
                "status": "erro",
                "retorno": "ERRO",
                "mensagem": (
                    "Não foi possível recarregar o item após as leituras."
                )
            }), 409

        con.commit()
        return jsonify({
            "status": "ok",
            "retorno": "OK",
            "mensagem": mensagem_sucesso,
            "leituras_salvas": leituras_salvas,
            **resultado
        })

    except (TypeError, ValueError):
        if con:
            try:
                con.rollback()
            except:
                pass
        return jsonify({
            "status": "erro",
            "retorno": "ERRO",
            "mensagem": "Parâmetros inválidos para salvar as leituras."
        }), 400
    except Exception as e:
        if con:
            try:
                con.rollback()
            except:
                pass
        print("\n===== ERRO AO SALVAR ITEM DA REQUISIÇÃO =====")
        print(e)
        traceback.print_exc()
        print("==============================================\n")
        return jsonify({
            "status": "erro",
            "retorno": "ERRO",
            "mensagem": str(e)
        }), 500
    finally:
        try:
            if con:
                con.close()
        except:
            pass


@app.route(
    "/transferencias/requisicoes/finalizar-separacao",
    methods=["POST"]
)
def finalizar_separacao_transferencia():
    con = None

    try:
        dados = request.get_json(silent=True) or {}
        empresa = int(dados.get("empresa") or 0)
        requisicao = int(dados.get("requisicao") or 0)
        usuario = int(dados.get("usuario") or 0)
        observacao = (dados.get("observacao") or "").strip()

        if empresa <= 0 or requisicao <= 0 or usuario <= 0:
            return jsonify({
                "status": "erro",
                "retorno": "ERRO",
                "mensagem": (
                    "Empresa matriz, requisição e usuário devem ser "
                    "informados."
                )
            }), 400

        con = get_connection()
        con.begin()
        cur = con.cursor()
        cur.execute("""
            SELECT
                RETORNO,
                MENSAGEM,
                STATUS_REQUISICAO,
                STATUS_SEPARACAO
            FROM SP_FINALIZA_SEP_TRANSF_REQ (?, ?, ?, ?)
        """, (empresa, requisicao, usuario, observacao))

        row = cur.fetchone()
        if not row:
            con.rollback()
            return jsonify({
                "status": "erro",
                "retorno": "ERRO",
                "mensagem": "A procedure não retornou o resultado esperado."
            }), 500

        retorno = (row[0] or "").strip()
        mensagem = (row[1] or "").strip()
        status_requisicao = (row[2] or "").strip()
        status_separacao = (row[3] or "").strip()

        if retorno.upper() != "OK":
            con.rollback()
            return jsonify({
                "status": "erro",
                "retorno": retorno or "ERRO",
                "mensagem": mensagem or "Não foi possível finalizar a separação.",
                "status_requisicao": status_requisicao,
                "status_separacao": status_separacao
            }), 409

        con.commit()
        return jsonify({
            "status": "ok",
            "retorno": retorno,
            "mensagem": mensagem,
            "status_requisicao": status_requisicao,
            "status_separacao": status_separacao
        })

    except (TypeError, ValueError):
        if con:
            try:
                con.rollback()
            except:
                pass
        return jsonify({
            "status": "erro",
            "retorno": "ERRO",
            "mensagem": "Parâmetros inválidos para finalizar a separação."
        }), 400
    except Exception as e:
        if con:
            try:
                con.rollback()
            except:
                pass
        print("\n===== ERRO AO FINALIZAR SEPARAÇÃO DA REQUISIÇÃO =====")
        print(e)
        traceback.print_exc()
        print("=====================================================\n")
        return jsonify({
            "status": "erro",
            "retorno": "ERRO",
            "mensagem": str(e)
        }), 500
    finally:
        try:
            if con:
                con.close()
        except:
            pass


# ==============================================================
# PEDIDOS DE COMPRA - CONSULTA SOMENTE DE LEITURA
# ==============================================================
def _pedido_compra_recebimento_json(row):
    return {
        "empresa": int(row[0]),
        "pedido_id": int(row[1]),
        "status": (row[2] or "").strip(),
        "data_emissao": _formatar_data_transferencia(row[3]),
        "fornecedor_id": int(row[4] or 0),
        "fornecedor_nome": (row[5] or "").strip(),
        "numero_nota": (row[6] or "").strip() or None,
        "total_itens": int(row[7] or 0),
        "itens_pendentes": int(row[8] or 0),
        "quantidade_total": _quantidade_json(row[9]),
        "quantidade_recebida": _quantidade_json(row[10]),
        "quantidade_pendente": _quantidade_json(row[11])
    }


# Exemplo: /pedidos-compra/recebimento?empresa=10
# Lista somente pedidos que ainda possuem item recebivel.
@app.route("/pedidos-compra/recebimento", methods=["GET"])
def listar_pedidos_compra_recebimento():
    con = None

    try:
        empresa_param = request.args.get("empresa")
        if not empresa_param:
            return jsonify({
                "status": "erro",
                "mensagem": "Empresa nao informada."
            }), 400

        empresa = int(empresa_param)
        if empresa <= 0:
            raise ValueError

        con = get_connection()
        cur = con.cursor()
        cur.execute("""
            SELECT
                P.PDC_EMPRESA AS EMPRESA,
                P.PDC_ID AS PEDIDO_ID,
                P.PDC_STATUS AS STATUS,
                P.PDC_DT_EMISSAO AS DATA_EMISSAO,
                P.PDC_FORNECEDOR AS FORNECEDOR_ID,
                COALESCE(F.FOR_RSOCIAL_NOME, '') AS FORNECEDOR_NOME,
                P.PDC_NUMERO_NOTA AS NUMERO_NOTA,
                COUNT(I.PDCI_SEQUENCIA) AS TOTAL_ITENS,
                SUM(
                    CASE
                        WHEN COALESCE(I.PDCI_STATUS, 'A') <> 'T'
                         AND COALESCE(I.PDCI_QUANTIDADE, 0)
                             - COALESCE(I.PDCI_QTDE_RECEBIDA, 0)
                             - COALESCE(I.PDCI_QTDE_NAO_ATENDIDA, 0) > 0
                        THEN 1 ELSE 0
                    END
                ) AS ITENS_PENDENTES,
                SUM(COALESCE(I.PDCI_QUANTIDADE, 0)) AS QUANTIDADE_TOTAL,
                SUM(COALESCE(I.PDCI_QTDE_RECEBIDA, 0)) AS QUANTIDADE_RECEBIDA,
                SUM(
                    CASE
                        WHEN COALESCE(I.PDCI_STATUS, 'A') <> 'T'
                         AND COALESCE(I.PDCI_QUANTIDADE, 0)
                             - COALESCE(I.PDCI_QTDE_RECEBIDA, 0)
                             - COALESCE(I.PDCI_QTDE_NAO_ATENDIDA, 0) > 0
                        THEN COALESCE(I.PDCI_QUANTIDADE, 0)
                             - COALESCE(I.PDCI_QTDE_RECEBIDA, 0)
                             - COALESCE(I.PDCI_QTDE_NAO_ATENDIDA, 0)
                        ELSE 0
                    END
                ) AS QUANTIDADE_PENDENTE
            FROM TB_PEDIDO_COMPRA P
            JOIN TB_PEDIDO_COMPRA_ITEM I
              ON I.PDCI_EMPRESA = P.PDC_EMPRESA
             AND I.PDCI_PEDIDO_COMPRA = P.PDC_ID
            LEFT JOIN TB_FORNECEDOR F
              ON F.FOR_EMPRESA = P.PDC_EMPRESA
             AND F.FOR_ID = P.PDC_FORNECEDOR
            WHERE P.PDC_EMPRESA = ?
              AND P.PDC_STATUS NOT IN ('R', 'C', 'T')
            GROUP BY
                P.PDC_EMPRESA,
                P.PDC_ID,
                P.PDC_STATUS,
                P.PDC_DT_EMISSAO,
                P.PDC_FORNECEDOR,
                F.FOR_RSOCIAL_NOME,
                P.PDC_NUMERO_NOTA
            HAVING SUM(
                CASE
                    WHEN COALESCE(I.PDCI_STATUS, 'A') <> 'T'
                     AND COALESCE(I.PDCI_QUANTIDADE, 0)
                         - COALESCE(I.PDCI_QTDE_RECEBIDA, 0)
                         - COALESCE(I.PDCI_QTDE_NAO_ATENDIDA, 0) > 0
                    THEN 1 ELSE 0
                END
            ) > 0
            ORDER BY P.PDC_DT_EMISSAO, P.PDC_ID
        """, (empresa,))

        pedidos = [
            _pedido_compra_recebimento_json(row)
            for row in cur.fetchall()
        ]

        return jsonify({
            "status": "ok",
            "empresa": empresa,
            "pedidos": pedidos
        })

    except (TypeError, ValueError):
        return jsonify({
            "status": "erro",
            "mensagem": "Empresa invalida."
        }), 400
    except Exception as e:
        print("\n===== ERRO NA ROTA /pedidos-compra/recebimento =====")
        print(e)
        traceback.print_exc()
        print("=====================================================\n")
        return jsonify({"status": "erro", "mensagem": str(e)}), 500
    finally:
        try:
            if con:
                con.close()
        except:
            pass


# Exemplo: /pedidos-compra/recebimento/detalhe?empresa=10&pedido_id=273
# Consulta a capa e todos os itens reais de um pedido de compra.
@app.route("/pedidos-compra/recebimento/detalhe", methods=["GET"])
def detalhar_pedido_compra_recebimento():
    con = None

    try:
        empresa_param = request.args.get("empresa")
        pedido_param = request.args.get("pedido_id")

        if not empresa_param or not pedido_param:
            return jsonify({
                "status": "erro",
                "mensagem": "Empresa e pedido_id devem ser informados."
            }), 400

        empresa = int(empresa_param)
        pedido_id = int(pedido_param)
        if empresa <= 0 or pedido_id <= 0:
            raise ValueError

        con = get_connection()
        cur = con.cursor()
        cur.execute("""
            SELECT
                P.PDC_EMPRESA,
                P.PDC_ID,
                P.PDC_STATUS,
                P.PDC_DT_EMISSAO,
                P.PDC_FORNECEDOR,
                COALESCE(F.FOR_RSOCIAL_NOME, ''),
                P.PDC_DT_RECEBIMENTO,
                P.PDC_VALOR_TOTAL,
                P.PDC_VALOR_RECEBIDO,
                P.PDC_NUMERO_NOTA
            FROM TB_PEDIDO_COMPRA P
            LEFT JOIN TB_FORNECEDOR F
              ON F.FOR_EMPRESA = P.PDC_EMPRESA
             AND F.FOR_ID = P.PDC_FORNECEDOR
            WHERE P.PDC_EMPRESA = ?
              AND P.PDC_ID = ?
        """, (empresa, pedido_id))

        capa = cur.fetchone()
        if not capa:
            return jsonify({
                "status": "nao_encontrado",
                "mensagem": "Pedido de Compra nao encontrado."
            }), 404

        cur.execute("""
            SELECT
                I.PDCI_SEQUENCIA,
                I.PDCI_PRODUTO,
                I.PDCI_DESCRICAO,
                I.PDCI_QUANTIDADE,
                I.PDCI_QTDE_RECEBIDA,
                I.PDCI_QTDE_NAO_ATENDIDA,
                COALESCE(I.PDCI_QUANTIDADE, 0)
                    - COALESCE(I.PDCI_QTDE_RECEBIDA, 0)
                    - COALESCE(I.PDCI_QTDE_NAO_ATENDIDA, 0),
                I.PDCI_STATUS
            FROM TB_PEDIDO_COMPRA_ITEM I
            WHERE I.PDCI_EMPRESA = ?
              AND I.PDCI_PEDIDO_COMPRA = ?
            ORDER BY I.PDCI_SEQUENCIA
        """, (empresa, pedido_id))

        itens = []
        for item in cur.fetchall():
            itens.append({
                "sequencia": int(item[0] or 0),
                "produto": int(item[1] or 0),
                "descricao": (item[2] or "").strip(),
                "quantidade": _quantidade_json(item[3]),
                "quantidade_recebida": _quantidade_json(item[4]),
                "quantidade_nao_atendida": _quantidade_json(item[5]),
                "saldo": _quantidade_json(item[6]),
                "status": (item[7] or "").strip()
            })

        pedido = {
            "empresa": int(capa[0]),
            "pedido_id": int(capa[1]),
            "status": (capa[2] or "").strip(),
            "data_emissao": (
                _formatar_data_transferencia(capa[3]) if capa[3] else None
            ),
            "fornecedor_id": int(capa[4] or 0),
            "fornecedor_nome": (capa[5] or "").strip(),
            "data_recebimento": (
                _formatar_data_transferencia(capa[6]) if capa[6] else None
            ),
            "valor_total": float(capa[7] or 0),
            "valor_recebido": float(capa[8] or 0),
            "numero_nota": (capa[9] or "").strip() or None,
            "itens": itens
        }

        return jsonify({"status": "ok", "pedido": pedido})

    except (TypeError, ValueError):
        return jsonify({
            "status": "erro",
            "mensagem": "Empresa ou pedido_id invalido."
        }), 400
    except Exception as e:
        print("\n===== ERRO NA ROTA /pedidos-compra/recebimento/detalhe =====")
        print(e)
        traceback.print_exc()
        print("==============================================================\n")
        return jsonify({"status": "erro", "mensagem": str(e)}), 500
    finally:
        try:
            if con:
                con.close()
        except:
            pass


def _payload_recebimento_compra(empresa, pedido_id, usuario, excedente, leituras):
    itens = []
    for leitura in leituras:
        if not isinstance(leitura, dict):
            raise ValueError('Leitura inválida.')
        item = inteiro_seguro(leitura.get('item'), 0)
        produto = inteiro_seguro(leitura.get('produto'), 0)
        tipo = (leitura.get('tipo') or '').strip().upper()
        codigo = (leitura.get('codigo') or '').strip()
        quantidade = decimal_seguro(leitura.get('quantidade'))
        if item <= 0 or produto <= 0 or tipo not in ('R', 'C') or not codigo or quantidade <= 0:
            raise ValueError('Cada leitura exige item, produto, tipo R/C, código e quantidade positiva.')
        itens.append({
            'item': item,
            'produto': produto,
            'tipo': tipo,
            'codigo': codigo,
            'quantidade': format(quantidade, '.4f'),
        })
    if not itens:
        raise ValueError('Informe ao menos uma etiqueta aceita.')
    itens.sort(key=lambda item: (item['item'], item['produto'], item['tipo'], item['codigo'], item['quantidade']))
    return json.dumps({
        'versao': 1,
        'empresa': empresa,
        'pedido_id': pedido_id,
        'usuario': usuario,
        'excedente_confirmado': bool(excedente),
        'leituras': itens,
    }, ensure_ascii=True, separators=(',', ':'))


@app.route('/pedidos-compra/recebimento/confirmar', methods=['POST'])
def confirmar_recebimento_pedido_compra():
    """Coordena procedures de Compras; não contém regra de recebimento em Python."""
    con = None
    try:
        dados = request.get_json() or {}
        empresa = inteiro_seguro(dados.get('empresa'), 0)
        pedido_id = inteiro_seguro(dados.get('pedido_id'), 0)
        usuario = inteiro_seguro(dados.get('usuario'), 0)
        operacao_guid = (dados.get('operacao_guid') or '').strip().lower()
        excedente = bool(dados.get('excedente_confirmado'))
        leituras = dados.get('leituras')
        if empresa <= 0 or pedido_id <= 0 or usuario != 1:
            return jsonify({'status': 'erro', 'mensagem': 'Empresa, pedido e usuário operacional 1 são obrigatórios.'}), 400
        if not re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', operacao_guid):
            return jsonify({'status': 'erro', 'mensagem': 'operacao_guid inválido.'}), 400
        if not isinstance(leituras, list):
            return jsonify({'status': 'erro', 'mensagem': 'Leituras inválidas.'}), 400
        canonico = _payload_recebimento_compra(empresa, pedido_id, usuario, excedente, leituras)
        payload_hash = hashlib.sha256(canonico.encode('utf-8')).hexdigest().upper()

        con = get_connection()
        cur = con.cursor()
        cur.execute('select retorno,mensagem,recebimento,pedido_filho,replay from SP_BC_PC_REC_OPERACAO_INICIAR(?,?,?,?,?,?,?)',
                    (empresa, pedido_id, usuario, operacao_guid, payload_hash, 'S' if excedente else 'N', 'S'))
        inicio = cur.fetchone()
        if not inicio:
            raise Exception('Procedure de início não retornou resultado.')
        retorno, mensagem, recebimento, pedido_filho, replay = inicio
        if (retorno or '').strip().upper() == 'REPLAY':
            con.rollback()
            return jsonify({'status': 'ok', 'mensagem': mensagem or 'Recebimento já confirmado.', 'recebimento': int(recebimento or 0), 'pedido_filho': int(pedido_filho or 0), 'replay': True})
        if (retorno or '').strip().upper() != 'OK':
            con.rollback()
            return jsonify({'status': 'erro', 'mensagem': mensagem or 'Operação recusada.'}), 409

        for sequencia, leitura in enumerate(json.loads(canonico)['leituras'], start=1):
            cur.execute('select retorno,mensagem from SP_BC_PC_REC_OPERACAO_LEITURA(?,?,?,?,?,?,?)',
                        (operacao_guid, sequencia, leitura['item'], leitura['produto'], leitura['tipo'], leitura['codigo'], Decimal(leitura['quantidade'])))
            linha = cur.fetchone()
            if not linha or (linha[0] or '').strip().upper() != 'OK':
                raise Exception((linha[1] if linha else '') or 'Leitura recusada pela procedure.')

        cur.execute('select retorno,mensagem,recebimento,pedido_filho from SP_BC_PC_REC_OPERACAO_CONFIRMAR(?)', (operacao_guid,))
        fim = cur.fetchone()
        if not fim or (fim[0] or '').strip().upper() != 'OK':
            raise Exception((fim[1] if fim else '') or 'Confirmação recusada pela procedure.')
        con.commit()
        return jsonify({'status': 'ok', 'mensagem': fim[1] or 'Recebimento confirmado.', 'recebimento': int(fim[2] or 0), 'pedido_filho': int(fim[3] or 0), 'replay': False})
    except ValueError as erro:
        return jsonify({'status': 'erro', 'mensagem': str(erro)}), 400
    except Exception as erro:
        try:
            if con:
                con.rollback()
        except Exception:
            pass
        print('\n===== ERRO NA ROTA /pedidos-compra/recebimento/confirmar =====')
        print(erro)
        traceback.print_exc()
        print('=================================================================\n')
        return jsonify({'status': 'erro', 'mensagem': str(erro)}), 409
    finally:
        try:
            if con:
                con.close()
        except Exception:
            pass


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)
