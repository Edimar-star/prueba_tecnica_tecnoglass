#!/bin/bash
# ============================================================
# Entrypoint del contenedor backend
# 1. Crea/actualiza usuarios con hashes bcrypt reales
# 2. Arranca el servidor FastAPI
# ============================================================

set -e

echo "=== Configurando usuarios iniciales... ==="
python create_admin.py

echo "=== Iniciando servidor FastAPI... ==="
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
