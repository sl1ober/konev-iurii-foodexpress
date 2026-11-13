CREATE OR REPLACE PROCEDURE konev_food.insert_test_data(IN value integer)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_client_ids uuid[] := ARRAY[]::uuid[];
    v_courier_ids uuid[] := ARRAY[]::uuid[];
    v_restaurant_ids uuid[] := ARRAY[]::uuid[];
    v_category_ids uuid[] := ARRAY[]::uuid[];

    v_client_id uuid;
    v_courier_id uuid;
    v_client_address_id uuid;
    v_restaurant_address_id uuid;
    v_restaurant_id uuid;
    v_product_id uuid;
    v_order_id uuid;

    v_product_price numeric(10,2);
    v_order_timestamp timestamp;
    v_total_amount numeric(12,2);
    v_period_start timestamp;
    v_month_start date;

    v_coefficient numeric(2,1);
    v_commission_sum numeric(12,2);
    v_delivered_count integer;

    -- Значения ENUM берутся из enum_range(), как требует FOOD-102.
    v_courier_statuses konev_food.courier_status[]
        := enum_range(NULL::konev_food.courier_status);
    v_restaurant_statuses konev_food.restaurant_status[]
        := enum_range(NULL::konev_food.restaurant_status);
    v_product_statuses konev_food.product_status[]
        := enum_range(NULL::konev_food.product_status);
    v_order_statuses konev_food.order_status[]
        := enum_range(NULL::konev_food.order_status);
    v_order_pay_statuses konev_food.order_pay_status[]
        := enum_range(NULL::konev_food.order_pay_status);
    v_payment_statuses konev_food.payment_status[]
        := enum_range(NULL::konev_food.payment_status);
    v_payment_types konev_food.payment_type[]
        := enum_range(NULL::konev_food.payment_type);
    v_review_entity_types konev_food.review_entity_type[]
        := enum_range(NULL::konev_food.review_entity_type);

    i integer;
    j integer;
    k integer;
BEGIN
    IF value IS NULL OR value <= 0 THEN
        RAISE EXCEPTION 'Параметр value должен быть больше 0';
    END IF;

    -- Скользящий период: последние шесть месяцев.
    -- Оставляем один час до текущего момента, чтобы доставка, платёж
    -- и отзыв, создаваемые позднее, также не оказались в будущем.
    v_period_start := date_trunc('month', current_timestamp) - interval '5 months';

    -- Клиенты: value записей.
    FOR i IN 1..value LOOP
        INSERT INTO konev_food.client (
            login,
            password,
            phone_number
        )
        VALUES (
            'client_' || exts.uuid_generate_v4()::text,
            md5(random()::text),
            lpad(floor(random() * 100000000000)::bigint::text, 11, '0')
        )
        RETURNING client_id INTO v_client_id;

        v_client_ids := array_append(v_client_ids, v_client_id);
    END LOOP;

    -- Курьеры: value записей. Первый курьер гарантированно активен.
    FOR i IN 1..value LOOP
        INSERT INTO konev_food.courier (
            fio,
            phone_number,
            status,
            hire_date,
            dismissal_date,
            coefficient
        )
        VALUES (
            'курьер ' || i || '_' || exts.uuid_generate_v4()::text,
            lpad(floor(random() * 100000000000)::bigint::text, 11, '0'),
            CASE
                WHEN i = 1 THEN v_courier_statuses[1]
                ELSE v_courier_statuses[1 + floor(random() * 3)::integer]
            END,
            (current_date - interval '6 months')::date,
            NULL,
            0.1
        )
        RETURNING courier_id INTO v_courier_id;

        v_courier_ids := array_append(v_courier_ids, v_courier_id);
    END LOOP;

    -- Категории товаров: value записей.
    FOR i IN 1..value LOOP
        INSERT INTO konev_food.product_category (name)
        VALUES (
            'категория ' || i || '_' || exts.uuid_generate_v4()::text
        )
        RETURNING category_id INTO v_client_id;

        v_category_ids := array_append(v_category_ids, v_client_id);
    END LOOP;

    -- Адреса ресторанов и рестораны: по value записей.
    -- UUID в улице обеспечивает уникальность адресов при повторных вызовах.
    FOR i IN 1..value LOOP
        INSERT INTO konev_food.address (
            street,
            house_number,
            apartment_office
        )
        VALUES (
            'улица ресторанная ' || exts.uuid_generate_v4()::text,
            i::text,
            NULL
        )
        RETURNING address_id INTO v_restaurant_address_id;

        INSERT INTO konev_food.restaurant (
            name,
            address_id,
            description,
            work_start,
            work_end,
            company_details,
            rating,
            status
        )
        VALUES (
            'ресторан ' || i || '_' || exts.uuid_generate_v4()::text,
            v_restaurant_address_id,
            'тестовый ресторан',
            '09:00',
            '21:00',
            'тестовые реквизиты ресторана',
            NULL,
            v_restaurant_statuses[1]
        )
        RETURNING restaurant_id INTO v_restaurant_id;

        v_restaurant_ids := array_append(v_restaurant_ids, v_restaurant_id);
    END LOOP;

    -- Четыре адреса для каждого клиента.
    FOR i IN 1..value LOOP
        FOR j IN 1..4 LOOP
            INSERT INTO konev_food.address (
                street,
                house_number,
                apartment_office
            )
            VALUES (
                'улица клиентская ' || exts.uuid_generate_v4()::text,
                j::text,
                NULL
            )
            RETURNING address_id INTO v_client_address_id;

            INSERT INTO konev_food.client_address (
                client_id,
                address_id
            )
            VALUES (
                v_client_ids[i],
                v_client_address_id
            );
        END LOOP;
    END LOOP;

    -- Товары: value * 5 записей.
    FOR i IN 1..(value * 5) LOOP
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
            'товар ' || i || '_' || exts.uuid_generate_v4()::text,
            v_category_ids[((i - 1) % value) + 1],
            (1000 + floor(random() * 4000))::numeric(10,2),
            v_restaurant_ids[((i - 1) % value) + 1],
            NULL,
            NULL,
            v_product_statuses[1],
            'тестовое описание товара'
        );
    END LOOP;

    -- Заказы: value * 5 записей.
    FOR i IN 1..(value * 5) LOOP
        v_client_id := v_client_ids[1 + floor(random() * value)::integer];
        v_courier_id := v_courier_ids[1 + ((i - 1) % value)];
        v_restaurant_id := v_restaurant_ids[1 + ((i - 1) % value)];

        -- Адрес выбранного клиента.
        SELECT ca.address_id
        INTO v_client_address_id
        FROM konev_food.client_address AS ca
        WHERE ca.client_id = v_client_id
        ORDER BY random()
        LIMIT 1;

        -- Товар выбранного ресторана.
        SELECT p.product_id, p.price
        INTO v_product_id, v_product_price
        FROM konev_food.product AS p
        WHERE p.restaurant_id = v_restaurant_id
        ORDER BY random()
        LIMIT 1;

        -- Время заказа находится в последних шести месяцах;
        -- доставка, платёж и отзыв также останутся не позднее текущего времени.
        v_order_timestamp :=
            v_period_start
            + random() * (
                current_timestamp - interval '1 hour' - v_period_start
            );

        v_total_amount :=
            v_product_price + round(v_product_price * 0.10, 2);

        INSERT INTO konev_food."order" (
            courier_id,
            client_id,
            address_id,
            restaurant_id,
            order_timestamp,
            delivery_timestamp,
            order_amount,
            commission,
            total_amount,
            status,
            pay_status,
            description
        )
        VALUES (
            v_courier_id,
            v_client_id,
            v_client_address_id,
            v_restaurant_id,
            v_order_timestamp,
            v_order_timestamp + interval '30 minutes',
            v_product_price,
            round(v_product_price * 0.10, 2),
            v_total_amount,
            v_order_statuses[4],
            v_order_pay_statuses[2],
            'тестовый заказ'
        )
        RETURNING order_id INTO v_order_id;

        -- Одна позиция товара в каждом заказе.
        INSERT INTO konev_food.order_structure (
            order_id,
            product_id,
            quantity
        )
        VALUES (
            v_order_id,
            v_product_id,
            1
        );

        -- Одна успешная оплата на каждый заказ.
        INSERT INTO konev_food.payment (
            order_id,
            payment_type,
            amount,
            transaction_id,
            transaction_timestamp,
            status
        )
        VALUES (
            v_order_id,
            v_payment_types[1 + floor(random() * cardinality(v_payment_types))::integer],
            v_total_amount,
            exts.uuid_generate_v4()::text,
            v_order_timestamp + interval '30 minutes',
            v_payment_statuses[1]
        );

        -- Отзыв клиента на собственный заказ.
        INSERT INTO konev_food.review (
            client_id,
            review_timestamp,
            entity_id,
            entity_type,
            order_id,
            description,
            photo_url,
            rating
        )
        VALUES (
            v_client_id,
            v_order_timestamp + interval '1 hour',
            v_order_id,
            v_review_entity_types[3],
            v_order_id,
            'тестовый отзыв',
            NULL,
            1 + floor(random() * 5)::integer
        );
    END LOOP;

    -- Начисления курьерам за шесть календарных месяцев.
    -- В каждом месяце используется коэффициент, действовавший именно в нём.
    FOR i IN 1..value LOOP
        v_courier_id := v_courier_ids[i];
        v_coefficient := 0.1;

        FOR k IN 0..5 LOOP
            v_month_start :=
                (
                    date_trunc('month', current_date)
                    - (5 - k) * interval '1 month'
                )::date;

            -- Месяц определяется по фактическому времени доставки.
            SELECT
                COALESCE(sum(o.commission), 0),
                count(*)::integer
            INTO
                v_commission_sum,
                v_delivered_count
            FROM konev_food."order" AS o
            WHERE o.courier_id = v_courier_id
              AND o.status = v_order_statuses[4]
              AND o.delivery_timestamp >= v_month_start
              AND o.delivery_timestamp < v_month_start + interval '1 month';

            INSERT INTO konev_food.courier_pay (
                year,
                month,
                courier_id,
                amount,
                coefficient_used
            )
            VALUES (
                extract(year FROM v_month_start)::integer,
                extract(month FROM v_month_start)::integer,
                v_courier_id,
                round(v_commission_sum * v_coefficient, 2),
                v_coefficient
            );

            -- Коэффициент следующего месяца по числу доставок текущего месяца.
            IF v_delivered_count <= 150 THEN
                v_coefficient := 0.1;
            ELSIF v_delivered_count <= 250 THEN
                v_coefficient := 0.2;
            ELSIF v_delivered_count <= 500 THEN
                v_coefficient := 0.3;
            ELSE
                v_coefficient := 0.5;
            END IF;
        END LOOP;

        -- Коэффициент, который будет действовать в следующем месяце.
        UPDATE konev_food.courier
        SET coefficient = v_coefficient
        WHERE courier_id = v_courier_id;
    END LOOP;
END;
$procedure$

CREATE OR REPLACE PROCEDURE konev_food.erase_test_data()
 LANGUAGE plpgsql
AS $procedure$
BEGIN
    TRUNCATE TABLE
        konev_food.order_structure,
        konev_food.payment,
        konev_food.review,
        konev_food.courier_pay,
        konev_food."order",
        konev_food.client_address,
        konev_food.product,
        konev_food.restaurant,
        konev_food.courier,
        konev_food.client,
        konev_food.product_category,
        konev_food.address
    RESTART IDENTITY CASCADE;
END;
$procedure$
