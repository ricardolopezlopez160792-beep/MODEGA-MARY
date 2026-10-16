-- =====================================================================
-- Query tuning: índices, consultas reescritas y vista materializada
-- =====================================================================
SET search_path TO bodega;

-- Índices B-Tree para los reportes de alta frecuencia
CREATE INDEX idx_venta_fecha          ON venta (fecha_hora);
CREATE INDEX idx_venta_cliente_fecha  ON venta (id_cliente, fecha_hora) INCLUDE (total);
CREATE INDEX idx_detalle_producto     ON detalle_venta (id_producto);
CREATE INDEX idx_producto_categoria   ON producto (id_categoria);
-- Agrupación física (equivalente a índice clustered en SQL Server)
CLUSTER venta USING idx_venta_fecha;

-- Vista materializada para el panel diario
CREATE MATERIALIZED VIEW mv_ventas_diarias AS
SELECT v.fecha_hora::date AS dia,
       COUNT(DISTINCT v.id_venta) AS n_ventas,
       SUM(d.subtotal) AS venta,
       SUM(d.cantidad * (d.precio_unitario - p.precio_compra)) AS ganancia
FROM venta v
JOIN detalle_venta d ON d.id_venta = v.id_venta
JOIN producto p      ON p.id_producto = d.id_producto
WHERE v.estado <> 'ANULADA'
GROUP BY v.fecha_hora::date;
CREATE UNIQUE INDEX idx_mv_ventas_diarias_dia ON mv_ventas_diarias (dia);
-- Se actualiza al cierre de caja sin bloquear lecturas:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_diarias;

ANALYZE;
