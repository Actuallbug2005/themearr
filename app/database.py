import sqlite3
import os
from contextlib import contextmanager

DB_PATH = os.getenv("DB_PATH", "/opt/themearr/data/themearr.db")


def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    with get_conn() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS movies (
                id          INTEGER PRIMARY KEY,
                title       TEXT NOT NULL,
                year        INTEGER,
                folderName  TEXT,
                status      TEXT NOT NULL DEFAULT 'pending'
            )
        """)
        conn.commit()


@contextmanager
def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def upsert_movies(movies: list[dict]):
    with get_conn() as conn:
        conn.executemany(
            """
            INSERT INTO movies (id, title, year, folderName, status)
            VALUES (:id, :title, :year, :folderName, 'pending')
            ON CONFLICT(id) DO UPDATE SET
                title      = excluded.title,
                year       = excluded.year,
                folderName = excluded.folderName
            """,
            movies,
        )
        conn.commit()


def get_all_movies() -> list[dict]:
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT id, title, year, folderName, status FROM movies ORDER BY status, title"
        ).fetchall()
        return [dict(r) for r in rows]


def get_movie(movie_id: int) -> dict | None:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT id, title, year, folderName, status FROM movies WHERE id = ?",
            (movie_id,),
        ).fetchone()
        return dict(row) if row else None


def set_status(movie_id: int, status: str):
    with get_conn() as conn:
        conn.execute("UPDATE movies SET status = ? WHERE id = ?", (status, movie_id))
        conn.commit()
