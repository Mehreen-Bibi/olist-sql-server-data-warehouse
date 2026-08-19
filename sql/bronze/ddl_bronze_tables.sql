/*
================================================================================
DDL Script: Create Bronze Tables
================================================================================
Scripts Purpose:
	This script creates tables in the 'bronze' schema, dropping existing tables
	if they already exist.
	Run this script to re-define the DDL structure of 'bronze' Tables
================================================================================
*/

USE OlistDataWarehouse;
GO

-- ------------------------------------------------------------
-- TABLE 1: bronze.olist_customers_dataset
-- Contains customer information including location details.
-- customer_id and customer_unique_id are MD5 hashes (32 chars).
-- ------------------------------------------------------------
IF OBJECT_ID ('bronze.olist_customers_dataset', 'U') IS NOT NULL
	DROP TABLE bronze.olist_customers_dataset;
GO
 
CREATE TABLE bronze.olist_customers_dataset (
	customer_id              NVARCHAR(32)  NOT NULL,
	customer_unique_id		   NVARCHAR(32)  NOT NULL,
	customer_zip_code_prefix NVARCHAR(5)   NULL,
	customer_city            NVARCHAR(100) NULL,
	customer_state           CHAR(2)       NULL
);
GO

-- -------------------------------------------------------------------
-- TABLE 2: bronze.olist_geolocation_dataset
-- Contains latitude and longitude data mapped to Brazilian zip codes.
-- -------------------------------------------------------------------
IF OBJECT_ID ('bronze.olist_geolocation_dataset', 'U') IS NOT NULL
	DROP TABLE bronze.olist_geolocation_dataset;
GO

CREATE TABLE bronze.olist_geolocation_dataset (
	geolocation_zip_code_prefix NVARCHAR(5)   NULL,
	geolocation_lat				      FLOAT         NULL,
	geolocation_lng			      	FLOAT         NULL,
	geolocation_city			      NVARCHAR(100) NULL,
	geolocation_state		        CHAR(2)       NULL
);
GO

-- ------------------------------------------------------------
-- TABLE 3: bronze.olist_order_items_dataset
-- Contains individual items within each order including
-- price, freight, and shipping details.
-- ------------------------------------------------------------
IF OBJECT_ID ('bronze.olist_order_items_dataset', 'U') IS NOT NULL
	DROP TABLE bronze.olist_order_items_dataset;
GO

CREATE TABLE bronze.olist_order_items_dataset (
	order_id		      	NVARCHAR(32)  NOT NULL,
	order_item_id		    INT           NOT NULL,
	product_id			    NVARCHAR(32)  NOT NULL,
	seller_id           NVARCHAR(32)  NOT NULL, 
	shipping_limit_date NVARCHAR(50)  NULL,
	price				        DECIMAL(18,2) NULL,
	freight_value	    	DECIMAL(18,2) NULL
);
GO

-- ------------------------------------------------------------
-- TABLE 4: bronze.olist_order_payments_dataset
-- Contains payment details for each order.
-- An order can have multiple payment rows (installments).
-- ------------------------------------------------------------
IF OBJECT_ID ('bronze.olist_order_payments_dataset', 'U') IS NOT NULL
	DROP TABLE bronze.olist_order_payments_dataset;
GO

CREATE TABLE bronze.olist_order_payments_dataset (
	order_id		         NVARCHAR(32)  NOT NULL,
	payment_sequential   INT           NULL,
	payment_type	       NVARCHAR(20)  NULL,
	payment_installments INT           NULL,
	payment_value        DECIMAL(18,2) NULL
);
GO

-- ------------------------------------------------------------
-- TABLE 5: bronze.olist_order_reviews_dataset
-- Contains customer reviews submitted after order delivery.
-- Dates stored as NVARCHAR to preserve raw format from CSV.
-- ------------------------------------------------------------
IF OBJECT_ID ('bronze.olist_order_reviews_dataset', 'U') IS NOT NULL
	DROP TABLE bronze.olist_order_reviews_dataset;
GO

CREATE TABLE bronze.olist_order_reviews_dataset (
	review_id               NVARCHAR(32)  NOT NULL,
	order_id                NVARCHAR(32)  NOT NULL,
	review_score            INT           NULL,
	review_comment_title    NVARCHAR(500) NULL,
	review_comment_message  NVARCHAR(MAX) NULL,
	review_creation_date    NVARCHAR(50)  NULL,
	review_answer_timestamp NVARCHAR(50)  NULL
);
GO

-- ------------------------------------------------------------
-- TABLE 6: bronze.olist_orders_dataset.
-- Contains order lifecycle timestamps from purchase to delivery.
-- ------------------------------------------------------------
IF OBJECT_ID ('bronze.olist_orders_dataset', 'U') IS NOT NULL
	DROP TABLE bronze.olist_orders_dataset;
GO

CREATE TABLE bronze.olist_orders_dataset (
	order_id                      NVARCHAR(32) NOT NULL,
	customer_id                   NVARCHAR(32) NOT NULL,
	order_status                  NVARCHAR(50) NULL,
	order_purchase_timestamp      NVARCHAR(50) NULL,
	order_approved_at             NVARCHAR(50) NULL,
	order_delivered_carrier_date  NVARCHAR(50) NULL,
	order_delivered_customer_date NVARCHAR(50) NULL,
	order_estimated_delivery_date NVARCHAR(50) NULL
);
GO

-- ------------------------------------------------------------------
-- TABLE 7: bronze.olist_products_dataset
-- Contains product attributes including category and dimensions.
-- NOTE: 'lenght' is kept as-is to match the source CSV column name.
-- ------------------------------------------------------------------
IF OBJECT_ID ('bronze.olist_products_dataset', 'U') IS NOT NULL
	DROP TABLE bronze.olist_products_dataset;
GO

CREATE TABLE bronze.olist_products_dataset (
	product_id                 NVARCHAR(32)  NOT NULL,
	product_category_name      NVARCHAR(100) NULL,
	product_name_lenght        INT           NULL,
	product_description_lenght INT           NULL,
	product_photos_qty         INT           NULL,
	product_weight_g           INT           NULL,
	product_length_cm          INT           NULL,
	product_height_cm          INT           NULL,
	product_width_cm           INT           NULL
);
GO

-- ------------------------------------------------------------
-- TABLE 8: bronze.olist_sellers_dataset
-- Contains seller information and location details.
-- ------------------------------------------------------------
IF OBJECT_ID ('bronze.olist_sellers_dataset', 'U') IS NOT NULL
	DROP TABLE bronze.olist_sellers_dataset;
GO

CREATE TABLE bronze.olist_sellers_dataset (
	seller_id              NVARCHAR(32)  NOT NULL,
	seller_zip_code_prefix NVARCHAR(5)   NULL,
	seller_city            NVARCHAR(100) NULL,
	seller_state           CHAR(2)       NULL
);
GO

-- ------------------------------------------------------------
-- TABLE 9: bronze.product_category_name_translation
-- Maps Portuguese category names to English equivalents.
-- Used in Gold layer for English-language reporting.
-- ------------------------------------------------------------
IF OBJECT_ID ('bronze.product_category_name_translation', 'U') IS NOT NULL
	DROP TABLE bronze.product_category_name_translation;
GO

CREATE TABLE bronze.product_category_name_translation (
	product_category_name         NVARCHAR(100) NOT NULL,
	product_category_name_english NVARCHAR(100) NULL
);
GO
PRINT '===========================================';
PRINT 'Bronze tables created successfully.';
PRINT '===========================================';
GO
