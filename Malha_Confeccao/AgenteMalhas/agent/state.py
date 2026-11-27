import json
import sqlite3

class State:
    def __init__(self,path):
        self.db=sqlite3.connect(path)
        self.db.execute("CREATE TABLE IF NOT EXISTS pending (resource TEXT PRIMARY KEY, revision INTEGER NOT NULL, body TEXT NOT NULL)")
        self.db.execute("CREATE TABLE IF NOT EXISTS revisions (resource TEXT PRIMARY KEY, revision INTEGER NOT NULL)")
        self.db.commit()
    def pending(self,resource):
        row=self.db.execute("SELECT revision, body FROM pending WHERE resource=?",(resource,)).fetchone()
        return (row[0],json.loads(row[1])) if row else None
    def save(self,resource,revision,body):
        self.db.execute("INSERT OR REPLACE INTO pending(resource,revision,body) VALUES(?,?,?)",(resource,revision,json.dumps(body,separators=(",",":"),ensure_ascii=False))); self.db.commit()
    def done(self,resource,revision):
        self.db.execute("INSERT OR REPLACE INTO revisions(resource,revision) VALUES(?,?)",(resource,revision)); self.db.execute("DELETE FROM pending WHERE resource=?",(resource,)); self.db.commit()
    def next_revision(self,resource):
        row=self.db.execute("SELECT revision FROM revisions WHERE resource=?",(resource,)).fetchone()
        return (row[0] if row else 0)+1
    def close(self): self.db.close()
