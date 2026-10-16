-- =====================================================================
-- Bodega Mary - Esquema relacional normalizado (3FN) - PostgreSQL 16
-- =====================================================================
DROP SCHEMA IF EXISTS bodega CASCADE;
CREATE SCHEMA bodega;
SET search_path TO bodega;

CREATE TABLE categoria (
    id_categoria   SMALLSERIAL  PRIMARY KEY,
    nombre         VARCHAR(40)  NOT NULL UNIQUE,
    descripcion    VARCHAR(150)
);

CREATE TABLE proveedor (
    id_proveedor   SERIAL       PRIMARY KEY,
    razon_social   VARCHAR(100) NOT NULL UNIQUE,
    ruc            CHAR(11)     UNIQUE CHECK (ruc ~ '^[0-9]{11}$'),
    telefono       VARCHAR(15),
    email          VARCHAR(100),
    activo         BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE producto (
    id_producto    SERIAL        PRIMARY KEY,
    codigo_barras  VARCHAR(20)   UNIQUE,
    nombre         VARCHAR(100)  NOT NULL,
    id_categoria   SMALLINT      NOT NULL REFERENCES categoria(id_categoria),
    id_proveedor   INTEGER       NOT NULL REFERENCES proveedor(id_proveedor),
    unidad_venta   VARCHAR(15)   NOT NULL,
    precio_compra  NUMERIC(10,2) NOT NULL CHECK (precio_compra > 0),
    precio_venta   NUMERIC(10,2) NOT NULL,
    activo         BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_precio_venta CHECK (precio_venta >= precio_compra)
);

CREATE TABLE inventario (
    id_producto    INTEGER      PRIMARY KEY REFERENCES producto(id_producto) ON DELETE CASCADE,
    stock_actual   INTEGER      NOT NULL DEFAULT 0 CHECK (stock_actual >= 0),
    stock_minimo   INTEGER      NOT NULL DEFAULT 5 CHECK (stock_minimo >= 0),
    fecha_vencimiento DATE,
    ultima_actualizacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE cliente (
    id_cliente     SERIAL       PRIMARY KEY,
    dni            CHAR(8)      UNIQUE CHECK (dni ~ '^[0-9]{8}$'),
    nombres        VARCHAR(60)  NOT NULL,
    apellidos      VARCHAR(60)  NOT NULL,
    telefono       VARCHAR(15),
    direccion      VARCHAR(120),
    limite_credito NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (limite_credito >= 0),
    fecha_registro DATE         NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE medio_pago (
    id_medio_pago  SMALLSERIAL  PRIMARY KEY,
    nombre         VARCHAR(20)  NOT NULL UNIQUE
);

CREATE TABLE venta (
    id_venta       SERIAL        PRIMARY KEY,
    fecha_hora     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_cliente     INTEGER       REFERENCES cliente(id_cliente),      -- NULL = cliente ocasional
    id_medio_pago  SMALLINT      NOT NULL REFERENCES medio_pago(id_medio_pago),
    total          NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    estado         VARCHAR(10)   NOT NULL DEFAULT 'PAGADA'
                   CHECK (estado IN ('PAGADA','FIADO','ANULADA'))
);

CREATE TABLE detalle_venta (
    id_venta        INTEGER       NOT NULL REFERENCES venta(id_venta) ON DELETE CASCADE,
    id_producto     INTEGER       NOT NULL REFERENCES producto(id_producto),
    cantidad        INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario > 0),
    subtotal        NUMERIC(12,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
    PRIMARY KEY (id_venta, id_producto)
);
