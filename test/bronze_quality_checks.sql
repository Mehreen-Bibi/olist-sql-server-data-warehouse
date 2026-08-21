-- ==========================================================
-- QUALITY CHECKS: Bronze Layer
-- Run these before building Silver Layer transformations
-- ==========================================================

USE OlistDataWarehouse;
GO
-- ==========================================================
-- TABLE 1: olist_customers_dataset
-- ==========================================================

-- Check total row count
SELECT 
	COUNT(*) AS total_rows
FROM bronze.olist_customers_dataset;

-- Check for NULLS in all columns
SELECT
	COUNT(*) AS total_rows,
	COUNT(customer_id) AS non_null_customer_id,
	COUNT(customer_unique_id) AS non_null_unique_id,
	COUNT(customer_zip_code_prefix) AS non_null_zip_code,
	COUNT(customer_city) AS non_null_city,
	COUNT(customer_state) AS non_null_state
FROM bronze.olist_customers_dataset;

-- Check for duplicate customer_id
SELECT
	customer_id,
	COUNT(*) AS duplicate_count
FROM bronze.olist_customers_dataset
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Check for unwanted spaces in city and state
SELECT 
	customer_city,
	customer_state
FROM bronze.olist_customers_dataset
WHERE customer_city != TRIM(customer_city)
	OR customer_state != TRIM(customer_state);

-- Check distinct cities (look for duplicates for different spelling
SELECT DISTINCT
	customer_city
FROM bronze.olist_customers_dataset
ORDER BY customer_city;

-- Check distinct states (should be 2 letter codes)
SELECT DISTINCT
	customer_state,
	LEN(customer_state) AS state_length
FROM bronze.olist_customers_dataset
ORDER BY state_length DESC;

-- ==========================================================
-- TABLE 2: bronze.olist_geolocation_dataset
-- ==========================================================

-- Check total row count
SELECT
	COUNT(*) AS total_rows
FROM bronze.olist_geolocation_dataset;

-- Check for NULLs in all columns
SELECT 
	COUNT(*) AS total_rows,
	COUNT(geolocation_zip_code_prefix) AS non_null_zip_code,
	COUNT(geolocation_lat) AS non_null_lat,
	COUNT(geolocation_lng) AS non_null_lng,
	COUNT(geolocation_city) AS non_null_city,
	COUNT(geolocation_state) AS non_null_state
FROM bronze.olist_geolocation_dataset;

-- Check for zero coordinates
SELECT
	geolocation_lat,
	geolocation_lng
FROM bronze.olist_geolocation_dataset
WHERE geolocation_lat = 0 
	OR geolocation_lng = 0;

-- Check for invalid Brazil coordinates
-- Brazil lat: -35 to 5, lng: -75 to -30
SELECT 
	COUNT(*) AS invalid_coordinates
FROM bronze.olist_geolocation_dataset
WHERE geolocation_lat NOT BETWEEN -35 AND 5
	OR geolocation_lng NOT BETWEEN -75 and -30;

-- Check for unwanted spaces
SELECT
	geolocation_city,	
	geolocation_state
FROM bronze.olist_geolocation_dataset
WHERE  geolocation_state != TRIM(geolocation_state)
	OR geolocation_city != TRIM(geolocation_city);

-- Check state length issues
SELECT DISTINCT
    geolocation_state,
    LEN(geolocation_state) AS state_length
FROM bronze.olist_geolocation_dataset
WHERE LEN(geolocation_state) != 2
ORDER BY state_length DESC;

-- Check distinct cities
SELECT DISTINCT
	geolocation_city
FROM bronze.olist_geolocation_dataset;

-- ==========================================================
-- TABLE 3: bronze.olist_order_items_dataset
-- ==========================================================

-- Check total row count
SELECT
	COUNT(*) AS total_rows
FROM bronze.olist_order_items_dataset;

-- Check for NUULs in all columns
SELECT
	COUNT(*) AS total_rows,
	COUNT(order_id) AS non_null_order_id,
	COUNT(order_item_id) AS non_null_item_id,
	COUNT(product_id) AS non_null_product_id,
	COUNT(seller_id) AS non_null_seller_id,
	COUNT(shipping_limit_date) AS non_null_date,
	COUNT(price) AS non_null_price,
	COUNT(freight_value) AS non_null_freight_value
FROM bronze.olist_order_items_dataset;

-- Check for duplicate order_id + order_item_id
SELECT
	order_id,
	order_item_id,
	COUNT(*) AS duplicate_count
FROM bronze.olist_order_items_dataset
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- Check date validity
SELECT 
	shipping_limit_date,
	ISDATE(shipping_limit_date) AS is_valid_date,
	COUNT(*) AS row_count
FROM bronze.olist_order_items_dataset
GROUP BY shipping_limit_date, ISDATE(shipping_limit_date)
ORDER BY is_valid_date ASC;

-- Check for negative or zero prices
SELECT 
	price
FROM bronze.olist_order_items_dataset
WHERE price <= 0 OR price IS NULL;

-- Check for negative freight
SELECT 
	freight_value
FROM bronze.olist_order_items_dataset
WHERE freight_value < 0 OR freight_value IS NULL;

-- Check price distribution
SELECT 
	MIN(price) AS min_price,
	MAX(price) AS max_price,
	AVG(price) AS avg_price
FROM bronze.olist_order_items_dataset;

-- ==========================================================
-- TABLE 4: bronze.olist_order_payments_dataset
-- ==========================================================

-- Check total row count
SELECT
	COUNT(*) AS total_rows
FROM bronze.olist_order_payments_dataset;

-- Check for NULLs in all columns
SELECT
	COUNT(*) AS total_rows,
	COUNT(order_id) AS non_null_order_id,
	COUNT(payment_sequential) AS non_null_payment_sequential,
	COUNT(payment_type) AS non_null_payment_type,
	COUNT(payment_installments) AS non_null_installments,
    COUNT(payment_value) AS non_null_value
FROM bronze.olist_order_payments_dataset;

-- Check distinct payment types
SELECT DISTINCT
	payment_type,
	COUNT(*) AS count_type
FROM bronze.olist_order_payments_dataset
GROUP BY payment_type
ORDER BY count_type DESC;

-- Check for zero or negative payment values
SELECT
	payment_value
FROM bronze.olist_order_payments_dataset
WHERE payment_value <= 0;

-- Check installments range
SELECT
    MIN(payment_installments) AS min_installments,
    MAX(payment_installments) AS max_installments
FROM bronze.olist_order_payments_dataset;

-- Check payment distribution stats
SELECT
    MIN(payment_value) AS min_value,
    MAX(payment_value) AS max_value,
    AVG(payment_value) AS avg_value
FROM bronze.olist_order_payments_dataset;

-- ==========================================================
-- TABLE 5: bronze.olist_order_reviews_dataset
-- ==========================================================

-- Check total row count
SELECT
	COUNT(*) AS total_row
FROM bronze.olist_order_reviews_dataset;

-- Check for NULLS in all columns
SELECT
	COUNT(*) AS total_row,
	COUNT(review_id) AS non_null_review_id,
	COUNT(order_id) AS non_null_order_id,
	COUNT(review_score) AS non_null_score,
	COUNT(review_comment_title) AS non_null_title,
	COUNT(review_comment_message) AS non_null_message,
	COUNT(review_creation_date) AS non_null_date,
	COUNT(review_answer_timestamp) AS non_null_timestamp
FROM bronze.olist_order_reviews_dataset;

-- Check duplicate review_id
SELECT
	review_id,
	COUNT(*) AS duplicate_count
FROM bronze.olist_order_reviews_dataset
GROUP BY review_id
HAVING COUNT(*) > 1;

-- 
SELECT
*,
ROW_NUMBER() OVER(PARTITION BY review_id ORDER BY order_id) AS rn
FROM bronze.olist_order_reviews_dataset
WHERE review_id = 'a0caeb49360c7afacbd5dc0e64d96b93'


-- Check review score range (must be 1 to 5 only)
SELECT DISTINCT
    review_score,
    COUNT(*) AS count
FROM bronze.olist_order_reviews_dataset
GROUP BY review_score
ORDER BY review_score;

-- Check unwanted spaces
SELECT 
	review_comment_title,
	TRIM(review_comment_title) AS review_comment_title_trim
FROM bronze.olist_order_reviews_dataset
WHERE review_comment_title != TRIM(review_comment_title);

-- Check special characters in review comment title
SELECT 
	review_comment_title
FROM bronze.olist_order_reviews_dataset
WHERE review_comment_title IN ('???', ' ', '"', '', '??', '?', '.', '..', '...', '....');

-- Check special characters in review comment message
SELECT 
	review_comment_message
FROM bronze.olist_order_reviews_dataset
WHERE review_comment_message IN ('???', '', '??', '?', '.', '..', '...', '....', '.....');

-- Check date validity
SELECT
	ISDATE(review_creation_date) AS is_valid_creation,
	ISDATE(review_answer_timestamp) AS is_valid_answer,
	COUNT(*) AS count
FROM bronze.olist_order_reviews_dataset
GROUP BY 
	ISDATE(review_creation_date),
	ISDATE(review_answer_timestamp);

-- ==========================================================
-- TABLE 6: bronze.olist_orders_dataset
-- ==========================================================

-- Check total row count
SELECT
	COUNT(*) AS total_row
FROM bronze.olist_orders_dataset;

-- Check for NULLs in all columns
SELECT
	COUNT(*) AS total_row,
	COUNT(order_id) AS non_null_order_id,
	COUNT(customer_id) AS non_null_customer_id,
	COUNT(order_status) AS non_null_status,
	COUNT(order_purchase_timestamp) AS non_null_purchase,
	COUNT(order_approved_at) AS non_null_approved,
	COUNT(order_delivered_carrier_date) AS non_null_carrier_date,
	COUNT(order_delivered_customer_date) AS non_null_customer_date,
	COUNT(order_estimated_delivery_date) AS non_null_estimated_date
FROM bronze.olist_orders_dataset;

-- Check distinct order statuses
SELECT DISTINCT
    order_status,
    COUNT(*) AS count
FROM bronze.olist_orders_dataset
GROUP BY order_status
ORDER BY count DESC;

-- Check for duplicate order_id
SELECT
	order_id,
	COUNT(*) AS duplicate_count
FROM bronze.olist_orders_dataset
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Check date validity for all date columns
SELECT
	ISDATE(order_purchase_timestamp) AS is_valid_purchase,
	ISDATE(order_approved_at) AS is_valid_approved,
	ISDATE(order_delivered_carrier_date) AS is_valid_carrier,
    ISDATE(order_delivered_customer_date) AS is_valid_delivered,
    ISDATE(order_estimated_delivery_date) AS is_valid_estimated,
    COUNT(*) AS count
FROM bronze.olist_orders_dataset
GROUP BY
	ISDATE(order_purchase_timestamp),
	ISDATE(order_approved_at),
	ISDATE(order_delivered_carrier_date),
	ISDATE(order_delivered_customer_date),
	ISDATE(order_estimated_delivery_date);

-- Check delivery date logic
-- delivered date should always be after purchase date
SELECT 
	order_delivered_customer_date,
	order_purchase_timestamp 
FROM bronze.olist_orders_dataset
WHERE CAST(order_delivered_customer_date AS DATETIME2) 
    < CAST(order_purchase_timestamp AS DATETIME2);

-- 
SELECT 
	order_approved_at,
	order_purchase_timestamp
FROM bronze.olist_orders_dataset
WHERE CAST(order_approved_at AS DATETIME2) 
    < CAST(order_purchase_timestamp AS DATETIME2)
	OR order_approved_at IS NULL;

-- ==========================================================
-- TABLE 7: olist_products_dataset
-- ==========================================================

-- Check total row counts
SELECT
	COUNT(*) AS total_rows
FROM bronze.olist_products_dataset;

-- Check for NULLs
SELECT
    COUNT(*) AS total_rows,
    COUNT(product_id) AS non_null_product_id,
    COUNT(product_category_name) AS non_null_category,
    COUNT(product_name_lenght) AS non_null_name_len,
    COUNT(product_description_lenght) AS non_null_desc_len,
    COUNT(product_photos_qty) AS non_null_photos,
    COUNT(product_weight_g) AS non_null_weight,
    COUNT(product_length_cm) AS non_null_length,
    COUNT(product_height_cm) AS non_null_height,
    COUNT(product_width_cm) AS non_null_width
FROM bronze.olist_products_dataset;

-- Check for duplicate product_id
SELECT 
    product_id,
    COUNT(*) AS duplicate_count
FROM bronze.olist_products_dataset
GROUP BY product_id
HAVING COUNT(*) > 1;

-- Check for unwanted spaces
SELECT
	product_category_name
FROM bronze.olist_products_dataset
WHERE product_category_name != TRIM(product_category_name);

-- Check distinct categories
SELECT DISTINCT
    product_category_name,
    COUNT(*) AS count
FROM bronze.olist_products_dataset
GROUP BY product_category_name
ORDER BY count DESC;

-- Check for negative photo count
SELECT 
	product_photos_qty
FROM bronze.olist_products_dataset
WHERE product_photos_qty < 0;

-- Check for negative dimensions
SELECT 
	NULLIF(product_weight_g, 0) AS product_weight_g,
	product_length_cm,
	product_height_cm,
	product_width_cm
FROM bronze.olist_products_dataset
WHERE product_weight_g <= 0 OR product_weight_g IS NULL
   OR product_length_cm <= 0 OR product_length_cm IS NULL
   OR product_height_cm <= 0 OR product_height_cm IS NULL
   OR product_width_cm <= 0 OR product_width_cm IS NULL;

-- Check dimension stats
SELECT
    MIN(product_weight_g) AS min_weight,
    MAX(product_weight_g) AS max_weight,
    MIN(product_length_cm) AS min_length,
    MAX(product_length_cm) AS max_length
FROM bronze.olist_products_dataset;

-- ============================================================
-- TABLE 8: olist_sellers_dataset
-- ============================================================

-- Check total row count
SELECT COUNT(*) AS total_rows 
FROM bronze.olist_sellers_dataset;

-- Check for NULLs
SELECT
    COUNT(*) AS total_rows,
    COUNT(seller_id) AS non_null_seller_id,
    COUNT(seller_zip_code_prefix) AS non_null_zip,
    COUNT(seller_city) AS non_null_city,
    COUNT(seller_state) AS non_null_state
FROM bronze.olist_sellers_dataset;

-- Check for duplicate seller_id
SELECT 
    seller_id,
    COUNT(*) AS duplicate_count
FROM bronze.olist_sellers_dataset
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- Check distinct states
SELECT DISTINCT
    LEN(seller_state) AS state_length,
    COUNT(*) AS count
FROM bronze.olist_sellers_dataset
GROUP BY LEN(seller_state)
ORDER BY state_length DESC;

-- ============================================================
-- TABLE 9: product_category_name_translation
-- ============================================================

-- Check total row count
SELECT COUNT(*) AS total_rows 
FROM bronze.product_category_name_translation;

-- Check for NULLs
SELECT
    COUNT(*) AS total_rows,
    COUNT(product_category_name) AS non_null_portuguese,
    COUNT(product_category_name_english) AS non_null_english
FROM bronze.product_category_name_translation;

-- Check for duplicates
SELECT 
    product_category_name,
    COUNT(*) AS duplicate_count
FROM bronze.product_category_name_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;

-- Check for unwanted spaces
SELECT 
	product_category_name,
	product_category_name_english
FROM bronze.product_category_name_translation
WHERE product_category_name != TRIM(product_category_name)
   OR product_category_name_english != TRIM(product_category_name_english)

-- Check special characters 
SELECT 
	product_category_name,
	product_category_name_english
FROM bronze.product_category_name_translation
WHERE product_category_name_english LIKE '%"%';
