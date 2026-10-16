# Datos de conexión a PostgreSQL. Se toman de variables de entorno (PGHOST, PGPASSWORD, ...)
# y la contraseña también puede ir en config_local.py (no se sube a GitHub).
import os

try:
    from config_local import PASSWORD as _PASSWORD
except ImportError:
    _PASSWORD = ""

DB = {
    "host": os.environ.get("PGHOST", "localhost"),
    "port": int(os.environ.get("PGPORT", "5432")),
    "dbname": os.environ.get("PGDATABASE", "bodega_mary"),
    "user": os.environ.get("PGUSER", "postgres"),
    "password": os.environ.get("PGPASSWORD", _PASSWORD),
}
