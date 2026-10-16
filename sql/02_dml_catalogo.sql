SET search_path TO bodega;

INSERT INTO categoria (nombre) VALUES
 ('Abarrotes'),('Bebidas'),('Lácteos'),('Limpieza'),('Aseo Personal'),('Golosinas'),('Snacks');

INSERT INTO proveedor (razon_social) VALUES
 ('Alicorp'),('Arca Continental'),('Backus'),('Gloria S.A.'),('G.W. Yichang'),
 ('Costeño Alimentos'),('Mercado Mayorista'),('Kimberly-Clark'),('Clorox Perú'),
 ('Nestlé'),('Colgate-Palmolive'),('PepsiCo (Frito Lay)');

INSERT INTO medio_pago (nombre) VALUES ('Efectivo'),('Yape'),('Plin'),('Tarjeta');

INSERT INTO producto (nombre, id_categoria, id_proveedor, unidad_venta, precio_compra, precio_venta)
SELECT p.nombre, c.id_categoria, pr.id_proveedor, p.unidad, p.compra, p.venta
FROM (VALUES
 ('Leche Evaporada Gloria Azul 400g','Lácteos','Gloria S.A.','Lata',3.50,4.20),
 ('Arroz Extra Costeño','Abarrotes','Costeño Alimentos','Kilo',3.20,4.50),
 ('Azúcar Rubia','Abarrotes','Mercado Mayorista','Kilo',2.80,3.80),
 ('Fideos Spaghetti Don Vittorio 500g','Abarrotes','Alicorp','Paquete',2.20,2.80),
 ('Aceite Primor Premium 1L','Abarrotes','Alicorp','Botella',8.50,10.50),
 ('Atún Florida Filete 170g','Abarrotes','G.W. Yichang','Lata',4.50,6.00),
 ('Gaseosa Coca Cola 1.5L','Bebidas','Arca Continental','Botella',4.50,5.50),
 ('Gaseosa Inca Kola 1.5L','Bebidas','Arca Continental','Botella',4.50,5.50),
 ('Agua San Luis sin gas 625ml','Bebidas','Arca Continental','Botella',1.00,1.50),
 ('Cerveza Pilsen Callao 630ml','Bebidas','Backus','Botella',5.50,7.00),
 ('Detergente Bolívar 140g','Limpieza','Alicorp','Bolsa',1.20,1.80),
 ('Lejía Clorox 1Kg','Limpieza','Clorox Perú','Botella',2.50,3.50),
 ('Papel Higiénico Suave (Paq. x 2)','Limpieza','Kimberly-Clark','Paquete',1.80,2.50),
 ('Papas Lays Clásicas 30g','Snacks','PepsiCo (Frito Lay)','Bolsa',1.20,1.70),
 ('Galletas Casino (Varios sabores)','Golosinas','Alicorp','Paquete',0.60,1.00),
 ('Chocolate Sublime Clásico','Golosinas','Nestlé','Unidad',1.00,1.50),
 ('Jabón de Tocador Neko','Aseo Personal','Alicorp','Unidad',2.00,2.80),
 ('Pasta Dental Colgate 75ml','Aseo Personal','Colgate-Palmolive','Caja',2.50,3.50),
 ('Yogurt Gloria Fresa 1L','Lácteos','Gloria S.A.','Botella',5.50,7.00)
) AS p(nombre,categoria,proveedor,unidad,compra,venta)
JOIN categoria c  ON c.nombre = p.categoria
JOIN proveedor pr ON pr.razon_social = p.proveedor;

INSERT INTO inventario (id_producto, stock_actual, stock_minimo)
SELECT id_producto, s.stock, s.minimo
FROM producto p JOIN (VALUES
 ('Leche Evaporada Gloria Azul 400g',48,12),('Arroz Extra Costeño',50,15),('Azúcar Rubia',50,15),
 ('Fideos Spaghetti Don Vittorio 500g',30,10),('Aceite Primor Premium 1L',24,8),('Atún Florida Filete 170g',36,10),
 ('Gaseosa Coca Cola 1.5L',40,12),('Gaseosa Inca Kola 1.5L',40,12),('Agua San Luis sin gas 625ml',30,10),
 ('Cerveza Pilsen Callao 630ml',48,12),('Detergente Bolívar 140g',50,12),('Lejía Clorox 1Kg',20,6),
 ('Papel Higiénico Suave (Paq. x 2)',30,8),('Papas Lays Clásicas 30g',24,8),('Galletas Casino (Varios sabores)',60,15),
 ('Chocolate Sublime Clásico',40,10),('Jabón de Tocador Neko',20,6),('Pasta Dental Colgate 75ml',15,5),
 ('Yogurt Gloria Fresa 1L',12,6)) AS s(nombre,stock,minimo) ON s.nombre = p.nombre;
