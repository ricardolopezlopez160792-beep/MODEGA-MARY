-- =====================================================================
-- Integridad transaccional (ACID): descuento automático de stock
-- =====================================================================
SET search_path TO bodega;

CREATE OR REPLACE FUNCTION fn_descontar_stock() RETURNS trigger AS $$
BEGIN
    UPDATE inventario
       SET stock_actual = stock_actual - NEW.cantidad,
           ultima_actualizacion = CURRENT_TIMESTAMP
     WHERE id_producto = NEW.id_producto;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_descontar_stock
AFTER INSERT ON detalle_venta
FOR EACH ROW EXECUTE FUNCTION fn_descontar_stock();

-- Vista de alertas de reposición
CREATE OR REPLACE VIEW v_alerta_stock AS
SELECT p.nombre, i.stock_actual, i.stock_minimo
FROM inventario i JOIN producto p ON p.id_producto = i.id_producto
WHERE i.stock_actual <= i.stock_minimo;
