"""Persistent relay moderation metadata, separate from the WGU account database."""
import os
import sqlite3
import time
from pathlib import Path
from contextlib import contextmanager


class ModerationStore:
    def __init__(self, path=None):
        self.path = Path(path or os.getenv("LFG_MODERATION_DB", str(Path(__file__).parent / "data" / "moderation.sqlite")))

    @contextmanager
    def connect(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        db = sqlite3.connect(self.path, timeout=3)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA journal_mode=WAL")
        db.executescript("""
            CREATE TABLE IF NOT EXISTS steam_blocks (
                steam_id TEXT PRIMARY KEY, reason TEXT NOT NULL, actor TEXT NOT NULL, created REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS moderation_audit (
                id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp REAL NOT NULL,
                actor TEXT NOT NULL, action TEXT NOT NULL, target TEXT NOT NULL, reason TEXT NOT NULL
            );
        """)
        try:
            with db:
                yield db
        finally:
            db.close()

    def blocked(self, steam_id):
        with self.connect() as db:
            return db.execute("SELECT 1 FROM steam_blocks WHERE steam_id=?", (steam_id,)).fetchone() is not None

    @staticmethod
    def record(db, actor, action, target, reason):
        db.execute("INSERT INTO moderation_audit(timestamp,actor,action,target,reason) VALUES(?,?,?,?,?)",
                   (time.time(), actor, action, target, reason))

    def block(self, steam_id, reason, actor):
        with self.connect() as db:
            db.execute("INSERT INTO steam_blocks VALUES(?,?,?,?) ON CONFLICT(steam_id) DO UPDATE SET reason=excluded.reason,actor=excluded.actor,created=excluded.created",
                       (steam_id, reason, actor, time.time()))
            self.record(db, actor, "steam.block", steam_id, reason)

    def unblock(self, steam_id, reason, actor):
        with self.connect() as db:
            changed = db.execute("DELETE FROM steam_blocks WHERE steam_id=?", (steam_id,)).rowcount
            if changed:
                self.record(db, actor, "steam.unblock", steam_id, reason)
            return bool(changed)

    def removed(self, listing_id, reason, actor):
        with self.connect() as db:
            self.record(db, actor, "listing.remove", listing_id, reason)

    def overview(self):
        with self.connect() as db:
            return {
                "blocks": [dict(r) for r in db.execute("SELECT * FROM steam_blocks ORDER BY created DESC LIMIT 200")],
                "blocked_count": db.execute("SELECT COUNT(*) FROM steam_blocks").fetchone()[0],
                "audit": [dict(r) for r in db.execute("SELECT * FROM moderation_audit ORDER BY id DESC LIMIT 60")],
            }
