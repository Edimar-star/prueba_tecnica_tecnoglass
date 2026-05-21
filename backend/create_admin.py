"""
Script para crear/actualizar el usuario admin en la BD.
Ejecutar una sola vez después del seed: python create_admin.py
"""
import sys

from passlib.context import CryptContext

sys.path.insert(0, ".")

from app.core.config import settings
from app.core.database import get_db

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

USUARIOS = [
    ("admin",     "Admin123!",     "Administrador del Sistema", "ADMIN"),
    ("operador1", "Operador123!",  "Operador Uno",              "OPERADOR"),
]

with get_db() as conn:
    cursor = conn.cursor()
    for username, password, nombre, rol in USUARIOS:
        hashed = pwd.hash(password)
        cursor.execute(
            """
            MERGE dbo.Usuarios AS target
            USING (SELECT ? AS Username) AS src ON target.Username = src.Username
            WHEN MATCHED THEN
                UPDATE SET PasswordHash = ?, Nombre = ?, Rol = ?
            WHEN NOT MATCHED THEN
                INSERT (Username, PasswordHash, Nombre, Rol)
                VALUES (?, ?, ?, ?);
            """,
            (username, hashed, nombre, rol, username, hashed, nombre, rol),
        )
        print(f"  ✓ Usuario '{username}' listo (contraseña: {password})")

print("\nUsuarios creados correctamente.")
