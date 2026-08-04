from flask import Flask, request, jsonify
import fdb
import os
from PIL import Image
import json
import socket

app = Flask(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LOGO_ZEBRA_PATH = os.path.join(BASE_DIR, "logo_cliente.png")
CONFIG_IMPRESSAO_PATH = os.path.join(BASE_DIR, "config_impressao.json")

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
            "mensagem": f"Lote {lote} enviado com {len(ids_impressos)} etiqueta(s).",
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
