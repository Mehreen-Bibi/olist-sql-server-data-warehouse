/*
================================================================================
DDL SCRIPT: Create Gold Layer (Star Schema)
================================================================================
Script Purpose:
    This script creates tables in the 'gold' schema, dropping existing tables
    if they already exist.
    Gold layer stores business-ready facts and dimensions built from Silver,
    modeled as a star schema for analytics and reporting.

Key improvements over Silver:
    - Surrogate keys (*_key) used for all dimension tables
    - Natural keys preserved alongside surrogate keys for traceability
    - Fact tables reference dimensions via surrogate keys, enforced
      with foreign keys
    - Indexes for performance on all fact-to-dimension join columns
    - SCD Type 1 strategy applied to dimensions (no historical tracking)

Tables:
    Dimensions (6):
        dim_customer        - Who bought? (SCD Type 1 - latest address only)
        dim_product         - What was bought?
        dim_seller          - Who sold it? (SCD Type 1 - latest address only)
        dim_date            - Calendar date dimension
        dim_order_status    - Order status lookup
        dim_payment_method  - Payment method lookup

    Facts (4):
        fact_sales          - One row per order item (product performance)
        fact_delivery       - One row per order (logistics) - includes date keys
        fact_reviews        - One row per review (customer feedback)
        fact_payments       - One row per payment installment

Usage:
    Run this script to create or recreate all Gold layer tables.
    Run before executing gold.load_gold stored procedure.
================================================================================
*/

USE OlistDataWarehouse;
GO

-- ============================================================================
-- STEP 0: DROP EXISTING TABLES IN REVERSE DEPENDENCY ORDER
-- Facts must be dropped BEFORE Dimensions to avoid FK constraint errors.
-- ============================================================================

-- 0.1 Drop Fact Tables First (they reference Dimensions)
IF OBJECT_ID('gold.fact_sales', 'U') IS NOT NULL
    DROP TABLE gold.fact_sales;
GO

IF OBJECT_ID('gold.fact_delivery', 'U') IS NOT NULL
    DROP TABLE gold.fact_delivery;
GO

IF OBJECT_ID('gold.fact_reviews', 'U') IS NOT NULL
    DROP TABLE gold.fact_reviews;
GO

IF OBJECT_ID('gold.fact_payments', 'U') IS NOT NULL
    DROP TABLE gold.fact_payments;
GO

-- 0.2 Drop Dimension Tables Second (no dependencies on facts)
IF OBJECT_ID('gold.dim_customer', 'U') IS NOT NULL
    DROP TABLE gold.dim_customer;
GO

IF OBJECT_ID('gold.dim_product', 'U') IS NOT NULL
    DROP TABLE gold.dim_product;
GO

IF OBJECT_ID('gold.dim_seller', 'U') IS NOT NULL
    DROP TABLE gold.dim_seller;
GO

IF OBJECT_ID('gold.dim_date', 'U') IS NOT NULL
    DROP TABLE gold.dim_date;
GO

IF OBJECT_ID('gold.dim_order_status', 'U') IS NOT NULL
    DROP TABLE gold.dim_order_status;
GO

IF OBJECT_ID('gold.dim_payment_method', 'U') IS NOT NULL
    DROP TABLE gold.dim_payment_method;
GO
-- ============================================================================
-- STEP 1: CREATE DIMENSION TABLES 
-- ============================================================================

-- ------------------------------------------------------------
-- DIMENSION 1: gold.dim_customer
-- Who bought? One row per customer_unique_id.
-- SCD Strategy: Type 1.
-- Surrogate key: customer_key
-- Natural key:   customer_unique_id
-- ------------------------------------------------------------
CREATE TABLE gold.dim_customer(
    customer_key       INT IDENTITY(1,1) NOT NULL, -- Surrogate key
    customer_unique_id NVARCHAR(32)      NOT NULL, -- Natural key
    customer_zip_code  NVARCHAR(5)       NULL,     
    customer_city      NVARCHAR(100)     NULL,    
    customer_state     CHAR(2)           NULL,    

    CONSTRAINT PK_dim_customers PRIMARY KEY (customer_key),
    CONSTRAINT UQ_dim_customer_natural UNIQUE (customer_unique_id)
);
GO

-- ------------------------------------------------------------
-- DIMENSION 2: gold.dim_product
-- What was bought? One row per product_id.
-- SCD Strategy: Type 1.
-- Surrogate key: product_key
-- Natural key:   product_id
-- ------------------------------------------------------------
CREATE TABLE gold.dim_product(
    product_key                INT IDENTITY(1,1) NOT NULL, -- Surrogate key
    product_id                 NVARCHAR(32)      NOT NULL, -- Natural key
    product_category_name      NVARCHAR(100)     NULL,     -- Portuguese category
    product_category_english   NVARCHAR(100)     NULL,     -- English category
    product_weight_g           INT               NULL,     
    product_length_cm          INT               NULL,     
    product_height_cm          INT               NULL,     
    product_width_cm           INT               NULL,     
    product_volume_cm3         INT               NULL,

    CONSTRAINT PK_dim_products PRIMARY KEY (product_key),
    CONSTRAINT UQ_dim_product_natural UNIQUE (product_id)

);
GO

-- ----------------------------------------------------------------------------
-- DIMENSION 3: gold.dim_seller
-- Who sold it? One row per seller_id.
-- Includes geolocation coordinates for map visualization.
-- Surrogate key: seller_key
-- Natural key:   seller_id
-- ----------------------------------------------------------------------------
CREATE TABLE gold.dim_seller (
    seller_key      INT IDENTITY(1,1) NOT NULL, -- Surrogate key
    seller_id       NVARCHAR(32)      NOT NULL, -- Natural key
    seller_zip_code NVARCHAR(5)       NULL,     
    seller_city     NVARCHAR(100)     NULL,   
    seller_state    CHAR(2)           NULL,    

    CONSTRAINT PK_dim_sellers PRIMARY KEY (seller_key),
    CONSTRAINT UQ_dim_seller_natural UNIQUE (seller_id)

);
GO
-- ------------------------------------------------------------
-- DIMENSION 4: gold.dim_date
-- When? One row per calendar date, generated from the order date
-- range plus a one-year buffer on each side.
-- Required for Power BI time intelligence functions.
-- Surrogate key: date_key (YYYYMMDD integer format)
-- Natural key:   full_date
-- ------------------------------------------------------------
CREATE TABLE gold.dim_date (
    date_key       INT           NOT NULL, -- Surrogate key
    full_date      DATE          NOT NULL, -- Natural key
    year_number    SMALLINT      NOT NULL, -- e.g 2017
    quarter_number TINYINT       NOT NULL, -- 1, 2, 3, 4]
    quarter_name   NVARCHAR(5)   NOT NULL, -- Q1, Q2, Q3, Q4
    month_number   TINYINT       NOT NULL, -- 1 - 12
    month_name     NVARCHAR(20)  NOT NULL, -- January, February etc.
    week_number    TINYINT       NOT NULL, -- 1 -53
    day_number     TINYINT       NOT NULL, -- 1 - 31
    day_of_week    TINYINT       NOT NULL, -- 1 = Sunday 7 = Saturday
    day_name       NVARCHAR(20)  NOT NULL, -- Monday, tuesday etc.
    -- Useful derived columns for Power BI
    year_month     NVARCHAR(7)   NOT NULL, -- 2017-10 (for sorting)
    is_weekend     BIT           NOT NULL, -- 1=weekend 0=weekday
    -- Brazilian season (Southern hemisphere seasons)
    brazil_season  NVARCHAR(10)  NULL,     -- Summer/Autumn/Winter/Spring

    CONSTRAINT PK_dim_date PRIMARY KEY (date_key)
);
GO

-- ----------------------------------------------------------------------------
-- DIMENSION 5: gold.dim_order_status
-- Lookup table for order status values.
-- Small dimension — manually loaded with known values.
-- Surrogate key: status_key
-- Natural key:   status_code
-- ----------------------------------------------------------------------------
CREATE TABLE gold.dim_order_status (
    order_status_key INT IDENTITY(1,1) NOT NULL, -- Surrogate key
    order_status     NVARCHAR(30)      NOT NULL, -- Natural key

    CONSTRAINT PK_dim_order_status PRIMARY KEY (order_status_key),
    CONSTRAINT UQ_dim_order_status_natural UNIQUE (order_status)
);
GO

-- ----------------------------------------------------------------------------
-- DIMENSION 6: gold.dim_payment_method
-- Lookup table for payment method values.
-- Small dimension — manually loaded with known values.
-- Surrogate key: payment_type_key
-- Natural key:   payment_type_code
-- ----------------------------------------------------------------------------
CREATE TABLE gold.dim_payment_method (
    payment_method_key INT IDENTITY(1,1) NOT NULL, -- Surrogate key
    payment_type       NVARCHAR(20)      NOT NULL, -- Natural key

    CONSTRAINT PK_dim_payment_type PRIMARY KEY (payment_method_key),
    CONSTRAINT UQ_dim_payment_method_natural UNIQUE (payment_type)
);
GO

-- ============================================================================
-- STEP 2: CREATE FACT TABLES
-- ============================================================================

-- --------------------------------------------------------------------
-- FACT 1: gold.fact_sales
-- Grain: one row = one order item.
-- total_item_value is computed automatically from price + freight.
-- --------------------------------------------------------------------
CREATE TABLE gold.fact_sales (
   sales_key           BIGINT IDENTITY(1,1) NOT NULL,
   order_id            NVARCHAR(32)         NOT NULL,
   order_item_id       INT                  NOT NULL,
   -- Foreign Keys to Dimensions
   customer_key        INT                  NULL,
   product_key         INT                  NULL,
   seller_key          INT                  NULL,
   order_date_key      INT                  NULL,
   order_status_key    INT                  NULL,
   shipping_limit_date DATETIME2            NULL,
   -- Mearsures
   quantity            INT                  NOT NULL DEFAULT 1,
   item_price          DECIMAL(10,2)        NULL,
   freight_value       DECIMAL(10,2)        NULL,
   total_item_value    AS (item_price + freight_value) PERSISTED,

   -- primary key
   CONSTRAINT PK_fact_sales PRIMARY KEY (sales_key),
   -- foreign keys
   CONSTRAINT FK_fact_sales_customer FOREIGN KEY (customer_key)     
       REFERENCES gold.dim_customer(customer_key),
   CONSTRAINT FK_fact_sales_product FOREIGN KEY (product_key)     
       REFERENCES gold.dim_product(product_key),
   CONSTRAINT FK_fact_sales_seller FOREIGN KEY (seller_key)       
       REFERENCES gold.dim_seller(seller_key),
   CONSTRAINT FK_fact_sales_date FOREIGN KEY (order_date_key)   
       REFERENCES gold.dim_date(date_key),
   CONSTRAINT FK_fact_sales_status FOREIGN KEY (order_status_key) 
       REFERENCES gold.dim_order_status(order_status_key)
);
GO

-- ------------------------------------------------------------
-- FACT 2: gold.fact_delivery
-- Grain: one row = one order.
-- ------------------------------------------------------------
CREATE TABLE gold.fact_delivery (
    delivery_key                      INT IDENTITY(1,1) NOT NULL,
    order_id                          NVARCHAR(32)      NOT NULL,
    -- Foreign Keys to Dimensions
    customer_key                      INT               NULL,
    order_status_key                  INT               NULL,
    -- Date Keys (for fast joins to dim_date)
    order_purchase_date_key           INT               NULL,
    order_approved_date_key           INT               NULL,
    order_delivered_carrier_date_key  INT               NULL,
    order_delivered_customer_date_key INT               NULL,
    order_estimated_delivery_date_key INT               NULL,
    -- Raw Timestamps 
    order_purchase_timestamp          DATETIME2         NULL,
    order_approved_at                 DATETIME2         NULL,
    order_delivered_carrier_date      DATETIME2         NULL,
    order_delivered_customer_date     DATETIME2         NULL,
    order_estimated_delivery_date     DATETIME2         NULL,
     -- Business Metrics
    delivery_days                     INT               NULL, -- Days between purchase and delivery
    approval_hours                    INT               NULL, -- Hours between purchase and approval
    late_delivery_flag                INT               NULL, -- 1 = delivered after estimated date

    -- primark key
    CONSTRAINT PK_fact_delivery PRIMARY KEY (delivery_key),
    -- foreign keys
    CONSTRAINT FK_fact_delivery_customer FOREIGN KEY (customer_key) 
        REFERENCES gold.dim_customer(customer_key),
    CONSTRAINT FK_fact_delivery_status   FOREIGN KEY (order_status_key) 
        REFERENCES gold.dim_order_status(order_status_key),
    CONSTRAINT FK_fact_delivery_purchase_date FOREIGN KEY (order_purchase_date_key) 
        REFERENCES gold.dim_date(date_key)
);
GO

-- ----------------------------------------------------------------------------
-- FACT 3: gold.fact_reviews
-- Grain: One row = one review
-- ----------------------------------------------------------------------------
CREATE TABLE gold.fact_reviews (
    review_key              INT IDENTITY(1,1) NOT NULL,
    review_id               NVARCHAR(32)      NOT NULL,
    order_id                NVARCHAR(32)      NOT NULL,
    -- Foreign Keys to Dimensions
    customer_key            INT               NULL,
    review_date_key         INT               NULL,

    review_creation_date    DATETIME2         NULL,
    review_answer_timestamp DATETIME2         NULL,
    review_score            INT               NULL,
    review_sentiment        NVARCHAR(20)      NULL,
    has_comment             BIT               NULL DEFAULT 0,

    -- primary key
    CONSTRAINT PK_gold_fact_reviews PRIMARY KEY (review_key),
    -- foreign keys
    CONSTRAINT FK_fact_reviews_customer FOREIGN KEY (customer_key)   
        REFERENCES gold.dim_customer(customer_key),
    CONSTRAINT FK_fact_reviews_date FOREIGN KEY (review_date_key) 
        REFERENCES gold.dim_date(date_key)
);
GO

-- ----------------------------------------------------------------------------
-- FACT 4: gold.fact_payments
-- Grain: One row = one payment installment per order
-- (order_id + payment_sequential)
-- Purpose: Analyze payment behavior, installments, and total
-- order value without distorting item-level sales.
-- ----------------------------------------------------------------------------
CREATE TABLE gold.fact_payments (
    payment_fact_key     INT IDENTITY(1,1) NOT NULL,

    -- Natural Keys
    order_id             NVARCHAR(32)  NOT NULL,
    payment_sequential   INT           NOT NULL,
    -- Foreign Keys to Dimensions
    customer_key         INT           NULL,  
    order_date_key       INT           NULL,  
    payment_method_key   INT           NULL,   

    -- Measures
    payment_installments INT           NULL,   
    payment_value        DECIMAL(10,2) NULL,   

    -- primary key
    CONSTRAINT PK_gold_fact_payments PRIMARY KEY (payment_fact_key),
    -- foreign keys
    CONSTRAINT FK_fact_payments_customer FOREIGN KEY (customer_key)       
        REFERENCES gold.dim_customer(customer_key),
    CONSTRAINT FK_fact_payments_date     FOREIGN KEY (order_date_key)     
        REFERENCES gold.dim_date(date_key),
    CONSTRAINT FK_fact_payments_method   FOREIGN KEY (payment_method_key) 
        REFERENCES gold.dim_payment_method(payment_method_key)
);
GO

-- ============================================================================
-- STEP 3: INDEXES FOR PERFORMANCE 
-- One index per foreign-key / join column on every fact table, so
-- Power BI-style filters and joins to dimensions stay fast.
-- ============================================================================

-- Indexes for fact_sales
CREATE INDEX IX_fact_sales_order_id
    ON gold.fact_sales(order_id);
GO
CREATE INDEX IX_fact_sales_customer_key    
    ON gold.fact_sales(customer_key);
GO
CREATE INDEX IX_fact_sales_product_key     
    ON gold.fact_sales(product_key);
GO
CREATE INDEX IX_fact_sales_seller_key      
    ON gold.fact_sales(seller_key);
GO
CREATE INDEX IX_fact_sales_order_date_key   
    ON gold.fact_sales(order_date_key);
GO

-- Indexes for fact_delivery 
CREATE INDEX IX_fact_delivery_order_id
    ON gold.fact_delivery(order_id);
GO
CREATE INDEX IX_fact_delivery_customer_key
    ON gold.fact_delivery(customer_key);
GO
CREATE INDEX IX_fact_delivery_order_status_key                
    ON gold.fact_delivery(order_status_key);
GO
CREATE INDEX IX_fact_delivery_purchase_date_key               
    ON gold.fact_delivery(order_purchase_date_key);
GO

-- Indexes for fact_reviews
CREATE INDEX IX_fact_reviews_order_id         
    ON gold.fact_reviews(order_id);
GO
CREATE INDEX IX_fact_reviews_customer_key     
    ON gold.fact_reviews(customer_key);
GO
CREATE INDEX IX_fact_reviews_review_date_key  
    ON gold.fact_reviews(review_date_key);
GO

-- Indexes for fact_payments
CREATE INDEX IX_fact_payments_order_id            
    ON gold.fact_payments(order_id);
GO
CREATE INDEX IX_fact_payments_customer_key        
    ON gold.fact_payments(customer_key);
GO
CREATE INDEX IX_fact_payments_order_date_key      
    ON gold.fact_payments(order_date_key);
GO
CREATE INDEX IX_fact_payments_payment_method_key  
    ON gold.fact_payments(payment_method_key);
GO

-- ============================================================================
-- DEPLOYMENT SUMMARY
-- ============================================================================
PRINT '============================================================';
PRINT 'DEPLOYMENT SUMMARY:';
PRINT '  Schema          : gold';
PRINT '  Dimensions      : 6 tables (customer, product, seller, date, order_status, payment_method)';
PRINT '  Facts           : 4 tables (sales, delivery, reviews, payments)';
PRINT '  Constraints     : PRIMARY KEY, UNIQUE, FOREIGN KEY applied';
PRINT '  Indexes         : 16 performance indexes created';
PRINT '  Status          : SUCCESS';
PRINT '============================================================';
GO
