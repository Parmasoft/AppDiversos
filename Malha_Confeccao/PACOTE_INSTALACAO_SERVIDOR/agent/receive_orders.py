"""Receive immutable cloud orders into the four existing ParmaGestor tables."""
import hashlib
import json
from contextlib import contextmanager
from datetime import date, datetime
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

ORIGIN="FLUTTER"; MONEY=Decimal("0.0001")

class PayloadError(ValueError): pass
class DestinationConflict(ValueError): pass

def _text(value,name,limit,required=True):
    result="" if value is None else str(value).strip()
    if (required and not result) or len(result)>limit: raise PayloadError(f"{name} invalido")
    return result
def _integer(value,name,required=True):
    if value is None and not required: return None
    try: result=int(value)
    except (TypeError,ValueError): raise PayloadError(f"{name} invalido")
    if result<=0: raise PayloadError(f"{name} invalido")
    return result
def _decimal(value,name,scale,positive=False):
    try: result=Decimal(str(value))
    except (InvalidOperation,TypeError,ValueError): raise PayloadError(f"{name} invalido")
    if not result.is_finite() or result.as_tuple().exponent < -scale or result < 0 or (positive and result<=0): raise PayloadError(f"{name} invalido")
    return result.quantize(Decimal(1).scaleb(-scale))

def normalize(payload):
    if not isinstance(payload,dict): raise PayloadError("pedido invalido")
    try: created=datetime.fromisoformat(_text(payload.get("created_at"),"created_at",40).replace("Z","+00:00")); delivery=date.fromisoformat(_text(payload.get("previsao_entrega"),"previsao_entrega",10))
    except ValueError: raise PayloadError("data invalida")
    client=payload.get("cliente")
    if not isinstance(client,dict) or client.get("tipo") not in {"oficial","provisorio"}: raise PayloadError("cliente invalido")
    provisional=None; official=None
    if client["tipo"]=="oficial": official=_integer(client.get("id"),"cliente.id")
    else:
        raw=client.get("provisorio")
        if not isinstance(raw,dict): raise PayloadError("cliente.provisorio invalido")
        kind=_text(raw.get("tipo_pessoa"),"tipo_pessoa",2).upper()
        if kind not in {"PF","PJ"}: raise PayloadError("tipo_pessoa invalido")
        provisional={"local_id":_text(raw.get("local_id"),"cliente.local_id",100),"person_type":kind,"name":_text(raw.get("nome"),"cliente.nome",100),"fantasy":_text(raw.get("fantasia"),"cliente.fantasia",100,False),"document":_text(raw.get("cpf_cnpj"),"cliente.cpf_cnpj",14,False),"phone":_text(raw.get("telefone"),"cliente.telefone",20,False),"state_registration":_text(raw.get("inscricao_estadual"),"cliente.inscricao_estadual",30,False),"email":_text(raw.get("email"),"cliente.email",254,False),"whatsapp":_text(raw.get("whatsapp"),"cliente.whatsapp",20,False),"zip_code":_text(raw.get("cep"),"cliente.cep",8,False),"street":_text(raw.get("logradouro"),"cliente.logradouro",150,False),"number":_text(raw.get("numero"),"cliente.numero",20,False),"complement":_text(raw.get("complemento"),"cliente.complemento",100,False),"neighborhood":_text(raw.get("bairro"),"cliente.bairro",100,False),"city":_text(raw.get("cidade"),"cliente.cidade",100,False),"state":_text(raw.get("uf"),"cliente.uf",2,False)}
    rows=payload.get("itens")
    if not isinstance(rows,list) or not rows or len(rows)>999: raise PayloadError("itens invalidos")
    items=[]
    for pos,row in enumerate(rows,1):
        if not isinstance(row,dict): raise PayloadError("item invalido")
        quantity=_decimal(row.get("quantidade"),"quantidade",6,True); price=_decimal(row.get("valor_unitario"),"valor_unitario",4); subtotal=_decimal(row.get("subtotal"),"subtotal",4)
        if (quantity*price).quantize(MONEY,rounding=ROUND_HALF_UP)!=subtotal: raise PayloadError("subtotal invalido")
        items.append({"position":pos,"product":_integer(row.get("produto_id"),"produto_id"),"description":_text(row.get("descricao"),"descricao",120),"unit":_text(row.get("unidade"),"unidade",6),"quantity":quantity,"unit_price":price,"subtotal":subtotal})
    total=_decimal(payload.get("valor_total"),"valor_total",4)
    if total != sum((x["subtotal"] for x in items),Decimal("0.0000")): raise PayloadError("total invalido")
    if not isinstance(payload.get("gerencial"),bool): raise PayloadError("gerencial invalido")
    return {"local_id":_text(payload.get("local_id"),"local_id",100),"created_at":created,"official_id":official,"provisional":provisional,"client_name":_text(client.get("nome"),"cliente.nome",100,False),"payment":_integer(payload.get("forma_pagamento_id"),"forma_pagamento_id"),"days":_integer(payload.get("prazo_dias"),"prazo_dias"),"delivery":delivery,"managerial":payload["gerencial"],"notes":_text(payload.get("observacoes"),"observacoes",20000,False),"items":items,"total":total}

def content_hash(order):
    value={"origin":ORIGIN,"local_id":order["local_id"],"created_at":order["created_at"].isoformat(),"official_id":order["official_id"],"provisional":order["provisional"],"client_name":order["client_name"],"payment":order["payment"],"days":order["days"],"delivery":order["delivery"].isoformat(),"managerial":order["managerial"],"notes":order["notes"],"total":format(order["total"],"f"),"items":[{**x,"quantity":format(x["quantity"],"f"),"unit_price":format(x["unit_price"],"f"),"subtotal":format(x["subtotal"],"f")} for x in order["items"]]}
    return hashlib.sha256(json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(",",":"),default=str).encode()).hexdigest()

@contextmanager
def _connection(settings):
    import fdb
    db=fdb.connect(host=settings.fb_host,port=settings.fb_port,database=settings.fb_database,user=settings.fb_user,password=settings.fb_password,charset=settings.fb_charset)
    try: yield db; db.commit()
    except Exception: db.rollback(); raise
    finally: db.close()

def _existing(cursor,company,local_id):
    cursor.execute("SELECT MPR_ID,MPR_HASH_CONTEUDO,MPR_DT_RECEBIMENTO FROM TB_MALHA_PEDIDO_RECEBIDO WHERE MPR_EMPRESA=? AND MPR_ORIGEM=? AND MPR_ID_LOCAL_PEDIDO=?",(company,ORIGIN,local_id)); return cursor.fetchone()

def receive(settings,payload,vendedor_id,connection_factory=_connection):
    order=normalize(payload); digest=content_hash(order); company=settings.empresa_id
    with connection_factory(settings) as db:
        cursor=db.cursor()
        try:
            old=_existing(cursor,company,order["local_id"])
            if old:
                if str(old[1]).strip()!=digest: raise DestinationConflict("UUID ja existe com conteudo diferente")
                return {"pedido_recebido_id":int(old[0]),"status":"RECEBIDO","repetido":True}
            provisional_id=None
            if order["provisional"]:
                x=order["provisional"]; cursor.execute("SELECT MCPR_ID FROM TB_MALHA_CLIENTE_PROV_REC WHERE MCPR_EMPRESA=? AND MCPR_VENDEDOR=? AND MCPR_ORIGEM=? AND MCPR_ID_LOCAL_CLIENTE=?",(company,vendedor_id,ORIGIN,x["local_id"])); row=cursor.fetchone()
                if row: provisional_id=int(row[0])
                else:
                    cursor.execute("INSERT INTO TB_MALHA_CLIENTE_PROV_REC (MCPR_EMPRESA,MCPR_VENDEDOR,MCPR_ORIGEM,MCPR_ID_LOCAL_CLIENTE,MCPR_TIPO_PESSOA,MCPR_NOME_RAZAO,MCPR_NOME_FANTASIA,MCPR_CPF_CNPJ,MCPR_TELEFONE,MCPR_INSCRICAO_ESTADUAL,MCPR_EMAIL,MCPR_WHATSAPP,MCPR_CEP,MCPR_LOGRADOURO,MCPR_NUMERO,MCPR_COMPLEMENTO,MCPR_BAIRRO,MCPR_CIDADE,MCPR_UF,MCPR_DT_RECEBIMENTO,MCPR_SITUACAO) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP,'PENDENTE') RETURNING MCPR_ID",(company,vendedor_id,ORIGIN,x["local_id"],x["person_type"],x["name"],x["fantasy"] or None,x["document"] or None,x["phone"] or None,x["state_registration"] or None,x["email"] or None,x["whatsapp"] or None,x["zip_code"] or None,x["street"] or None,x["number"] or None,x["complement"] or None,x["neighborhood"] or None,x["city"] or None,x["state"] or None)); provisional_id=int(cursor.fetchone()[0])
            cursor.execute("INSERT INTO TB_MALHA_PEDIDO_RECEBIDO (MPR_EMPRESA,MPR_VENDEDOR,MPR_ORIGEM,MPR_ID_LOCAL_PEDIDO,MPR_HASH_CONTEUDO,MPR_DT_CRIADO_APP,MPR_DT_RECEBIMENTO,MPR_CLIENTE,MPR_CLIENTE_PROVISORIO,MPR_CLIENTE_NOME_SNAPSHOT,MPR_FORMA_PAGTO,MPR_PRAZO_DIAS,MPR_PREVISAO_ENTREGA,MPR_GERENCIAL,MPR_OBSERVACAO,MPR_VALOR_TOTAL,MPR_STATUS) VALUES (?,?,?,?,?,?,CURRENT_TIMESTAMP,?,?,?,?,?,?,?,?,?,'RECEBIDO') RETURNING MPR_ID",(company,vendedor_id,ORIGIN,order["local_id"],digest,order["created_at"],order["official_id"],provisional_id,order["client_name"] or None,order["payment"],order["days"],order["delivery"],'S' if order["managerial"] else 'N',order["notes"] or None,order["total"])); order_id=int(cursor.fetchone()[0])
            for x in order["items"]: cursor.execute("INSERT INTO TB_MALHA_PEDIDO_RECEBIDO_ITEM (MPRI_EMPRESA,MPRI_PEDIDO,MPRI_SEQUENCIA,MPRI_PRODUTO,MPRI_DESCRICAO_ORIGINAL,MPRI_UNIDADE,MPRI_QUANTIDADE,MPRI_VALOR_UNITARIO,MPRI_SUBTOTAL) VALUES (?,?,?,?,?,?,?,?,?)",(company,order_id,x["position"],x["product"],x["description"],x["unit"],x["quantity"],x["unit_price"],x["subtotal"]))
            cursor.execute("INSERT INTO TB_MALHA_PEDIDO_EVENTO (MPE_EMPRESA,MPE_PEDIDO,MPE_DT_EVENTO,MPE_TIPO_EVENTO,MPE_STATUS_POSTERIOR,MPE_DESCRICAO) VALUES (?,?,CURRENT_TIMESTAMP,'RECEBIDO','RECEBIDO','Pedido recebido pelo Agente Malhas.')",(company,order_id))
            return {"pedido_recebido_id":order_id,"status":"RECEBIDO","repetido":False}
        finally: cursor.close()
