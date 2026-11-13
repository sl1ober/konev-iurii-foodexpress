CREATE OR REPLACE PROCEDURE konev_food.add_product(
    p_name varchar,
    p_category_id uuid,
    p_price numeric,
    p_restaurant_id uuid,
    p_photo_url text,
    p_rating numeric,
    p_status konev_food.product_status,
    p_description text
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Проверяем существование ресторана
    IF NOT EXISTS (
        SELECT 1
        FROM konev_food.restaurant
        WHERE restaurant_id = p_restaurant_id
    ) THEN
        RAISE EXCEPTION 'Restaurant with ID % does not exist', p_restaurant_id;
    END IF;

    -- Проверяем существование категории
    IF NOT EXISTS (
        SELECT 1
        FROM konev_food.product_category
        WHERE category_id = p_category_id
    ) THEN
        RAISE EXCEPTION 'Product category with ID % does not exist', p_category_id;
    END IF;

    -- Добавляем блюдо
    INSERT INTO konev_food.product (
        name,
        category_id,
        price,
        restaurant_id,
        photo_url,
        rating,
        status,
        description
    )
    VALUES (
        p_name,
        p_category_id,
        p_price,
        p_restaurant_id,
        p_photo_url,
        p_rating,
        p_status,
        p_description
    );
END;
$$;
