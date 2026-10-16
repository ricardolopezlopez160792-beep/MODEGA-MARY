-- Réplica de la hoja de cálculo plana (AS-IS) con los mismos datos, para comparar.
SET search_path TO bodega;
DROP TABLE IF EXISTS ventas_plano;
CREATE TABLE ventas_plano AS
SELECT v.id_venta::text AS id_venta, to_char(v.fecha_hora,'DD/MM/YYYY') AS fecha,
       p.nombre AS producto, c.nombre AS categoria, d.precio_unitario::text AS precio,
       d.cantidad::text AS cant, m.nombre AS medio_pago,
       COALESCE(cl.nombres || ' ' || cl.apellidos, 'Cliente ocasional') AS cliente,
       cl.telefono AS tlf_cliente, pr.razon_social AS proveedor
FROM venta v
JOIN detalle_venta d ON d.id_venta = v.id_venta
JOIN producto p      ON p.id_producto = d.id_producto
JOIN categoria c     ON c.id_categoria = p.id_categoria
JOIN proveedor pr    ON pr.id_proveedor = p.id_proveedor
JOIN medio_pago m    ON m.id_medio_pago = v.id_medio_pago
LEFT JOIN cliente cl ON cl.id_cliente = v.id_cliente;
ANALYZE ventas_plano;
