from contextlib import contextmanager
from typing import Generator

import pyodbc

from .config import settings

pyodbc.pooling = False


def _new_connection() -> pyodbc.Connection:
    conn = pyodbc.connect(settings.database_url, autocommit=True)
    conn.setdecoding(pyodbc.SQL_CHAR, encoding="utf-8")
    conn.setdecoding(pyodbc.SQL_WCHAR, encoding="utf-8")
    conn.setencoding(encoding="utf-8")
    return conn


@contextmanager
def get_db() -> Generator[pyodbc.Connection, None, None]:
    """Entrega una conexión y la cierra al salir del bloque with."""
    conn = _new_connection()
    try:
        yield conn
    finally:
        conn.close()


def _skip_empty_resultsets(cursor: pyodbc.Cursor) -> bool:
    while cursor.description is None:
        if not cursor.nextset():
            return False
    return True


def advance_resultset(cursor: pyodbc.Cursor) -> bool:
    """Move to the next non-empty result set. Returns False if none remain."""
    if not cursor.nextset():
        return False
    return _skip_empty_resultsets(cursor)


def rows_to_dicts(cursor: pyodbc.Cursor) -> list[dict]:
    if not _skip_empty_resultsets(cursor):
        return []
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def row_to_dict(cursor: pyodbc.Cursor) -> dict | None:
    if not _skip_empty_resultsets(cursor):
        return None
    columns = [col[0] for col in cursor.description]
    rows = cursor.fetchall()
    return dict(zip(columns, rows[0])) if rows else None
