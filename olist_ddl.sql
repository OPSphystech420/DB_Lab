-- PostgreSQL Оlist DDL
--
-- Database: olist_db
-- ------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS olist;

-- ===============================================
-- 1. Customers
-- ===============================================
CREATE TABLE olist.customers (
	customer_id                  VARCHAR(50) PRIMARY KEY,
    customer_unique_id           VARCHAR(50) NOT NULL,
    customer_zip_code_prefix     INT,
    customer_city                VARCHAR(100),
    customer_state               CHAR(2)
);

-- ===============================================
-- 2. Sellers
-- ===============================================
CREATE TABLE olist.sellers (
    seller_id                    VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix       INT,
    seller_city                  VARCHAR(100),
    seller_state                 CHAR(2)
);


-- ===============================================
-- 3. Products
-- ===============================================
CREATE TABLE olist.products (
    product_id                  VARCHAR(50) PRIMARY KEY,
    product_category_name       VARCHAR(100),
    product_name_lenght         SMALLINT,
    product_description_lenght  INT,
    product_photos_qty          SMALLINT,
    product_weight_g            INT,
    product_length_cm           SMALLINT,
    product_height_cm           SMALLINT,
    product_width_cm            SMALLINT
);

-- ===============================================
-- 4. Orders
-- ===============================================
CREATE TABLE olist.orders (
    order_id                     VARCHAR(50) PRIMARY KEY,
    customer_id                  VARCHAR(50) NOT NULL,
    order_status                 VARCHAR(20),
    order_purchase_timestamp     TIMESTAMP WITHOUT TIME ZONE,
    order_approved_at            TIMESTAMP WITHOUT TIME ZONE,
    order_delivered_carrier_date TIMESTAMP WITHOUT TIME ZONE,
    order_delivered_customer_date TIMESTAMP WITHOUT TIME ZONE,
    order_estimated_delivery_date TIMESTAMP WITHOUT TIME ZONE,
    FOREIGN KEY (customer_id) REFERENCES olist.customers (customer_id)
);

-- ===============================================
-- 5. Order payments
-- ===============================================
CREATE TABLE olist.order_payments (
    order_id             VARCHAR(50)  NOT NULL,
    payment_sequential   SMALLINT     NOT NULL,
    payment_type         VARCHAR(20),
    payment_installments SMALLINT,
    payment_value        DECIMAL(10,2),
    FOREIGN KEY (order_id) REFERENCES olist.orders (order_id)
);

-- ===============================================
-- 6. Order positions
-- ===============================================
CREATE TABLE olist.order_items (
    order_id            VARCHAR(50)  NOT NULL,
    order_item_id       SMALLINT     NOT NULL,
    product_id          VARCHAR(50)  NOT NULL,
    seller_id           VARCHAR(50)  NOT NULL,
    shipping_limit_date TIMESTAMP WITHOUT TIME ZONE,
    price               DECIMAL(10,2),
    freight_value       DECIMAL(10,2),
    FOREIGN KEY (order_id) REFERENCES olist.orders (order_id),
    FOREIGN KEY (product_id) REFERENCES olist.products (product_id),
    FOREIGN KEY (seller_id) REFERENCES olist.sellers (seller_id)
);

-- ===============================================
-- 7. Customer reviews
-- ===============================================
CREATE TABLE olist.order_reviews (
    review_id               VARCHAR(50) NOT NULL,
    order_id                VARCHAR(50) NOT NULL,
    review_score            SMALLINT,
    review_comment_title    VARCHAR(255),
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP WITHOUT TIME ZONE,
    review_answer_timestamp TIMESTAMP WITHOUT TIME ZONE,
    FOREIGN KEY (order_id) REFERENCES olist.orders (order_id)
);

-- ===============================================
-- 8. Delivery location
-- ===============================================
CREATE TABLE olist.geolocation (
    geolocation_zip_code_prefix INTEGER NOT NULL,
    geolocation_lat             DECIMAL(9,6),
    geolocation_lng             DECIMAL(9,6),
    geolocation_city            VARCHAR(100),
    geolocation_state           CHAR(2)
);

-- ===============================================
-- 9. Category name translation
-- ===============================================
CREATE TABLE olist.product_category_name_translation (
    product_category_name          VARCHAR(100) PRIMARY KEY,
    product_category_name_english  VARCHAR(100)
);
