-- Не более одной успешной оплаты для одного заказа
CREATE UNIQUE INDEX uq_payment_one_success_per_order
ON konev_food.payment (order_id)
WHERE status = 'success';

-- Не более одного отзыва на один объект в рамках заказа
CREATE UNIQUE INDEX uq_review_one_per_object_per_order
ON konev_food.review (order_id, entity_type, entity_id);