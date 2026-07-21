CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    email VARCHAR(200) UNIQUE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    item VARCHAR(200) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

INSERT INTO customers (name, email) VALUES
    ('Ada Lovelace', 'ada@example.com'),
    ('Grace Hopper', 'grace@example.com');

INSERT INTO orders (customer_id, item, amount, status) VALUES
    (1, 'Mechanical Keyboard', 129.99, 'COMPLETED'),
    (1, 'USB Cable', 9.50, 'PENDING'),
    (2, 'Monitor Stand', 45.00, 'COMPLETED');

CREATE OR REPLACE PROCEDURE add_order(
    IN p_customer_id INT, IN p_item VARCHAR, IN p_amount NUMERIC
) LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO orders (customer_id, item, amount) VALUES (p_customer_id, p_item, p_amount);
END;
$$;
