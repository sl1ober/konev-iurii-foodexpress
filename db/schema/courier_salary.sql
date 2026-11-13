CREATE OR REPLACE PROCEDURE konev_food.courier_salary()
LANGUAGE plpgsql
AS $$
DECLARE
    -- Определяем текущий год и месяц для формирования выплаты
    v_year integer := EXTRACT(YEAR FROM CURRENT_DATE)::integer;
    v_month integer := EXTRACT(MONTH FROM CURRENT_DATE)::integer;

    -- Определяем начало текущего и следующего месяца
    -- Это позволяет выбрать доставки только за текущий месяц
    v_month_start timestamp := DATE_TRUNC('month', CURRENT_DATE);
    v_next_month_start timestamp := DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month';

BEGIN
    -- Создаём временную таблицу для хранения промежуточных результатов расчёта
    -- Она нужна, чтобы не выполнять расчёты повторно для разных операций
    CREATE TEMP TABLE IF NOT EXISTS courier_salary_calc (
        courier_id uuid,
        orders_count bigint,
        commission_sum numeric,
        current_coefficient numeric,
        new_coefficient numeric,
        salary_amount numeric
    ) ON COMMIT DROP;

    -- Очищаем временную таблицу перед заполнением новыми данными
    TRUNCATE TABLE courier_salary_calc;

    -- Рассчитываем количество доставленных заказов, сумму комиссий,
    -- используемый коэффициент, новый коэффициент и зарплату каждого курьера
    INSERT INTO courier_salary_calc (
        courier_id,
        orders_count,
        commission_sum,
        current_coefficient,
        new_coefficient,
        salary_amount
    )
    SELECT
        c.courier_id,
        COUNT(o.order_id),
        COALESCE(SUM(o.commission), 0),

        -- Если выплата за текущий месяц уже существует,
        -- используем сохранённый коэффициент, чтобы повторный вызов
        -- не изменял ранее рассчитанную зарплату
        COALESCE(cp.coefficient_used, c.coefficient),

        -- Определяем новый коэффициент в зависимости от количества доставок
        CASE
            WHEN COUNT(o.order_id) <= 150 THEN 0.1
            WHEN COUNT(o.order_id) <= 250 THEN 0.2
            WHEN COUNT(o.order_id) <= 500 THEN 0.3
            ELSE 0.5
        END,

        -- Рассчитываем зарплату по текущему (используемому) коэффициенту
        COALESCE(cp.coefficient_used, c.coefficient)
            * COALESCE(SUM(o.commission), 0)

    FROM konev_food.courier c

    -- LEFT JOIN позволяет включить в расчёт даже курьеров,
    -- у которых в текущем месяце нет доставленных заказов
    LEFT JOIN konev_food."order" o
        ON o.courier_id = c.courier_id
        AND o.status = 'delivered'
        AND o.delivery_timestamp >= v_month_start
        AND o.delivery_timestamp < v_next_month_start

    -- Получаем коэффициент из уже существующей выплаты за этот месяц,
    -- если процедура ранее запускалась
    LEFT JOIN konev_food.courier_pay cp
        ON cp.courier_id = c.courier_id
        AND cp.year = v_year
        AND cp.month = v_month

    -- Группируем данные отдельно для каждого курьера
    GROUP BY
        c.courier_id,
        c.coefficient,
        cp.coefficient_used;

    -- Записываем рассчитанную зарплату в таблицу выплат
    INSERT INTO konev_food.courier_pay (
        year,
        month,
        courier_id,
        amount,
        coefficient_used
    )
    SELECT
        v_year,
        v_month,
        courier_id,
        salary_amount,
        current_coefficient
    FROM courier_salary_calc

    -- Если выплата за этот месяц уже существует,
    -- обновляем её вместо создания дубликата
    ON CONFLICT (year, month, courier_id)
    DO UPDATE SET
        amount = EXCLUDED.amount,
        coefficient_used = EXCLUDED.coefficient_used;

    -- Обновляем коэффициенты только работающих курьеров
    -- Новый коэффициент будет использоваться при расчёте зарплаты
    -- за следующий месяц
    UPDATE konev_food.courier c
    SET coefficient = s.new_coefficient
    FROM courier_salary_calc s
    WHERE c.courier_id = s.courier_id
      AND c.status <> 'dismissed'
      AND c.dismissal_date IS NULL;

END;
$$;