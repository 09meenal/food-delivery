-- ============ DDL: Food Delivery Database (PostgreSQL) ============
CREATE DATABASE food_delivery;
\c food_delivery

CREATE TABLE users (
  user_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name      VARCHAR(60) NOT NULL,
  phone     VARCHAR(10) NOT NULL UNIQUE,
  email     VARCHAR(80) NOT NULL UNIQUE,
  user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('Customer','Manager','DeliveryPartner'))
);

CREATE TABLE restaurant (
  restaurant_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name            VARCHAR(60) NOT NULL,
  address         VARCHAR(120) NOT NULL,
  contact_details VARCHAR(15) NOT NULL
);

CREATE TABLE customer (
  customer_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        VARCHAR(60) NOT NULL,
  phone       VARCHAR(10) NOT NULL UNIQUE,
  address     VARCHAR(120) NOT NULL,
  email       VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE delivery_partner (
  partner_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name           VARCHAR(60) NOT NULL,
  phone          VARCHAR(10) NOT NULL UNIQUE,
  current_status VARCHAR(10) NOT NULL DEFAULT 'Available'
                 CHECK (current_status IN ('Available','Busy','Offline'))
);

CREATE TABLE food_item (
  item_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  restaurant_id INT NOT NULL REFERENCES restaurant(restaurant_id) ON DELETE CASCADE,
  item_name     VARCHAR(60) NOT NULL,
  price         NUMERIC(8,2) NOT NULL CHECK (price > 0),
  category      VARCHAR(30) NOT NULL,
  type          VARCHAR(10) NOT NULL CHECK (type IN ('Veg','NonVeg'))
);

CREATE TABLE orders (
  order_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id  INT NOT NULL REFERENCES customer(customer_id),
  partner_id   INT REFERENCES delivery_partner(partner_id),   -- NULL until order is confirmed
  order_date   DATE NOT NULL DEFAULT CURRENT_DATE,
  status       VARCHAR(10) NOT NULL DEFAULT 'Placed'
               CHECK (status IN ('Placed','Confirmed','Delivered','Cancelled')),
  total_amount NUMERIC(10,2) NOT NULL DEFAULT 0
);

CREATE TABLE order_item (          -- "contains" (N:M between orders and food_item)
  order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
  item_id  INT NOT NULL REFERENCES food_item(item_id),
  quantity INT NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (order_id, item_id)
);

CREATE TABLE payment (
  payment_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id       INT NOT NULL UNIQUE REFERENCES orders(order_id) ON DELETE CASCADE,  -- 1:1
  amount         NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
  payment_date   DATE NOT NULL DEFAULT CURRENT_DATE,
  payment_status VARCHAR(10) NOT NULL DEFAULT 'Pending' CHECK (payment_status IN ('Pending','Paid','Failed')),
  payment_method VARCHAR(5) NOT NULL CHECK (payment_method IN ('COD','UPI','Card')),
  transaction_id VARCHAR(30) UNIQUE,   -- only for online payments
  cash_collected NUMERIC(10,2)         -- only for COD
);

-- ============ ALTER TABLE ============
ALTER TABLE orders  ADD COLUMN restaurant_id INT NOT NULL REFERENCES restaurant(restaurant_id);
ALTER TABLE payment ADD COLUMN managed_by INT REFERENCES users(user_id);   -- USER manages PAYMENT
ALTER TABLE customer         ADD CONSTRAINT chk_cust_phone CHECK (phone ~ '^[0-9]{10}$');
ALTER TABLE delivery_partner ADD CONSTRAINT chk_dp_phone   CHECK (phone ~ '^[0-9]{10}$');
ALTER TABLE payment ADD CONSTRAINT chk_method_fields CHECK (
  (payment_method = 'COD' AND transaction_id IS NULL) OR
  (payment_method IN ('UPI','Card') AND cash_collected IS NULL)
);
