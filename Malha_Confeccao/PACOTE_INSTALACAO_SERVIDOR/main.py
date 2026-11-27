import argparse, logging, time
from logging.handlers import RotatingFileHandler
from pathlib import Path
from agent.config import Settings
from agent.http_client import Client
from agent.instance_lock import AgentAlreadyRunningError, InstanceLock
from agent.read_source import snapshot
from agent.state import State
from agent.sync import run_forever, run_once

def configure_logging(settings):
    path=Path(settings.log_path); path.parent.mkdir(parents=True,exist_ok=True)
    handler=RotatingFileHandler(path,maxBytes=settings.log_max_bytes,backupCount=settings.log_backup_count,encoding="utf-8")
    logging.basicConfig(level=logging.INFO,format="%(asctime)s %(levelname)s %(message)s",handlers=[handler],force=True)

def main():
    parser=argparse.ArgumentParser(); parser.add_argument("--once",action="store_true"); args=parser.parse_args()
    settings=Settings.from_env(); configure_logging(settings)
    lock=InstanceLock(settings.state_path+".lock")
    try: lock.acquire()
    except AgentAlreadyRunningError as error:
        logging.error("%s",error); return 2
    state=None
    try:
        state=State(settings.state_path); client=Client(settings.api_url,settings.token)
        logging.info("Agente Malhas iniciado para empresa %s",settings.empresa_id)
        if args.once: run_once(settings,state,snapshot,client)
        else: run_forever(settings,state,snapshot,client,time.sleep,lambda:Path(settings.stop_file).exists())
    except KeyboardInterrupt:
        logging.info("Encerramento controlado por operador")
    except Exception:
        logging.exception("Erro inesperado; o supervisor podera reiniciar o Agente")
        return 1
    finally:
        if state: state.close()
        lock.release()
    logging.info("Agente Malhas encerrado controladamente")
    return 0
if __name__=="__main__": raise SystemExit(main())
