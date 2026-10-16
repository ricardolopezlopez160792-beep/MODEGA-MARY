# =====================================================================
# Bodega Mary - Crea la base bodega_mary y ejecuta todos los scripts SQL
# Uso:  powershell -ExecutionPolicy Bypass -File instalar_bd.ps1
# =====================================================================
param(
    [string]$PgBin   = "C:\Program Files\PostgreSQL\16\bin",
    [string]$Usuario = "postgres",
    [string]$Servidor = "localhost",
    [int]$Puerto     = 5432
)

$ErrorActionPreference = "Stop"
$psql = Join-Path $PgBin "psql.exe"
if (-not (Test-Path $psql)) {
    Write-Host "No se encontró psql en $PgBin. Instala PostgreSQL 16 o indica la ruta con -PgBin." -ForegroundColor Red
    exit 1
}

if (-not $env:PGPASSWORD) {
    $seguro = Read-Host "Contraseña del usuario $Usuario de PostgreSQL" -AsSecureString
    $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro))
}
$env:PGCLIENTENCODING = "UTF8"
$env:PGOPTIONS = "-c client_min_messages=warning"

$sql = Join-Path $PSScriptRoot "sql"
function Ejecutar($base, $archivo) {
    Write-Host ">> $archivo" -ForegroundColor Cyan
    & $psql -h $Servidor -p $Puerto -U $Usuario -d $base -v ON_ERROR_STOP=1 -q -f (Join-Path $sql $archivo)
    if ($LASTEXITCODE -ne 0) { throw "Falló $archivo" }
}

Ejecutar "postgres"    "00_crear_bd.sql"
Ejecutar "bodega_mary" "01_ddl.sql"
Ejecutar "bodega_mary" "02_dml_catalogo.sql"
Ejecutar "bodega_mary" "03_dml_datos_prueba.sql"
Ejecutar "bodega_mary" "04_tabla_plana.sql"
Ejecutar "bodega_mary" "05_tuning.sql"
Ejecutar "bodega_mary" "06_transacciones.sql"
Ejecutar "bodega_mary" "07_vistas_app.sql"

Write-Host "`nBase bodega_mary lista." -ForegroundColor Green
& $psql -h $Servidor -p $Puerto -U $Usuario -d bodega_mary -c "SELECT (SELECT COUNT(*) FROM bodega.producto) AS productos, (SELECT COUNT(*) FROM bodega.cliente) AS clientes, (SELECT COUNT(*) FROM bodega.venta) AS ventas;"
