
CREATE OR REPLACE FUNCTION konev_food.get_statistic()
RETURNS TABLE (
    restaurant_name text,
    best_product_name text,
    total_amount numeric,
    avg_amount numeric,
    best_user text
)
LANGUAGE sql
STABLE
AS $$
    -- Получаем только доставленные заказы
    WITH delivered_orders AS MATERIALIZED (
        SELECT
            o.order_id,
            o.restaurant_id,
            o.client_id,
            o.total_amount
        FROM konev_food."order" o
        WHERE o.status = 'delivered'
    ),

    -- Считаем общую и среднюю сумму заказов ресторана
    restaurant_stats AS (
        SELECT
            restaurant_id,
            SUM(total_amount) AS total_amount,
            AVG(total_amount) AS avg_amount
        FROM delivered_orders
        GROUP BY restaurant_id
    ),

    -- Считаем количество проданных единиц каждого блюда
    product_sales AS (
        SELECT
            d.restaurant_id,
            os.product_id,
            SUM(os.quantity) AS quantity_sold
        FROM delivered_orders d
        JOIN konev_food.order_structure os
            ON os.order_id = d.order_id
        GROUP BY d.restaurant_id, os.product_id
    ),

    -- Выбираем самое покупаемое блюдо ресторана
    best_products AS (
        SELECT DISTINCT ON (ps.restaurant_id)
            ps.restaurant_id,
            p.name AS best_product_name
        FROM product_sales ps
        JOIN konev_food.product p
            ON p.product_id = ps.product_id
        ORDER BY
            ps.restaurant_id,
            ps.quantity_sold DESC,
            random()
    ),

    -- Считаем количество доставленных заказов каждого клиента
    client_orders AS (
        SELECT
            restaurant_id,
            client_id,
            COUNT(*) AS order_count
        FROM delivered_orders
        GROUP BY restaurant_id, client_id
    ),

    -- Выбираем клиента с наибольшим количеством заказов
    best_clients AS (
        SELECT DISTINCT ON (co.restaurant_id)
            co.restaurant_id,
            c.login AS best_user
        FROM client_orders co
        JOIN konev_food.client c
            ON c.client_id = co.client_id
        ORDER BY
            co.restaurant_id,
            co.order_count DESC,
            random()
    )

    -- Формируем итоговую таблицу
    SELECT
        r.name::text AS restaurant_name,
        bp.best_product_name::text,
        rs.total_amount,
        rs.avg_amount,
        bc.best_user::text
    FROM konev_food.restaurant r
    LEFT JOIN restaurant_stats rs
        ON rs.restaurant_id = r.restaurant_id
    LEFT JOIN best_products bp
        ON bp.restaurant_id = r.restaurant_id
    LEFT JOIN best_clients bc
        ON bc.restaurant_id = r.restaurant_id;
$$;

