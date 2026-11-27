from contextlib import contextmanager
from decimal import Decimal, InvalidOperation

@contextmanager
def connection(settings):
    import fdb
    db=fdb.connect(host=settings.fb_host,port=settings.fb_port,database=settings.fb_database,user=settings.fb_user,password=settings.fb_password,charset=settings.fb_charset)
    try:
        db.begin(tpb=bytes((fdb.isc_tpb_version3,fdb.isc_tpb_read,fdb.isc_tpb_read_committed,fdb.isc_tpb_rec_version,fdb.isc_tpb_wait)))
        yield db; db.commit()
    except Exception:
        db.rollback(); raise
    finally: db.close()

def _price(value):
    if value is None: return None
    try: value=Decimal(value)
    except (InvalidOperation,ValueError): return None
    return format(value,"f") if value >= 0 else None

def snapshot(settings):
    with connection(settings) as db:
        cursor=db.cursor()
        try:
            # Mesma regra de vendedor/login usada pela API local; nenhuma escrita Firebird.
            cursor.execute("SELECT VDR_ID,VDR_RSOCIAL_NOME,VDR_LOGIN,VDR_SENHA,VDR_STATUS FROM TB_VENDEDOR WHERE VDR_EMPRESA=?",(settings.empresa_id,))
            # Somente vendedores com login e senha de tablet podem compor a
            # projeção autenticável da API Nuvem.
            sellers=[{"id":int(r[0]),"nome":r[1] or "","login":r[2] or "","senha":r[3] or "","ativo":(r[4] or "").strip().upper()=="A","empresas_permitidas":[settings.empresa_id]} for r in cursor.fetchall() if (r[2] or "").strip() and (r[3] or "").strip()]
            # Regra já validada: cliente ativo vinculado à carteira do vendedor.
            cursor.execute("SELECT CLI_ID,CLI_VENDEDOR,CLI_RSOCIAL_NOME,CLI_FANTASIA_APELIDO,CLI_STATUS FROM TB_CLIENTE WHERE CLI_EMPRESA=?",(settings.empresa_id,))
            # A projeção da API exige carteira de vendedor; clientes sem vínculo
            # não são elegíveis para pedidos pelo aplicativo.
            clients=[{"id":int(r[0]),"vendedor_id":int(r[1]),"nome":r[2] or "","fantasia":r[3] or "","ativo":(r[4] or "").strip().upper()=="A"} for r in cursor.fetchall() if r[1] is not None]
            # Mesma seleção touch: produto ativo e grupo habilitado para mostrar.
            cursor.execute("SELECT P.PRD_ID,P.PRD_DESCRICAO,P.PRD_UN_VENDA,P.PRD_PRECO_VENDA,COALESCE(P.PRD_STATUS,'A') FROM TB_PRODUTO P JOIN TB_PROD_GRUPO G ON G.PGRU_EMPRESA=P.PRD_EMPRESA AND G.PGRU_ID=P.PRD_GRUPO WHERE P.PRD_EMPRESA=? AND COALESCE(P.PRD_STATUS,'A')<>'I' AND G.PGRU_MOSTRAR='S' ORDER BY G.PGRU_ORDEM,P.PRD_DESCRICAO",(settings.empresa_id,))
            products=[{"id":int(r[0]),"descricao":r[1] or "","unidade":r[2] or "","preco_unitario":_price(r[3]),"ativo":(r[4] or "").strip().upper()!="I"} for r in cursor.fetchall()]
            cursor.execute("SELECT FPG_ID,FPG_DESCRICAO,FPG_STATUS FROM TB_FORMA_PAGTO WHERE FPG_EMPRESA=? AND FPG_STATUS='A' ORDER BY FPG_DESCRICAO",(settings.empresa_id,))
            payments=[{"id":int(r[0]),"descricao":r[1] or "","ativo":(r[2] or "").strip().upper()=="A"} for r in cursor.fetchall()]
        finally: cursor.close()
    return sellers,clients,products,payments
