-- PostgreSQL Оlist DML
--
-- Database: olist_db
-- ------------------------------------------------------
-- @param datadir = /path_to/olist_dataset

-- ===============================================
-- 1. Delete data inside tables
-- ===============================================
TRUNCATE TABLE
    olist.order_items,
    olist.order_payments,
    olist.order_reviews,
    olist.geolocation,
    olist.product_category_name_translation,
    olist.orders,
    olist.products,
    olist.sellers,
    olist.customers
RESTART IDENTITY CASCADE;

-- ===============================================
-- 2.1. Customers
-- ===============================================
COPY olist.customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
FROM '${datadir}/olist_customers_dataset.csv'
CSV HEADER;

-- ===============================================
-- 2.2. Sellers
-- ===============================================
COPY olist.sellers (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
FROM '${datadir}/olist_sellers_dataset.csv'
CSV HEADER;

-- ===============================================
-- 2.3. Products
-- ===============================================
COPY olist.products (
    product_id,
    product_category_name,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
FROM '${datadir}/olist_products_dataset.csv'
CSV HEADER;

-- ===============================================
-- 2.4. Orders
-- ===============================================
COPY olist.orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
)
FROM '${datadir}/olist_orders_dataset.csv'
CSV HEADER;

-- ===============================================
-- 2.5. Order payments
-- ===============================================
COPY olist.order_payments (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
FROM '${datadir}/olist_order_payments_dataset.csv'
CSV HEADER;

-- ===============================================
-- 2.6. Order items
-- ===============================================
COPY olist.order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
)
FROM '${datadir}/olist_order_items_dataset.csv'
CSV HEADER;

-- ===============================================
-- 2.7. Order reviews
-- ===============================================
COPY olist.order_reviews (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
FROM '${datadir}/olist_order_reviews_dataset.csv'
CSV HEADER;

-- ===============================================
-- 2.8. Geolocation
-- ===============================================
COPY olist.geolocation (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)
FROM '${datadir}/olist_geolocation_dataset.csv'
CSV HEADER;

-- ===============================================
-- 2.9. Category name translation
-- ===============================================
COPY olist.product_category_name_translation (
    product_category_name,
    product_category_name_english
)
FROM '${datadir}/product_category_name_translation.csv'
CSV HEADER;
