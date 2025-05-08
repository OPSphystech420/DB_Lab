-- PostgreSQL Оlist Query
--
-- Database: olist_db
-- ------------------------------------------------------
-- Вариант - 1

-- ===============================================
-- 1. Сравнение заказов по категориям
-- ===============================================
WITH top5_cities AS (
  -- ТОП-5 крупнейших городов
  SELECT UNNEST(ARRAY[
    'sao paulo',
    'rio de janeiro',
    'belo horizonte',
    'brasilia',
    'salvador'
  ]) AS city_name
),
order_cats AS (
  -- для каждой позиции берем город и категорию на английском
  SELECT
    lower(c.customer_city) AS city,
    replace(t.product_category_name_english, '_', ' ') AS category
  FROM olist.orders o
  JOIN olist.customers c
    ON o.customer_id = c.customer_id
  JOIN olist.order_items oi
    ON o.order_id = oi.order_id
  JOIN olist.products p
    ON oi.product_id = p.product_id
  JOIN olist.product_category_name_translation t
    ON p.product_category_name = t.product_category_name
  -- будем учитывать только доставленные заказы, чтобы сделать более корректную оценку 
  WHERE o.order_status = 'Delivered' AND o.order_delivered_customer_date IS NOT NULL
),
category_counts AS (
  -- считаем **сколько** позиций каждой категории доставлено в города
  SELECT
    category,
    COUNT(*) FILTER (WHERE city IN (SELECT city_name FROM top5_cities))     AS top5_delivered,
    COUNT(*) FILTER (WHERE city NOT IN (SELECT city_name FROM top5_cities)) AS other_delivered,
    COUNT(*) AS total_delivered
  FROM order_cats
  GROUP BY category
),
categorised AS (
  -- категории <500 позиций объединим в others для смягчения шума
  SELECT
    CASE WHEN total_delivered < 500 THEN 'others' ELSE category END AS category_group,
    top5_delivered,
    other_delivered,
    total_delivered
  FROM category_counts
),
sum_ AS (
  -- суммируем по новым группам
  SELECT
    category_group AS category,
    SUM(top5_delivered)       AS top5_delivered,
    SUM(other_delivered)      AS other_delivered,
    SUM(total_delivered) AS total_delivered
  FROM categorised
  GROUP BY category_group
),
totals AS (
  -- общая сумма по ТОП‑5 и остальным для нормировки
  SELECT
    SUM(top5_delivered)  AS total_top5,
    SUM(other_delivered) AS total_other
  FROM sum_
)
SELECT
  s.category,
  s.total_delivered,
  s.top5_delivered,
  s.other_delivered,
  -- метрики для оценки
  -- процент категории доли всех продаж в ТОП‑5
  ROUND(100.0 * s.top5_delivered  / t.total_top5, 3)  AS pct_top5,
  -- процент категории доли всех продаж в остальных
  ROUND(100.0 * s.other_delivered / t.total_other, 3) AS pct_other,
  -- абсолютная разница
  ROUND(
    ABS(
      (s.top5_delivered::decimal  / t.total_top5)
    - (s.other_delivered::decimal / t.total_other)
    ) * 100
  , 3) AS abs_pct_diff,
  -- знаковая разница
  ROUND(
    ((s.top5_delivered::decimal  / t.total_top5)
    - (s.other_delivered::decimal / t.total_other)) * 100
  , 3) AS signed_pct_diff,
  -- отношение долей (pct_top5 / pct_other)
  ROUND(
    (s.top5_delivered::decimal  / t.total_top5)
    / NULLIF((s.other_delivered::decimal / t.total_other), 0)
  , 3) AS ratio_pct,
  -- лог коэфф
  ROUND(
    LN(
      (s.top5_delivered::decimal / t.total_top5)
      / NULLIF((s.other_delivered::decimal / t.total_other), 0)
    )
  , 3) AS log_ratio
FROM sum_ s
CROSS JOIN totals t
-- отсортируем, закинем others в конец
ORDER BY
  CASE WHEN s.category = 'others' THEN 1 ELSE 0 END ASC,
  s.total_delivered DESC,
  abs_pct_diff DESC;

-- ===============================================
-- 2. Отличая стоимости доставки по регионам
-- ===============================================
WITH shipments AS (
  SELECT c.customer_state, oi.freight_value
  FROM olist.order_items oi
  JOIN olist.orders o
  ON oi.order_id = o.order_id
  JOIN olist.customers c
  ON o.customer_id = c.customer_id
)
SELECT
  customer_state,
  COUNT(*) AS shipments_count,
  ROUND(AVG(freight_value),2) AS avg_freight,
  ROUND(STDDEV_SAMP(freight_value),2) AS sd_freight,
  ROUND(MIN(freight_value),2) AS min_freight,
  ROUND(MAX(freight_value),2) AS max_freight
FROM shipments
GROUP BY customer_state
ORDER BY avg_freight DESC;

SELECT
  CASE
    WHEN c.customer_state = s.seller_state THEN 'intra_state'
    ELSE 'inter_state'
  END AS shipment_type,
  COUNT(*) AS shipments_count,
  ROUND(AVG(oi.freight_value),2) AS avg_freight
FROM olist.order_items oi
JOIN olist.orders o ON oi.order_id = o.order_id
JOIN olist.customers c ON o.customer_id = c.customer_id
JOIN olist.sellers s ON oi.seller_id = s.seller_id
GROUP BY shipment_type;

WITH state_stats AS (
  SELECT c.customer_state,
    COUNT(*) AS shipments_count,
    AVG(oi.freight_value) AS avg_freight
  FROM olist.order_items oi
  JOIN olist.orders o ON oi.order_id = o.order_id
  JOIN olist.customers c ON o.customer_id = c.customer_id
  GROUP BY c.customer_state
)
SELECT ROUND(CORR(shipments_count, avg_freight)::numeric, 2) AS corr_volume_freight
FROM state_stats;

SELECT
  CASE
    WHEN p.product_weight_g < 500 THEN '<500g'
    WHEN p.product_weight_g BETWEEN 500 AND 2000 THEN '500g–2kg'
    WHEN p.product_weight_g BETWEEN 2000 AND 5000 THEN '2–5kg'
    ELSE '>5kg'
  END AS weight_bucket,
  COUNT(*) AS cnt,
  ROUND(AVG(oi.freight_value),2) AS avg_freight
FROM olist.order_items oi
JOIN olist.products p
ON oi.product_id = p.product_id
GROUP BY weight_bucket
ORDER BY weight_bucket;

-- ===============================================
-- 3. Селлеры с самыми высокими скидками
-- ===============================================
WITH order_sums AS (
  SELECT
    oi.order_id,
    SUM(oi.price) AS total_price,
    SUM(oi.freight_value) AS total_freight,
    SUM(oi.price + oi.freight_value) AS total_expected,
    SUM(op.payment_value) AS total_paid
  FROM olist.order_items  oi
  JOIN olist.order_payments op USING(order_id)
  GROUP BY oi.order_id
)

SELECT
  COUNT(*) AS orders_total,
  SUM(CASE WHEN total_paid = total_price THEN 1 ELSE 0 END) AS paid_eq_price,
  SUM(CASE WHEN total_paid = total_expected THEN 1 ELSE 0 END) AS paid_eq_price_plus_freight,
  SUM(CASE WHEN total_paid BETWEEN total_price AND total_expected THEN 1 ELSE 0 END) AS paid_between_price_and_price_plus_freight,
  SUM(CASE WHEN total_paid < total_price THEN 1 ELSE 0 END) AS paid_less_than_price,
  SUM(CASE WHEN total_paid > total_expected THEN 1 ELSE 0 END) AS paid_above_price_plus_freight
FROM order_sums;

SELECT
  COUNT(*) AS items_total,
  SUM(CASE WHEN price = freight_value THEN 1 ELSE 0 END) AS price_eq_freight,
  SUM(CASE WHEN price > freight_value THEN 1 ELSE 0 END) AS price_gt_freight,
  SUM(CASE WHEN price < freight_value THEN 1 ELSE 0 END) AS price_lt_freight,
  AVG(price - freight_value) AS avg_price_minus_freight
FROM olist.order_items;

WITH price_stats AS (
  -- для каждого товара находим листовую цену (максимум)
  SELECT
    product_id,
    MAX(price) AS list_price
  FROM olist.order_items
  GROUP BY product_id
),
discounts AS (
  -- считаем по каждой позиции абсолютную и относительную скидку
  SELECT
    oi.seller_id,
    oi.product_id,
    ps.list_price,
    oi.price AS paid_price,
    (ps.list_price - oi.price) AS discount_value,
    ROUND((ps.list_price - oi.price) / ps.list_price, 4) AS discount_rate
  FROM olist.order_items AS oi
  JOIN price_stats AS ps
    ON oi.product_id = ps.product_id
  WHERE ps.list_price > oi.price
)
SELECT
  d.seller_id,
  COUNT(*) AS sales_count, -- число проданных позиций
  SUM(d.discount_value) AS total_discount, -- суммарная потеря по цене
  ROUND( AVG(d.discount_rate), 4 ) AS avg_discount_rate, -- средняя скидка
  ROUND( MAX(d.discount_rate), 4 ) AS max_discount_rate  -- максимальная скидка
FROM discounts AS d
GROUP BY d.seller_id
HAVING COUNT(*) > 50 -- только активные селеры
ORDER BY avg_discount_rate DESC
LIMIT 20;

WITH 
  -- ожидаемая сумма заказа
  order_expected AS (
    SELECT
      oi.order_id,
      SUM(oi.price + oi.freight_value) AS expected_total
    FROM olist.order_items oi
    GROUP BY oi.order_id
  ),
  -- фактически уплачено (кроме ваучеров)
  order_paid AS (
    SELECT
      op.order_id,
      SUM(op.payment_value) AS paid_total
    FROM olist.order_payments op
    WHERE LOWER(op.payment_type) <> 'voucher'
    GROUP BY op.order_id
  ),
  -- выбираем только те заказы, где paid < expected и статус = delivered
  order_discounts AS (
    SELECT
      e.order_id,
      e.expected_total,
      p.paid_total,
      (e.expected_total - p.paid_total) AS discount_value
    FROM order_expected e
    JOIN order_paid    p USING(order_id)
    JOIN olist.orders  o USING(order_id)
    WHERE p.paid_total < e.expected_total
      AND LOWER(o.order_status) = 'delivered'
  ),
  -- доля каждого селера в заказе
  seller_order_share AS (
    SELECT
      oi.order_id,
      oi.seller_id,
      SUM(oi.price + oi.freight_value) AS seller_order_total
    FROM olist.order_items oi
    GROUP BY oi.order_id, oi.seller_id
  ),
  -- распределяем скидку между селерами пропорционально их части в заказе
  seller_discounts AS (
    SELECT
      s.seller_id,
      s.order_id,
      d.discount_value * (s.seller_order_total / d.expected_total) AS seller_discount_value,
      s.seller_order_total
    FROM seller_order_share s
    JOIN order_discounts   d USING(order_id)
  )
SELECT
  sd.seller_id,
  COUNT(DISTINCT sd.order_id) AS discounted_orders,
  ROUND( AVG(sd.seller_discount_value), 2 ) AS avg_discount_amount,
  ROUND( SUM(sd.seller_discount_value), 2 ) AS total_discount_amount,
  ROUND( AVG(sd.seller_discount_value / sd.seller_order_total), 4 ) AS avg_discount_rate
FROM seller_discounts sd
GROUP BY sd.seller_id
ORDER BY discounted_orders DESC, avg_discount_rate DESC
LIMIT 20;

-- ===============================================
-- 4. Распределение заказов по способам оплаты
-- ===============================================
-- определяем ТОП-5 городов по общему числу заказов
WITH top_cities AS (
  SELECT
    c.customer_city,
    COUNT(*) AS total_orders
  FROM olist.orders o
    JOIN olist.customers c USING (customer_id)
  GROUP BY c.customer_city
  ORDER BY total_orders DESC
  LIMIT 5
),
-- считаем по этим городам распределение по способам оплаты
city_payments AS (
  SELECT
    c.customer_city,
    p.payment_type,
    COUNT(DISTINCT o.order_id) AS orders_count,
    SUM(p.payment_value) AS total_payment_value,
    ROUND(AVG(p.payment_value), 2) AS avg_payment_value
  FROM olist.orders o
    JOIN olist.customers c USING (customer_id)
    JOIN olist.order_payments p USING (order_id)
  WHERE c.customer_city IN (SELECT customer_city FROM top_cities)
  GROUP BY c.customer_city, p.payment_type
)
-- выбор с расчетом процента заказов каждого типа в городе
SELECT
  cp.customer_city,
  cp.payment_type,
  cp.orders_count,
  ROUND(100.0 * cp.orders_count / tc.total_orders, 2) AS pct_of_city_orders,
  cp.total_payment_value,
  cp.avg_payment_value
FROM city_payments cp
JOIN top_cities tc USING (customer_city)
ORDER BY tc.total_orders DESC, -- сначала города по убыванию общего числа заказов
    cp.orders_count DESC; -- внутри города — по убыванию количества заказов способа оплаты
