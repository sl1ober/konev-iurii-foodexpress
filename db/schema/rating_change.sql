
CREATE OR REPLACE FUNCTION konev_food.rating_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_id uuid;
    v_old_type konev_food.review_entity_type;
    v_new_id uuid;
    v_new_type konev_food.review_entity_type;
BEGIN
    -- При UPDATE или DELETE запоминаем старый объект отзыва
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        v_old_id := OLD.entity_id;
        v_old_type := OLD.entity_type;
    END IF;

    -- При UPDATE или INSERT запоминаем новый объект отзыва
    IF TG_OP IN ('UPDATE', 'INSERT') THEN
        v_new_id := NEW.entity_id;
        v_new_type := NEW.entity_type;
    END IF;

    -- Пересчитываем рейтинг старого объекта
    IF v_old_type = 'product' THEN
        UPDATE konev_food.product
        SET rating = (
            SELECT AVG(rating)
            FROM konev_food.review
            WHERE entity_type = 'product'
              AND entity_id = v_old_id
        )
        WHERE product_id = v_old_id;

    ELSIF v_old_type = 'restaurant' THEN
        UPDATE konev_food.restaurant
        SET rating = (
            SELECT AVG(rating)
            FROM konev_food.review
            WHERE entity_type = 'restaurant'
              AND entity_id = v_old_id
        )
        WHERE restaurant_id = v_old_id;
    END IF;

    -- Пересчитываем рейтинг нового объекта
    IF v_new_type = 'product' THEN
        UPDATE konev_food.product
        SET rating = (
            SELECT AVG(rating)
            FROM konev_food.review
            WHERE entity_type = 'product'
              AND entity_id = v_new_id
        )
        WHERE product_id = v_new_id;

    ELSIF v_new_type = 'restaurant' THEN
        UPDATE konev_food.restaurant
        SET rating = (
            SELECT AVG(rating)
            FROM konev_food.review
            WHERE entity_type = 'restaurant'
              AND entity_id = v_new_id
        )
        WHERE restaurant_id = v_new_id;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

-- Создаём триггер пересчёта рейтинга
DROP TRIGGER IF EXISTS trg_rating_change ON konev_food.review;

CREATE TRIGGER trg_rating_change
AFTER INSERT OR UPDATE OR DELETE
ON konev_food.review
FOR EACH ROW
EXECUTE FUNCTION konev_food.rating_change();

