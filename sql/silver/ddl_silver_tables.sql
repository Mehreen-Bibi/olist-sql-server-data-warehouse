/*
================================================================================
DDL Script: Create Silver Tables
================================================================================
Script Purpose:
    This script creates tables in the 'silver' schema, dropping existing tables
    if they already exist.
    Silver layer stores cleaned, standardized, and enriched data from Bronze.

Key improvements over Bronze:
        - Audit column (dwh_load_date) added to every table
        - Primary keys enforced on key tables
        - Indexes for performance
================================================================================
*/

USE OlistDataWarehouse;
GO

-- ------------------------------------------------------------
-- TABLE 1: silver.olist_customers_dataset
-- ------------------------------------------------------------
IF OBJECT_ID('silver.olist_customers_dataset', 'U') IS NOT NULL
    DROP TABLE silver.olist_customers_dataset;
GO

CREATE TABLE silver.olist_customers_dataset (
	customer_id              NVARCHAR(32) NOT NULL,
	customer_unique_id		 NVARCHAR(32) NOT NULL,
	customer_zip_code_prefix NVARCHAR(5)  NULL,
	customer_city            NVARCHAR(50) NULL,
	customer_state           CHAR(2)      NULL,
	dwh_load_date            DATETIME2    DEFAULT SYSDATETIME(),

	CONSTRAINT PK_silver_customers PRIMARY KEY (customer_id)
);
GO

-- -------------------------------------------------------------------
-- TABLE 2: silver.olist_geolocation_dataset
-- -------------------------------------------------------------------
IF OBJECT_ID('silver.olist_geolocation_dataset', 'U') IS NOT NULL
    DROP TABLE silver.olist_geolocation_dataset;
GO

CREATE TABLE silver.olist_geolocation_dataset (
	geolocation_zip_code_prefix NVARCHAR(5)  NOT NULL,
	geolocation_lat				      DECIMAL(9,6) NOT NULL,
	geolocation_lng				      DECIMAL(9,6) NOT NULL,
	geolocation_city			      NVARCHAR(50) NULL,
	geolocation_state			      NVARCHAR(2)  NULL,
	dwh_load_date               DATETIME2    DEFAULT SYSDATETIME()

);
GO
-- ------------------------------------------------------------
-- TABLE 3: silver.olist_order_items_dataset
-- ------------------------------------------------------------
IF OBJECT_ID('silver.olist_order_items_dataset', 'U') IS NOT NULL
    DROP TABLE silver.olist_order_items_dataset;
GO

CREATE TABLE silver.olist_order_items_dataset (
	order_id			NVARCHAR(32)  NOT NULL,
	order_item_id		INT           NOT NULL,
	product_id			NVARCHAR(32)  NOT NULL,
	seller_id           NVARCHAR(32)  NOT NULL, 
	shipping_limit_date DATETIME2     NULL,
	price				DECIMAL(10,2) NULL,
	freight_value		DECIMAL(10,2) NULL,
	dwh_load_date       DATETIME2      DEFAULT SYSDATETIME(),

	CONSTRAINT PK_silver_order_items PRIMARY KEY (order_id, order_item_id)
);
GO
  
-- ------------------------------------------------------------
-- TABLE 4: silver.olist_order_payments_dataset
-- ------------------------------------------------------------
IF OBJECT_ID('silver.olist_order_payments_dataset', 'U') IS NOT NULL
    DROP TABLE silver.olist_order_payments_dataset;
GO

CREATE TABLE silver.olist_order_payments_dataset (
	order_id		         NVARCHAR(32)  NOT NULL,
	payment_sequential   INT           NOT NULL,
	payment_type	       NVARCHAR(50)  NULL,
	payment_installments INT           NULL,
	payment_value        DECIMAL(10,2) NULL,
	dwh_load_date        DATETIME2     DEFAULT SYSDATETIME(),

    CONSTRAINT PK_silver_order_payments PRIMARY KEY (order_id, payment_sequential)
);
GO

-- ------------------------------------------------------------
-- TABLE 5: silver.olist_order_reviews_dataset
-- ------------------------------------------------------------
IF OBJECT_ID('silver.olist_order_reviews_dataset', 'U') IS NOT NULL
    DROP TABLE silver.olist_order_reviews_dataset;
GO

CREATE TABLE silver.olist_order_reviews_dataset (
	review_id               NVARCHAR(32)  NOT NULL,
	order_id                NVARCHAR(32)  NOT NULL,
	review_score            INT           NULL,
	review_sentiment        NVARCHAR(20)  NULL,
	review_comment_title    NVARCHAR(100) NULL,
	review_comment_message  NVARCHAR(MAX) NULL,
	review_creation_date    DATETIME2     NULL,
	review_answer_timestamp DATETIME2     NULL,
  dwh_load_date           DATETIME2     DEFAULT SYSDATETIME()

	CONSTRAINT PK_silver_order_reviews PRIMARY KEY (review_id, order_id)
    
);
GO
-- ------------------------------------------------------------
-- TABLE 6: silver.olist_orders_dataset
-- ------------------------------------------------------------
IF OBJECT_ID('silver.olist_orders_dataset', 'U') IS NOT NULL
    DROP TABLE silver.olist_orders_dataset;
GO

CREATE TABLE silver.olist_orders_dataset (
	order_id                      NVARCHAR(32) NOT NULL,
	customer_id                   NVARCHAR(32) NULL,
	order_status                  NVARCHAR(20) NULL,
	order_purchase_timestamp      DATETIME2    NULL,
	order_approved_at             DATETIME2    NULL,
	order_delivered_carrier_date  DATETIME2    NULL,
	order_delivered_customer_date DATETIME2    NULL,
	order_estimated_delivery_date DATETIME2    NULL,
	delivery_days                 INT          NULL,
	approval_hours                INT          NULL,
  late_delivery_flag            INT          NULL,
  dwh_load_date                 DATETIME2    DEFAULT SYSDATETIME(),

    CONSTRAINT PK_silver_orders PRIMARY KEY (order_id)
);
GO

-- ------------------------------------------------------------------
-- TABLE 7: silver.olist_products_dataset
-- ------------------------------------------------------------------
IF OBJECT_ID('silver.olist_products_dataset', 'U') IS NOT NULL
    DROP TABLE silver.olist_products_dataset;
GO

CREATE TABLE silver.olist_products_dataset (
	product_id                 NVARCHAR(32)  NOT NULL,
	product_category_name      NVARCHAR(100) NULL,
	product_name_lenght        INT           NULL,
	product_description_lenght INT           NULL,
	product_photos_qty         INT           NULL,
	product_weight_g           INT           NULL,
	product_length_cm          INT           NULL,
	product_height_cm          INT           NULL,
	product_width_cm           INT           NULL,
	product_volume_cm3         INT           NULL,
  dwh_load_date              DATETIME2     DEFAULT SYSDATETIME(),

    CONSTRAINT PK_silver_products PRIMARY KEY (product_id)
);
GO

-- ------------------------------------------------------------
-- TABLE 8: silver.olist_sellers_dataset
-- ------------------------------------------------------------
IF OBJECT_ID('silver.olist_sellers_dataset', 'U') IS NOT NULL
    DROP TABLE silver.olist_sellers_dataset;
GO

CREATE TABLE silver.olist_sellers_dataset (
	seller_id              NVARCHAR(32) NOT NULL,
	seller_zip_code_prefix NVARCHAR(5)  NULL,
	seller_city            NVARCHAR(50) NULL,
	seller_state           CHAR(2)      NULL,
	dwh_load_date          DATETIME2    DEFAULT SYSDATETIME(),

    CONSTRAINT PK_silver_sellers PRIMARY KEY (seller_id)
);
GO

-- ------------------------------------------------------------
-- TABLE 9: silver.product_category_name_translation
-- ------------------------------------------------------------
IF OBJECT_ID('silver.product_category_name_translation', 'U') IS NOT NULL
    DROP TABLE silver.product_category_name_translation;
GO

CREATE TABLE silver.product_category_name_translation (
	product_category_name         NVARCHAR(100) NOT NULL,
	product_category_name_english NVARCHAR(100) NULL,
	dwh_load_date                 DATETIME2     DEFAULT SYSDATETIME(),

	CONSTRAINT PK_silver_category_translation PRIMARY KEY (product_category_name)
);
GO

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Indexes for order_items 
CREATE INDEX IX_silver_order_items_order_id 
	ON silver.olist_order_items_dataset (order_id);
GO

CREATE INDEX IX_silver_order_items_product_id 
	ON silver.olist_order_items_dataset (product_id);
GO

CREATE INDEX IX_silver_order_items_seller_id 
	ON silver.olist_order_items_dataset (seller_id);
GO
  
-- Payments Index 
CREATE INDEX IX_silver_order_payments_order_id 
ON silver.olist_order_payments_dataset (order_id);
GO

-- Reviews Index
CREATE INDEX IX_silver_order_reviews_order_id 
ON silver.olist_order_reviews_dataset(order_id);
GO

CREATE INDEX IX_silver_orders_customer_id 
ON silver.olist_orders_dataset(customer_id);
GO

-- ============================================================================
-- DEPLOYMENT SUMMARY
-- ============================================================================
PRINT '============================================================';
PRINT 'DEPLOYMENT SUMMARY:';
PRINT '  Schema          : silver';
PRINT '  Tables Created  : 9 tables';
PRINT '  Primary Keys    : 8 tables (all except geolocation)';
PRINT '  Indexes         : 6 performance indexes created';
PRINT '  Status          : SUCCESS';
PRINT '============================================================';
GO
