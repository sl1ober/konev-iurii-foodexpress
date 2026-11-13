
-- FOOD-109: права пользователя inspector

-- Создание пользователя
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'inspector'
    ) THEN
        CREATE ROLE inspector LOGIN PASSWORD 'NetoSQL2025';
    ELSE
        ALTER ROLE inspector WITH LOGIN PASSWORD 'NetoSQL2025';
    END IF;
END
$$;

-- Права на схемы
GRANT ALL PRIVILEGES ON SCHEMA konev_food TO inspector;
GRANT USAGE ON SCHEMA exts TO inspector;
GRANT USAGE ON SCHEMA information_schema TO inspector;
GRANT USAGE ON SCHEMA pg_catalog TO inspector;

-- Права на существующие объекты
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA konev_food TO inspector;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA konev_food TO inspector;
GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA konev_food TO inspector;

-- Генерация UUID
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA exts TO inspector;

-- Права на объекты, которые будут созданы в будущем
ALTER DEFAULT PRIVILEGES IN SCHEMA konev_food
GRANT ALL PRIVILEGES ON TABLES TO inspector;

ALTER DEFAULT PRIVILEGES IN SCHEMA konev_food
GRANT ALL PRIVILEGES ON SEQUENCES TO inspector;

ALTER DEFAULT PRIVILEGES IN SCHEMA konev_food
GRANT ALL PRIVILEGES ON ROUTINES TO inspector;
