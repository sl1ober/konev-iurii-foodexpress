-- 05_functions_triggers.sql
-- Функции и триггеры FoodExpress

-- 1. Проверка товара и ресторана в заказе
create or replace function konev_food.check_order_product_restaurant()
returns trigger
language plpgsql
as $$
declare
    v_product_restaurant uuid;
    v_order_restaurant uuid;
begin
    select restaurant_id
    into v_product_restaurant
    from konev_food.product
    where product_id = new.product_id;

    select restaurant_id
    into v_order_restaurant
    from konev_food."order"
    where order_id = new.order_id;

    if v_product_restaurant is distinct from v_order_restaurant then
        raise exception
            'Товар не принадлежит ресторану, оформившему заказ';
    end if;

    return new;
end;
$$;

create trigger trg_check_order_product_restaurant
before insert or update of order_id, product_id
on konev_food.order_structure
for each row
execute function konev_food.check_order_product_restaurant();
-- 2. Проверка смены ресторана в заказе
create or replace function konev_food.check_order_restaurant_change()
returns trigger
language plpgsql
as $$
begin
    if new.restaurant_id is distinct from old.restaurant_id
       and exists (
           select 1
           from konev_food.order_structure os
           join konev_food.product p
               on p.product_id = os.product_id
           where os.order_id = old.order_id
             and p.restaurant_id <> new.restaurant_id
       )
    then
        raise exception
            'Нельзя изменить ресторан: в заказе есть товары другого ресторана';
    end if;

    return new;
end;
$$;

create trigger trg_check_order_restaurant_change
before update of restaurant_id
on konev_food."order"
for each row
execute function konev_food.check_order_restaurant_change();
-- 3. Проверка суммы платежа
create or replace function konev_food.check_payment_amount()
returns trigger
language plpgsql
as $$
declare
    v_order_total numeric(12,2);
begin
    select total_amount
    into v_order_total
    from konev_food."order"
    where order_id = new.order_id;

    if not found then
        raise exception 'Заказ не найден';
    end if;

    if new.amount <> v_order_total then
        raise exception
            'Сумма платежа должна совпадать с суммой заказа';
    end if;

    return new;
end;
$$;

create trigger trg_check_payment_amount
before insert or update
on konev_food.payment
for each row
execute function konev_food.check_payment_amount();


-- 4. Проверка корректности отзыва
create or replace function konev_food.check_review_target()
returns trigger
language plpgsql
as $$
declare
    v_order_client uuid;
    v_order_restaurant uuid;
begin
    select client_id, restaurant_id
    into v_order_client, v_order_restaurant
    from konev_food."order"
    where order_id = new.order_id;

    if not found then
        raise exception 'Заказ с указанным ID не найден';
    end if;

    if new.client_id is distinct from v_order_client then
        raise exception
            'Клиент может оставлять отзывы только по своим заказам';
    end if;

    if new.entity_type = 'product' then
        if not exists (
            select 1
            from konev_food.order_structure os
            where os.order_id = new.order_id
              and os.product_id = new.entity_id
        ) then
            raise exception
                'Товар отсутствует в заказе';
        end if;

    elsif new.entity_type = 'restaurant' then
        if new.entity_id is distinct from v_order_restaurant then
            raise exception
                'Отзыв относится не к ресторану данного заказа';
        end if;

    elsif new.entity_type = 'order' then
        if new.entity_id is distinct from new.order_id then
            raise exception
                'ID отзыва о заказе должен совпадать с order_id';
        end if;
    end if;

    return new;
end;
$$;

create trigger trg_check_review_target
before insert or update
on konev_food.review
for each row
execute function konev_food.check_review_target();
-- 5. Пересчёт рейтинга
create or replace function konev_food.rating_change()
returns trigger
language plpgsql
as $$
declare
    v_old_id uuid;
    v_old_type konev_food.review_entity_type;
    v_new_id uuid;
    v_new_type konev_food.review_entity_type;
begin
    -- При UPDATE или DELETE запоминаем старый объект отзыва
    if TG_OP in ('UPDATE', 'DELETE') then
        v_old_id := old.entity_id;
        v_old_type := old.entity_type;
    end if;

    -- При UPDATE или INSERT запоминаем новый объект отзыва
    if TG_OP in ('UPDATE', 'INSERT') then
        v_new_id := new.entity_id;
        v_new_type := new.entity_type;
    end if;

    -- Пересчитываем рейтинг старого объекта
    if v_old_type = 'product' then
        update konev_food.product
        set rating = (
            select avg(rating)
            from konev_food.review
            where entity_type = 'product'
              and entity_id = v_old_id
        )
        where product_id = v_old_id;

    elsif v_old_type = 'restaurant' then
        update konev_food.restaurant
        set rating = (
            select avg(rating)
            from konev_food.review
            where entity_type = 'restaurant'
              and entity_id = v_old_id
        )
        where restaurant_id = v_old_id;
    end if;

    -- Пересчитываем рейтинг нового объекта
    if v_new_type = 'product' then
        update konev_food.product
        set rating = (
            select avg(rating)
            from konev_food.review
            where entity_type = 'product'
              and entity_id = v_new_id
        )
        where product_id = v_new_id;

    elsif v_new_type = 'restaurant' then
        update konev_food.restaurant
        set rating = (
            select avg(rating)
            from konev_food.review
            where entity_type = 'restaurant'
              and entity_id = v_new_id
        )
        where restaurant_id = v_new_id;
    end if;

    if TG_OP = 'DELETE' then
        return old;
    end if;

    return new;
end;
$$;

create trigger trg_rating_change
after insert or update or delete
on konev_food.review
for each row
execute function konev_food.rating_change();
-- 6. Обновление статуса оплаты

CREATE OR REPLACE FUNCTION konev_food.refresh_order_pay_status(
    p_order_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_pay_status konev_food.order_pay_status;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM konev_food.payment
        WHERE order_id = p_order_id
          AND status = 'success'
    ) THEN
        v_pay_status := 'paid';

    ELSIF EXISTS (
        SELECT 1
        FROM konev_food.payment
        WHERE order_id = p_order_id
          AND status = 'processing'
    ) THEN
        v_pay_status := 'pending';

    ELSIF EXISTS (
        SELECT 1
        FROM konev_food.payment
        WHERE order_id = p_order_id
          AND status = 'error'
    ) THEN
        v_pay_status := 'error';

    ELSE
        v_pay_status := 'pending';
    END IF;

    UPDATE konev_food."order"
    SET pay_status = v_pay_status
    WHERE order_id = p_order_id;
END;
$$;

create or replace function konev_food.update_order_pay_status()
returns trigger
language plpgsql
as $$
begin
    if TG_OP = 'DELETE' then
        perform konev_food.refresh_order_pay_status(old.order_id);
        return old;

    elsif TG_OP = 'UPDATE' then
        if old.order_id is distinct from new.order_id then
            perform konev_food.refresh_order_pay_status(old.order_id);
        end if;

        perform konev_food.refresh_order_pay_status(new.order_id);
        return new;

    else
        perform konev_food.refresh_order_pay_status(new.order_id);
        return new;
    end if;
end;
$$;

create trigger trg_update_order_pay_status
after insert or update or delete
on konev_food.payment
for each row
execute function konev_food.update_order_pay_status();
-- 7. Проверка изменения суммы заказа
create or replace function konev_food.check_order_total_change()
returns trigger
language plpgsql
as $$
begin
    if new.total_amount is distinct from old.total_amount
       and exists (
           select 1
           from konev_food.payment
           where order_id = old.order_id
             and amount <> new.total_amount
       )
    then
        raise exception
            'Нельзя изменить сумму заказа: она не совпадает с существующими платежами';
    end if;

    return new;
end;
$$;

create trigger trg_check_order_total_change
before update of total_amount
on konev_food."order"
for each row
execute function konev_food.check_order_total_change();


-- 8. Запрет смены ресторана у товара, используемого в заказах

CREATE OR REPLACE FUNCTION konev_food.check_product_restaurant_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.restaurant_id IS DISTINCT FROM OLD.restaurant_id
       AND EXISTS (
           SELECT 1
           FROM konev_food.order_structure os
           WHERE os.product_id = OLD.product_id
       )
    THEN
        RAISE EXCEPTION
            'Нельзя изменить ресторан товара: товар уже используется в заказах';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_check_product_restaurant_change
BEFORE UPDATE OF restaurant_id
ON konev_food.product
FOR EACH ROW
EXECUTE FUNCTION konev_food.check_product_restaurant_change();
