#!/bin/bash
# ============================================================
# Tecnoglass — Inicialización de base de datos
# Funciona tanto dentro de Docker como en ejecución local.
#
# Variables de entorno (todas tienen valor por defecto):
#   SQLCMD_PATH   ruta al ejecutable sqlcmd  (defecto: sqlcmd en PATH)
#   DB_SERVER     host del SQL Server         (defecto: localhost)
#   DB_USER       usuario                     (defecto: sa)
#   DB_PASSWORD   contraseña                  (defecto: TecnoGlass2024!)
#   SQL_DIR       directorio con los .sql     (defecto: directorio del script)
#
# Uso local (con sqlcmd instalado en el sistema):
#   bash database/init.sh
#
# Para conectar a un servidor remoto:
#   DB_SERVER=192.168.1.10 DB_PASSWORD=MiClave bash database/init.sh
# ============================================================

set -e

SQLCMD="${SQLCMD_PATH:-sqlcmd}"
SERVER="${DB_SERVER:-localhost}"
USER="${DB_USER:-sa}"
PASS="${DB_PASSWORD:-TecnoGlass2024!}"
SQL_DIR="${SQL_DIR:-$(dirname "$0")}"

echo "=== Verificando si la BD ya está inicializada... ==="

RESULT=$($SQLCMD -S "$SERVER" -U "$USER" -P "$PASS" -C \
  -Q "IF DB_ID('TecnoglassDB') IS NOT NULL AND EXISTS (SELECT 1 FROM TecnoglassDB.sys.tables WHERE name='Estaciones') SELECT 'OK' ELSE SELECT 'INIT'" \
  -h -1 2>/dev/null | tr -d ' \r\n')

if [ "$RESULT" = "OK" ]; then
  echo ">>> TecnoglassDB ya inicializada. Omitiendo scripts."
  exit 0
fi

echo "=== Inicializando base de datos (primera vez)... ==="

echo "  [1/3] Creando tablas..."
$SQLCMD -S "$SERVER" -U "$USER" -P "$PASS" -C -i "$SQL_DIR/01_DDL_tablas.sql"
echo "  [2/3] Creando Stored Procedures..."
$SQLCMD -S "$SERVER" -U "$USER" -P "$PASS" -C -i "$SQL_DIR/02_SP_produccion.sql"
echo "  [3/3] Cargando datos iniciales..."
$SQLCMD -S "$SERVER" -U "$USER" -P "$PASS" -C -i "$SQL_DIR/03_seed_data.sql"

echo "=== Base de datos inicializada correctamente. ==="
