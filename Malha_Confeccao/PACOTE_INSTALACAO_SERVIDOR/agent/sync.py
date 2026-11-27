import logging
from .http_client import CommunicationError
from .receive_orders import receive

def receive_once(settings,client,receiver=receive):
    claimed=client.post("/api/v1/agente/pedidos/claim",{})["pedido"]
    if not claimed: return False
    result=receiver(settings,claimed["payload"],claimed["vendedor_id"])
    client.post("/api/v1/agente/pedidos/%s/ack" % claimed["id"],{"resultado":result})
    logging.info("Pedido %s confirmado",claimed["id"])
    return True

def run_once(settings,state,reader,client):
    sellers,clients,products,payments=reader(settings)
    company={"id":settings.empresa_id,"nome":settings.empresa_nome}
    jobs=[("vendedores","/api/v1/agente/vendedores/snapshot",{"empresa":company,"vendedores":sellers}), ("catalogo","/api/v1/agente/catalogo/snapshots",{"empresa":company,"clientes":clients,"produtos":products,"formas_pagamento":payments})]
    for resource,path,body in jobs:
        pending=state.pending(resource)
        if pending: revision,payload=pending
        else:
            revision=state.next_revision(resource); payload={**body,"revision":revision}; state.save(resource,revision,payload)
        client.post(path,payload); state.done(resource,revision)
        logging.info("Snapshot %s confirmado na revisao %s",resource,revision)
    while receive_once(settings,client): pass

def run_forever(settings,state,reader,client,sleep,should_stop=lambda:False):
    offline=False
    while not should_stop():
        try: run_once(settings,state,reader,client)
        except CommunicationError as error:
            if not offline: logging.warning("Comunicacao com a API indisponivel: %s; nova tentativa sera feita", error)
            offline=True
        else:
            if offline: logging.info("Comunicacao com a API recuperada")
            offline=False
        if should_stop(): break
        sleep(settings.retry_seconds)
    logging.info("Parada controlada solicitada")
