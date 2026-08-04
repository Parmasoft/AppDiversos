from flask import Flask, request, jsonify, send_from_directory, abort
from decimal import Decimal, ROUND_HALF_UP
from datetime import datetime, timedelta
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.utils import simpleSplit

import os
import fdb
import socket
import tempfile
import win32print
import win32ui
import win32con
import win32api
import subprocess

app = Flask(__name__)

# ==================================================
# CONFIG IMPRESSÃO
# ==================================================
########### Tratando a I9
NOME_IMPRESSORA = "Elgin i9(USB)"                         # quando a I9 está instalada na máquina onde está a API
#NOME_IMPRESSORA = win32print.GetDefaultPrinter()         # quando a I9 está em rede (fora da máquina onde roda a API)

########### Tratando a impressora A4
NOME_IMPRESSORA_A4 = "HP LaserJet 400 M401dne (A1CD31)"   # minha máquina do escritório 
#NOME_IMPRESSORA_A4 = r"\\estacao005\PROMISSORIA GRANDE"  # máquina do Fabri Tecidos

AUTO_IMPRIMIR_PROMISSORIA_PDF = True

SUMATRA_PDF_EXE = r"E:\Jorginho\Pedido_Pgto\API_PDV\SumatraPDF.exe"                                              
#SUMATRA_PDF_EXE = r"C:\Parmasoft\Pedido_App\API\SumatraPDF.exe"     # máquina do Fabri Tecidos 

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

STATUS_MAP = {
    "D": "DIGITADO",
    "A": "ABERTO",
    "F": "FECHADO",
    "C": "CANCELADO",
    "S": "SINCRONIZADO",
    "I": "IMPORTADO",
}

PASTA_PDFS_PROMISSORIAS = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "pdfs_promissorias"
)

TAMANHO_PROMISSORIA = A4

# ==================================================
# FUNÇÕES AUXILIARES GERAIS
# ==================================================
def valor_decimal(valor):
    if valor is None:
        return Decimal("0")
    return Decimal(str(valor))
    
CENTAVOS = Decimal("0.01")

def valor_monetario(valor):
    if valor is None:
        return Decimal("0.00")
    return Decimal(str(valor)).quantize(CENTAVOS, rounding=ROUND_HALF_UP)    


def valor_float(valor):
    if valor is None:
        return 0.0
    return float(valor)


def valor_int_ou_float(valor):
    if valor is None:
        return 0

    try:
        dec = Decimal(str(valor))
        if dec == dec.to_integral_value():
            return int(dec)
        return float(dec)
    except Exception:
        return float(valor)


def formatar_datahora(valor):
    if not valor:
        return ""

    try:
        return valor.strftime("%d/%m/%Y %H:%M")
    except Exception:
        return str(valor)


def status_descricao(status):
    status = (status or "").strip().upper()
    return STATUS_MAP.get(status, status)


def montar_foto_url(foto):
    if not foto:
        return None

    base_url = request.host_url.rstrip("/")
    return f"{base_url}/pdv/imagens/{foto}"


def normalizar_unidade(unidade):
    texto = (unidade or "").strip()
    return texto if texto else "UN"


def fracionado_por_unidade(cur, empresa, unidade_venda):
    _ = empresa

    unidade_venda = (unidade_venda or "").strip().upper()
    if not unidade_venda:
        return "N"

    cur.execute(
        """
        SELECT COALESCE(UN_FRACIONADO, 'N')
        FROM TB_UNIDADE_MEDIDA
        WHERE UN_SIGLA = ?
        """,
        (unidade_venda,),
    )

    row = cur.fetchone()

    if not row:
        return "N"

    return "S" if (row[0] or "").strip().upper() == "S" else "N"


def texto_limpo(valor):
    return (valor or "").strip()
    
def montar_observacao_tablet(ecf_id):
    return f"VENDA EFETUADA NO TABLET ECF {ecf_id}"[:100]


def resolver_indicador_desconto(desconto):
    if not isinstance(desconto, dict):
        return None

    valor = valor_monetario(desconto.get("valor") or 0)
    if valor <= 0:
        return None

    indicador = (
        desconto.get("indicador")
        or desconto.get("tipo")
        or desconto.get("modo")
        or ""
    ).strip().upper()

    percentual = desconto.get("percentual")

    if indicador in ("%", "P", "PERCENTUAL", "PORCENTAGEM"):
        return "%"

    if indicador in ("$", "V", "VALOR", "GERAL"):
        return "$"

    try:
        percentual_dec = Decimal(str(percentual or 0))
        if percentual_dec > 0:
            return "%"
    except Exception:
        pass

    return "$"    
    
def calcular_total_com_desconto_payload(subtotal_venda, desconto):
    subtotal_venda = valor_monetario(subtotal_venda)

    if not isinstance(desconto, dict):
        desconto = {}

    valor_desconto = valor_monetario(desconto.get("valor") or 0)

    total_final_payload = desconto.get("total_final")

    if total_final_payload not in (None, ""):
        total_final = valor_monetario(total_final_payload)

        if total_final < 0:
            raise Exception("Total final com desconto inválido")

        if total_final > subtotal_venda:
            raise Exception("Total final com desconto maior que o subtotal da venda")

        valor_desconto = valor_monetario(subtotal_venda - total_final)
    else:
        if valor_desconto < 0:
            raise Exception("Valor de desconto inválido")

        if valor_desconto > subtotal_venda:
            raise Exception("O desconto não pode ser maior que o subtotal da venda")

        total_final = valor_monetario(subtotal_venda - valor_desconto)

    if total_final <= 0:
        raise Exception("O total final da venda ficou inválido")

    indicador_desconto = resolver_indicador_desconto(desconto)

    return subtotal_venda, valor_desconto, indicador_desconto, total_final    


def buscar_dados_empresa_impressao(cur, empresa):    
    
    cur.execute(
        """
        SELECT
            COALESCE(NULLIF(TRIM(EMP_RAZAO_SOCIAL), ''), 'EMPRESA'),
            COALESCE(NULLIF(TRIM(EMP_FANTASIA), ''), NULLIF(TRIM(EMP_RAZAO_SOCIAL), ''), 'EMPRESA'),
            COALESCE(TRIM(EMP_ENDERECO), ''),
            COALESCE(TRIM(EMP_NUMERO), ''),
            COALESCE(TRIM(EMP_BAIRRO), ''),
            COALESCE(TRIM(EMP_CEP), ''),
            COALESCE(TRIM(EMP_TELEFONE), ''),
            COALESCE(TRIM(EMP_CELULAR), '')
        FROM TB_EMPRESA
        WHERE EMP_ID = ?
        """,
        (empresa,),
    )

    row = cur.fetchone()

    if not row:
        raise Exception(f"Empresa {empresa} não encontrada")

    telefone = texto_limpo(row[6]) or texto_limpo(row[7])

    return {
        "razao_social": texto_limpo(row[0]) or "EMPRESA",
        "nome": texto_limpo(row[1]) or texto_limpo(row[0]) or "EMPRESA",
        "endereco": texto_limpo(row[2]),
        "numero": texto_limpo(row[3]),
        "bairro": texto_limpo(row[4]),
        "cep": texto_limpo(row[5]),
        "telefone": telefone,
    }

def montar_linhas_empresa_impressao(dados_empresa):
    linhas = [dados_empresa["nome"]]

    linha_endereco = ""
    if dados_empresa["endereco"] and dados_empresa["numero"]:
        linha_endereco = f"{dados_empresa['endereco']}, {dados_empresa['numero']}"
    elif dados_empresa["endereco"]:
        linha_endereco = dados_empresa["endereco"]
    elif dados_empresa["numero"]:
        linha_endereco = dados_empresa["numero"]

    if linha_endereco:
        linhas.append(linha_endereco)

    linha_bairro_cep = ""
    if dados_empresa["bairro"] and dados_empresa["cep"]:
        linha_bairro_cep = f"{dados_empresa['bairro']} - CEP {dados_empresa['cep']}"
    elif dados_empresa["bairro"]:
        linha_bairro_cep = dados_empresa["bairro"]
    elif dados_empresa["cep"]:
        linha_bairro_cep = f"CEP {dados_empresa['cep']}"

    if linha_bairro_cep:
        linhas.append(linha_bairro_cep)

    if dados_empresa["telefone"]:
        linhas.append(dados_empresa["telefone"])

    return linhas


def buscar_descricao_vendedor(cur, empresa, vendedor_id):
    try:
        vendedor_id = int(vendedor_id or 0)
    except Exception:
        vendedor_id = 0

    if vendedor_id <= 0:
        return "NAO INFORMADO"

    cur.execute(
        """
        SELECT
            VDR_ID,
            COALESCE(
                NULLIF(TRIM(VDR_FANTASIA_APELIDO), ''),
                NULLIF(TRIM(VDR_RSOCIAL_NOME), ''),
                ''
            )
        FROM TB_VENDEDOR
        WHERE VDR_EMPRESA = ?
          AND VDR_ID = ?
          AND COALESCE(VDR_STATUS, 'A') = 'A'
        """,
        (empresa, vendedor_id),
    )

    row = cur.fetchone()

    if not row:
        return f"{vendedor_id} - NAO LOCALIZADO"

    nome = texto_limpo(row[1])

    if nome:
        return f"{row[0]} - {nome}"

    return str(row[0])


# ==================================================
# FUNÇÕES AUXILIARES IMPRESSÃO
# ==================================================
def imprimir_ticket_cozinha(comanda, itens_cozinha):
    if not itens_cozinha:
        return

    comanda_fmt = str(comanda).zfill(2)

    linhas = []

    linhas.append("")
    linhas.append(
        f"{ALIGN_CENTER}{TXT_DUPLO}{BOLD_ON} <<< COMANDA:{BOLD_OFF} {comanda_fmt} >>>{TXT_NORMAL}"
    )
    linhas.append(f"{ALIGN_LEFT}")
    linhas.append("-" * LARGURA_TRACEJADO)

    agora = datetime.now()
    data_fmt = agora.strftime("%d/%m/%y")
    hora_fmt = agora.strftime("%H:%M")

    parte_esquerda = f"{BOLD_ON}DATA:{BOLD_OFF} {data_fmt}"
    parte_direita = f"{hora_fmt} hs "

    largura_dupla = LARGURA_LINHA // 2
    espacos = largura_dupla - len(f"DATA: {data_fmt}") - len(f"{hora_fmt} hs")
    if espacos < 1:
        espacos = 1

    linhas.append(
        f"{TXT_DUPLO_LARGURA}{parte_esquerda}{' ' * espacos}{parte_direita}{TXT_NORMAL}"
    )

    linhas.append("=" * LARGURA_TRACEJADO)
    linhas.append("")

    for item in itens_cozinha:
        qtd_float = float(item["quantidade"])
        qtd = int(qtd_float) if qtd_float.is_integer() else qtd_float
        qtd_fmt = str(qtd).zfill(2)

        linhas.append(
            f"{TXT_DUPLO_LARGURA}{BOLD_ON}{qtd_fmt} X  {item['descricao']}{BOLD_OFF}{TXT_NORMAL}"
        )
        linhas.append("")
        linhas.append("-" * LARGURA_TRACEJADO)
        linhas.append("")

    texto = "\n".join(linhas)
    texto += AVANCO_8_LINHAS
    texto += CORTE_TOTAL

    hPrinter = win32print.OpenPrinter(NOME_IMPRESSORA)
    try:
        win32print.StartDocPrinter(hPrinter, 1, ("Pedido Cozinha", None, "RAW"))
        win32print.StartPagePrinter(hPrinter)
        win32print.WritePrinter(hPrinter, texto.encode("cp860", errors="ignore"))
        win32print.EndPagePrinter(hPrinter)
        win32print.EndDocPrinter(hPrinter)
    finally:
        win32print.ClosePrinter(hPrinter)


def moeda_br(valor):
    return (
        f"{valor_monetario(valor):,.2f}"
        .replace(",", "X")
        .replace(".", ",")
        .replace("X", ".")
    )


def formatar_qtde_impressao(valor):
    dec = Decimal(str(valor or 0))

    if dec == dec.to_integral_value():
        return str(int(dec))

    return f"{dec.quantize(Decimal('0.001'))}".replace(".", ",")


def quebrar_texto(texto, largura):
    texto = " ".join((texto or "").split())

    if not texto:
        return [""]

    palavras = texto.split(" ")
    linhas = []
    atual = ""

    for palavra in palavras:
        if not atual:
            atual = palavra
        elif len(atual) + 1 + len(palavra) <= largura:
            atual += " " + palavra
        else:
            linhas.append(atual)
            atual = palavra

    if atual:
        linhas.append(atual)

    return linhas


def linha_esq_dir(texto_esquerda, texto_direita, largura=LARGURA_LINHA):
    texto_esquerda = str(texto_esquerda or "").strip()
    texto_direita = str(texto_direita or "").strip()

    total = len(texto_esquerda) + len(texto_direita)

    if total <= largura:
        return texto_esquerda + (" " * (largura - total)) + texto_direita

    return texto_esquerda + "\n" + texto_direita.rjust(largura)
    
def linha_esq_dir(texto_esquerda, texto_direita, largura=LARGURA_LINHA):
    texto_esquerda = str(texto_esquerda or "").strip()
    texto_direita = str(texto_direita or "").strip()

    total = len(texto_esquerda) + len(texto_direita)

    if total <= largura:
        return texto_esquerda + (" " * (largura - total)) + texto_direita

    return texto_esquerda + "\n" + texto_direita.rjust(largura)  

def enviar_texto_para_impressora(texto, nome_doc="Comprovante Venda"):
    hPrinter = win32print.OpenPrinter(NOME_IMPRESSORA)
    try:
        win32print.StartDocPrinter(hPrinter, 1, (nome_doc, None, "RAW"))
        win32print.StartPagePrinter(hPrinter)
        win32print.WritePrinter(hPrinter, texto.encode("cp860", errors="ignore"))
        win32print.EndPagePrinter(hPrinter)
        win32print.EndDocPrinter(hPrinter)
    finally:
        win32print.ClosePrinter(hPrinter)    

def buscar_promissorias_orcamento(cur, empresa, orc_id):
    cur.execute(
        """
        select
            r.rec_id,
            r.rec_empresa,
            r.rec_status,
            r.rec_cliente,
            r.rec_dt_vencimento,
            r.rec_origem,
            r.rec_id_origem,
            r.rec_documento,
            (
                coalesce(r.rec_valor, 0)
                - coalesce(r.rec_valor_desc_cartao, 0)
                - coalesce(r.rec_valor_desconto, 0)
                + coalesce(r.rec_valor_acrescimo, 0)
            ) as valor_documento,
            c.cli_rsocial_nome,
            c.cli_fantasia_apelido,
            c.cli_cnpj_cpf,
            c.cli_endereco,
            c.cli_numero,
            c.cli_bairro,
            c.cli_cep,
            c.cli_telefone,
            c.cli_celular,
            cid.cid_nome,
            est.est_sigla,
            o.orc_vendedor,
            v.vdr_fantasia_apelido,
            v.vdr_rsocial_nome
        from tb_recebimento r
        left outer join tb_cliente c
            on (r.rec_empresa = c.cli_empresa)
           and (r.rec_cliente = c.cli_id)
        left outer join tb_cidade cid
            on (c.cli_cidade = cid.cid_id)
        left outer join tb_estado est
            on (cid.cid_estado = est.est_id)
        left outer join tb_orcamento o
            on (r.rec_empresa = o.orc_empresa)
           and (r.rec_id_origem = o.orc_id)
           and (r.rec_origem = 'ORCAMENTO')
        left outer join tb_vendedor v
            on (o.orc_vendedor = v.vdr_id)
           and (o.orc_empresa = v.vdr_empresa)
        where
              r.rec_empresa = ?
          and r.rec_origem = 'ORCAMENTO'
          and r.rec_id_origem = ?
          and coalesce(r.rec_sistema, 'N') = 'N'
          and (r.rec_status = 'AB' or r.rec_status = 'PB')
        order by r.rec_id
        """,
        (empresa, orc_id),
    )

    dados = []

    for row in cur.fetchall():
        nome_cliente = texto_limpo(row[10]) or texto_limpo(row[9]) or "CLIENTE NÃO INFORMADO"
        vendedor_nome = texto_limpo(row[21]) or texto_limpo(row[22])
        vendedor_desc = f"{row[20]} - {vendedor_nome}" if row[20] and vendedor_nome else (
            str(row[20]) if row[20] else ""
        )

        dados.append(
            {
                "rec_id": row[0],
                "empresa": row[1],
                "status": texto_limpo(row[2]),
                "cliente_id": row[3],
                "vencimento": row[4],
                "origem": texto_limpo(row[5]),
                "id_origem": row[6],
                "documento": texto_limpo(row[7]),
                "valor_documento": valor_monetario(row[8]),
                "cliente_nome": nome_cliente,
                "cliente_documento": texto_limpo(row[11]),
                "endereco": texto_limpo(row[12]),
                "numero": texto_limpo(row[13]),
                "bairro": texto_limpo(row[14]),
                "cep": texto_limpo(row[15]),
                "telefone": texto_limpo(row[16]),
                "celular": texto_limpo(row[17]),
                "cidade": texto_limpo(row[18]),
                "uf": texto_limpo(row[19]),
                "vendedor": vendedor_desc,
            }
        )

    return dados


def montar_texto_promissoria(dados_empresa, promissoria):
    data_emissao = datetime.now().strftime("%d/%m/%Y")
    vencimento = (
        promissoria["vencimento"].strftime("%d/%m/%Y")
        if promissoria["vencimento"]
        else ""
    )

    nome_empresa = dados_empresa["nome"] or "EMPRESA"
    endereco_empresa = dados_empresa["endereco"] or ""
    numero_empresa = dados_empresa["numero"] or ""
    bairro_empresa = dados_empresa["bairro"] or ""
    cep_empresa = dados_empresa["cep"] or ""
    telefone_empresa = dados_empresa["telefone"] or ""

    endereco_cliente = promissoria["endereco"] or ""
    numero_cliente = promissoria["numero"] or ""
    bairro_cliente = promissoria["bairro"] or ""
    cep_cliente = promissoria["cep"] or ""
    cidade_cliente = promissoria["cidade"] or ""
    uf_cliente = promissoria["uf"] or ""
    telefone_cliente = promissoria["telefone"] or ""
    celular_cliente = promissoria["celular"] or ""

    linhas = [
        f"{nome_empresa}",
        f"{endereco_empresa}, {numero_empresa}".strip(", "),
        f"{bairro_empresa} - CEP {cep_empresa}".strip(" -"),
        f"Fone: {telefone_empresa}" if telefone_empresa else "",
        "",
        f"Documento: {promissoria['documento']}    Venda: {promissoria['id_origem']}    Emissão: {data_emissao}",
        "",
        f"No dia {vencimento} pagarei por esta única via de NOTA PROMISSÓRIA a",
        f"{nome_empresa}",
        f"a quantia de R$ {moeda_br(promissoria['valor_documento'])}",
        "",
        f"Sacado: {promissoria['cliente_id']} - {promissoria['cliente_nome']}",
        f"Cnpj/Cpf: {promissoria['cliente_documento']}",
        f"Endereço: {endereco_cliente}, {numero_cliente}".strip(", "),
        f"Bairro: {bairro_cliente}",
        f"Cep: {cep_cliente}",
        f"Cidade: {cidade_cliente}    UF: {uf_cliente}",
        f"Telefone: {telefone_cliente}    Cel: {celular_cliente}",
        f"Vendedor: {promissoria['vendedor']}",
        "",
        "",
        "________________________________________",
        "Assinatura do Sacado",
    ]

    return [linha for linha in linhas if linha is not None]
    
def texto_extenso_simples(valor):
    valor = valor_monetario(valor)

    unidades = [
        "", "UM", "DOIS", "TRÊS", "QUATRO", "CINCO", "SEIS", "SETE", "OITO", "NOVE",
        "DEZ", "ONZE", "DOZE", "TREZE", "QUATORZE", "QUINZE", "DEZESSEIS",
        "DEZESSETE", "DEZOITO", "DEZENOVE"
    ]
    dezenas = [
        "", "", "VINTE", "TRINTA", "QUARENTA", "CINQUENTA",
        "SESSENTA", "SETENTA", "OITENTA", "NOVENTA"
    ]
    centenas = [
        "", "CENTO", "DUZENTOS", "TREZENTOS", "QUATROCENTOS",
        "QUINHENTOS", "SEISCENTOS", "SETECENTOS", "OITOCENTOS", "NOVECENTOS"
    ]

    def ate_999(n):
        n = int(n)
        if n == 0:
            return ""
        if n == 100:
            return "CEM"
        if n < 20:
            return unidades[n]
        if n < 100:
            d = n // 10
            r = n % 10
            return dezenas[d] if r == 0 else f"{dezenas[d]} E {unidades[r]}"
        c = n // 100
        r = n % 100
        return centenas[c] if r == 0 else f"{centenas[c]} E {ate_999(r)}"

    inteiro = int(valor)
    centavos = int((valor - Decimal(inteiro)).quantize(Decimal("0.01")) * 100)

    partes = []

    if inteiro == 0:
        partes.append("ZERO REAL")
    elif inteiro == 1:
        partes.append("UM REAL")
    elif inteiro < 1000:
        partes.append(f"{ate_999(inteiro)} REAIS")
    else:
        milhares = inteiro // 1000
        resto = inteiro % 1000

        if milhares == 1:
            txt_milhar = "MIL"
        else:
            txt_milhar = f"{ate_999(milhares)} MIL"

        if resto == 0:
            partes.append(f"{txt_milhar} REAIS")
        elif resto < 100:
            partes.append(f"{txt_milhar} E {ate_999(resto)} REAIS")
        else:
            partes.append(f"{txt_milhar}, {ate_999(resto)} REAIS")

    if centavos > 0:
        txt_cent = "UM CENTAVO" if centavos == 1 else f"{ate_999(centavos)} CENTAVOS"
        partes.append(txt_cent)

    return " E ".join(partes)


def desenhar_texto(hdc, x, y, texto, fonte):
    hdc.SelectObject(fonte)
    hdc.TextOut(int(x), int(y), str(texto or ""))


def desenhar_texto_centralizado(hdc, y, texto, fonte, largura_pagina):
    hdc.SelectObject(fonte)
    texto = str(texto or "")
    largura_texto = hdc.GetTextExtent(texto)[0]
    x = max(0, int((largura_pagina - largura_texto) / 2))
    hdc.TextOut(x, int(y), texto)


def desenhar_linha(hdc, x1, y1, x2, y2):
    hdc.MoveTo((int(x1), int(y1)))
    hdc.LineTo((int(x2), int(y2)))   
    
def _pdf_y_top(altura_pagina, topo_mm):
    return altura_pagina - (topo_mm * mm)


def _pdf_centralizado_multilinha(pdf, texto, fonte, tamanho, centro_x, y_inicial, largura_max_mm, passo_mm=5):
    linhas = simpleSplit(str(texto or ""), fonte, tamanho, largura_max_mm * mm)
    y = y_inicial

    pdf.setFont(fonte, tamanho)
    for linha in linhas:
        pdf.drawCentredString(centro_x, y, linha)
        y -= passo_mm * mm

    return y
    
def _pdf_esquerda_multilinha(pdf, texto, fonte, tamanho, x, y_inicial, largura_max_mm, passo_mm=4):
    linhas = simpleSplit(str(texto or ""), fonte, tamanho, largura_max_mm * mm)
    y = y_inicial

    pdf.setFont(fonte, tamanho)
    for linha in linhas:
        pdf.drawString(x, y, linha)
        y -= passo_mm * mm

    return y    

def gerar_promissorias_pdf(cur, empresa, orc_id):
    dados_empresa = buscar_dados_empresa_impressao(cur, empresa)
    promissorias = buscar_promissorias_orcamento(cur, empresa, orc_id)

    if not promissorias:
        return {
            "total": 0,
            "arquivo": None,
            "caminho": None,
            "url": None,
        }

    os.makedirs(PASTA_PDFS_PROMISSORIAS, exist_ok=True)

    nome_arquivo = f"promissorias_orc_{orc_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
    caminho_pdf = os.path.join(PASTA_PDFS_PROMISSORIAS, nome_arquivo)

    pdf = canvas.Canvas(caminho_pdf, pagesize=TAMANHO_PROMISSORIA)
    largura, altura = TAMANHO_PROMISSORIA

    # metade superior do A4
    topo_base_mm = 8
    largura_util_mm = 190
    centro_x = largura / 2

    def y(mm_topo):
        return altura - ((topo_base_mm + mm_topo) * mm)

    for indice, promissoria in enumerate(promissorias):
        if indice > 0:
            pdf.showPage()

        vencimento = (
            promissoria["vencimento"].strftime("%d/%m/%Y")
            if promissoria["vencimento"]
            else ""
        )
        emissao = datetime.now().strftime("%d/%m/%Y")
        valor_fmt = f"R$ {moeda_br(promissoria['valor_documento'])}"
        valor_extenso = texto_extenso_simples(promissoria["valor_documento"])

        nome_empresa = (dados_empresa["nome"] or "EMPRESA").upper()
        razao_empresa = (dados_empresa["razao_social"] or "EMPRESA").upper()

        endereco_empresa = dados_empresa["endereco"] or ""
        numero_empresa = dados_empresa["numero"] or ""
        bairro_empresa = dados_empresa["bairro"] or ""
        cep_empresa = dados_empresa["cep"] or ""
        telefone_empresa = dados_empresa["telefone"] or ""

        endereco_cliente = promissoria["endereco"] or ""
        numero_cliente = promissoria["numero"] or ""
        bairro_cliente = promissoria["bairro"] or ""
        cep_cliente = promissoria["cep"] or ""
        cidade_cliente = promissoria["cidade"] or ""
        uf_cliente = promissoria["uf"] or ""
        telefone_cliente = promissoria["telefone"] or ""
        celular_cliente = promissoria["celular"] or ""
        vendedor_cliente = promissoria["vendedor"] or ""

        telefone_exibir = telefone_cliente
        if celular_cliente:
            telefone_exibir = f"{telefone_cliente} / {celular_cliente}" if telefone_cliente else celular_cliente

        linha_endereco_empresa = f"{endereco_empresa}, {numero_empresa}".strip(", ")

        linha_bairro_cep_tel = ""
        if bairro_empresa and cep_empresa:
            linha_bairro_cep_tel = f"{bairro_empresa} - {cep_empresa}"
        elif bairro_empresa:
            linha_bairro_cep_tel = bairro_empresa
        elif cep_empresa:
            linha_bairro_cep_tel = cep_empresa

        if telefone_empresa:
            linha_bairro_cep_tel = f"{linha_bairro_cep_tel}  TELEFONE: {telefone_empresa}".strip()

        # =========================
        # CABEÇALHO
        # =========================
        pdf.setFont("Helvetica-Bold", 14)
        pdf.drawString(10 * mm, y(0), nome_empresa)

        pdf.setFont("Helvetica", 8)
        _pdf_esquerda_multilinha(
            pdf,
            linha_endereco_empresa,
            "Helvetica",
            8,
            10 * mm,
            y(6),
            95,
            passo_mm=3.5,
        )

        _pdf_esquerda_multilinha(
            pdf,
            linha_bairro_cep_tel,
            "Helvetica",
            8,
            10 * mm,
            y(12),
            95,
            passo_mm=3.5,
        )

        pdf.setFont("Helvetica-Bold", 15)
        pdf.drawRightString(200 * mm, y(0), vencimento)

        pdf.setFont("Helvetica-Bold", 15)
        pdf.drawRightString(200 * mm, y(8), valor_fmt)

        pdf.line(10 * mm, y(18), 200 * mm, y(18))

        # =========================
        # DOCUMENTO / VENDA / EMISSÃO
        # =========================
        pdf.setFont("Helvetica", 8)
        pdf.drawString(10 * mm, y(22), f"Documento: {promissoria['documento']}")
        pdf.drawCentredString(105 * mm, y(22), f"Venda: {promissoria['id_origem']}")
        pdf.drawRightString(200 * mm, y(22), f"Emissão: {emissao}")

        # =========================
        # TEXTO CENTRAL
        # =========================
        y_central = y(30)

        y_central = _pdf_centralizado_multilinha(
            pdf,
            f"No dia {vencimento} pagarei por esta única via de NOTA PROMISSÓRIA emitida por computador a",
            "Helvetica",
            9,
            centro_x,
            y_central,
            170,
            passo_mm=4,
        )

        y_central -= 2 * mm
        pdf.setFont("Helvetica-Bold", 10)
        for linha in simpleSplit(razao_empresa, "Helvetica-Bold", 10, 170 * mm):
            pdf.drawCentredString(centro_x, y_central, linha)
            y_central -= 4.5 * mm

        y_central -= 1.5 * mm
        pdf.setFont("Helvetica", 9)
        pdf.drawCentredString(centro_x, y_central, "ou a sua ordem, a quantia de")

        y_central -= 5.5 * mm
        _pdf_centralizado_multilinha(
            pdf,
            valor_extenso,
            "Helvetica-Bold",
            9.5,
            centro_x,
            y_central,
            170,
            passo_mm=4,
        )

        # =========================
        # BLOCO CLIENTE
        # =========================
        y_bloco = y(58)

        # esquerda
        y_esq = _pdf_esquerda_multilinha(
            pdf,
            f"Sacado: {promissoria['cliente_id']} - {promissoria['cliente_nome']}",
            "Helvetica-Bold",
            9,
            10 * mm,
            y_bloco,
            90,
            passo_mm=4,
        )

        y_esq -= 1 * mm
        y_esq = _pdf_esquerda_multilinha(
            pdf,
            f"Cnpj/Cpf: {promissoria['cliente_documento']}",
            "Helvetica",
            8.5,
            10 * mm,
            y_esq,
            90,
            passo_mm=4,
        )

        y_esq -= 1 * mm
        y_esq = _pdf_esquerda_multilinha(
            pdf,
            f"Endereço: {endereco_cliente}, {numero_cliente}".strip(", "),
            "Helvetica",
            8.5,
            10 * mm,
            y_esq,
            90,
            passo_mm=4,
        )

        y_esq -= 1 * mm
        y_esq = _pdf_esquerda_multilinha(
            pdf,
            f"Cidade: {cidade_cliente}",
            "Helvetica",
            8.5,
            10 * mm,
            y_esq,
            90,
            passo_mm=4,
        )

        y_esq -= 1 * mm
        _pdf_esquerda_multilinha(
            pdf,
            f"Telefone: {telefone_exibir}",
            "Helvetica",
            8.5,
            10 * mm,
            y_esq,
            90,
            passo_mm=4,
        )

        # direita
        y_dir = y_bloco
        x_dir = 120 * mm

        y_dir = _pdf_esquerda_multilinha(
            pdf,
            f"Bairro: {bairro_cliente}",
            "Helvetica",
            8.5,
            x_dir,
            y_dir,
            75,
            passo_mm=4,
        )

        y_dir -= 1 * mm
        y_dir = _pdf_esquerda_multilinha(
            pdf,
            f"Cep: {cep_cliente}",
            "Helvetica",
            8.5,
            x_dir,
            y_dir,
            75,
            passo_mm=4,
        )

        y_dir -= 1 * mm
        y_dir = _pdf_esquerda_multilinha(
            pdf,
            f"UF: {uf_cliente}",
            "Helvetica",
            8.5,
            x_dir,
            y_dir,
            75,
            passo_mm=4,
        )

        y_dir -= 1 * mm
        _pdf_esquerda_multilinha(
            pdf,
            f"Vendedor: {vendedor_cliente}",
            "Helvetica",
            8.5,
            x_dir,
            y_dir,
            75,
            passo_mm=4,
        )

        # =========================
        # LOCAL DE TRABALHO
        # =========================
        y_inf = y(92)

        pdf.setFont("Helvetica-Bold", 9)
        pdf.drawString(10 * mm, y_inf, "LOCAL DE TRABALHO:")

        pdf.setFont("Helvetica", 8.5)
        y_inf -= 7 * mm
        pdf.drawString(10 * mm, y_inf, "Empresa:")
        pdf.drawString(120 * mm, y_inf, "Complemento:")

        y_inf -= 6 * mm
        pdf.drawString(10 * mm, y_inf, "Endereço:")
        pdf.drawString(120 * mm, y_inf, "Número:")

        y_inf -= 6 * mm
        pdf.drawString(10 * mm, y_inf, "Bairro:")
        pdf.drawString(120 * mm, y_inf, "Telefone:")

        y_inf -= 6 * mm
        pdf.drawString(10 * mm, y_inf, "Cidade:")
        pdf.drawString(120 * mm, y_inf, "UF:")
        pdf.drawString(145 * mm, y_inf, "CEP:")

        # =========================
        # ASSINATURAS
        # =========================
        y_ass = y(128)

        pdf.line(25 * mm, y_ass, 75 * mm, y_ass)
        pdf.line(125 * mm, y_ass, 190 * mm, y_ass)

        pdf.setFont("Helvetica", 8)
        pdf.drawCentredString(50 * mm, y_ass - (4 * mm), "Data do Aceite")
        pdf.drawCentredString(157.5 * mm, y_ass - (4 * mm), "Assinatura do Sacado")

    pdf.save()

    url_pdf = f"{request.host_url.rstrip('/')}/pdv/promissorias/pdf/{nome_arquivo}"

    return {
        "total": len(promissorias),
        "arquivo": nome_arquivo,
        "caminho": caminho_pdf,
        "url": url_pdf,
    }

    

def imprimir_promissorias_a4(cur, empresa, orc_id, nome_impressora=None):
    impressora_a4 = (nome_impressora or NOME_IMPRESSORA_A4 or "").strip()
    if not impressora_a4:
        raise Exception("Impressora A4 não configurada")

    dados_empresa = buscar_dados_empresa_impressao(cur, empresa)
    promissorias = buscar_promissorias_orcamento(cur, empresa, orc_id)

    if not promissorias:
        return 0

    hdc = win32ui.CreateDC()
    hdc.CreatePrinterDC(impressora_a4)

    try:
        largura = hdc.GetDeviceCaps(win32con.HORZRES)
        altura = hdc.GetDeviceCaps(win32con.VERTRES)

        margem_esq = 90
        margem_dir = largura - 90

        fonte_empresa = win32ui.CreateFont({
            "name": "Arial",
            "height": -120,
            "weight": 700,
        })

        fonte_header = win32ui.CreateFont({
            "name": "Arial",
            "height": -72,
            "weight": 400,
        })

        fonte_header_negrito = win32ui.CreateFont({
            "name": "Arial",
            "height": -72,
            "weight": 700,
        })

        fonte_topo_destaque = win32ui.CreateFont({
            "name": "Arial",
            "height": -150,
            "weight": 700,
        })

        fonte_corpo = win32ui.CreateFont({
            "name": "Arial",
            "height": -86,
            "weight": 400,
        })

        fonte_corpo_negrito = win32ui.CreateFont({
            "name": "Arial",
            "height": -86,
            "weight": 700,
        })

        fonte_menor = win32ui.CreateFont({
            "name": "Arial",
            "height": -72,
            "weight": 400,
        })

        fonte_menor_negrito = win32ui.CreateFont({
            "name": "Arial",
            "height": -72,
            "weight": 700,
        })

        for promissoria in promissorias:
            vencimento = (
                promissoria["vencimento"].strftime("%d/%m/%Y")
                if promissoria["vencimento"]
                else ""
            )
            emissao = datetime.now().strftime("%d/%m/%Y")
            valor_fmt = f"R$ {moeda_br(promissoria['valor_documento'])}"
            valor_extenso = texto_extenso_simples(promissoria["valor_documento"])

            endereco_empresa = dados_empresa["endereco"] or ""
            numero_empresa = dados_empresa["numero"] or ""
            bairro_empresa = dados_empresa["bairro"] or ""
            cep_empresa = dados_empresa["cep"] or ""
            telefone_empresa = dados_empresa["telefone"] or ""

            endereco_cliente = promissoria["endereco"] or ""
            numero_cliente = promissoria["numero"] or ""
            bairro_cliente = promissoria["bairro"] or ""
            cep_cliente = promissoria["cep"] or ""
            cidade_cliente = promissoria["cidade"] or ""
            uf_cliente = promissoria["uf"] or ""
            telefone_cliente = promissoria["telefone"] or ""
            celular_cliente = promissoria["celular"] or ""

            hdc.StartDoc(f"Promissoria {promissoria['documento']}")
            hdc.StartPage()

            y = 220

            desenhar_texto(hdc, margem_esq, y, dados_empresa["nome"].upper(), fonte_empresa)
            y += 150
            desenhar_texto(
                hdc,
                margem_esq,
                y,
                f"{endereco_empresa}, {numero_empresa}".strip(", "),
                fonte_header,
            )
            y += 100
            
            linha_bairro_cep_tel = f"{bairro_empresa} - MG - {cep_empresa}".strip(" -")
            if telefone_empresa:
                linha_bairro_cep_tel += f"  TELEFONE: {telefone_empresa}"

            desenhar_texto(
                hdc,
                margem_esq,
                y,
                linha_bairro_cep_tel,
                fonte_header,
            )
            y += 100
            

            # Topo direito            
            desenhar_texto(hdc, largura - 980, 200, vencimento, fonte_topo_destaque)
            desenhar_texto(hdc, largura - 860, 410, valor_fmt, fonte_topo_destaque)

            # Linha divisória
            desenhar_linha(hdc, margem_esq, 560, margem_dir, 560)

            # Linha documento / venda / emissão
            desenhar_texto(hdc, margem_esq, 590, f"Documento: {promissoria['documento']}", fonte_corpo)
            desenhar_texto_centralizado(hdc, 590, f"Venda: {promissoria['id_origem']}", fonte_corpo, largura)
            desenhar_texto(hdc, largura - 920, 590, f"Emissão: {emissao}", fonte_corpo)
            
            # Texto central            
            desenhar_texto_centralizado(
                hdc,
                820,
                f"No dia {vencimento} pagarei por esta única via de NOTA PROMISSÓRIA emitida por computador a",
                fonte_corpo,
                largura,
            )
            desenhar_texto_centralizado(
                hdc,
                960,
                dados_empresa["razao_social"].upper(),
                fonte_corpo_negrito,
                largura,
            )
            desenhar_texto_centralizado(
                hdc,
                1080,
                "ou a sua ordem, a quantia de",
                fonte_corpo,
                largura,
            )
            desenhar_texto_centralizado(
                hdc,
                1200,
                valor_extenso,
                fonte_corpo_negrito,
                largura,
            )
            
            
            # Bloco cliente esquerdo
            y_bloco = 1500
            desenhar_texto(
                hdc,
                margem_esq,
                y_bloco,
                f"Sacado: {promissoria['cliente_id']} - {promissoria['cliente_nome']}",
                fonte_corpo_negrito,
            )
            y_bloco += 110
            desenhar_texto(hdc, margem_esq, y_bloco, f"Cnpj/Cpf: {promissoria['cliente_documento']}", fonte_corpo)
            y_bloco += 110
            desenhar_texto(hdc, margem_esq, y_bloco, f"Endereço: {endereco_cliente}, {numero_cliente}".strip(", "), fonte_corpo)
            y_bloco += 110
            desenhar_texto(hdc, margem_esq, y_bloco, f"Cidade: {cidade_cliente}", fonte_corpo)
            y_bloco += 110
            desenhar_texto(hdc, margem_esq, y_bloco, f"Telefone: {telefone_cliente}", fonte_corpo)

            # Bloco cliente direito
            x_dir = largura - 1650
            y_dir = 1600
            desenhar_texto(hdc, x_dir, y_dir, f"Bairro: {bairro_cliente}", fonte_corpo)
            y_dir += 110
            desenhar_texto(hdc, x_dir, y_dir, f"Cep: {cep_cliente}", fonte_corpo)
            y_dir += 110
            desenhar_texto(hdc, x_dir, y_dir, f"UF: {uf_cliente}", fonte_corpo)
            y_dir += 110
            desenhar_texto(hdc, x_dir, y_dir, f"Vendedor: {promissoria['vendedor']}", fonte_corpo)

            # Complementares inferiores estilo do modelo
            y_inf = 2350            
            desenhar_texto(hdc, margem_esq, y_inf, "LOCAL DE TRABALHO:", fonte_corpo_negrito)
            y_inf += 110
            
            
            x_comp = largura - 1650

            desenhar_texto(hdc, margem_esq, y_inf, "Empresa:", fonte_corpo)
            desenhar_texto(hdc, x_comp, y_inf, "Complemento", fonte_corpo)
            y_inf += 110
            desenhar_texto(hdc, margem_esq, y_inf, "Endereço", fonte_corpo)
            desenhar_texto(hdc, x_comp, y_inf, "Número:", fonte_corpo)
            y_inf += 110
            desenhar_texto(hdc, margem_esq, y_inf, "Bairro:", fonte_corpo)
            desenhar_texto(hdc, x_comp, y_inf, "Telefone:", fonte_corpo)
            y_inf += 110
            desenhar_texto(hdc, margem_esq, y_inf, "Cidade:", fonte_corpo)
            desenhar_texto(hdc, x_comp, y_inf, "UF:", fonte_corpo)
            desenhar_texto(hdc, x_comp + 420, y_inf, "CEP:", fonte_corpo)

            # Assinaturas
            y_ass = 3100
            desenhar_linha(hdc, margem_esq + 20, y_ass, margem_esq + 900, y_ass)
            desenhar_linha(hdc, largura - 1900, y_ass, largura - 250, y_ass)

            desenhar_texto(hdc, margem_esq + 240, y_ass + 20, "Data do Aceite", fonte_menor)
            desenhar_texto(hdc, largura - 1450, y_ass + 20, "Assinatura do Sacado", fonte_menor)

            hdc.EndPage()
            hdc.EndDoc()

    finally:
        hdc.DeleteDC()

    return len(promissorias)


def imprimir_comprovante_venda(cur, empresa, ecf_id, orc_id, vendedor_id=None):
    validar_ecf(cur, empresa, ecf_id)

    cur.execute(
        """
        SELECT
            O.ORC_ID,
            O.ORC_DT_LANCAMENTO,
            COALESCE(O.ORC_SUB_TOTAL, 0),
            COALESCE(O.ORC_DESCONTO_VALOR, 0),
            COALESCE(O.ORC_ACRESCIMO_VALOR, 0),
            COALESCE(O.ORC_VALOR_TOTAL, 0),
            COALESCE(O.ORC_VALOR_TROCO, 0),
            COALESCE(O.ORC_VALOR_PAGO, 0),
            COALESCE(O.ORC_VENDEDOR, 0),
            COALESCE(O.ORC_CLIENTE, 0),
            COALESCE(
                NULLIF(TRIM(C.CLI_FANTASIA_APELIDO), ''),
                NULLIF(TRIM(C.CLI_RSOCIAL_NOME), ''),
                ''
            )
        FROM TB_ORCAMENTO O
        LEFT JOIN TB_CLIENTE C
          ON C.CLI_EMPRESA = O.ORC_EMPRESA
         AND C.CLI_ID = O.ORC_CLIENTE
        WHERE O.ORC_EMPRESA = ?
          AND O.ORC_ID = ?
          AND O.ORC_ECF = ?
        """,
        (empresa, orc_id, ecf_id),
    )

    cab = cur.fetchone()

    if not cab:
        raise Exception("Venda não encontrada para este aparelho")

    numero_venda = cab[0]
    data_lancamento = cab[1]
    sub_total = Decimal(str(cab[2] or 0))
    desconto = Decimal(str(cab[3] or 0))
    acrescimo = Decimal(str(cab[4] or 0))
    valor_total = Decimal(str(cab[5] or 0))
    troco_capa = Decimal(str(cab[6] or 0))
    valor_pago_capa = Decimal(str(cab[7] or 0))
    vendedor_orc = cab[8] or 0
    cliente_id = int(cab[9] or 0)
    cliente_nome = texto_limpo(cab[10])

    vendedor_final = vendedor_orc if vendedor_orc not in (None, 0, "0", "") else vendedor_id

    dados_empresa = buscar_dados_empresa_impressao(cur, empresa)
    linhas_empresa = montar_linhas_empresa_impressao(dados_empresa)
    vendedor_desc = buscar_descricao_vendedor(cur, empresa, vendedor_final)

    cur.execute(
        """
        SELECT
            I.ORCI_SEQUENCIAL,
            I.ORCI_PRODUTO,
            P.PRD_DESCRICAO,
            COALESCE(I.ORCI_QUANTIDADE, 0),
            COALESCE(I.ORCI_UNIDADE, P.PRD_UN_VENDA, 'UN'),
            COALESCE(I.ORCI_VALOR_UNITARIO, 0),
            COALESCE(I.ORCI_VALOR_TOTAL, 0)
        FROM TB_ORCAMENTO_ITEM I
        JOIN TB_PRODUTO P
          ON P.PRD_EMPRESA = I.ORCI_EMPRESA
         AND P.PRD_ID = I.ORCI_PRODUTO
        WHERE I.ORCI_EMPRESA = ?
          AND I.ORCI_ORCAMENTO = ?
          AND COALESCE(I.ORCI_STATUS, 'A') <> 'C'
        ORDER BY I.ORCI_SEQUENCIAL
        """,
        (empresa, orc_id),
    )

    itens = cur.fetchall()

    if not itens:
        raise Exception("Venda sem itens para imprimir")

    cur.execute(
        """
        SELECT
            COALESCE(ORCP_PARCELA, 0),
            COALESCE(ORCP_DESCRICAO, ''),
            COALESCE(ORCP_VALOR, 0),
            COALESCE(ORCP_FORMA_PAGTO, 0),
            COALESCE(ORCP_ESPECIE_MOEDA, '')
        FROM TB_ORCAMENTO_PARCELA
        WHERE ORCP_EMPRESA = ?
          AND ORCP_ORCAMENTO = ?
        ORDER BY ORCP_PARCELA
        """,
        (empresa, orc_id),
    )

    pagamentos = cur.fetchall()

    eh_prazo = any(
        int(row[3] or 0) == 5 or (row[4] or "").strip().upper() == "PZ"
        for row in pagamentos
    )

    total_pago = sum((Decimal(str(row[2] or 0)) for row in pagamentos), Decimal("0.00"))

    if total_pago <= 0 and valor_pago_capa > 0:
        total_pago = valor_pago_capa

    troco = troco_capa if troco_capa > 0 else (total_pago - valor_total)

    if troco < 0:
        troco = Decimal("0.00")


    if data_lancamento:
        data_data = data_lancamento.strftime("%d/%m/%Y")
        data_hora = data_lancamento.strftime("%H:%M:%S")
    else:
        agora = datetime.now()
        data_data = agora.strftime("%d/%m/%Y")
        data_hora = agora.strftime("%H:%M:%S")

    linhas = []

    linhas.append("")
    linhas.append(
         f"{ALIGN_CENTER}{TXT_DUPLO_ALTURA}{BOLD_ON}{linhas_empresa[0].upper()}{BOLD_OFF}{TXT_NORMAL}"
    )

    for linha_empresa in linhas_empresa[1:]:
        if linha_empresa:
             linhas.append(linha_empresa.center(LARGURA_LINHA))

    linhas.append(f"{ALIGN_LEFT}")
    linhas.append("-" * LARGURA_TRACEJADO)    
  
    linhas.append(linha_esq_dir(f"DATA: {data_data}", f"HORA: {data_hora}"))
    linhas.append(linha_esq_dir(f"NUMERO: {numero_venda}", f"VENDEDOR: {vendedor_desc}"))
    linhas.append("-" * LARGURA_TRACEJADO)
    
    if eh_prazo:
        linhas.append(f"{BOLD_ON}CLIENTE:{BOLD_OFF}")
        if cliente_id > 0:
            cliente_cab = f"{str(cliente_id).zfill(4)} - {cliente_nome or 'NAO INFORMADO'}"
        else:
            cliente_cab = cliente_nome or "NAO INFORMADO"

        for linha_cliente in quebrar_texto(cliente_cab.upper(), LARGURA_LINHA):
            linhas.append(f"{BOLD_ON}{linha_cliente}{BOLD_OFF}")

        linhas.append("-" * LARGURA_TRACEJADO)        

    linhas.append("SEQ.  DESCRICAO DO PRODUTO")
    linhas.append("CODIGO     QTDE UN.  UNIT.(R$) VL.ITEM(R$)")
    linhas.append("-" * LARGURA_TRACEJADO)

    for row in itens:
        sequencial = row[0]
        codigo = row[1]
        descricao = row[2] or ""
        quantidade = formatar_qtde_impressao(row[3])
        unidade = (row[4] or "UN").strip()[:3]
        valor_unit = moeda_br(row[5])
        valor_item = moeda_br(row[6])

        linhas_descricao = quebrar_texto(descricao.upper(), 40)

        primeira = linhas_descricao[0] if linhas_descricao else ""
        linhas.append(f"{str(sequencial).zfill(3)}  {primeira}")

        for extra in linhas_descricao[1:]:
            linhas.append(f"     {extra}")

        linha_medidas = (
            f"{str(codigo):<8}"
            f"{quantidade:>8} "
            f"{unidade:<3}"
            f"{valor_unit:>11}"
            f"{valor_item:>13}"
        )
        linhas.append(linha_medidas)
        linhas.append("")

    linhas.append("-" * LARGURA_TRACEJADO)
    linhas.append(f"{'SUB-TOTAL (+):':<28}{moeda_br(sub_total):>20}")
    linhas.append(f"{'DESCONTO (-):':<28}{moeda_br(desconto):>20}")
    linhas.append(f"{'ACRESCIMO (+):':<28}{moeda_br(acrescimo):>20}")
    linhas.append(f"{BOLD_ON}{'VALOR TOTAL:':<28}{moeda_br(valor_total):>20}{BOLD_OFF}")
    linhas.append("-" * LARGURA_TRACEJADO)

    if pagamentos:        
        if eh_prazo:
            linhas.append("CONDICOES DE PAGAMENTO:")
            for row_pag in pagamentos:
                numero_parcela = int(row_pag[0] or 0)
                descricao_pag = (row_pag[1] or "PRAZO").strip().upper()
                valor_pag = Decimal(str(row_pag[2] or 0))

                linhas.append(
                    linha_esq_dir(
                        f"{numero_parcela:02d} - {descricao_pag[:22]}",
                        moeda_br(valor_pag),
                    )
                )

            linhas.append(f"{'TOTAL A PRAZO:':<28}{moeda_br(valor_total):>20}")
            linhas.append(f"{'TROCO:':<28}{moeda_br(Decimal('0.00')):>20}")
            
        else:
            for row_pag in pagamentos:
                descricao_pag = (row_pag[1] or "PAGAMENTO").strip().upper()[:28]
                valor_pag = Decimal(str(row_pag[2] or 0))
                linhas.append(f"{descricao_pag + ':':<28}{moeda_br(valor_pag):>20}")

            linhas.append(f"{'TROCO:':<28}{moeda_br(troco):>20}")
    else:
        valor_pagamento_fallback = total_pago if total_pago > 0 else valor_total
        linhas.append(f"{'PAGAMENTO:':<28}{moeda_br(valor_pagamento_fallback):>20}")
        linhas.append(f"{'TROCO:':<28}{moeda_br(troco):>20}")
    
    linhas.append("")
    linhas.append(f"{ALIGN_CENTER}OBRIGADO PELA PREFERENCIA")
    linhas.append("VOLTE SEMPRE!")
    linhas.append("*** SEM VALOR FISCAL ***")
    linhas.append(f"{ALIGN_LEFT}")

    texto = "\n".join(linhas)
    texto += AVANCO_8_LINHAS
    texto += CORTE_TOTAL

    enviar_texto_para_impressora(texto, "Comprovante Venda")


# ==================================================
# CONEXÃO FIREBIRD
# ==================================================
def get_connection():
    return fdb.connect(
        host="localhost",
        database=r"E:\Dados Clientes\Fabri Tecidos\DADOS.FDB",
        #database=r"C:\Parmasoft\Dados\DADOS.FDB",        
        user="SYSDBA",
        password="masterkey",
        charset="ISO8859_1",
    )


# ==================================================
# HELPERS TABLET
# ==================================================
def validar_ecf(cur, empresa, ecf_id):
    cur.execute(
        """
        SELECT
            ECF_ID,
            ECF_DESCRICAO,
            ECF_STATUS
        FROM TB_ECF
        WHERE ECF_EMPRESA = ?
          AND ECF_ID = ?
        """,
        (empresa, ecf_id),
    )

    row = cur.fetchone()

    if not row:
        raise Exception(f"Aparelho/ECF {ecf_id} não encontrado")

    status = (row[2] or "").strip().upper()

    if status != "A":
        raise Exception(f"Aparelho/ECF {ecf_id} está inativo")

    return {
        "id": row[0],
        "descricao": row[1] or "",
        "status": status,
    }


def gerar_novo_orcamento_id(cur, empresa):
    cur.execute(
        """
        SELECT SEQ_SEQUENCIAL
        FROM TB_SEQUENCIAL
        WHERE SEQ_EMPRESA = ?
          AND SEQ_TABELA = 'TB_ORCAMENTO'
        FOR UPDATE
        """,
        (empresa,),
    )

    row = cur.fetchone()

    if not row:
        raise Exception("Sequencial TB_ORCAMENTO não encontrado")

    novo_orc_id = row[0] + 1

    cur.execute(
        """
        UPDATE TB_SEQUENCIAL
        SET SEQ_SEQUENCIAL = ?
        WHERE SEQ_EMPRESA = ?
          AND SEQ_TABELA = 'TB_ORCAMENTO'
        """,
        (novo_orc_id, empresa),
    )

    return novo_orc_id


def gerar_novo_recebimento_id(cur, empresa):
    cur.execute(
        """
        SELECT SEQ_SEQUENCIAL
        FROM TB_SEQUENCIAL
        WHERE SEQ_EMPRESA = ?
          AND SEQ_TABELA = 'TB_RECEBIMENTO'
        FOR UPDATE
        """,
        (empresa,),
    )

    row = cur.fetchone()

    if not row:
        raise Exception("Sequencial TB_RECEBIMENTO não encontrado")

    novo_rec_id = row[0] + 1

    cur.execute(
        """
        UPDATE TB_SEQUENCIAL
        SET SEQ_SEQUENCIAL = ?
        WHERE SEQ_EMPRESA = ?
          AND SEQ_TABELA = 'TB_RECEBIMENTO'
        """,
        (novo_rec_id, empresa),
    )

    return novo_rec_id


def proximo_sequencial_item(cur, empresa, orc_id):
    cur.execute(
        """
        SELECT MAX(ORCI_SEQUENCIAL)
        FROM TB_ORCAMENTO_ITEM
        WHERE ORCI_EMPRESA = ?
          AND ORCI_ORCAMENTO = ?
        """,
        (empresa, orc_id),
    )

    row = cur.fetchone()
    atual = row[0] if row and row[0] else 0
    return atual + 1


def recalcular_totais_orcamento(cur, empresa, orc_id):
    cur.execute(
        """
        SELECT
            SUM(ORCI_QUANTIDADE),
            SUM(ORCI_VALOR_TOTAL)
        FROM TB_ORCAMENTO_ITEM
        WHERE ORCI_EMPRESA = ?
          AND ORCI_ORCAMENTO = ?
          AND COALESCE(ORCI_STATUS, 'A') <> 'C'
        """,
        (empresa, orc_id),
    )

    totais = cur.fetchone()

    total_itens = totais[0] or 0
    total_geral = totais[1] or 0

    cur.execute(
        """
        UPDATE TB_ORCAMENTO
        SET ORC_NR_ITENS = ?,
            ORC_SUB_TOTAL = ?,
            ORC_VALOR_TOTAL = ?
        WHERE ORC_EMPRESA = ?
          AND ORC_ID = ?
        """,
        (total_itens, total_geral, total_geral, empresa, orc_id),
    )

    return total_itens, total_geral


def validar_cliente(cur, empresa, cliente_id):
    cur.execute(
        """
        SELECT CLI_ID
        FROM TB_CLIENTE
        WHERE CLI_EMPRESA = ?
          AND CLI_ID = ?
        """,
        (empresa, cliente_id),
    )

    row = cur.fetchone()

    if not row:
        raise Exception(f"Cliente {cliente_id} não encontrado")

    return row[0]
    
def buscar_nome_cliente(cur, empresa, cliente_id):
    try:
        cliente_id = int(cliente_id or 0)
    except Exception:
        return ""

    if cliente_id <= 0:
        return ""

    cur.execute(
        """
        SELECT
            CLI_RSOCIAL_NOME,
            CLI_FANTASIA_APELIDO
        FROM TB_CLIENTE
        WHERE CLI_EMPRESA = ?
          AND CLI_ID = ?
        """,
        (empresa, cliente_id),
    )

    row = cur.fetchone()

    if not row:
        return ""

    nome = (row[0] or "").strip()
    fantasia = (row[1] or "").strip()

    return fantasia if fantasia else nome


def montar_descricao_grid_venda(cur, empresa, orc_id, cliente_id):
    nome_cliente = buscar_nome_cliente(cur, empresa, cliente_id)

    cur.execute(
        """
        SELECT
            COALESCE(ORCP_FORMA_PAGTO, 0),
            COALESCE(ORCP_ESPECIE_MOEDA, ''),
            COALESCE(ORCP_DESCRICAO, '')
        FROM TB_ORCAMENTO_PARCELA
        WHERE ORCP_EMPRESA = ?
          AND ORCP_ORCAMENTO = ?
        ORDER BY ORCP_PARCELA
        """,
        (empresa, orc_id),
    )

    parcelas = cur.fetchall()

    if parcelas:
        eh_prazo = any(
            int(row[0] or 0) == 5 or (row[1] or "").strip().upper() == "PZ"
            for row in parcelas
        )

        if eh_prazo:
            return nome_cliente if nome_cliente else "CONSUMIDOR FINAL"

        descricoes = []
        for row in parcelas:
            desc = (row[2] or "").strip().upper()
            if desc and desc not in descricoes:
                descricoes.append(desc)

        if descricoes:
            return " / ".join(descricoes)

    if nome_cliente:
        return nome_cliente

    return "CONSUMIDOR FINAL"
    


def formatar_data_iso(data):
    return data.strftime("%Y-%m-%d")


def formatar_data_br(data):
    return data.strftime("%d/%m/%Y")


def gerar_parcelas_prazo(valor_total, quantidade_parcelas, intervalo_dias, data_emissao, orc_id):
    valor_total = valor_monetario(valor_total)
    quantidade_parcelas = int(quantidade_parcelas)
    intervalo_dias = int(intervalo_dias)

    if quantidade_parcelas <= 0:
        raise Exception("Quantidade de parcelas inválida")

    if intervalo_dias <= 0:
        raise Exception("Intervalo de dias inválido")

    valor_base = valor_monetario(valor_total / Decimal(str(quantidade_parcelas)))
    parcelas = []
    acumulado = Decimal("0.00")
    documento_base = str(int(orc_id)).zfill(4)

    for numero_parcela in range(1, quantidade_parcelas + 1):
        if numero_parcela < quantidade_parcelas:
            valor_parcela = valor_base
        else:
            valor_parcela = valor_monetario(valor_total - acumulado)

        acumulado = valor_monetario(acumulado + valor_parcela)
        vencimento = data_emissao + timedelta(days=intervalo_dias * numero_parcela)

        parcelas.append(
            {
                "parcela": numero_parcela,
                "documento": f"{documento_base}-{numero_parcela}",
                "data_emissao": data_emissao,
                "vencimento": vencimento,
                "valor": valor_parcela,
            }
        )

    soma_parcelas = valor_monetario(
        sum((parcela["valor"] for parcela in parcelas), Decimal("0.00"))
    )

    if soma_parcelas != valor_total:
        raise Exception(
            f"Falha ao gerar parcelas. Soma {soma_parcelas} diferente do total {valor_total}"
        )

    return parcelas


def venda_ja_possui_financeiro(cur, empresa, orc_id):
    cur.execute(
        """
        SELECT FIRST 1 REC_ID
        FROM TB_RECEBIMENTO
        WHERE REC_EMPRESA = ?
          AND REC_ORIGEM = 'ORCAMENTO'
          AND REC_ID_ORIGEM = ?
        """,
        (empresa, orc_id),
    )

    row = cur.fetchone()
    return row[0] if row else None


def venda_ja_possui_orcamento_parcela(cur, empresa, orc_id):
    cur.execute(
        """
        SELECT COUNT(*)
        FROM TB_ORCAMENTO_PARCELA
        WHERE ORCP_EMPRESA = ?
          AND ORCP_ORCAMENTO = ?
        """,
        (empresa, orc_id),
    )

    row = cur.fetchone()
    return (row[0] or 0) > 0


def buscar_orcamento_tablet(cur, empresa, ecf_id, orc_id):
    cur.execute(
        """        
        SELECT
            ORC_ID,
            ORC_COMANDA,
            ORC_ECF,
            ORC_STATUS,
            ORC_NR_ITENS,
            ORC_VALOR_TOTAL,
            COALESCE(ORC_CLIENTE, 1),
            ORC_DT_LANCAMENTO            
        FROM TB_ORCAMENTO
        WHERE ORC_EMPRESA = ?
          AND ORC_ID = ?
          AND ORC_ECF = ?
        """,
        (empresa, orc_id, ecf_id),
    )

    row = cur.fetchone()

    if not row:
        return None

    return {
        "orc_id": row[0],
        "comanda": row[1],
        "ecf_id": row[2],
        "status": row[3],
        "itens": valor_int_ou_float(row[4]),
        "valor_total": valor_float(row[5]),
        "cliente_id": row[6],
        "data_hora": formatar_datahora(row[7]),
    }
    
def travar_orcamento_tablet(cur, empresa, ecf_id, orc_id):
    cur.execute(
        """
        SELECT
            ORC_ID,
            ORC_COMANDA,
            ORC_ECF,
            ORC_STATUS,
            ORC_NR_ITENS,
            ORC_VALOR_TOTAL,
            COALESCE(ORC_CLIENTE, 1),
            ORC_DT_LANCAMENTO
        FROM TB_ORCAMENTO
        WHERE ORC_EMPRESA = ?
          AND ORC_ID = ?
          AND ORC_ECF = ?
        FOR UPDATE
        """,
        (empresa, orc_id, ecf_id),
    )

    row = cur.fetchone()

    if not row:
        return None

    return {
        "orc_id": row[0],
        "comanda": row[1],
        "ecf_id": row[2],
        "status": row[3],
        "itens": valor_int_ou_float(row[4]),
        "valor_total": valor_float(row[5]),
        "cliente_id": row[6],
        "data_hora": formatar_datahora(row[7]),
    }


def travar_produto_para_movimento(cur, empresa, produto_id):
    cur.execute(
        """
        SELECT PRD_ID
        FROM TB_PRODUTO
        WHERE PRD_EMPRESA = ?
          AND PRD_ID = ?
        FOR UPDATE
        """,
        (empresa, produto_id),
    )

    row = cur.fetchone()

    if not row:
        raise Exception(f"Produto {produto_id} não encontrado para trava")

    return row[0]


def travar_item_orcamento(cur, empresa, orc_id, sequencial_item):
    cur.execute(
        """
        SELECT
            ORCI_SEQUENCIAL,
            ORCI_PRODUTO
        FROM TB_ORCAMENTO_ITEM
        WHERE ORCI_EMPRESA = ?
          AND ORCI_ORCAMENTO = ?
          AND ORCI_SEQUENCIAL = ?
        FOR UPDATE
        """,
        (empresa, orc_id, sequencial_item),
    )

    row = cur.fetchone()

    if not row:
        return None

    return {
        "sequencial": row[0],
        "produto_id": row[1],
    }    


def buscar_item_orcamento_tablet(cur, empresa, orc_id, sequencial_item):
    cur.execute(
        """
        SELECT
            I.ORCI_SEQUENCIAL,
            I.ORCI_PRODUTO,
            COALESCE(I.ORCI_QUANTIDADE, 0),
            COALESCE(I.ORCI_VALOR_UNITARIO, 0),
            COALESCE(I.ORCI_STATUS, 'A'),
            P.PRD_DESCRICAO,
            P.PRD_TIPO_PRODUTO,
            P.PRD_LOCAL_PREPARO,
            COALESCE(I.ORCI_UNIDADE, P.PRD_UN_VENDA)
        FROM TB_ORCAMENTO_ITEM I
        JOIN TB_PRODUTO P
          ON P.PRD_EMPRESA = I.ORCI_EMPRESA
         AND P.PRD_ID = I.ORCI_PRODUTO
        WHERE I.ORCI_EMPRESA = ?
          AND I.ORCI_ORCAMENTO = ?
          AND I.ORCI_SEQUENCIAL = ?
        """,
        (empresa, orc_id, sequencial_item),
    )

    row = cur.fetchone()

    if not row:
        return None

    unidade_venda = normalizar_unidade(row[8])

    return {
        "sequencial": row[0],
        "produto_id": row[1],
        "quantidade": Decimal(str(row[2] or 0)),
        "valor_unitario": Decimal(str(row[3] or 0)),
        "status": (row[4] or "").strip().upper(),
        "descricao": row[5] or "",
        "tipo_produto": row[6],
        "local_preparo": row[7],
        "unidade_venda": unidade_venda,
        "fracionado": fracionado_por_unidade(cur, empresa, unidade_venda),
    }
    
def proximo_sequencial_produto_movimento(cur, empresa, produto_id):
    cur.execute(
        """
        SELECT COALESCE(MAX(PRDM_SEQUENCIA), 0)
        FROM TB_PRODUTO_MOVIMENTO
        WHERE PRDM_EMPRESA = ?
          AND PRDM_PRODUTO = ?
        """,
        (empresa, produto_id),
    )

    row = cur.fetchone()
    atual = row[0] if row and row[0] else 0
    return int(atual) + 1


def registrar_movimento_pre_venda(
    cur,
    empresa,
    produto_id,
    quantidade,
    tipo,
    orc_id,
    sequencial_item,
    historico=None,
    grade=None,
    prod_cor=None,
    setor_mov=None,
    custo_un=None,
    custo=None,
):
    quantidade = valor_decimal(quantidade)

    if quantidade <= 0:
        return

    produto_id = int(produto_id)
    usuario = 1

    tipo = str(tipo or "").strip().upper()
    if tipo not in ("SAI", "ENT"):
        raise Exception(f"Tipo de movimento inválido: {tipo}")

    prdm_sequencia = proximo_sequencial_produto_movimento(cur, empresa, produto_id)

    grade = None if grade in (None, "", 0, "0") else int(grade)
    prod_cor = None if prod_cor in (None, "", 0, "0") else int(prod_cor)
    setor_mov = None if setor_mov in (None, "", 0, "0") else int(setor_mov)

    custo_un = valor_decimal(custo_un or 0)
    custo = valor_decimal(custo or 0)

    if historico is None:
        acao = "SAÍDA" if tipo == "SAI" else "ENTRADA"
        historico = f"{acao} PRÉ-VENDA TABLET ORCAMENTO {orc_id} ITEM {sequencial_item}"

    cur.execute(
        """
        INSERT INTO TB_PRODUTO_MOVIMENTO (
            PRDM_EMPRESA,
            PRDM_PRODUTO,
            PRDM_SEQUENCIA,
            PRDM_PROD_COR,
            PRDM_TIPO,
            PRDM_DT_MOVIMENTO,
            PRDM_QUANTIDADE,
            PRDM_ORIGEM_NUMERO,
            PRDM_ORIGEM_ITEM,
            PRDM_ORIGEM_MOVIMENTO,
            PRDM_DT_LANCAMENTO,
            PRDM_USUARIO,
            PRDM_HISTORICO,
            PRDM_GRADE,
            PRDM_CUSTO_UN,
            PRDM_CUSTO,
            PRDM_CUSTO_DIA,
            PRDM_CUSTO_DIA_TOTAL,
            PRDM_SETOR_MOV
        )
        VALUES (
            ?, ?, ?, ?, ?, CURRENT_DATE, ?, ?, ?, 'ORCAMENTO',
            CURRENT_TIMESTAMP, ?, ?, ?, ?, ?, 0, 0, ?
        )
        """,
        (
            empresa,
            produto_id,
            prdm_sequencia,
            prod_cor,
            tipo,
            quantidade,
            orc_id,
            sequencial_item,
            usuario,
            historico,
            grade,
            custo_un,
            custo,
            setor_mov,
        ),
    )    


# ==================================================
# PING
# ==================================================
@app.get("/ping")
def ping():
    return {"ok": True}


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
        except Exception:
            pass


# ==================================================
# IMAGENS
# ==================================================
############ Imagens na minha máquina do escritório
IMAGENS_PATH = r"C:\Parmatech\Imagens\Imagens"
############ Imagens na pasta padrão no cliente
#IMAGENS_PATH = r"C:\Parmasoft\Imagens"

@app.route("/pdv/imagens/<filename>")
def imagens(filename):
    if ".." in filename or "/" in filename or "\\" in filename:
        abort(400)

    file_path = os.path.join(IMAGENS_PATH, filename)

    if not os.path.exists(file_path):
        abort(404)

    return send_from_directory(IMAGENS_PATH, filename)
    
@app.route("/pdv/promissorias/pdf/<filename>")
def baixar_pdf_promissoria(filename):
    if ".." in filename or "/" in filename or "\\" in filename:
        abort(400)

    file_path = os.path.join(PASTA_PDFS_PROMISSORIAS, filename)

    if not os.path.exists(file_path):
        abort(404)

    return send_from_directory(PASTA_PDFS_PROMISSORIAS, filename)    

def imprimir_pdf_automatico(caminho_pdf, nome_impressora=None):
    impressora = (nome_impressora or NOME_IMPRESSORA_A4 or "").strip()

    if not caminho_pdf:
        raise Exception("Caminho do PDF não informado")

    if not os.path.exists(caminho_pdf):
        raise Exception(f"PDF não encontrado: {caminho_pdf}")

    if not impressora:
        raise Exception("Impressora A4 não configurada")

    if not os.path.exists(SUMATRA_PDF_EXE):
        raise Exception(f"SumatraPDF não encontrado em: {SUMATRA_PDF_EXE}")

    cmd = [
        SUMATRA_PDF_EXE,
        "-print-to",
        impressora,
        "-silent",
        caminho_pdf,
    ]

    resultado = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="cp1252",
        timeout=60
    )

    if resultado.returncode != 0:
        raise Exception(
            f"Falha ao imprimir PDF. "
            f"returncode={resultado.returncode} "
            f"stdout={resultado.stdout.strip()} "
            f"stderr={resultado.stderr.strip()}"
        )
    
    return True

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

        cur.execute(
            """
            SELECT
                PGRU_ID,
                PGRU_DESCRICAO,
                PGRU_FOTO
            FROM TB_PROD_GRUPO
            WHERE PGRU_EMPRESA = ?
              AND PGRU_MOSTRAR = 'S'
            ORDER BY PGRU_ORDEM
            """,
            (empresa,),
        )

        grupos = []

        for row in cur.fetchall():
            foto = row[2]

            grupos.append(
                {
                    "id": row[0],
                    "descricao": row[1],
                    "foto_url": montar_foto_url(foto) if foto else None,
                }
            )

        return {"ok": True, "total": len(grupos), "dados": grupos}

    except Exception as e:
        return {"ok": False, "erro": str(e)}, 500

    finally:
        try:
            if cur:
                cur.close()
            if con:
                con.close()
        except Exception:
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

        cur.execute(
            """
            SELECT
                P.PRD_ID,
                P.PRD_DESCRICAO,
                P.PRD_PRECO_VENDA,
                P.PRD_FOTO,
                P.PRD_UN_VENDA
            FROM TB_PRODUTO P
            JOIN TB_PROD_GRUPO G
              ON G.PGRU_EMPRESA = P.PRD_EMPRESA
             AND G.PGRU_ID = P.PRD_GRUPO
            WHERE P.PRD_EMPRESA = ?
              AND P.PRD_GRUPO = ?
              AND P.PRD_STATUS = 'A'
              AND G.PGRU_MOSTRAR = 'S'
            ORDER BY P.PRD_DESCRICAO
            """,
            (empresa, grupo),
        )

        produtos = []

        for row in cur.fetchall():
            foto = row[3]
            unidade_venda = normalizar_unidade(row[4])
            fracionado = fracionado_por_unidade(cur, empresa, unidade_venda)

            produtos.append(
                {
                    "id": row[0],
                    "descricao": row[1],
                    "preco": float(row[2]) if row[2] else 0,
                    "foto_url": montar_foto_url(foto) if foto else None,
                    "unidade_venda": unidade_venda,
                    "fracionado": fracionado,
                }
            )

        return {"ok": True, "total": len(produtos), "dados": produtos}

    except Exception as e:
        return {"ok": False, "erro": str(e)}, 500

    finally:
        try:
            if cur:
                cur.close()
            if con:
                con.close()
        except Exception:
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
        return {"ok": True, "total": 0, "dados": []}

    con = None
    cur = None

    try:
        con = get_connection()
        cur = con.cursor()

        termo_busca = "%" + termo.upper() + "%"

        cur.execute(
            """
            SELECT
                PRD_ID,
                PRD_DESCRICAO,
                PRD_PRECO_VENDA,
                PRD_FOTO,
                PRD_UN_VENDA
            FROM TB_PRODUTO
            WHERE PRD_EMPRESA = ?
              AND PRD_STATUS = 'A'
              AND UPPER(PRD_DESCRICAO) LIKE ?
            ORDER BY PRD_DESCRICAO
            """,
            (empresa, termo_busca),
        )

        produtos = []

        for row in cur.fetchall():
            foto = row[3]
            unidade_venda = normalizar_unidade(row[4])
            fracionado = fracionado_por_unidade(cur, empresa, unidade_venda)

            produtos.append(
                {
                    "id": row[0],
                    "descricao": row[1],
                    "preco": float(row[2]) if row[2] else 0,
                    "foto_url": montar_foto_url(foto) if foto else None,
                    "unidade_venda": unidade_venda,
                    "fracionado": fracionado,
                }
            )

        return {"ok": True, "total": len(produtos), "dados": produtos}

    except Exception as e:
        return {"ok": False, "erro": str(e)}, 500

    finally:
        try:
            if cur:
                cur.close()
            if con:
                con.close()
        except Exception:
            pass

# ==================================================
# BUSCAR CLIENTES (PESQUISA)
# ==================================================
@app.get("/pdv/clientes/buscar")
def buscar_clientes():
    empresa = request.args.get("empresa")
    termo = (request.args.get("q") or "").strip()

    if not empresa:
        return {"ok": False, "message": "Empresa não informada"}, 400

    if len(termo) < 3:
        return {"ok": True, "total": 0, "dados": []}

    con = None
    cur = None

    try:
        con = get_connection()
        cur = con.cursor()
        
        termo_upper = "%" + termo.upper() + "%"        
        termo_documento_limpo = "".join(ch for ch in termo if ch.isdigit())
        termo_codigo = termo + "%"

        sql = """
            SELECT FIRST 60
                CLI_ID,
                CLI_RSOCIAL_NOME,
                CLI_FANTASIA_APELIDO,
                CLI_CNPJ_CPF,
                CLI_TELEFONE
            FROM TB_CLIENTE
            WHERE CLI_EMPRESA = ?
              AND COALESCE(CLI_STATUS, 'A') = 'A'
              AND (
                    UPPER(COALESCE(CLI_RSOCIAL_NOME, '')) LIKE ?
                 OR UPPER(COALESCE(CLI_FANTASIA_APELIDO, '')) LIKE ?
                 OR CAST(CLI_ID AS VARCHAR(20)) LIKE ?
        """

        params = [empresa, termo_upper, termo_upper, termo_codigo]

        if termo_documento_limpo:
            sql += " OR COALESCE(CLI_CNPJ_CPF, '') LIKE ?"
            params.append(termo_documento_limpo + "%")

        sql += """
              )
            ORDER BY
                COALESCE(CLI_FANTASIA_APELIDO, CLI_RSOCIAL_NOME),
                CLI_ID
        """

        cur.execute(sql, tuple(params))

        clientes = []

        for row in cur.fetchall():
            cli_id = row[0]
            nome = (row[1] or "").strip()
            fantasia = (row[2] or "").strip()
            documento = (row[3] or "").strip()
            telefone = (row[4] or "").strip()

            descricao = fantasia if fantasia else nome

            clientes.append(
                {
                    "id": cli_id,
                    "nome": nome,
                    "fantasia": fantasia,
                    "descricao": descricao,
                    "documento": documento,
                    "telefone": telefone,
                }
            )

        return {"ok": True, "total": len(clientes), "dados": clientes}

    except Exception as e:
        return {"ok": False, "erro": str(e)}, 500

    finally:
        try:
            if cur:
                cur.close()
            if con:
                con.close()
        except Exception:
            pass


# ==================================================
# LISTAR VENDEDORES
# ==================================================
@app.get("/pdv/vendedores")
def listar_vendedores():
    empresa = request.args.get("empresa")

    if not empresa:
        return {"ok": False, "message": "Empresa não informada"}, 400

    con = None
    cur = None

    try:
        con = get_connection()
        cur = con.cursor()

        cur.execute(
            """
            SELECT
                VDR_ID,
                COALESCE(
                    NULLIF(TRIM(VDR_FANTASIA_APELIDO), ''),
                    NULLIF(TRIM(VDR_RSOCIAL_NOME), ''),
                    ''
                )
            FROM TB_VENDEDOR
            WHERE VDR_EMPRESA = ?
              AND COALESCE(VDR_STATUS, 'A') = 'A'
            ORDER BY 2, 1
            """,
            (empresa,),
        )

        vendedores = []

        for row in cur.fetchall():
            nome = texto_limpo(row[1])
            vendedores.append(
                {
                    "id": row[0],
                    "nome": nome,
                    "descricao": f"{row[0]} - {nome}" if nome else str(row[0]),
                }
            )

        return {"ok": True, "total": len(vendedores), "dados": vendedores}

    except Exception as e:
        return {"ok": False, "erro": str(e)}, 500

    finally:
        try:
            if cur:
                cur.close()
            if con:
                con.close()
        except Exception:
            pass

# ==================================================
# FINALIZAR PEDIDO (LEGADO - PEDIDO SIMPLES)
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

        cur.execute(
            """
            SELECT FIRST 1 ORC_ID
            FROM TB_ORCAMENTO
            WHERE ORC_EMPRESA = ?
              AND ORC_COMANDA = ?
              AND ORC_STATUS = 'D'
            ORDER BY ORC_ID DESC
            """,
            (empresa, comanda),
        )

        orc = cur.fetchone()

        if orc:
            novo_orc_id = orc[0]
        else:
            novo_orc_id = gerar_novo_orcamento_id(cur, empresa)

            cur.execute(
                """
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
                """,
                (empresa, novo_orc_id, comanda, usuario),
            )

        cur.execute(
            """
            SELECT MAX(ORCI_SEQUENCIAL)
            FROM TB_ORCAMENTO_ITEM
            WHERE ORCI_EMPRESA = ?
              AND ORCI_ORCAMENTO = ?
            """,
            (empresa, novo_orc_id),
        )

        row = cur.fetchone()
        sequencial_item = row[0] if row and row[0] else 0

        itens_cozinha = []

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

            cur.execute(
                """
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
                """,
                (empresa, produto_id),
            )

            prod = cur.fetchone()

            if not prod:
                raise Exception(f"Produto {produto_id} inválido")

            unidade, valor_unitario, descricao, tipo_produto, local_preparo = prod

            valor_unitario = Decimal(str(valor_unitario))
            sub_total = quantidade * valor_unitario
            sequencial_item += 1

            if str(tipo_produto).strip() == "R" and local_preparo not in (None, 0, ""):
                itens_cozinha.append(
                    {
                        "produto_id": produto_id,
                        "descricao": descricao,
                        "quantidade": float(quantidade),
                        "local_preparo": int(local_preparo),
                    }
                )

            cur.execute(
                """
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
                """,
                (
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
                    comanda,
                ),
            )

        total_itens, total_geral = recalcular_totais_orcamento(cur, empresa, novo_orc_id)
        conn.commit()

        aviso = None

        if itens_cozinha:
            try:
                imprimir_ticket_cozinha(comanda, itens_cozinha)
            except Exception as e_impressao:
                aviso = (
                    "Pedido gravado com sucesso, mas a impressão da cozinha falhou: "
                    f"{str(e_impressao)}"
                )

        return jsonify({"sucesso": True, "orcamento_id": novo_orc_id, "aviso": aviso})

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
        except Exception:
            pass


# ==================================================
# BLOQUEIO DE COMANDA + CARREGAR ITENS (LEGADO)
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

        cur.execute(
            """
            SELECT FIRST 1 ORC_ID
            FROM TB_ORCAMENTO
            WHERE ORC_EMPRESA = ?
              AND ORC_COMANDA = ?
              AND ORC_STATUS = 'A'
            """,
            (empresa, comanda),
        )

        orc = cur.fetchone()

        if orc:
            return jsonify({"erro": f"Comanda {comanda} está sendo utilizada no balcão."}), 409

        cur.execute(
            """
            SELECT FIRST 1 ORC_ID
            FROM TB_ORCAMENTO
            WHERE ORC_EMPRESA = ?
              AND ORC_COMANDA = ?
              AND ORC_STATUS = 'D'
            ORDER BY ORC_ID DESC
            """,
            (empresa, comanda),
        )

        orc = cur.fetchone()

        if not orc:
            return jsonify({"orc_id": None, "itens": []})

        orc_id = orc[0]

        cur.execute(
            """
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
            """,
            (empresa, orc_id),
        )

        itens = []

        for row in cur.fetchall():
            itens.append(
                {
                    "produto_id": row[0],
                    "descricao": row[1],
                    "valor_unitario": float(row[2]) if row[2] else 0,
                    "quantidade": float(row[3]) if row[3] else 0,
                    "valor_total": float(row[4]) if row[4] else 0,
                }
            )

        return jsonify({"orc_id": orc_id, "itens": itens})

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

    finally:
        try:
            if cur:
                cur.close()
            if conn:
                conn.close()
        except Exception:
            pass


# ==================================================
# TABLET - ABRIR VENDA
# ORC_COMANDA = ORC_ID
# ORC_ECF = ECF_ID DO TABLET
# ==================================================
@app.post("/pdv/tablet/venda/abrir")
def tablet_abrir_venda():
    dados = request.json or {}

    empresa = dados.get("empresa")
    usuario = dados.get("usuario", 1)
    ecf_id = dados.get("ecf_id")

    if not empresa:
        return jsonify({"erro": "Empresa não informada"}), 400

    if not ecf_id:
        return jsonify({"erro": "ECF_ID não informado"}), 400

    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        validar_ecf(cur, empresa, ecf_id)

        novo_orc_id = gerar_novo_orcamento_id(cur, empresa)

        cur.execute(
            """
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
                ORC_USUARIO,
                ORC_ECF
            )
            VALUES (?, ?, 'D', 0, 0, 0, CURRENT_TIMESTAMP, CURRENT_DATE, ?, 'O', 'N', 1, ?, ?)
            """,
            (
                empresa,
                novo_orc_id,
                novo_orc_id,
                usuario,
                ecf_id,
            ),
        )

        conn.commit()

        return jsonify(
            {
                "sucesso": True,
                "orc_id": novo_orc_id,
                "numero": novo_orc_id,
                "comanda": novo_orc_id,
                "ecf_id": ecf_id,
                "status": "D",
                "status_descricao": status_descricao("D"),
                "cliente": "CONSUMIDOR FINAL",
                "itens": 0,
                "valor_total": 0.0,
                "data_hora": formatar_datahora(datetime.now()),
            }
        )

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
        except Exception:
            pass


# ==================================================
# TABLET - IMPRIMIR VENDA
# impressão manual do comprovante
# ==================================================
@app.post("/pdv/tablet/venda/imprimir")
def tablet_imprimir_venda():
    dados = request.json or {}

    empresa = dados.get("empresa")
    ecf_id = dados.get("ecf_id")
    orc_id = dados.get("orc_id")
    vendedor_id = dados.get("vendedor_id")

    try:
        empresa = int(empresa)
        ecf_id = int(ecf_id)
        orc_id = int(orc_id)

        if vendedor_id not in (None, "", 0, "0"):
            vendedor_id = int(vendedor_id)
        else:
            vendedor_id = None
    except Exception:
        return jsonify({"erro": "empresa/ecf_id/orc_id/vendedor_id inválidos"}), 400

    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        imprimir_comprovante_venda(cur, empresa, ecf_id, orc_id, vendedor_id=vendedor_id)

        conn.rollback()

        return jsonify({
            "sucesso": True,
            "mensagem": "Comprovante enviado para impressão.",
            "orc_id": orc_id,
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
        except Exception:
            pass


# ==================================================
# TABLET - LISTAR VENDAS DO APARELHO
# ==================================================
@app.get("/pdv/tablet/vendas")
def tablet_listar_vendas():
    empresa = request.args.get("empresa")
    ecf_id = request.args.get("ecf_id")

    if not empresa:
        return jsonify({"erro": "Empresa não informada"}), 400

    if not ecf_id:
        return jsonify({"erro": "ECF_ID não informado"}), 400

    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        validar_ecf(cur, empresa, ecf_id)

        cur.execute(
            """
            SELECT FIRST 100
                ORC_ID,
                ORC_COMANDA,
                ORC_STATUS,
                ORC_NR_ITENS,
                ORC_VALOR_TOTAL,
                COALESCE(ORC_CLIENTE, 1),
                ORC_DT_LANCAMENTO
            FROM TB_ORCAMENTO
            
            
            WHERE ORC_EMPRESA = ?
              AND ORC_ECF = ?
            ORDER BY ORC_ID DESC
            """,
            (empresa, ecf_id),
        )

        vendas = []

        for row in cur.fetchall():
            vendas.append(
                {
                    "orc_id": row[0],
                    "numero": row[0],
                    "comanda": row[1],
                    "cliente": montar_descricao_grid_venda(cur, empresa, row[0], row[5]),
                    "itens": valor_int_ou_float(row[3]),
                    "valor": valor_float(row[4]),
                    "status": row[2],
                    "status_descricao": status_descricao(row[2]),
                    "dataHora": formatar_datahora(row[6]),
                }
            )

        return jsonify({"sucesso": True, "total": len(vendas), "dados": vendas})

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

    finally:
        try:
            if cur:
                cur.close()
            if conn:
                conn.close()
        except Exception:
            pass


# ==================================================
# TABLET - DETALHE DE UMA VENDA
# ==================================================
@app.get("/pdv/tablet/venda")
def tablet_detalhar_venda():
    empresa = request.args.get("empresa")
    ecf_id = request.args.get("ecf_id")
    orc_id = request.args.get("orc_id")

    if not empresa:
        return jsonify({"erro": "Empresa não informada"}), 400

    if not ecf_id:
        return jsonify({"erro": "ECF_ID não informado"}), 400

    if not orc_id:
        return jsonify({"erro": "ORC_ID não informado"}), 400

    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        validar_ecf(cur, empresa, ecf_id)

        cab = buscar_orcamento_tablet(cur, empresa, ecf_id, orc_id)

        if not cab:
            return jsonify({"erro": "Venda não encontrada para este aparelho"}), 404

        cur.execute(
            """
            SELECT
                I.ORCI_SEQUENCIAL,
                I.ORCI_PRODUTO,
                P.PRD_DESCRICAO,
                I.ORCI_VALOR_UNITARIO,
                I.ORCI_QUANTIDADE,
                I.ORCI_VALOR_TOTAL,
                P.PRD_FOTO,
                COALESCE(I.ORCI_UNIDADE, P.PRD_UN_VENDA)
            FROM TB_ORCAMENTO_ITEM I
            JOIN TB_PRODUTO P
              ON P.PRD_EMPRESA = I.ORCI_EMPRESA
             AND P.PRD_ID = I.ORCI_PRODUTO
            WHERE I.ORCI_EMPRESA = ?
              AND I.ORCI_ORCAMENTO = ?
              AND COALESCE(I.ORCI_STATUS, 'A') <> 'C'
            ORDER BY I.ORCI_SEQUENCIAL
            """,
            (empresa, orc_id),
        )

        itens = []

        for row in cur.fetchall():
            unidade_venda = normalizar_unidade(row[7])
            fracionado = fracionado_por_unidade(cur, empresa, unidade_venda)

            itens.append(
                {
                    "sequencial": row[0],
                    "produto_id": row[1],
                    "descricao": row[2],
                    "valor_unitario": valor_float(row[3]),
                    "quantidade": valor_int_ou_float(row[4]),
                    "valor_total": valor_float(row[5]),
                    "foto_url": montar_foto_url(row[6]) if row[6] else None,
                    "unidade_venda": unidade_venda,
                    "fracionado": fracionado,
                }
            )

        return jsonify(
            {
                "sucesso": True,
                "orc_id": cab["orc_id"],
                "numero": cab["orc_id"],
                "comanda": cab["comanda"],
                "ecf_id": cab["ecf_id"],
                "status": cab["status"],
                "status_descricao": status_descricao(cab["status"]),
                
                "cliente": montar_descricao_grid_venda(
                    cur,
                    empresa,
                    cab["orc_id"],
                    cab["cliente_id"],
                ),
                
                "itens": itens,
                "total_itens": cab["itens"],
                "valor_total": cab["valor_total"],
                "dataHora": cab["data_hora"],
            }
        )

    except Exception as e:
        return jsonify({"erro": str(e)}), 500

    finally:
        try:
            if cur:
                cur.close()
            if conn:
                conn.close()
        except Exception:
            pass


# ==================================================
# TABLET - ADICIONAR ITEM NA VENDA
# GRAVA DIRETO NO BANCO
# ==================================================
@app.post("/pdv/tablet/venda/item/adicionar")
def tablet_adicionar_item():
    dados = request.json or {}

    empresa = dados.get("empresa")
    ecf_id = dados.get("ecf_id")
    orc_id = dados.get("orc_id")
    produto_id = dados.get("produto_id")
    quantidade_raw = dados.get("quantidade")
    valor_unitario_raw = dados.get("valor_unitario")

    if not empresa:
        return jsonify({"erro": "Empresa não informada"}), 400

    if not ecf_id:
        return jsonify({"erro": "ECF_ID não informado"}), 400

    if not orc_id:
        return jsonify({"erro": "ORC_ID não informado"}), 400

    if not produto_id:
        return jsonify({"erro": "Produto não informado"}), 400

    if quantidade_raw is None:
        return jsonify({"erro": "Quantidade não informada"}), 400

    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        validar_ecf(cur, empresa, ecf_id)

        # trava a venda antes de calcular o próximo sequencial do item
        cab = travar_orcamento_tablet(cur, empresa, ecf_id, orc_id)

        if not cab:
            return jsonify({"erro": "Venda não encontrada para este aparelho"}), 404

        status_orc = (cab["status"] or "").strip().upper()
        if status_orc != "D":
            return jsonify({"erro": "Somente vendas digitadas podem receber itens no tablet"}), 409            

        quantidade = Decimal(str(quantidade_raw))
        if quantidade <= 0:
            return jsonify({"erro": "Quantidade inválida"}), 400

        cur.execute(
            """
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
            """,
            (empresa, produto_id),
        )

        prod = cur.fetchone()

        if not prod:
            return jsonify({"erro": f"Produto {produto_id} inválido"}), 404

        unidade, valor_unitario_cadastro, descricao, tipo_produto, local_preparo = prod
        unidade = normalizar_unidade(unidade)
        fracionado = fracionado_por_unidade(cur, empresa, unidade)

        valor_unitario_cadastro = valor_monetario(valor_unitario_cadastro)
        valor_unitario_final = valor_unitario_cadastro

        if valor_unitario_raw not in (None, ""):
            valor_unitario_final = valor_monetario(valor_unitario_raw)

        if valor_unitario_final <= 0:
            return jsonify({"erro": "Valor unitário inválido"}), 400

        sub_total = valor_monetario(quantidade * valor_unitario_final)

        # como o orçamento já está travado, este MAX+1 fica protegido dentro da venda
        sequencial_item = proximo_sequencial_item(cur, empresa, orc_id)

        cur.execute(
            """
            INSERT INTO TB_ORCAMENTO_ITEM (
                ORCI_EMPRESA,
                ORCI_ORCAMENTO,
                ORCI_SEQUENCIAL,
                ORCI_PRODUTO,
                ORCI_PRODUTO_DIGITADO,
                ORCI_UNIDADE,
                ORCI_QUANTIDADE,
                ORCI_VOLUMES,
                ORCI_VALOR_UNITARIO,
                ORCI_SUB_TOTAL,
                ORCI_VALOR_TOTAL,
                ORCI_STATUS,
                ORCI_COMANDA
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'A', ?)
            """,
            (
                empresa,
                orc_id,
                sequencial_item,
                produto_id,
                str(produto_id),
                unidade,
                quantidade,
                1,
                valor_unitario_final,
                sub_total,
                sub_total,
                cab["comanda"],
            ),
        )

        # trava o produto antes de gerar o sequencial do movimento
        travar_produto_para_movimento(cur, empresa, produto_id)

        registrar_movimento_pre_venda(
            cur=cur,
            empresa=empresa,
            produto_id=produto_id,
            quantidade=quantidade,
            tipo="SAI",
            orc_id=orc_id,
            sequencial_item=sequencial_item,
            historico=f"SAÍDA PRÉ-VENDA TABLET ORCAMENTO {orc_id} ITEM {sequencial_item}",
        )

        total_itens, total_geral = recalcular_totais_orcamento(cur, empresa, orc_id)
        conn.commit()

        aviso = None

        if str(tipo_produto).strip() == "R" and local_preparo not in (None, 0, ""):
            try:
                imprimir_ticket_cozinha(
                    cab["comanda"],
                    [
                        {
                            "produto_id": produto_id,
                            "descricao": descricao,
                            "quantidade": float(quantidade),
                            "local_preparo": int(local_preparo),
                        }
                    ],
                )
            except Exception as e_impressao:
                aviso = (
                    "Item gravado com sucesso, mas a impressão da cozinha falhou: "
                    + str(e_impressao)
                )

        return jsonify(
            {
                "sucesso": True,
                "orc_id": orc_id,
                "sequencial_item": sequencial_item,
                "produto_id": produto_id,
                "descricao": descricao,
                "quantidade": valor_int_ou_float(quantidade),                
                "valor_unitario": valor_float(valor_unitario_final),
                "preco_alterado": "S" if valor_unitario_final != valor_unitario_cadastro else "N",                
                "valor_total_item": valor_float(sub_total),
                "total_itens": valor_int_ou_float(total_itens),
                "valor_total": valor_float(total_geral),
                "unidade_venda": unidade,
                "fracionado": fracionado,
                "aviso": aviso,
            }
        )

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
        except Exception:
            pass


# ==================================================
# TABLET - INCREMENTAR ITEM DA VENDA
# ==================================================
@app.post("/pdv/tablet/venda/item/incrementar")
def tablet_incrementar_item():
    dados = request.json or {}

    empresa = dados.get("empresa")
    ecf_id = dados.get("ecf_id")
    orc_id = dados.get("orc_id")
    sequencial_item = dados.get("sequencial_item")

    try:
        empresa = int(empresa)
        ecf_id = int(ecf_id)
        orc_id = int(orc_id)
        sequencial_item = int(sequencial_item)
    except Exception:
        return jsonify({"erro": "empresa/ecf_id/orc_id/sequencial_item inválidos"}), 400

    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        validar_ecf(cur, empresa, ecf_id)

        cab = buscar_orcamento_tablet(cur, empresa, ecf_id, orc_id)
        if not cab:
            return jsonify({"erro": "Venda não encontrada para este aparelho"}), 404

        status_orc = (cab["status"] or "").strip().upper()
        if status_orc != "D":
            return jsonify({"erro": "Somente vendas digitadas podem ser alteradas no tablet"}), 409

        item = buscar_item_orcamento_tablet(cur, empresa, orc_id, sequencial_item)
        if not item:
            return jsonify({"erro": "Item não encontrado"}), 404

        if item["status"] == "C":
            return jsonify({"erro": "Item já está cancelado"}), 409

        nova_quantidade = item["quantidade"] + Decimal("1")
        novo_total = nova_quantidade * item["valor_unitario"]

        cur.execute(
            """
            UPDATE TB_ORCAMENTO_ITEM
            SET ORCI_QUANTIDADE = ?,
                ORCI_SUB_TOTAL = ?,
                ORCI_VALOR_TOTAL = ?
            WHERE ORCI_EMPRESA = ?
              AND ORCI_ORCAMENTO = ?
              AND ORCI_SEQUENCIAL = ?
            """,
            (nova_quantidade, novo_total, novo_total, empresa, orc_id, sequencial_item),
        )

        registrar_movimento_pre_venda(
            cur=cur,
            empresa=empresa,
            produto_id=item["produto_id"],
            quantidade=Decimal("1"),
            tipo="SAI",
            orc_id=orc_id,
            sequencial_item=sequencial_item,
            historico=f"SAÍDA PRÉ-VENDA TABLET ORCAMENTO {orc_id} ITEM {sequencial_item} (+)",
        )

        total_itens, total_geral = recalcular_totais_orcamento(cur, empresa, orc_id)
        conn.commit()

        aviso = None

        if str(item["tipo_produto"]).strip() == "R" and item["local_preparo"] not in (None, 0, ""):
            try:
                imprimir_ticket_cozinha(
                    cab["comanda"],
                    [
                        {
                            "produto_id": item["produto_id"],
                            "descricao": item["descricao"],
                            "quantidade": 1.0,
                            "local_preparo": int(item["local_preparo"]),
                        }
                    ],
                )
            except Exception as e_impressao:
                aviso = (
                    "Item alterado com sucesso, mas a impressão da cozinha falhou: "
                    + str(e_impressao)
                )

        return jsonify(
            {
                "sucesso": True,
                "orc_id": orc_id,
                "sequencial_item": sequencial_item,
                "produto_id": item["produto_id"],
                "descricao": item["descricao"],
                "quantidade": valor_int_ou_float(nova_quantidade),
                "valor_unitario": valor_float(item["valor_unitario"]),
                "valor_total_item": valor_float(novo_total),
                "total_itens": valor_int_ou_float(total_itens),
                "valor_total": valor_float(total_geral),
                "unidade_venda": item["unidade_venda"],
                "fracionado": item["fracionado"],
                "aviso": aviso,
            }
        )

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
        except Exception:
            pass


# ==================================================
# TABLET - DECREMENTAR ITEM DA VENDA
# se chegar em 1, cancela a linha
# ==================================================
@app.post("/pdv/tablet/venda/item/decrementar")
def tablet_decrementar_item():
    dados = request.json or {}

    empresa = dados.get("empresa")
    ecf_id = dados.get("ecf_id")
    orc_id = dados.get("orc_id")
    sequencial_item = dados.get("sequencial_item")

    try:
        empresa = int(empresa)
        ecf_id = int(ecf_id)
        orc_id = int(orc_id)
        sequencial_item = int(sequencial_item)
    except Exception:
        return jsonify({"erro": "empresa/ecf_id/orc_id/sequencial_item inválidos"}), 400

    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        validar_ecf(cur, empresa, ecf_id)

        cab = buscar_orcamento_tablet(cur, empresa, ecf_id, orc_id)
        if not cab:
            return jsonify({"erro": "Venda não encontrada para este aparelho"}), 404

        status_orc = (cab["status"] or "").strip().upper()
        if status_orc != "D":
            return jsonify({"erro": "Somente vendas digitadas podem ser alteradas no tablet"}), 409

        item = buscar_item_orcamento_tablet(cur, empresa, orc_id, sequencial_item)
        if not item:
            return jsonify({"erro": "Item não encontrado"}), 404

        if item["status"] == "C":
            return jsonify({"erro": "Item já está cancelado"}), 409

        removido_totalmente = False
        nova_quantidade = Decimal("0")
        novo_total = Decimal("0")
        quantidade_movimento_entrada = (
            item["quantidade"] if item["quantidade"] <= Decimal("1") else Decimal("1")
        )

        if item["quantidade"] <= Decimal("1"):
            cur.execute(
                """
                UPDATE TB_ORCAMENTO_ITEM
                SET ORCI_STATUS = 'C'
                WHERE ORCI_EMPRESA = ?
                  AND ORCI_ORCAMENTO = ?
                  AND ORCI_SEQUENCIAL = ?
                """,
                (empresa, orc_id, sequencial_item),
            )
            removido_totalmente = True
        else:
            nova_quantidade = item["quantidade"] - Decimal("1")
            novo_total = nova_quantidade * item["valor_unitario"]

            cur.execute(
                """
                UPDATE TB_ORCAMENTO_ITEM
                SET ORCI_QUANTIDADE = ?,
                    ORCI_SUB_TOTAL = ?,
                    ORCI_VALOR_TOTAL = ?
                WHERE ORCI_EMPRESA = ?
                  AND ORCI_ORCAMENTO = ?
                  AND ORCI_SEQUENCIAL = ?
                """,
                (nova_quantidade, novo_total, novo_total, empresa, orc_id, sequencial_item),
            )

        registrar_movimento_pre_venda(
            cur=cur,
            empresa=empresa,
            produto_id=item["produto_id"],
            quantidade=quantidade_movimento_entrada,
            tipo="ENT",
            orc_id=orc_id,
            sequencial_item=sequencial_item,
            historico=f"ENTRADA PRÉ-VENDA TABLET ORCAMENTO {orc_id} ITEM {sequencial_item} (-)",
        )

        total_itens, total_geral = recalcular_totais_orcamento(cur, empresa, orc_id)
        conn.commit()

        return jsonify(
            {
                "sucesso": True,
                "orc_id": orc_id,
                "sequencial_item": sequencial_item,
                "produto_id": item["produto_id"],
                "descricao": item["descricao"],
                "quantidade": valor_int_ou_float(nova_quantidade),
                "valor_unitario": valor_float(item["valor_unitario"]),
                "valor_total_item": valor_float(novo_total),
                "total_itens": valor_int_ou_float(total_itens),
                "valor_total": valor_float(total_geral),
                "unidade_venda": item["unidade_venda"],
                "fracionado": item["fracionado"],
                "removido_totalmente": removido_totalmente,
            }
        )

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
        except Exception:
            pass


# ==================================================
# TABLET - REMOVER ITEM DA VENDA
# cancela a linha inteira
# ==================================================
@app.post("/pdv/tablet/venda/item/remover")
def tablet_remover_item():
    dados = request.json or {}

    empresa = dados.get("empresa")
    ecf_id = dados.get("ecf_id")
    orc_id = dados.get("orc_id")
    sequencial_item = dados.get("sequencial_item")

    try:
        empresa = int(empresa)
        ecf_id = int(ecf_id)
        orc_id = int(orc_id)
        sequencial_item = int(sequencial_item)
    except Exception:
        return jsonify({"erro": "empresa/ecf_id/orc_id/sequencial_item inválidos"}), 400

    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        validar_ecf(cur, empresa, ecf_id)

        cab = buscar_orcamento_tablet(cur, empresa, ecf_id, orc_id)
        if not cab:
            return jsonify({"erro": "Venda não encontrada para este aparelho"}), 404

        status_orc = (cab["status"] or "").strip().upper()
        if status_orc != "D":
            return jsonify({"erro": "Somente vendas digitadas podem ser alteradas no tablet"}), 409

        item = buscar_item_orcamento_tablet(cur, empresa, orc_id, sequencial_item)
        if not item:
            return jsonify({"erro": "Item não encontrado"}), 404

        if item["status"] == "C":
            return jsonify({"erro": "Item já está cancelado"}), 409

        cur.execute(
            """
            UPDATE TB_ORCAMENTO_ITEM
            SET ORCI_STATUS = 'C'
            WHERE ORCI_EMPRESA = ?
              AND ORCI_ORCAMENTO = ?
              AND ORCI_SEQUENCIAL = ?
            """,
            (empresa, orc_id, sequencial_item),
        )

        registrar_movimento_pre_venda(
            cur=cur,
            empresa=empresa,
            produto_id=item["produto_id"],
            quantidade=item["quantidade"],
            tipo="ENT",
            orc_id=orc_id,
            sequencial_item=sequencial_item,
            historico=f"ENTRADA PRÉ-VENDA TABLET ORCAMENTO {orc_id} ITEM {sequencial_item} (remoção)",
        )

        total_itens, total_geral = recalcular_totais_orcamento(cur, empresa, orc_id)
        conn.commit()

        return jsonify(
            {
                "sucesso": True,
                "orc_id": orc_id,
                "sequencial_item": sequencial_item,
                "produto_id": item["produto_id"],
                "descricao": item["descricao"],
                "total_itens": valor_int_ou_float(total_itens),
                "valor_total": valor_float(total_geral),
            }
        )

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
        except Exception:
            pass


# ==================================================
# TABLET - PRAZO - SIMULAR PARCELAMENTO
# não grava nada, só devolve a grade
# ==================================================
@app.post("/pdv/tablet/pagamento/prazo/simular")
def tablet_simular_pagamento_prazo():
    dados = request.json or {}

    empresa = dados.get("empresa")
    ecf_id = dados.get("ecf_id")
    orc_id = dados.get("orc_id")
    cliente_id = dados.get("cliente_id")
    quantidade_parcelas = dados.get("quantidade_parcelas")
    intervalo_dias = dados.get("intervalo_dias", 30)
    desconto = dados.get("desconto") or {}

    try:
        empresa = int(empresa)
        ecf_id = int(ecf_id)
        orc_id = int(orc_id)
        cliente_id = int(cliente_id)
        quantidade_parcelas = int(quantidade_parcelas)
        intervalo_dias = int(intervalo_dias)
    except Exception:
        return jsonify(
            {
                "erro": (
                    "empresa/ecf_id/orc_id/cliente_id/"
                    "quantidade_parcelas/intervalo_dias inválidos"
                )
            }
        ), 400

    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        validar_ecf(cur, empresa, ecf_id)
        validar_cliente(cur, empresa, cliente_id)

        cur.execute(
            """
            SELECT
                ORC_ID,
                ORC_ECF,
                ORC_STATUS,
                COALESCE(ORC_VALOR_TOTAL, 0)
            FROM TB_ORCAMENTO
            WHERE ORC_EMPRESA = ?
              AND ORC_ID = ?
              AND ORC_ECF = ?
            """,
            (empresa, orc_id, ecf_id),
        )

        row = cur.fetchone()

        if not row:
            return jsonify({"erro": "Venda não encontrada para este aparelho"}), 404

        orc_status = (row[2] or "").strip().upper()

        if orc_status != "D":
            return jsonify({"erro": "Somente vendas digitadas podem gerar prazo"}), 409

        rec_existente = venda_ja_possui_financeiro(cur, empresa, orc_id)
        if rec_existente:
            return jsonify({"erro": "Esta venda já possui recebimento gravado"}), 409

        if venda_ja_possui_orcamento_parcela(cur, empresa, orc_id):
            return jsonify({"erro": "Esta venda já possui parcelas gravadas"}), 409

        _, total_recalculado = recalcular_totais_orcamento(cur, empresa, orc_id)
        valor_total_venda = valor_monetario(total_recalculado or 0)

        if valor_total_venda <= 0:
            return jsonify({"erro": "Venda sem valor total para parcelar"}), 409

        data_emissao = datetime.now().date()

        parcelas = gerar_parcelas_prazo(
            valor_total=valor_total_venda,
            quantidade_parcelas=quantidade_parcelas,
            intervalo_dias=intervalo_dias,
            data_emissao=data_emissao,
            orc_id=orc_id,
        )

        conn.rollback()

        return jsonify(
            {
                "sucesso": True,
                "orc_id": orc_id,
                "cliente_id": cliente_id,
                "valor_total": valor_float(valor_total_venda),
                "quantidade_parcelas": quantidade_parcelas,
                "intervalo_dias": intervalo_dias,
                "data_emissao": formatar_data_iso(data_emissao),
                "data_emissao_br": formatar_data_br(data_emissao),
                "parcelas": [
                    {
                        "parcela": parcela["parcela"],
                        "documento": parcela["documento"],
                        "data_emissao": formatar_data_iso(parcela["data_emissao"]),
                        "data_emissao_br": formatar_data_br(parcela["data_emissao"]),
                        "vencimento": formatar_data_iso(parcela["vencimento"]),
                        "vencimento_br": formatar_data_br(parcela["vencimento"]),
                        "valor": valor_float(parcela["valor"]),
                    }
                    for parcela in parcelas
                ],
            }
        )

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
        except Exception:
            pass


# ==================================================
# TABLET - PRAZO - FINALIZAR
# grava:
# - TB_ORCAMENTO_PARCELA
# - 1 TB_RECEBIMENTO por parcela
# - 1 TB_RECEBIMENTO_ITEM(IN) por parcela
# e fecha ORC_STATUS = 'F'
# ==================================================
@app.post("/pdv/tablet/pagamento/prazo/finalizar")
def tablet_finalizar_pagamento_prazo():
    dados = request.json or {}

    empresa = dados.get("empresa")
    ecf_id = dados.get("ecf_id")
    orc_id = dados.get("orc_id")
    usuario = dados.get("usuario", 1)
    vendedor_id = dados.get("vendedor_id")
    cliente_id = dados.get("cliente_id")
    quantidade_parcelas = dados.get("quantidade_parcelas")
    intervalo_dias = dados.get("intervalo_dias", 30)

    try:
        empresa = int(empresa)
        ecf_id = int(ecf_id)
        orc_id = int(orc_id)
        usuario = int(usuario)
        cliente_id = int(cliente_id)
        quantidade_parcelas = int(quantidade_parcelas)
        intervalo_dias = int(intervalo_dias)

        if vendedor_id not in (None, "", 0, "0"):
            vendedor_id = int(vendedor_id)
        else:
            vendedor_id = None
    except Exception:
        return jsonify(
            {
                "erro": (
                    "empresa/ecf_id/orc_id/usuario/vendedor_id/cliente_id/"
                    "quantidade_parcelas/intervalo_dias inválidos"
                )
            }
        ), 400

    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()
        
        
        validar_ecf(cur, empresa, ecf_id)
        validar_cliente(cur, empresa, cliente_id)

        # trava a venda antes de validar status e antes de gravar parcelas/recebimentos
        cab = travar_orcamento_tablet(cur, empresa, ecf_id, orc_id)

        if not cab:
            return jsonify({"erro": "Venda não encontrada para este aparelho"}), 404

        orc_status = (cab["status"] or "").strip().upper()
        

        if orc_status != "D":
            return jsonify({"erro": "Somente vendas digitadas podem ser finalizadas a prazo"}), 409

        rec_existente = venda_ja_possui_financeiro(cur, empresa, orc_id)
        if rec_existente:
            return jsonify({"erro": "Esta venda já possui recebimento gravado"}), 409

        if venda_ja_possui_orcamento_parcela(cur, empresa, orc_id):
            return jsonify({"erro": "Esta venda já possui parcelas gravadas"}), 409

        _, total_recalculado = recalcular_totais_orcamento(cur, empresa, orc_id)
        valor_total_venda = valor_monetario(total_recalculado or 0)

        if valor_total_venda <= 0:
            return jsonify({"erro": "Venda sem valor total para parcelar"}), 409

        data_emissao = datetime.now().date()

        parcelas = gerar_parcelas_prazo(
            valor_total=valor_total_venda,
            quantidade_parcelas=quantidade_parcelas,
            intervalo_dias=intervalo_dias,
            data_emissao=data_emissao,
            orc_id=orc_id,
        )

        for parcela in parcelas:
            cur.execute(
                """
                INSERT INTO TB_ORCAMENTO_PARCELA (
                    ORCP_EMPRESA,
                    ORCP_ORCAMENTO,
                    ORCP_PARCELA,
                    ORCP_FORMA_PAGTO,
                    ORCP_VALOR,
                    ORCP_STATUS,
                    ORCP_ESPECIE_MOEDA,
                    ORCP_FORMA_PAGTO_NFE,
                    ORCP_DESCRICAO
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    empresa,
                    orc_id,
                    parcela["parcela"],
                    5,
                    parcela["valor"],
                    None,
                    "PZ",
                    "05",
                    f"PRAZO {parcela['parcela']}/{quantidade_parcelas}",
                ),
            )

            rec_id = gerar_novo_recebimento_id(cur, empresa)

           
           
           

            cur.execute(
                """
                INSERT INTO TB_RECEBIMENTO (
                    REC_ID,
                    REC_EMPRESA,
                    REC_TIPO,
                    REC_STATUS,
                    REC_CLIENTE,
                    REC_DT_EMISSAO,
                    REC_DT_VENCIMENTO,
                    REC_DT_LANCAMENTO,
                    REC_DOCUMENTO,
                    REC_VALOR,
                    REC_VALOR_DESCONTO,
                    REC_VALOR_ACRESCIMO,
                    REC_USUARIO,
                    REC_ABERTO,
                    REC_SELECIONADO,
                    REC_ORIGEM,
                    REC_ID_ORIGEM,
                    REC_FORMA_PAGTO,
                    REC_ESPECIE_MOEDA,
                    REC_VENDEDOR
                )
                VALUES (
                    ?, ?, 'DP', 'AB', ?, ?, ?, CURRENT_TIMESTAMP,
                    ?, ?, 0, 0, ?, 'S', 'N', 'ORCAMENTO', ?, ?, ?, ?
                )
                """,
                (
                    rec_id,
                    empresa,
                    cliente_id,
                    parcela["data_emissao"],
                    parcela["vencimento"],
                    parcela["documento"],
                    parcela["valor"],
                    usuario,
                    orc_id,
                    5,
                    "PZ",
                    vendedor_id,
                ),
            )
            
            
            
            

            cur.execute(
                """
                INSERT INTO TB_RECEBIMENTO_ITEM (
                    RIT_EMPRESA,
                    RIT_RECEBIMENTO,
                    RIT_SEQUENCIAL,
                    RIT_ACAO,
                    RIT_DT_ACAO,
                    RIT_VALOR,
                    RIT_HISTORICO,
                    RIT_DT_LANCAMENTO,
                    RIT_ORIGEM_MOVIMENTO,
                    RIT_ORIGEM_NUMERO,
                    RIT_USUARIO,
                    RIT_ESPECIE_MOEDA,
                    RIT_CAIXA,
                    RIT_FORMA_PAGTO_NFE,
                    RIT_PIX
                )
                VALUES (
                    ?, ?, 1, 'IN', ?, ?, ?, CURRENT_TIMESTAMP,
                    'ORCAMENTO', ?, ?, ?, ?, ?, ?
                )
                """,
                (
                    empresa,
                    rec_id,
                    parcela["data_emissao"],
                    parcela["valor"],
                    f"INCLUSÃO DO RECEBIMENTO PELO ORCAMENTO: {orc_id}",
                    orc_id,
                    usuario,
                    None,
                    None,
                    "99",
                    "N",
                ),
            )

        observacao_tablet = montar_observacao_tablet(ecf_id)

        cur.execute(
            """
            UPDATE TB_ORCAMENTO
            SET ORC_CLIENTE = ?,
                ORC_VENDEDOR = ?,
                ORC_STATUS = 'F',
                ORC_TIPO_MOVIMENTO = 'V',
                ORC_OBSERVACAO = ?
            WHERE ORC_EMPRESA = ?
              AND ORC_ID = ?
              AND ORC_ECF = ?
            """,
            (
                cliente_id,
                vendedor_id,
                observacao_tablet,
                empresa,
                orc_id,
                ecf_id,
            ),
        )
              
        conn.commit()

        aviso = None
        promissorias_impressas = 0
        promissorias_pdf_url = None
        promissorias_pdf_arquivo = None

        try:
            imprimir_comprovante_venda(
                cur,
                empresa,
                ecf_id,
                orc_id,
                vendedor_id=vendedor_id,
            )
        except Exception as e_impressao_termica:
            aviso = f"Venda gravada com sucesso, mas a impressão do comprovante falhou: {str(e_impressao_termica)}"

        try:
            resultado_pdf = gerar_promissorias_pdf(
                cur,
                empresa,
                orc_id,
            )
            promissorias_impressas = resultado_pdf["total"]
            promissorias_pdf_url = resultado_pdf["url"]
            promissorias_pdf_arquivo = resultado_pdf["arquivo"]
            
            if AUTO_IMPRIMIR_PROMISSORIA_PDF and resultado_pdf["caminho"]:
                imprimir_pdf_automatico(
                    resultado_pdf["caminho"],
                    NOME_IMPRESSORA_A4,
                )            
            
        except Exception as e_pdf:
            print(f"[PDF][ERRO] {str(e_pdf)}")
            if aviso:
                aviso += f" | Geração do PDF das promissórias falhou: {str(e_pdf)}"
            else:
                aviso = f"Venda gravada com sucesso, mas a geração do PDF das promissórias falhou: {str(e_pdf)}"

        return jsonify(
            {
                "sucesso": True,
                "orc_id": orc_id,
                "status": "F",
                "status_descricao": status_descricao("F"),
                "cliente_id": cliente_id,
                "quantidade_parcelas": quantidade_parcelas,
                "valor_total": valor_float(valor_total_venda),
                "promissorias_impressas": promissorias_impressas,                
                "promissorias_pdf_url": promissorias_pdf_url,
                "promissorias_pdf_arquivo": promissorias_pdf_arquivo,
                "aviso": aviso,
                "parcelas": [
                    {
                        "parcela": parcela["parcela"],
                        "documento": parcela["documento"],
                        "vencimento": formatar_data_iso(parcela["vencimento"]),
                        "vencimento_br": formatar_data_br(parcela["vencimento"]),
                        "valor": valor_float(parcela["valor"]),
                    }
                    for parcela in parcelas
                ],
            }
        )



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
        except Exception:
            pass


# ==================================================
# TABLET - FINALIZAR PAGAMENTO
# grava:
# - TB_ORCAMENTO_PARCELA
# - TB_RECEBIMENTO
# - TB_RECEBIMENTO_ITEM
# e fecha ORC_STATUS = 'F'
# ==================================================
@app.post("/pdv/tablet/pagamento/finalizar")
def tablet_finalizar_pagamento():
    dados = request.json or {}

    empresa = dados.get("empresa")
    ecf_id = dados.get("ecf_id")
    orc_id = dados.get("orc_id")
    usuario = dados.get("usuario", 1)
    vendedor_id = dados.get("vendedor_id")
    desconto = dados.get("desconto") or {}
    pagamentos = dados.get("pagamentos", [])

    try:
        empresa = int(empresa)
        ecf_id = int(ecf_id)
        orc_id = int(orc_id)
        usuario = int(usuario)

        if vendedor_id not in (None, "", 0, "0"):
            vendedor_id = int(vendedor_id)
        else:
            vendedor_id = None
    except Exception:
        return jsonify({"erro": "empresa/ecf_id/orc_id/usuario/vendedor_id inválidos"}), 400

    if not empresa:
        return jsonify({"erro": "Empresa não informada"}), 400

    if not ecf_id:
        return jsonify({"erro": "ECF_ID não informado"}), 400

    if not orc_id:
        return jsonify({"erro": "ORC_ID não informado"}), 400

    if not pagamentos or not isinstance(pagamentos, list):
        return jsonify({"erro": "Pagamentos não informados"}), 400
        
    if desconto and not isinstance(desconto, dict):
        return jsonify({"erro": "Bloco de desconto inválido"}), 400        

    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()
        
        validar_ecf(cur, empresa, ecf_id)

        # trava a venda antes de validar status e antes de gravar financeiro
        cab = travar_orcamento_tablet(cur, empresa, ecf_id, orc_id)

        if not cab:
            return jsonify({"erro": "Venda não encontrada para este aparelho"}), 404

        orc_status = (cab["status"] or "").strip().upper()
        cliente_id = cab["cliente_id"] or 1

        _, total_recalculado = recalcular_totais_orcamento(cur, empresa, orc_id)
        subtotal_venda = valor_monetario(total_recalculado or 0)
        

        if orc_status != "D":
            return jsonify({"erro": "Somente vendas digitadas podem ser pagas no tablet"}), 409

        if subtotal_venda <= 0:
            return jsonify({"erro": "Venda sem valor total para finalizar"}), 409

        valor_desconto = valor_monetario((desconto or {}).get("valor") or 0)
        
        indicador_desconto = resolver_indicador_desconto(desconto)
        observacao_tablet = montar_observacao_tablet(ecf_id)        

        if valor_desconto < 0:
            return jsonify({"erro": "Valor de desconto inválido"}), 400

        if valor_desconto > subtotal_venda:
            return jsonify({"erro": "O desconto não pode ser maior que o subtotal da venda"}), 409
        
        if valor_desconto > 0:
            formas_permitidas_desconto = {1, 4}  # Dinheiro e Pix

            for pag in pagamentos:
                try:
                    forma_pagto_tmp = int(pag.get("forma_pagto") or 0)
                except Exception:
                    forma_pagto_tmp = 0

                if forma_pagto_tmp not in formas_permitidas_desconto:
                    return jsonify({
                        "erro": "Com desconto, a finalização só pode ser em Dinheiro ou Pix"
                    }), 409

        valor_total_venda = valor_monetario(subtotal_venda - valor_desconto)

        if valor_total_venda <= 0:
            return jsonify({"erro": "O total final da venda ficou inválido"}), 409

        cur.execute(
            """
            SELECT FIRST 1 REC_ID
            FROM TB_RECEBIMENTO
            WHERE REC_EMPRESA = ?
              AND REC_ORIGEM = 'ORCAMENTO'
              AND REC_ID_ORIGEM = ?
            """,
            (empresa, orc_id),
        )

        rec_existente = cur.fetchone()
        if rec_existente:
            return jsonify({"erro": "Esta venda já possui recebimento gravado"}), 409

        cur.execute(
            """
            SELECT COUNT(*)
            FROM TB_ORCAMENTO_PARCELA
            WHERE ORCP_EMPRESA = ?
              AND ORCP_ORCAMENTO = ?
            """,
            (empresa, orc_id),
        )

        total_parcelas_existentes = cur.fetchone()[0] or 0
        if total_parcelas_existentes > 0:
            return jsonify({"erro": "Esta venda já possui parcelas gravadas"}), 409

        
        for i, pag in enumerate(pagamentos, start=1):
            forma_pagto_raw = pag.get("forma_pagto")
            especie_moeda_raw = (pag.get("especie_moeda") or "").strip().upper()
            forma_pagto_nfe_raw = (pag.get("forma_pagto_nfe") or "").strip()
            vencimento_raw = (pag.get("vencimento") or "").strip()
            a_prazo = pag.get("a_prazo") is True

            if (
                str(forma_pagto_raw).strip() == "5"
                or especie_moeda_raw == "PZ"
                or forma_pagto_nfe_raw == "05"
                or a_prazo
                or vencimento_raw
            ):
                return jsonify(
                    {
                        "erro": (
                            "Pagamento a prazo deve usar o endpoint "
                            "/pdv/tablet/pagamento/prazo/finalizar"
                        )
                    }
                ), 409

        pagamentos_tratados = []
        soma_pagamentos = Decimal("0.00")
        soma_recebido_bruto = Decimal("0.00")

        for i, pag in enumerate(pagamentos, start=1):
            forma_pagto_raw = pag.get("forma_pagto")

            try:
                forma_pagto = int(forma_pagto_raw)
            except Exception:
                raise Exception(f"Forma de pagamento inválida no item {i}")

            descricao = (pag.get("descricao") or "").strip().upper()
            especie_moeda = (pag.get("especie_moeda") or "").strip().upper()
            forma_pagto_nfe = (pag.get("forma_pagto_nfe") or "").strip()
            valor_raw = pag.get("valor")
            valor_recebido_raw = pag.get("valor_recebido")
            pix_raw = (pag.get("pix") or "").strip().upper()

            if not forma_pagto:
                raise Exception(f"Forma de pagamento não informada no item {i}")

            if valor_raw is None:
                raise Exception(f"Valor não informado no item {i}")

            valor = valor_monetario(valor_raw)
            valor_recebido = valor_monetario(
                valor_recebido_raw if valor_recebido_raw not in (None, "") else valor_raw
            )

            if valor <= 0:
                raise Exception(f"Valor inválido no item {i}")

            if valor_recebido < valor:
                raise Exception(f"Valor recebido menor que o valor lançado no item {i}")

            if not descricao:
                raise Exception(f"Descrição não informada no item {i}")

            if not especie_moeda:
                raise Exception(f"Espécie moeda não informada no item {i}")

            if not forma_pagto_nfe:
                raise Exception(f"Forma pagto NFE não informada no item {i}")

            pix = (
                "S"
                if pix_raw == "S" or especie_moeda == "PX" or forma_pagto_nfe == "17"
                else "N"
            )

            pagamentos_tratados.append(
                {
                    "forma_pagto": forma_pagto,
                    "descricao": descricao,
                    "especie_moeda": especie_moeda,
                    "forma_pagto_nfe": forma_pagto_nfe,
                    "valor": valor,
                    "valor_recebido": valor_recebido,
                    "pix": pix,
                }
            )

            soma_pagamentos += valor
            soma_recebido_bruto += valor_recebido

        soma_pagamentos = valor_monetario(soma_pagamentos)
        soma_recebido_bruto = valor_monetario(soma_recebido_bruto)        

        if soma_pagamentos != valor_total_venda:
            return jsonify(
                {
                    "erro": (
                        f"Total dos pagamentos ({valor_float(soma_pagamentos):.2f}) "
                        f"diferente do total final da venda ({valor_float(valor_total_venda):.2f})"
                    )
                }
            ), 409

        troco = valor_monetario(soma_recebido_bruto - valor_total_venda)
        if troco < 0:
            troco = Decimal("0.00")

        rec_id = gerar_novo_recebimento_id(cur, empresa)

        parcela = 1
        for pag in pagamentos_tratados:
            cur.execute(
                """
                INSERT INTO TB_ORCAMENTO_PARCELA (
                    ORCP_EMPRESA,
                    ORCP_ORCAMENTO,
                    ORCP_PARCELA,
                    ORCP_FORMA_PAGTO,
                    ORCP_VALOR,
                    ORCP_STATUS,
                    ORCP_ESPECIE_MOEDA,
                    ORCP_FORMA_PAGTO_NFE,
                    ORCP_DESCRICAO
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    empresa,
                    orc_id,
                    parcela,
                    pag["forma_pagto"],
                    pag["valor"],
                    None,
                    pag["especie_moeda"],
                    pag["forma_pagto_nfe"],
                    pag["descricao"],
                ),
            )
            parcela += 1

        header_forma_pagto = (
            pagamentos_tratados[0]["forma_pagto"] if len(pagamentos_tratados) == 1 else None
        )
        header_especie = (
            pagamentos_tratados[0]["especie_moeda"] if len(pagamentos_tratados) == 1 else None
        )
        documento = f"{str(int(orc_id)).zfill(4)}-E"

        
        
        cur.execute(
            """
            INSERT INTO TB_RECEBIMENTO (
                REC_ID,
                REC_EMPRESA,
                REC_TIPO,
                REC_STATUS,
                REC_CLIENTE,
                REC_DT_EMISSAO,
                REC_DT_VENCIMENTO,
                REC_DT_LANCAMENTO,
                REC_DOCUMENTO,
                REC_VALOR,
                REC_VALOR_DESCONTO,
                REC_VALOR_ACRESCIMO,
                REC_USUARIO,
                REC_ABERTO,
                REC_SELECIONADO,
                REC_ORIGEM,
                REC_ID_ORIGEM,
                REC_FORMA_PAGTO,
                REC_ESPECIE_MOEDA,
                REC_VENDEDOR
            )
            VALUES (
                ?, ?, 'DP', 'BX', ?, CURRENT_DATE, CURRENT_DATE, CURRENT_TIMESTAMP,
                ?, ?, ?, 0, ?, 'N', 'N', 'ORCAMENTO', ?, ?, ?, ?
            )
            """,
            (
                rec_id,
                empresa,
                cliente_id,
                documento,
                valor_total_venda,
                valor_desconto,
                usuario,
                orc_id,
                header_forma_pagto,
                header_especie,
                vendedor_id,
            ),
        )
        

        cur.execute(
            """
            INSERT INTO TB_RECEBIMENTO_ITEM (
                RIT_EMPRESA,
                RIT_RECEBIMENTO,
                RIT_SEQUENCIAL,
                RIT_ACAO,
                RIT_DT_ACAO,
                RIT_VALOR,
                RIT_HISTORICO,
                RIT_DT_LANCAMENTO,
                RIT_ORIGEM_MOVIMENTO,
                RIT_ORIGEM_NUMERO,
                RIT_USUARIO,
                RIT_ESPECIE_MOEDA,
                RIT_CAIXA,
                RIT_FORMA_PAGTO_NFE,
                RIT_PIX
            )
            VALUES (
                ?, ?, 1, 'IN', CURRENT_DATE, ?, ?, CURRENT_TIMESTAMP,
                'ORCAMENTO', ?, ?, ?, ?, ?, ?
            )
            """,
            (
                empresa,
                rec_id,
                valor_total_venda,
                f"INCLUSÃO DO RECEBIMENTO PELO ORCAMENTO: {orc_id}",
                orc_id,
                usuario,
                None,
                None,
                "99",
                "N",
            ),
        )

        sequencial = 2
        for pag in pagamentos_tratados:
            cur.execute(
                """
                INSERT INTO TB_RECEBIMENTO_ITEM (
                    RIT_EMPRESA,
                    RIT_RECEBIMENTO,
                    RIT_SEQUENCIAL,
                    RIT_ACAO,
                    RIT_DT_ACAO,
                    RIT_VALOR,
                    RIT_HISTORICO,
                    RIT_DT_LANCAMENTO,
                    RIT_ORIGEM_MOVIMENTO,
                    RIT_ORIGEM_NUMERO,
                    RIT_USUARIO,
                    RIT_ESPECIE_MOEDA,
                    RIT_CAIXA,
                    RIT_FORMA_PAGTO_NFE,
                    RIT_PIX
                )
                VALUES (
                    ?, ?, ?, 'RC', CURRENT_DATE, ?, ?, CURRENT_TIMESTAMP,
                    'ORCAMENTO', ?, ?, ?, ?, ?, ?
                )
                """,
                (
                    empresa,
                    rec_id,
                    sequencial,
                    pag["valor"],
                    "BAIXA REFERENTE A RECEBIMENTO À VISTA",
                    orc_id,
                    usuario,
                    pag["especie_moeda"],
                    None,
                    pag["forma_pagto_nfe"],
                    pag["pix"],
                ),
            )
            sequencial += 1

        cur.execute(
            """
            UPDATE TB_ORCAMENTO
            SET ORC_STATUS = 'F',
                ORC_SUB_TOTAL = ?,
                ORC_DESCONTO_VALOR = ?,
                ORC_INDICADOR_DESCONTO = ?,
                ORC_ACRESCIMO_VALOR = 0,
                ORC_VALOR_TOTAL = ?,
                ORC_VENDEDOR = ?,
                ORC_VALOR_PAGO = ?,
                ORC_VALOR_TROCO = ?,
                ORC_DT_FATURAMENTO = CURRENT_TIMESTAMP,
                ORC_TIPO_MOVIMENTO = 'V',
                ORC_OBSERVACAO = ?
            WHERE ORC_EMPRESA = ?
              AND ORC_ID = ?
              AND ORC_ECF = ?
            """,
            (
                subtotal_venda,
                valor_desconto,
                indicador_desconto,
                valor_total_venda,
                vendedor_id,
                soma_recebido_bruto,
                troco,
                observacao_tablet,
                empresa,
                orc_id,
                ecf_id,
            ),
        )

        conn.commit()

        return jsonify(
            {
                "sucesso": True,
                "orc_id": orc_id,
                "rec_id": rec_id,
                "status": "F",
                "status_descricao": status_descricao("F"),
                "total_recebido": valor_float(soma_pagamentos),
                "quantidade_pagamentos": len(pagamentos_tratados),
            }
        )

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
        except Exception:
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
    print("Acesso local : http://127.0.0.1:5000")
    print(f"Acesso rede  : http://{ip_local}:5000")
    print("=====================================")


# ==================================================
# INICIALIZAÇÃO
# ==================================================
from waitress import serve

if __name__ == "__main__":
    mostrar_ips()
    serve(app, host="0.0.0.0", port=5000)
