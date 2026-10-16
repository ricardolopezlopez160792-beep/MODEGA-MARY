-- =====================================================================
-- Vistas, funciones y triggers que usa la aplicación web
-- (se ejecuta después de 01..06)
-- =====================================================================
SET search_path TO bodega;

-- Total de la venta siempre igual a la suma de su detalle
CREATE OR REPLACE FUNCTION fn_actualizar_total() RETURNS trigger AS $$
BEGIN
    UPDATE venta
       SET total = (SELECT COALESCE(SUM(subtotal), 0)
                      FROM detalle_venta WHERE id_venta = NEW.id_venta)
     WHERE id_venta = NEW.id_venta;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_actualizar_total
AFTER INSERT ON detalle_venta
FOR EACH ROW EXECUTE FUNCTION fn_actualizar_total();

-- Anulación de una venta: devuelve el stock y marca la venta como ANULADA
CREATE OR REPLACE FUNCTION fn_anular_venta(p_id_venta INTEGER) RETURNS VOID AS $$
DECLARE
    v_estado VARCHAR(10);
BEGIN
    SELECT estado INTO v_estado FROM venta WHERE id_venta = p_id_venta FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La venta % no existe', p_id_venta;
    END IF;
    IF v_estado = 'ANULADA' THEN
        RAISE EXCEPTION 'La venta % ya estaba anulada', p_id_venta;
    END IF;

    UPDATE inventario i
       SET stock_actual = i.stock_actual + d.cantidad,
           ultima_actualizacion = CURRENT_TIMESTAMP
      FROM detalle_venta d
     WHERE d.id_venta = p_id_venta AND d.id_producto = i.id_producto;

    UPDATE venta SET estado = 'ANULADA' WHERE id_venta = p_id_venta;
END;
$$ LANGUAGE plpgsql;

-- Catálogo con stock, categoría y proveedor
CREATE OR REPLACE VIEW v_catalogo AS
SELECT p.id_producto, p.codigo_barras, p.nombre, c.nombre AS categoria,
       pr.razon_social AS proveedor, p.unidad_venta,
       p.precio_compra, p.precio_venta,
       ROUND((p.precio_venta - p.precio_compra) / p.precio_compra * 100, 1) AS margen_pct,
       i.stock_actual, i.stock_minimo, i.fecha_vencimiento,
       (i.stock_actual <= i.stock_minimo) AS requiere_reposicion,
       p.activo
FROM producto p
JOIN categoria c   ON c.id_categoria = p.id_categoria
JOIN proveedor pr  ON pr.id_proveedor = p.id_proveedor
JOIN inventario i  ON i.id_producto = p.id_producto;

-- Cabecera de ventas con cliente y medio de pago
CREATE OR REPLACE VIEW v_ventas AS
SELECT v.id_venta, v.fecha_hora, v.total, v.estado,
       m.nombre AS medio_pago, v.id_cliente,
       COALESCE(cl.nombres || ' ' || cl.apellidos, 'Cliente ocasional') AS cliente,
       (SELECT COUNT(*) FROM detalle_venta d WHERE d.id_venta = v.id_venta) AS n_items
FROM venta v
JOIN medio_pago m    ON m.id_medio_pago = v.id_medio_pago
LEFT JOIN cliente cl ON cl.id_cliente = v.id_cliente;

-- Deuda (fiado) acumulada por cliente
CREATE OR REPLACE VIEW v_deuda_cliente AS
SELECT cl.id_cliente, cl.dni, cl.nombres, cl.apellidos, cl.telefono,
       cl.limite_credito,
       COALESCE(SUM(v.total) FILTER (WHERE v.estado = 'FIADO'), 0) AS deuda,
       COUNT(v.id_venta) FILTER (WHERE v.estado <> 'ANULADA')     AS n_compras,
       MAX(v.fecha_hora) AS ultima_compra
FROM cliente cl
LEFT JOIN venta v ON v.id_cliente = cl.id_cliente
GROUP BY cl.id_cliente;

-- Ranking de productos más vendidos
CREATE OR REPLACE VIEW v_top_productos AS
SELECT p.nombre, c.nombre AS categoria,
       SUM(d.cantidad) AS unidades,
       SUM(d.subtotal) AS venta,
       SUM(d.cantidad * (d.precio_unitario - p.precio_compra)) AS ganancia
FROM detalle_venta d
JOIN venta v     ON v.id_venta = d.id_venta
JOIN producto p  ON p.id_producto = d.id_producto
JOIN categoria c ON c.id_categoria = p.id_categoria
WHERE v.estado <> 'ANULADA'
GROUP BY p.nombre, c.nombre;

-- Ventas por mes
CREATE OR REPLACE VIEW v_ventas_mensuales AS
SELECT date_trunc('month', dia)::date AS mes,
       SUM(n_ventas) AS n_ventas, SUM(venta) AS venta, SUM(ganancia) AS ganancia
FROM mv_ventas_diarias
GROUP BY 1;

ANALYZE;
