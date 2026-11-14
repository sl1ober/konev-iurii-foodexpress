-- 1. Адреса
CREATE TABLE konev_food.address (
    address_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    street VARCHAR(150) NOT NULL,
    house_number VARCHAR(20) NOT NULL,
    apartment_office VARCHAR(20)
);

-- 2. Клиенты
CREATE TABLE konev_food.client (
    client_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    login VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(32) NOT NULL,
    phone_number CHAR(11) NOT NULL UNIQUE,
    CONSTRAINT chk_client_password_md5
        CHECK (password ~ '^[0-9a-fA-F]{32}$')
);

-- 3. Категории товаров
CREATE TABLE konev_food.product_category (
    category_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    name VARCHAR(100) NOT NULL
);

-- 4. Курьеры
CREATE TABLE konev_food.courier (
    courier_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    fio VARCHAR(200) NOT NULL,
    phone_number CHAR(11) NOT NULL,
    status konev_food.courier_status NOT NULL,
    hire_date DATE NOT NULL,
    dismissal_date DATE,
    coefficient NUMERIC(2,1) NOT NULL DEFAULT 0.1,
    CHECK (coefficient BETWEEN 0.1 AND 0.5),
    CHECK (
        (status = 'dismissed' AND dismissal_date IS NOT NULL)
        OR
        (status <> 'dismissed' AND dismissal_date IS NULL)
    ),
    CHECK (
        dismissal_date IS NULL
        OR dismissal_date >= hire_date
    )
);

-- 5. Рестораны
CREATE TABLE konev_food.restaurant (
    restaurant_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    name VARCHAR(150) NOT NULL,
    address_id UUID NOT NULL UNIQUE,
    description TEXT NOT NULL,
    work_start TIME NOT NULL,
    work_end TIME NOT NULL,
    company_details TEXT NOT NULL,
    rating NUMERIC(3,2),
    status konev_food.restaurant_status NOT NULL,
    FOREIGN KEY (address_id) REFERENCES konev_food.address(address_id),
    CHECK (rating IS NULL OR rating BETWEEN 0 AND 5),
    CHECK (work_end > work_start)
);

-- 6. Связь клиентов и адресов
CREATE TABLE konev_food.client_address (
    client_id UUID NOT NULL,
    address_id UUID NOT NULL,
    PRIMARY KEY (client_id, address_id),
    FOREIGN KEY (client_id) REFERENCES konev_food.client(client_id),
    FOREIGN KEY (address_id) REFERENCES konev_food.address(address_id)
);

-- 7. Выплаты курьерам
CREATE TABLE konev_food.courier_pay (
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    courier_id UUID NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    coefficient_used NUMERIC(2,1) NOT NULL,
    PRIMARY KEY (year, month, courier_id),
    FOREIGN KEY (courier_id) REFERENCES konev_food.courier(courier_id),
    CHECK (month BETWEEN 1 AND 12),
    CHECK (amount >= 0),
    CHECK (coefficient_used BETWEEN 0.1 AND 0.5)
);

-- 8. Товары
CREATE TABLE konev_food.product (
    product_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    name VARCHAR(150) NOT NULL,
    category_id UUID NOT NULL,
    price NUMERIC(10,2) NOT NULL,
    restaurant_id UUID NOT NULL,
    photo_url TEXT,
    rating NUMERIC(3,2),
    status konev_food.product_status NOT NULL,
    description TEXT NOT NULL,
    FOREIGN KEY (category_id) REFERENCES konev_food.product_category(category_id),
    FOREIGN KEY (restaurant_id) REFERENCES konev_food.restaurant(restaurant_id),
    CHECK (price >= 0),
    CHECK (rating IS NULL OR rating BETWEEN 0 AND 5)
);

-- 9. Заказы
CREATE TABLE konev_food."order" (
    order_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    courier_id UUID NOT NULL,
    client_id UUID NOT NULL,
    address_id UUID NOT NULL,
    restaurant_id UUID NOT NULL,
    order_timestamp TIMESTAMP NOT NULL,
    delivery_timestamp TIMESTAMP,
    order_amount NUMERIC(12,2) NOT NULL,
    commission NUMERIC(12,2) NOT NULL,
    total_amount NUMERIC(12,2) NOT NULL,
    status konev_food.order_status NOT NULL,
    pay_status konev_food.order_pay_status NOT NULL,
    description TEXT NOT NULL,
    FOREIGN KEY (courier_id) REFERENCES konev_food.courier(courier_id),
    FOREIGN KEY (client_id, address_id)
        REFERENCES konev_food.client_address(client_id, address_id),
    FOREIGN KEY (restaurant_id) REFERENCES konev_food.restaurant(restaurant_id),
    CHECK (order_amount >= 0),
    CHECK (commission >= 0),
    CHECK (total_amount >= 1000),
    CHECK (commission = ROUND(order_amount * 0.10, 2)),
    CHECK (total_amount = order_amount + commission),
    CHECK (
        delivery_timestamp IS NULL
        OR delivery_timestamp >= order_timestamp
    )
);

-- 10. Платежи
CREATE TABLE konev_food.payment (
    payment_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    order_id UUID NOT NULL,
    payment_type konev_food.payment_type NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    transaction_id VARCHAR(255) NOT NULL UNIQUE,
    transaction_timestamp TIMESTAMP NOT NULL,
    status konev_food.payment_status NOT NULL,
    FOREIGN KEY (order_id) REFERENCES konev_food."order"(order_id),
    CHECK (amount >= 0)
);

-- 11. Состав заказа
CREATE TABLE konev_food.order_structure (
    order_id UUID NOT NULL,
    product_id UUID NOT NULL,
    quantity NUMERIC(10,3) NOT NULL,
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id) REFERENCES konev_food."order"(order_id),
    FOREIGN KEY (product_id) REFERENCES konev_food.product(product_id),
    CHECK (quantity > 0)
);

-- 12. Отзывы
CREATE TABLE konev_food.review (
    review_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    client_id UUID NOT NULL,
    review_timestamp TIMESTAMP NOT NULL,
    entity_id UUID NOT NULL,
    entity_type konev_food.review_entity_type NOT NULL,
    order_id UUID NOT NULL,
    description TEXT,
    photo_url TEXT,
    rating NUMERIC(2,1) NOT NULL,
    FOREIGN KEY (client_id) REFERENCES konev_food.client(client_id),
    FOREIGN KEY (order_id) REFERENCES konev_food."order"(order_id),
    CHECK (rating BETWEEN 1 AND 5)
);