import os
from pathlib import Path

class AgentAlreadyRunningError(RuntimeError): pass

class InstanceLock:
    """Exclusive process lock kept beside the Agent's persistent state."""
    def __init__(self,path): self.path=Path(path); self.handle=None
    def acquire(self):
        self.path.parent.mkdir(parents=True,exist_ok=True)
        self.handle=open(self.path,"a+b")
        try:
            self.handle.seek(0)
            if not self.handle.read(1): self.handle.seek(0); self.handle.write(b"0"); self.handle.flush()
            self.handle.seek(0)
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(self.handle.fileno(),msvcrt.LK_NBLCK,1)
            else:
                import fcntl
                fcntl.flock(self.handle.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
        except OSError as error:
            self.handle.close(); self.handle=None
            raise AgentAlreadyRunningError("Ja existe uma instancia do Agente Malhas para este state.db") from error
        return self
    def release(self):
        if not self.handle: return
        try:
            self.handle.seek(0)
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(self.handle.fileno(),msvcrt.LK_UNLCK,1)
            else:
                import fcntl
                fcntl.flock(self.handle.fileno(),fcntl.LOCK_UN)
        finally:
            self.handle.close(); self.handle=None
    def __enter__(self): return self.acquire()
    def __exit__(self,*_): self.release()
