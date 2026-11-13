create type konev_food.restaurant_status as enum (
    'active',
    'inactive'
);

create type konev_food.product_status as enum (
    'available',
    'out_of_stock',
    'archive'
);

create type konev_food.courier_status as enum (
    'free',
    'busy',
    'on_delivery',
    'dismissed'
);

create type konev_food.order_status as enum (
    'created',
    'preparing',
    'in_delivery',
    'delivered',
    'cancelled'
);

create type konev_food.order_pay_status as enum (
    'pending',
    'paid',
    'error'
);

create type konev_food.payment_status as enum (
    'success',
    'error',
    'processing'
);

create type konev_food.payment_type as enum (
    'card',
    'cash',
    'cashless'
);

create type konev_food.review_entity_type as enum (
    'product',
    'restaurant',
    'order'
);