SET search_path TO bodega;
-- Stock antes de las ventas
SELECT p.nombre, i.stock_actual FROM inventario i JOIN producto p USING (id_producto)
WHERE p.nombre IN ('Gaseosa Coca Cola 1.5L', 'Yogurt Gloria Fresa 1L');

-- Transacción 1 (válida): 2 Coca Cola 1.5L pagadas con Yape
BEGIN;
INSERT INTO venta (id_medio_pago, total) VALUES (2, 11.00);
INSERT INTO detalle_venta (id_venta, id_producto, cantidad, precio_unitario)
SELECT currval('venta_id_venta_seq'), id_producto, 2, 5.50
FROM producto WHERE nombre = 'Gaseosa Coca Cola 1.5L';
COMMIT;

-- Transacción 2 (inválida): 20 yogures cuando solo hay 12 en stock
BEGIN;
INSERT INTO venta (id_medio_pago, total) VALUES (1, 140.00);
INSERT INTO detalle_venta (id_venta, id_producto, cantidad, precio_unitario)
SELECT currval('venta_id_venta_seq'), id_producto, 20, 7.00
FROM producto WHERE nombre = 'Yogurt Gloria Fresa 1L';
ROLLBACK;

-- Stock después: la Coca Cola bajó en 2 y el yogur no cambió
SELECT p.nombre, i.stock_actual FROM inventario i JOIN producto p USING (id_producto)
WHERE p.nombre IN ('Gaseosa Coca Cola 1.5L', 'Yogurt Gloria Fresa 1L');
