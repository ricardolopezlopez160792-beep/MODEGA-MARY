-- Carga masiva de datos de prueba SIMULADOS (12 meses) para medir rendimiento.
SET search_path TO bodega;
SELECT setseed(0.42);

INSERT INTO cliente (dni, nombres, apellidos, telefono, limite_credito, fecha_registro)
SELECT lpad((10000000 + g)::text, 8, '0'),
       (ARRAY['Rosa','Juan','María','Carlos','Lucía','Pedro','Ana','Luis','Carmen','Jorge'])[1 + g % 10],
       (ARRAY['Quispe','Huamán','Flores','Mamani','Torres','Rojas','Castillo','Ramos'])[1 + g % 8] || ' ' || g,
       '9' || lpad((g * 7919 % 100000000)::text, 8, '0'),
       (ARRAY[0, 50, 100, 150])[1 + g % 4],
       DATE '2025-10-01' + (g % 300)
FROM generate_series(1, 300) g;

-- 60 000 ventas entre el 01/10/2025 y el 30/09/2026 (aprox. 165 por día)
INSERT INTO venta (fecha_hora, id_cliente, id_medio_pago, estado)
SELECT TIMESTAMP '2025-10-01 08:00' + (floor(random()*365) || ' days')::interval
                                    + (floor(random()*840) || ' minutes')::interval,
       CASE WHEN random() < 0.35 THEN 1 + floor(random()*300)::int END,
       CASE WHEN r < 0.55 THEN 1 WHEN r < 0.85 THEN 2 WHEN r < 0.95 THEN 3 ELSE 4 END,
       CASE WHEN random() < 0.05 THEN 'FIADO' ELSE 'PAGADA' END
FROM (SELECT random() AS r FROM generate_series(1, 60000)) s;

-- 1 a 4 productos distintos por venta
INSERT INTO detalle_venta (id_venta, id_producto, cantidad, precio_unitario)
SELECT v.id_venta, p.id_producto, 1 + floor(random()*3)::int, p.precio_venta
FROM venta v
CROSS JOIN LATERAL (
    SELECT id_producto, precio_venta FROM producto
    ORDER BY random() + v.id_venta * 0 LIMIT 1 + (v.id_venta % 4)
) p;

UPDATE venta v SET total = d.suma
FROM (SELECT id_venta, SUM(subtotal) AS suma FROM detalle_venta GROUP BY id_venta) d
WHERE d.id_venta = v.id_venta;

ANALYZE;
