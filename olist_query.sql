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
    WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
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
-- 2. Отличается стоимость доставки по регионам
-- ===============================================


-- ===============================================
-- 3. Селлеры с самыми высокими скидками
-- ===============================================


-- ===============================================
-- 4. Распределение заказов по способам оплаты
-- ===============================================
