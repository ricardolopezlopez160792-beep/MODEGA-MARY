@echo off
REM Inicia la aplicacion web de Bodega Mary en http://localhost:5000
REM La conexion a PostgreSQL se configura en app\config.py
cd /d "%~dp0app"
start "" http://localhost:5000
python app.py
