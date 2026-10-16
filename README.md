# Sistema de gestión de Bodega Mary

Proyecto final del curso **Sistemas de Gestión de Bases de Datos**. Implementa la base
`bodega_mary` (PostgreSQL 16, esquema `bodega`) descrita en el informe final y una
aplicación web sencilla en Python (Flask) conectada a ella para registrar **ventas**,
administrar **clientes** e **inventario** y consultar **reportes**.

## Contenido

```
sistema_bodega_mary/
├── sql/
│   ├── 00_crear_bd.sql            Crea la base bodega_mary
│   ├── 01_ddl.sql                 Esquema bodega: 8 tablas en 3FN con PK, FK y CHECK
│   ├── 02_dml_catalogo.sql        7 categorías, 12 proveedores, 4 medios de pago, 19 productos reales y su stock
│   ├── 03_dml_datos_prueba.sql    300 clientes y 60 000 ventas simuladas (oct-2025 a set-2026)
│   ├── 04_tabla_plana.sql         Réplica de la hoja de cálculo plana (AS-IS) para comparar
│   ├── 05_tuning.sql              Índices B-Tree, CLUSTER y vista materializada mv_ventas_diarias
│   ├── 06_transacciones.sql       Trigger de descuento de stock (ACID) y vista v_alerta_stock
│   ├── 07_vistas_app.sql          Vistas, funciones y triggers que usa la aplicación
│   └── demo_acid.sql              Demostración de COMMIT y ROLLBACK
├── app/
│   ├── app.py                     Aplicación Flask
│   ├── config.py                  Datos de conexión
│   ├── config_local.ejemplo.py    Plantilla para la contraseña local
│   ├── requirements.txt
│   ├── templates/                 Pantallas HTML
│   └── static/estilo.css
├── instalar_bd.ps1                Crea la base y ejecuta los scripts 00 a 07 en orden
└── iniciar_app.bat                Abre la aplicación en el navegador
```

## Requisitos

| Programa | Versión | Cómo instalarlo |
|---|---|---|
| PostgreSQL | 16 | `winget install PostgreSQL.PostgreSQL.16` o el instalador de https://www.postgresql.org/download/windows/ |
| Python | 3.10 o superior | Ya instalado (3.14) |
| Librerías | Flask, psycopg 3 | `pip install -r app\requirements.txt` |

Durante la instalación de PostgreSQL se elige una **contraseña para el usuario `postgres`**
(puerto 5432 por defecto). La aplicación la lee de `app/config_local.py`, que no se sube a GitHub:

```powershell
copy app\config_local.ejemplo.py app\config_local.py
```

y luego escribe tu contraseña dentro de `app\config_local.py`. También se puede usar la variable
de entorno `PGPASSWORD`.

## Puesta en marcha

Todos los comandos se ejecutan en PowerShell dentro de la carpeta `sistema_bodega_mary`.

**1. Crear la base de datos y cargar los datos** (tarda menos de un minuto):

```powershell
powershell -ExecutionPolicy Bypass -File instalar_bd.ps1
```

El script pide la contraseña de `postgres`, crea `bodega_mary`, ejecuta los scripts 00 a 07
y al final muestra cuántos productos, clientes y ventas quedaron cargados (19, 300 y 60 000).
Si PostgreSQL está en otra ruta: `instalar_bd.ps1 -PgBin "D:\PostgreSQL\16\bin"`.

> También se pueden ejecutar los scripts a mano en pgAdmin: primero `00_crear_bd.sql`
> conectado a la base `postgres`, y luego `01` a `07` conectado a `bodega_mary`.

**2. Instalar las librerías de Python** (solo la primera vez):

```powershell
python -m pip install -r app\requirements.txt
```

**3. Iniciar la aplicación:**

```powershell
.\iniciar_app.bat
```

Abre el navegador en http://localhost:5000 y deja la
aplicación corriendo. Para detenerla, cierra la ventana o pulsa `Ctrl+C`.

La conexión se configura con `app\config_local.py` (contraseña) y con las variables `PGHOST`, `PGPORT`, `PGUSER` y `PGDATABASE`.

## Qué hace la aplicación

| Pantalla | Funciones | Objetos de la base que usa |
|---|---|---|
| **Panel** | Ventas y monto del día, fiado por cobrar, alertas de reposición, últimas ventas | `v_alerta_stock`, `v_ventas`, `v_deuda_cliente` |
| **Nueva venta** | Venta con varios productos, cliente opcional, medio de pago (Efectivo, Yape, Plin, Tarjeta) y estado PAGADA o FIADO | `venta`, `detalle_venta`, triggers `trg_descontar_stock` y `trg_actualizar_total` |
| **Ventas** | Listado con filtros por fecha y estado, detalle, anulación con devolución de stock, cobro de fiado | `v_ventas`, `fn_anular_venta()` |
| **Clientes** | Búsqueda por DNI o nombre, alta y edición, límite de crédito, deuda e historial de compras | `cliente`, `v_deuda_cliente` |
| **Inventario** | Catálogo con margen y stock, filtro por categoría y por reponer, reposición de stock, alta y edición de productos | `v_catalogo`, `producto`, `inventario` |
| **Reportes** | Ventas y ganancia por mes, top 10 productos, ventas por categoría y medio de pago, mayores deudores, botón de cierre de caja | `mv_ventas_diarias`, `v_ventas_mensuales`, `v_top_productos` |

### Integridad transaccional (ACID) en la aplicación

Cada venta se registra en **una sola transacción**: la cabecera en `venta`, cada línea en
`detalle_venta`, y por cada línea el trigger `trg_descontar_stock` descuenta el inventario.
Si algún producto no tiene stock suficiente, la restricción `CHECK (stock_actual >= 0)` falla,
PostgreSQL hace **ROLLBACK** de toda la venta y la aplicación muestra
"Stock insuficiente: la venta se canceló completa (ROLLBACK)". Lo mismo ocurre si una venta
al fiado supera el límite de crédito del cliente.

Para probarlo en clase: en **Nueva venta** elige *Yogurt Gloria Fresa 1L* (stock 12) con
cantidad 20. La venta no se registra y el stock sigue en 12.

### Reportes y vista materializada

Los reportes mensuales leen `mv_ventas_diarias`, que se calcula una vez y no se recalcula
en cada consulta. Las ventas nuevas aparecen en esos reportes después de pulsar
**"Cierre de caja: actualizar"**, que ejecuta
`REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_diarias` sin bloquear las lecturas.

## Problemas comunes

| Mensaje | Solución |
|---|---|
| `password authentication failed for user "postgres"` | La contraseña no coincide con la de la instalación de PostgreSQL. |
| `database "bodega_mary" does not exist` | Falta el paso 1 (`instalar_bd.ps1`). |
| `connection refused` / `Connection timed out` | El servicio de PostgreSQL está detenido: ábrelo en *Servicios* de Windows (`postgresql-x64-16`) e inícialo. |
| `No module named 'psycopg'` | Falta el paso 2 (`pip install -r app\requirements.txt`). |
| `No se encontró psql` | PostgreSQL no está en `C:\Program Files\PostgreSQL\16`; usa el parámetro `-PgBin`. |
