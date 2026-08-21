/*
================================================================================
Quality Checks: Silver Layer
================================================================================
Script Purpose:
    Validates data after running silver.load_silver.
    Compares Bronze vs Silver row counts, checks transformations,
    validates derived columns, and checks referential integrity.

Usage:
    Run AFTER: EXEC silver.load_silver]
================================================================================
*/

-- ============================================================
-- SECTION 0: ROW COUNT COMPARISON — Bronze vs Silver
-- All counts should match (except filtered invalid rows)
-- ============================================================

SELECT 'bronze.customers'    AS table_name, COUNT(*) AS row_count FROM bronze.olist_customers_dataset
UNION ALL
SELECT 'silver.customers',                  COUNT(*) FROM silver.olist_customers_dataset
UNION ALL
SELECT 'bronze.geolocation',                COUNT(*) FROM bronze.olist_geolocation_dataset
UNION ALL
SELECT 'silver.geolocation',                COUNT(*) FROM silver.olist_geolocation_dataset
UNION ALL
SELECT 'bronze.order_items',                COUNT(*) FROM bronze.olist_order_items_dataset
UNION ALL
SELECT 'silver.order_items',                COUNT(*) FROM silver.olist_order_items_dataset
UNION ALL
SELECT 'bronze.payments',                   COUNT(*) FROM bronze.olist_order_payments_dataset
UNION ALL
SELECT 'silver.payments',                   COUNT(*) FROM silver.olist_order_payments_dataset
UNION ALL
SELECT 'bronze.reviews',                    COUNT(*) FROM bronze.olist_order_reviews_dataset
UNION ALL
SELECT 'silver.reviews',                    COUNT(*) FROM silver.olist_order_reviews_dataset
UNION ALL
SELECT 'bronze.orders',                     COUNT(*) FROM bronze.olist_orders_dataset
UNION ALL
SELECT 'silver.orders',                     COUNT(*) FROM silver.olist_orders_dataset
UNION ALL
SELECT 'bronze.products',                   COUNT(*) FROM bronze.olist_products_dataset
UNION ALL
SELECT 'silver.products',                   COUNT(*) FROM silver.olist_products_dataset
UNION ALL
SELECT 'bronze.sellers',                    COUNT(*) FROM bronze.olist_sellers_dataset
UNION ALL
SELECT 'silver.sellers',                    COUNT(*) FROM silver.olist_sellers_dataset
UNION ALL
SELECT 'bronze.translations',               COUNT(*) FROM bronze.product_category_name_translation
UNION ALL
SELECT 'silver.translations',               COUNT(*) FROM silver.product_category_name_translation;

-- ==========================================================
-- TABLE 1: olist_customers_dataset
-- ==========================================================

-- Check no NULLs in primary key
SELECT 
	customer_id
FROM silver.olist_customers_dataset
WHERE customer_id IS NULL;


-- Check zip code still has leading zeros preserved
SELECT TOP 10
    customer_zip_code_prefix
FROM silver.olist_customers_dataset
ORDER BY customer_zip_code_prefix;

-- ==========================================================
-- TABLE 2: silver.olist_geolocation_dataset
-- ==========================================================

-- Check quotes and length of geolocation_zip_code_prefix
SELECT 
	geolocation_zip_code_prefix
FROM silver.olist_geolocation_dataset
WHERE LEN(geolocation_zip_code_prefix) > 5 ;

-- Check coordinates within valid Brazil range
SELECT 
	geolocation_lat,
	geolocation_lng
FROM silver.olist_geolocation_dataset
WHERE geolocation_lat NOT BETWEEN -35 AND 5
   OR geolocation_lng NOT BETWEEN -75 AND -30;

-- Check for unwanted spaces
SELECT
	geolocation_city,
	geolocation_state
FROM silver.olist_geolocation_dataset
WHERE geolocation_state != TRIM(geolocation_state)
	OR geolocation_city != TRIM(geolocation_city)
	OR LEN(geolocation_state) != 2;

-- Check distinct cities
SELECT DISTINCT
	geolocation_city
FROM silver.olist_geolocation_dataset
WHERE geolocation_city LIKE '%"%';

-- ==========================================================
-- TABLE 3: silver.olist_order_items_dataset
-- ==========================================================

-- Check shipping_limit_date converted correctly
SELECT 
	shipping_limit_date
FROM silver.olist_order_items_dataset
WHERE shipping_limit_date IS NULL;

-- ==========================================================
-- TABLE 4: silver.olist_order_payments_dataset
-- ==========================================================

-- Check no zero or negative payment values
SELECT
	payment_value
FROM silver.olist_order_payments_dataset
WHERE payment_value <= 0;

-- ==========================================================
-- TABLE 5: silver.olist_order_reviews_dataset
-- ==========================================================

-- Check line breaks removed from messages
SELECT 
	review_comment_message
FROM silver.olist_order_reviews_dataset
WHERE review_comment_message LIKE '%' + CHAR(10) + '%'
   OR review_comment_message LIKE '%' + CHAR(13) + '%'
   OR  review_comment_message LIKE '%' + CHAR(9) + '%';

SELECT
review_comment_title
FROM silver.olist_order_reviews_dataset
WHERE review_comment_title IN ('?', '??', '???', '????', '', '.', '..', '...', '....', '.....');

--
SELECT
review_comment_message
FROM silver.olist_order_reviews_dataset
WHERE review_comment_message IN ('?', '??', '???', '????', '', '.', '..', '...', '....', '.....');

-- ==========================================================
-- TABLE 6: silver.olist_orders_dataset
-- ==========================================================
SELECT TOP 5
    delivery_days,
    approval_hours,
    late_delivery_flag
FROM silver.olist_orders_dataset;

-- ==========================================================
-- TABLE 7: olist_products_dataset
-- ==========================================================

-- Check distinct product category name
SELECT DISTINCT
    product_category_name
FROM silver.olist_products_dataset;

-- ============================================================
-- TABLE 8: olist_sellers_dataset
-- ============================================================

-- Check state is always 2 uppercase letters
SELECT DISTINCT
    seller_state,
    LEN(seller_state) AS state_length
FROM silver.olist_sellers_dataset
WHERE LEN(seller_state) != 2;

-- Check zip code preserves leading zeros
SELECT TOP 10
    seller_zip_code_prefix
FROM silver.olist_sellers_dataset
ORDER BY seller_zip_code_prefix;

-- Check no spaces in city
SELECT 
    seller_city
FROM silver.olist_sellers_dataset
WHERE seller_city != TRIM(seller_city);

-- ============================================================
-- TABLE 9: product_category_name_translation
-- ============================================================

-- Check for duplicates
SELECT 
    product_category_name,
    COUNT(*) AS duplicate_count
FROM silver.product_category_name_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;

-- Check for unwanted spaces
SELECT 
	product_category_name,
	product_category_name_english
FROM silver.product_category_name_translation
WHERE product_category_name != TRIM(product_category_name)
   OR product_category_name_english != TRIM(product_category_name_english)

-- Check special characters 
SELECT 
	product_category_name,
	product_category_name_english
FROM silver.product_category_name_translation
WHERE product_category_name_english LIKE '%"%'

-- ============================================================
-- REFERENTIAL INTEGRITY CHECKS
-- Detect orphan records between tables
-- ============================================================

-- Orders without matching customer
SELECT 
    COUNT(*) AS orders_without_customer
FROM silver.olist_orders_dataset o
LEFT JOIN silver.olist_customers_dataset c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Order items without matching order
SELECT 
    COUNT(*) AS items_without_order
FROM silver.olist_order_items_dataset i
LEFT JOIN silver.olist_orders_dataset o
    ON i.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Order items without matching product
SELECT 
    COUNT(*) AS items_without_product
FROM silver.olist_order_items_dataset i
LEFT JOIN silver.olist_products_dataset p
    ON i.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Order items without matching seller
SELECT COUNT(*) AS items_without_seller
FROM silver.olist_order_items_dataset i
LEFT JOIN silver.olist_sellers_dataset s
    ON i.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- Payments without matching order
SELECT
    COUNT(*) AS payments_without_order
FROM silver.olist_order_payments_dataset p
LEFT JOIN silver.olist_orders_dataset o
 ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Reviews without matching order
SELECT
    COUNT(*) AS reviews_without_order
FROM silver.olist_order_reviews_dataset r
LEFT JOIN silver.olist_orders_dataset o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;
