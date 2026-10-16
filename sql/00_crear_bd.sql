-- =====================================================================
-- Bodega Mary - Creación de la base de datos (ejecutar conectado a "postgres")
-- =====================================================================
DROP DATABASE IF EXISTS bodega_mary;
CREATE DATABASE bodega_mary
    WITH ENCODING 'UTF8'
         TEMPLATE template0;
