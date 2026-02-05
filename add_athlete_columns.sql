-- Agrega columnas faltantes a la tabla athletes
-- Ejecuta este script en el Editor SQL de Supabase

-- 1. Agregar columnas para Cardio
ALTER TABLE athletes 
ADD COLUMN IF NOT EXISTS cardio_description text,
ADD COLUMN IF NOT EXISTS cardio_days integer[]; -- Array de enteros para los días (1=Lunes, 7=Domingo)

-- 2. Agregar columnas para Suplementación (por si acaso faltan)
ALTER TABLE athletes
ADD COLUMN IF NOT EXISTS daily_supplements text,
ADD COLUMN IF NOT EXISTS chemical_supplements text;

-- 3. Comentario para verificar
COMMENT ON COLUMN athletes.cardio_days IS 'Días de cardio: 1=Lunes, 7=Domingo';
