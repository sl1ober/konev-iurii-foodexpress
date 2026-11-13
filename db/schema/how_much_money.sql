CREATE OR REPLACE VIEW konev_food.how_much_money AS

WITH RECURSIVE
-- Находим первый и последний месяцы с доставленными заказами
date_limits AS (
    SELECT
        DATE_TRUNC('month', MIN(delivery_timestamp))::date AS first_month,
        DATE_TRUNC('month', MAX(delivery_timestamp))::date AS last_month
    FROM konev_food."order"
    WHERE status = 'delivered'
),

-- Генерируем последовательность месяцев от первого до последнего
months(month_start) AS (
    SELECT first_month
    FROM date_limits
    WHERE first_month IS NOT NULL

    UNION ALL

    SELECT (m.month_start + INTERVAL '1 month')::date
    FROM months m
    CROSS JOIN date_limits d
    WHERE m.month_start < d.last_month
),

-- Считаем суммы по доставленным заказам за каждый месяц
monthly_orders AS (
    SELECT
        DATE_TRUNC('month', o.delivery_timestamp)::date AS month_start,
        SUM(o.order_amount) AS sum_no_commission,
        SUM(o.total_amount) AS sum_with_commission
    FROM konev_food."order" o
    WHERE o.status = 'delivered'
    GROUP BY DATE_TRUNC('month', o.delivery_timestamp)::date
),

-- Считаем выплаты курьерам по каждому месяцу
monthly_courier_pay AS (
    SELECT
        MAKE_DATE(cp.year, cp.month, 1) AS month_start,
        SUM(cp.amount) AS courier_pay
    FROM konev_food.courier_pay cp
    GROUP BY cp.year, cp.month
),

-- Объединяем месяцы с заказами и выплатами
monthly_totals AS (
    SELECT
        m.month_start,
        COALESCE(mo.sum_no_commission, 0)::numeric AS sum_no_commission,
        COALESCE(mo.sum_with_commission, 0)::numeric AS sum_with_commission,
        (
            COALESCE(mo.sum_with_commission, 0)
            - COALESCE(mo.sum_no_commission, 0)
        )::numeric AS commission,
        COALESCE(mcp.courier_pay, 0)::numeric AS courier_pay
    FROM months m
    LEFT JOIN monthly_orders mo
        ON mo.month_start = m.month_start
    LEFT JOIN monthly_courier_pay mcp
        ON mcp.month_start = m.month_start
)

-- Формируем итоговый отчёт
SELECT
    TO_CHAR(month_start, 'YYYY-MM')::text AS year_month,
    sum_no_commission,
    sum_with_commission,
    commission,

    -- Комиссия за предыдущий месяц
    LAG(commission) OVER (ORDER BY month_start) AS prev_commission,

    -- Разница между текущей и предыдущей комиссией
    commission - LAG(commission) OVER (ORDER BY month_start)
        AS commission_diff,

    courier_pay,

    -- Чистая прибыль после выплаты курьерам
    (commission - courier_pay)::numeric AS net_profit

FROM monthly_totals;