import hashlib, hmac, json, secrets
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from uuid import uuid4

from flask import current_app
from sqlalchemy import and_, delete, select, update
from werkzeug.security import check_password_hash, generate_password_hash

from .database import engine
from .errors import ApiError
from .tables import acesso, agente, agente_sync, cliente, cliente_provisorio, empresa, evento, item, pagamento, pedido, produto, sessao, vendedor

MONEY = Decimal("0.0001")

def now(): return datetime.now(timezone.utc)
def _id(): return secrets.randbelow(2**62) + 1
def _digest(value): return hmac.new(current_app.config["TOKEN_HASH_SECRET"].encode(), value.encode(), hashlib.sha256).hexdigest()
def _decimal(value, name, scale, positive=False):
    try: result=Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError): raise ApiError(400,"CONTRATO_INVALIDO",f"{name} invalido")
    if not result.is_finite() or result.as_tuple().exponent < -scale or result < 0 or (positive and result <= 0): raise ApiError(400,"CONTRATO_INVALIDO",f"{name} invalido")
    return result.quantize(Decimal(1).scaleb(-scale))
def _text(value, name, limit, required=True):
    result="" if value is None else str(value).strip()
    if (required and not result) or len(result)>limit: raise ApiError(400,"CONTRATO_INVALIDO",f"{name} invalido")
    return result
def _canonical(value):
    if isinstance(value, dict): return {k:_canonical(v) for k,v in sorted(value.items())}
    if isinstance(value, list): return [_canonical(v) for v in value]
    return value
def _hash(payload): return hashlib.sha256(json.dumps(_canonical(payload),ensure_ascii=False,separators=(",",":"),sort_keys=True).encode()).hexdigest()

def authenticate(request):
    scheme, _, raw=request.headers.get("Authorization","").partition(" ")
    if scheme.lower()!="bearer" or not raw.strip(): raise ApiError(401,"NAO_AUTENTICADO","Sessao nao autenticada")
    with engine().connect() as c:
        row=c.execute(select(sessao.c.id,sessao.c.vendedor_id,vendedor.c.empresa_id,vendedor.c.vendedor_id.label("codigo_vendedor"),vendedor.c.nome).join(vendedor,vendedor.c.id==sessao.c.vendedor_id).where(and_(sessao.c.token_digest==_digest(raw.strip()),sessao.c.revoked_at.is_(None),sessao.c.expires_at>now()))).mappings().first()
    if not row: raise ApiError(401,"SESSAO_INVALIDA","Sessao invalida ou expirada")
    return row

def authenticate_agent(request):
    scheme, _, raw=request.headers.get("Authorization","").partition(" ")
    if scheme.lower()!="bearer" or not raw.strip(): raise ApiError(401,"AGENTE_NAO_AUTENTICADO","Credencial tecnica ausente")
    with engine().connect() as c:
        row=c.execute(select(agente.c.id,agente.c.empresa_id,empresa.c.empresa_id.label("empresa_codigo"),agente.c.agent_guid).join(empresa,empresa.c.id==agente.c.empresa_id).where(and_(agente.c.token_digest==_digest(raw.strip()),agente.c.active.is_(True)))).mappings().first()
    if not row: raise ApiError(401,"AGENTE_NAO_AUTENTICADO","Credencial tecnica invalida")
    return row

def login(data):
    if not isinstance(data,dict) or set(data)-{"login","usuario","senha","dispositivo"}: raise ApiError(400,"CONTRATO_INVALIDO","Campos de sessao invalidos")
    login=_text(data.get("login",data.get("usuario")),"login",80).upper(); password=_text(data.get("senha"),"senha",1024)
    with engine().begin() as c:
        rows=c.execute(select(vendedor).where(and_(vendedor.c.login==login,vendedor.c.active.is_(True)))).mappings().all()
        if len(rows)!=1 or not check_password_hash(rows[0]["password_verifier"],password): raise ApiError(401,"CREDENCIAIS_INVALIDAS","Usuario ou senha invalidos")
        access=c.execute(select(acesso.c.empresa_id).where(and_(acesso.c.vendedor_id==rows[0]["id"],acesso.c.active.is_(True)))).all()
        if not access: raise ApiError(401,"ACESSO_NEGADO","Vendedor sem empresa autorizada")
        company_code=c.execute(select(empresa.c.empresa_id).where(empresa.c.id==rows[0]["empresa_id"])).scalar_one()
        raw,refresh=secrets.token_urlsafe(32),secrets.token_urlsafe(32); c.execute(sessao.insert().values(id=_id(),vendedor_id=rows[0]["id"],token_digest=_digest(raw),refresh_digest=_digest(refresh),expires_at=now()+timedelta(seconds=current_app.config["SESSION_SECONDS"]),created_at=now()))
    return {"token_type":"Bearer","access_token":raw,"refresh_token":refresh,"expires_in":current_app.config["ACCESS_TOKEN_SECONDS"],"vendedor":{"id":rows[0]["vendedor_id"],"nome":rows[0]["nome"],"empresa":company_code}}

def renew(data):
    raw=data.get("refresh_token") if isinstance(data,dict) else None
    if not isinstance(raw,str) or not raw.strip(): raise ApiError(400,"CONTRATO_INVALIDO","refresh_token obrigatorio")
    with engine().begin() as c:
        row=c.execute(select(sessao).where(and_(sessao.c.refresh_digest==_digest(raw.strip()),sessao.c.revoked_at.is_(None),sessao.c.expires_at>now()))).mappings().first()
        if not row: raise ApiError(401,"SESSAO_INVALIDA","Refresh token invalido")
        token=secrets.token_urlsafe(32); c.execute(update(sessao).where(sessao.c.id==row["id"]).values(token_digest=_digest(token)))
    return {"token_type":"Bearer","access_token":token,"refresh_token":raw.strip(),"expires_in":current_app.config["ACCESS_TOKEN_SECONDS"]}

def companies(context):
    with engine().connect() as c: rows=c.execute(select(empresa.c.empresa_id,empresa.c.nome).join(acesso,acesso.c.empresa_id==empresa.c.id).where(and_(acesso.c.vendedor_id==context["vendedor_id"],acesso.c.active.is_(True)))).mappings().all()
    return [{"id":r["empresa_id"],"nome":r["nome"]} for r in rows]

def catalog_clients(context, term=""):
    term=_text(term,"termo",100,False)
    with engine().connect() as c:
        query=select(cliente.c.cliente_id,cliente.c.nome,cliente.c.fantasia).where(and_(cliente.c.empresa_id==context["empresa_id"],cliente.c.vendedor_id==context["codigo_vendedor"],cliente.c.active.is_(True)))
        if term:
            like=f"%{term.upper()}%"; query=query.where((cliente.c.nome.ilike(like))|(cliente.c.fantasia.ilike(like)))
        rows=c.execute(query.order_by(cliente.c.nome).limit(100)).mappings().all()
    return [{"id":x["cliente_id"],"nome":x["nome"],"fantasia":x["fantasia"] or ""} for x in rows]

def catalog_products(context):
    with engine().connect() as c: rows=c.execute(select(produto).where(and_(produto.c.empresa_id==context["empresa_id"],produto.c.active.is_(True))).order_by(produto.c.descricao)).mappings().all()
    return [{"id":x["produto_id"],"descricao":x["descricao"],"unidade":x["unidade"],"preco_unitario":None if x["preco_unitario"] is None else format(x["preco_unitario"],"f")} for x in rows]

def catalog_payments(context):
    with engine().connect() as c: rows=c.execute(select(pagamento).where(and_(pagamento.c.empresa_id==context["empresa_id"],pagamento.c.active.is_(True))).order_by(pagamento.c.descricao)).mappings().all()
    return [{"id":x["forma_pagamento_id"],"descricao":x["descricao"]} for x in rows]

def _validate(payload):
    if not isinstance(payload,dict): raise ApiError(400,"CONTRATO_INVALIDO","Pedido deve ser objeto")
    allowed={"local_id","created_at","cliente","forma_pagamento_id","prazo_dias","previsao_entrega","gerencial","observacoes","valor_total","itens"}
    if set(payload)!=allowed: raise ApiError(400,"CONTRATO_INVALIDO","Campos de pedido invalidos")
    try:
        # The local id is an opaque, scoped idempotency key.  UUID v4 is used by
        # current clients, but accepting the bounded legacy key keeps already
        # saved offline orders retryable without changing their commercial data.
        _text(payload["local_id"],"local_id",36)
        datetime.fromisoformat(_text(payload["created_at"],"created_at",40).replace("Z","+00:00"))
    except ValueError: raise ApiError(400,"CONTRATO_INVALIDO","local_id ou created_at invalido")
    client=payload["cliente"]
    if not isinstance(client,dict) or client.get("tipo") not in {"oficial","provisorio"}: raise ApiError(400,"CONTRATO_INVALIDO","cliente invalido")
    if client["tipo"]=="oficial" and not isinstance(client.get("id"),int): raise ApiError(400,"CONTRATO_INVALIDO","cliente.id obrigatorio")
    if client["tipo"]=="provisorio":
        provisional=client.get("provisorio")
        if not isinstance(provisional,dict): raise ApiError(400,"CONTRATO_INVALIDO","cliente.provisorio obrigatorio")
        required={"local_id","tipo_pessoa","nome"}
        optional={"fantasia","cpf_cnpj","telefone","inscricao_estadual","email","whatsapp","cep","logradouro","numero","complemento","bairro","cidade","uf"}
        if set(provisional)-required-optional or not required.issubset(provisional): raise ApiError(400,"CONTRATO_INVALIDO","cliente.provisorio invalido")
        _text(provisional["local_id"],"cliente.provisorio.local_id",100)
        if _text(provisional["tipo_pessoa"],"cliente.provisorio.tipo_pessoa",2).upper() not in {"PF","PJ"}: raise ApiError(400,"CONTRATO_INVALIDO","cliente.provisorio.tipo_pessoa invalido")
        _text(provisional["nome"],"cliente.provisorio.nome",100)
        for key,limit in {"fantasia":100,"cpf_cnpj":14,"telefone":20,"inscricao_estadual":30,"email":254,"whatsapp":20,"cep":8,"logradouro":150,"numero":20,"complemento":100,"bairro":100,"cidade":100,"uf":2}.items(): _text(provisional.get(key),f"cliente.provisorio.{key}",limit,False)
    values=payload["itens"]
    if not isinstance(values,list) or not values: raise ApiError(400,"CONTRATO_INVALIDO","itens obrigatorio")
    calculated=Decimal("0")
    for value in values:
        if not isinstance(value,dict): raise ApiError(400,"CONTRATO_INVALIDO","item invalido")
        quantity=_decimal(value.get("quantidade"),"quantidade",6,True); unit=_decimal(value.get("valor_unitario"),"valor_unitario",4); subtotal=_decimal(value.get("subtotal"),"subtotal",4)
        if (quantity*unit).quantize(MONEY,rounding=ROUND_HALF_UP)!=subtotal: raise ApiError(400,"CONTRATO_INVALIDO","subtotal diverge do pedido original")
        calculated+=subtotal
    if _decimal(payload["valor_total"],"valor_total",4)!=calculated: raise ApiError(400,"CONTRATO_INVALIDO","valor_total diverge dos itens")

def _view(row): return {"id":row["pedido_nuvem_id"],"pedido_local_id":row["pedido_local_id"],"status":row["status"],"recebido_em":row["received_at"].isoformat(),"processado_em":row["processed_at"].isoformat() if row["processed_at"] else None}
def receive(payload, context):
    _validate(payload); digest=_hash(payload)
    with engine().begin() as c:
        old=c.execute(select(pedido).where(and_(pedido.c.empresa_id==context["empresa_id"],pedido.c.vendedor_id==context["vendedor_id"],pedido.c.pedido_local_id==payload["local_id"]))).mappings().first()
        if old:
            if old["payload_hash"]!=digest: raise ApiError(409,"OPERACAO_CONFLITANTE","UUID ja utilizado com outro pedido")
            return _view(old),True
        order_id=_id(); cloud_id=str(uuid4()); received=now()
        if payload["cliente"]["tipo"] == "provisorio":
            provisional=payload["cliente"]["provisorio"]
            local_id=_text(provisional.get("local_id"),"cliente.provisorio.local_id",100)
            existing_provisional=c.execute(select(cliente_provisorio.c.id).where(and_(cliente_provisorio.c.empresa_id==context["empresa_id"],cliente_provisorio.c.vendedor_id==context["vendedor_id"],cliente_provisorio.c.local_id==local_id))).first()
            if existing_provisional:
                c.execute(update(cliente_provisorio).where(cliente_provisorio.c.id==existing_provisional[0]).values(payload_json=provisional))
            else:
                c.execute(cliente_provisorio.insert().values(id=_id(),empresa_id=context["empresa_id"],vendedor_id=context["vendedor_id"],local_id=local_id,payload_json=provisional,created_at=received))
        c.execute(pedido.insert().values(id=order_id,pedido_nuvem_id=cloud_id,empresa_id=context["empresa_id"],vendedor_id=context["vendedor_id"],pedido_local_id=payload["local_id"],payload_hash=digest,payload_json=payload,status="RECEBIDO_NUVEM",created_at=datetime.fromisoformat(payload["created_at"].replace("Z","+00:00")),received_at=received))
        for number,value in enumerate(payload["itens"],1): c.execute(item.insert().values(pedido_id=order_id,sequencia=number,produto_id=value["produto_id"],descricao_original=value["descricao"],unidade=value["unidade"],quantidade=_decimal(value["quantidade"],"quantidade",6),preco_unitario=_decimal(value["valor_unitario"],"valor_unitario",4),subtotal=_decimal(value["subtotal"],"subtotal",4)))
        c.execute(evento.insert().values(id=_id(),pedido_id=order_id,tipo="RECEBIDO_NUVEM",status="RECEBIDO_NUVEM",descricao="Pedido preservado para processamento futuro pelo Agente",created_at=received))
    return {"id":cloud_id,"pedido_local_id":payload["local_id"],"status":"RECEBIDO_NUVEM","recebido_em":received.isoformat(),"processado_em":None},False

def list_orders(context):
    with engine().connect() as c: rows=c.execute(select(pedido).where(and_(pedido.c.empresa_id==context["empresa_id"],pedido.c.vendedor_id==context["vendedor_id"])).order_by(pedido.c.received_at.desc())).mappings().all()
    return [_view(x) for x in rows]
def get_order(context, cloud_id):
    with engine().connect() as c: row=c.execute(select(pedido).where(and_(pedido.c.pedido_nuvem_id==cloud_id,pedido.c.empresa_id==context["empresa_id"],pedido.c.vendedor_id==context["vendedor_id"]))).mappings().first()
    if not row: raise ApiError(404,"PEDIDO_NAO_ENCONTRADO","Pedido nao encontrado")
    return _view(row)

def claim_order(request):
    """Atomically reserve one pending (or expired) order for its technical agent."""
    context=authenticate_agent(request); until=now()+timedelta(seconds=current_app.config["AGENT_CLAIM_SECONDS"])
    with engine().begin() as c:
        # PostgreSQL locks the selected row; the conditional UPDATE also makes this
        # safe on SQLite, which is used by the local contract tests.
        candidate=c.execute(select(pedido.c.id).where(and_(pedido.c.empresa_id==context["empresa_id"],((pedido.c.status=="RECEBIDO_NUVEM")|and_(pedido.c.status=="CLAIMED",pedido.c.claim_expires_at<now())))).order_by(pedido.c.received_at).limit(1).with_for_update(skip_locked=True)).scalar()
        if candidate is None: return {"pedido":None}
        changed=c.execute(update(pedido).where(and_(pedido.c.id==candidate,pedido.c.empresa_id==context["empresa_id"],((pedido.c.status=="RECEBIDO_NUVEM")|and_(pedido.c.status=="CLAIMED",pedido.c.claim_expires_at<now())))).values(status="CLAIMED",claimed_by_agent_id=context["id"],claim_expires_at=until,attempts=pedido.c.attempts+1)).rowcount
        if not changed: return {"pedido":None}
        row=c.execute(select(pedido,vendedor.c.vendedor_id.label("vendedor_codigo")).join(vendedor,vendedor.c.id==pedido.c.vendedor_id).where(pedido.c.id==candidate)).mappings().one()
        c.execute(evento.insert().values(id=_id(),pedido_id=row["id"],tipo="CLAIMED",status="CLAIMED",descricao="Reservado pelo Agente Malhas",created_at=now()))
    return {"pedido":{"id":row["pedido_nuvem_id"],"vendedor_id":row["vendedor_codigo"],"payload":row["payload_json"],"claim_expires_at":until.isoformat(),"tentativa":row["attempts"]}}

def acknowledge_order(cloud_id, body, request):
    context=authenticate_agent(request)
    if not isinstance(body,dict) or set(body)!={"resultado"} or not isinstance(body["resultado"],dict): raise ApiError(400,"CONTRATO_INVALIDO","Confirmacao invalida")
    with engine().begin() as c:
        row=c.execute(select(pedido).where(and_(pedido.c.pedido_nuvem_id==cloud_id,pedido.c.empresa_id==context["empresa_id"])).with_for_update()).mappings().first()
        if not row: raise ApiError(404,"PEDIDO_NAO_ENCONTRADO","Pedido nao encontrado")
        if row["status"]=="RECEBIDO_PARMAGESTOR": return {"id":cloud_id,"status":"RECEBIDO_PARMAGESTOR","repetido":True}
        if row["status"]!="CLAIMED" or row["claimed_by_agent_id"]!=context["id"]: raise ApiError(409,"CLAIM_INVALIDO","Pedido nao esta reservado por este Agente")
        c.execute(update(pedido).where(pedido.c.id==row["id"]).values(status="RECEBIDO_PARMAGESTOR",processed_at=now(),claim_expires_at=None,agent_result_json=body["resultado"]))
        c.execute(evento.insert().values(id=_id(),pedido_id=row["id"],tipo="ACK",status="RECEBIDO_PARMAGESTOR",descricao="Confirmado pelo Agente Malhas",created_at=now()))
    return {"id":cloud_id,"status":"RECEBIDO_PARMAGESTOR","repetido":False}

def _agent_payload(payload, resource, context):
    if not isinstance(payload,dict): raise ApiError(400,"CONTRATO_INVALIDO","Snapshot deve ser objeto")
    if set(payload)-{"empresa","revision","vendedores","clientes","produtos","formas_pagamento"}: raise ApiError(400,"CONTRATO_INVALIDO","Campos de snapshot invalidos")
    company=payload.get("empresa")
    if not isinstance(company,dict) or set(company)!={"id","nome"} or not isinstance(company["id"],int) or company["id"]!=context["empresa_codigo"]:
        raise ApiError(403,"EMPRESA_NAO_AUTORIZADA","Empresa do snapshot nao autorizada para este Agente")
    name=_text(company["nome"],"empresa.nome",200)
    revision=payload.get("revision")
    if not isinstance(revision,int) or revision<0: raise ApiError(400,"CONTRATO_INVALIDO","revision invalida")
    digest=_hash(payload)
    return name,revision,digest

def _sync_guard(c, context, resource, revision, digest):
    state=c.execute(select(agente_sync).where(and_(agente_sync.c.empresa_id==context["empresa_id"],agente_sync.c.recurso==resource))).mappings().first()
    if state:
        if revision<state["revision"]: raise ApiError(409,"REVISAO_ANTIGA","Snapshot mais antigo que o aplicado")
        if revision==state["revision"]:
            if state["content_hash"]!=digest: raise ApiError(409,"REVISAO_CONFLITANTE","Mesma revisao com conteudo diferente")
            return True
    return False

def _save_sync(c, context, resource, revision, digest):
    values={"empresa_id":context["empresa_id"],"recurso":resource,"revision":revision,"content_hash":digest,"updated_at":now()}
    exists=c.execute(select(agente_sync.c.empresa_id).where(and_(agente_sync.c.empresa_id==context["empresa_id"],agente_sync.c.recurso==resource))).first()
    if exists: c.execute(update(agente_sync).where(and_(agente_sync.c.empresa_id==context["empresa_id"],agente_sync.c.recurso==resource)).values(**values))
    else: c.execute(agente_sync.insert().values(**values))

def receive_sellers_snapshot(payload, request):
    context=authenticate_agent(request); name,revision,digest=_agent_payload(payload,"vendedores",context)
    values=payload.get("vendedores")
    if not isinstance(values,list): raise ApiError(400,"CONTRATO_INVALIDO","vendedores obrigatorio")
    parsed=[]
    for value in values:
        if not isinstance(value,dict) or set(value)!={"id","nome","login","senha","ativo","empresas_permitidas"} or not isinstance(value["id"],int) or not isinstance(value["ativo"],bool) or not isinstance(value["empresas_permitidas"],list): raise ApiError(400,"CONTRATO_INVALIDO","vendedor invalido")
        allowed=set(value["empresas_permitidas"])
        if not allowed or any(not isinstance(x,int) for x in allowed): raise ApiError(400,"CONTRATO_INVALIDO","empresas_permitidas invalida")
        parsed.append((value["id"],_text(value["nome"],"vendedor.nome",200),_text(value["login"],"vendedor.login",80).upper(),_text(value["senha"],"vendedor.senha",1024),value["ativo"],allowed))
    if len({x[0] for x in parsed})!=len(parsed) or len({x[2] for x in parsed})!=len(parsed): raise ApiError(400,"CONTRATO_INVALIDO","vendedor duplicado")
    with engine().begin() as c:
        if _sync_guard(c,context,"vendedores",revision,digest): return {"empresa_id":context["empresa_codigo"],"revision":revision,"repetido":True}
        current=c.execute(select(vendedor.c.id,vendedor.c.vendedor_id).where(vendedor.c.empresa_id==context["empresa_id"])).mappings().all()
        existing={x["vendedor_id"]:x["id"] for x in current}
        c.execute(update(empresa).where(empresa.c.id==context["empresa_id"]).values(nome=name,active=True))
        for seller_id,seller_name,login_name,password,active,allowed in parsed:
            internal=existing.get(seller_id)
            if internal: c.execute(update(vendedor).where(vendedor.c.id==internal).values(nome=seller_name,login=login_name,password_verifier=generate_password_hash(password),active=active))
            else:
                result=c.execute(vendedor.insert().values(empresa_id=context["empresa_id"],vendedor_id=seller_id,nome=seller_name,login=login_name,password_verifier=generate_password_hash(password),active=active)); internal=result.inserted_primary_key[0]
            c.execute(delete(acesso).where(acesso.c.vendedor_id==internal))
            company_rows=c.execute(select(empresa.c.id,empresa.c.empresa_id).where(empresa.c.empresa_id.in_(allowed))).all()
            if {x[1] for x in company_rows}!=allowed: raise ApiError(400,"CONTRATO_INVALIDO","Empresa permitida inexistente")
            for company_id,_ in company_rows: c.execute(acesso.insert().values(vendedor_id=internal,empresa_id=company_id,active=active))
        for seller_id,internal in existing.items():
            if seller_id not in {x[0] for x in parsed}: c.execute(update(vendedor).where(vendedor.c.id==internal).values(active=False)); c.execute(update(acesso).where(acesso.c.vendedor_id==internal).values(active=False))
        _save_sync(c,context,"vendedores",revision,digest)
    return {"empresa_id":context["empresa_codigo"],"revision":revision,"repetido":False}

def receive_catalog_snapshot(payload, request):
    context=authenticate_agent(request); name,revision,digest=_agent_payload(payload,"catalogo",context)
    if set(payload)!={"empresa","revision","clientes","produtos","formas_pagamento"}: raise ApiError(400,"CONTRATO_INVALIDO","Campos de catalogo invalidos")
    def list_of(key):
        value=payload.get(key)
        if not isinstance(value,list): raise ApiError(400,"CONTRATO_INVALIDO",f"{key} obrigatorio")
        return value
    clients=list_of("clientes"); products=list_of("produtos"); payments=list_of("formas_pagamento")
    def unique(rows,key):
        if any(not isinstance(x,dict) or not isinstance(x.get("id"),int) for x in rows) or len({x["id"] for x in rows})!=len(rows): raise ApiError(400,"CONTRATO_INVALIDO",f"{key} invalido")
    unique(clients,"clientes"); unique(products,"produtos"); unique(payments,"formas_pagamento")
    with engine().begin() as c:
        if _sync_guard(c,context,"catalogo",revision,digest): return {"empresa_id":context["empresa_codigo"],"revision":revision,"repetido":True}
        c.execute(update(empresa).where(empresa.c.id==context["empresa_id"]).values(nome=name,active=True))
        c.execute(delete(cliente).where(cliente.c.empresa_id==context["empresa_id"])); c.execute(delete(produto).where(produto.c.empresa_id==context["empresa_id"])); c.execute(delete(pagamento).where(pagamento.c.empresa_id==context["empresa_id"]))
        for x in clients:
            if set(x)!={"id","vendedor_id","nome","fantasia","ativo"} or not isinstance(x["vendedor_id"],int) or not isinstance(x["ativo"],bool): raise ApiError(400,"CONTRATO_INVALIDO","cliente invalido")
            c.execute(cliente.insert().values(empresa_id=context["empresa_id"],cliente_id=x["id"],vendedor_id=x["vendedor_id"],nome=_text(x["nome"],"cliente.nome",200),fantasia=_text(x["fantasia"],"cliente.fantasia",200,False) or None,active=x["ativo"]))
        for x in products:
            if set(x)!={"id","descricao","unidade","preco_unitario","ativo"} or not isinstance(x["ativo"],bool): raise ApiError(400,"CONTRATO_INVALIDO","produto invalido")
            price=None if x["preco_unitario"] is None else _decimal(x["preco_unitario"],"produto.preco_unitario",4)
            c.execute(produto.insert().values(empresa_id=context["empresa_id"],produto_id=x["id"],descricao=_text(x["descricao"],"produto.descricao",240),unidade=_text(x["unidade"],"produto.unidade",12),preco_unitario=price,active=x["ativo"]))
        for x in payments:
            if set(x)!={"id","descricao","ativo"} or not isinstance(x["ativo"],bool): raise ApiError(400,"CONTRATO_INVALIDO","forma_pagamento invalida")
            c.execute(pagamento.insert().values(empresa_id=context["empresa_id"],forma_pagamento_id=x["id"],descricao=_text(x["descricao"],"forma_pagamento.descricao",120),active=x["ativo"]))
        _save_sync(c,context,"catalogo",revision,digest)
    return {"empresa_id":context["empresa_codigo"],"revision":revision,"repetido":False}
