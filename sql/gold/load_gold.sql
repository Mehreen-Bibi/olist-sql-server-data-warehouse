/*
================================================================================
Stored Procedure: Load Gold Layer (Silver -> Gold)
================================================================================
Script Purpose:
    Transforms cleaned Silver data into a Star Schema for business reporting.
    Populates all dimension and fact tables in the Gold layer.

Actions Performed:
    - Logs batch start to etl.BatchLog
    - Truncates all Gold tables in correct order (facts first then dims)
    - Loads dimension tables in correct dependency order
    - Loads fact tables after all dimensions are populated
    - Generates dim_date from order date range automatically
    - Maps natural keys to surrogate keys using JOIN
    - Computes derived metrics in fact tables
    - Logs each table load to etl.TableLoadLog with duration
    - Updates batch summary on completion
    - Rolls back entire transaction on any error
    - Re-raises errors to caller using THROW

Note on Transaction:
    All Gold tables are loaded in a single transaction.
    If any table fails all changes are rolled back preventing
    partial loads that would cause inconsistent reporting data.

Note on Load Order:
    Dimensions loaded before facts — facts require surrogate keys
    from dimensions to exist before they can be inserted.

Parameters:
    None.

Usage Example:
    EXEC gold.load_gold;
================================================================================
*/
USE OlistDataWarehouse;
GO

CREATE OR ALTER PROCEDURE gold.load_gold AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ==================================================================
    -- VARIABLES
    -- ==================================================================
    DECLARE
        @BatchID          INT,
        @RowsLoaded       INT,
        @TotalTables      INT,
        @start_time       DATETIME2,
        @end_time         DATETIME2,
        @batch_start_time DATETIME2,
        @batch_end_time   DATETIME2,
        @CurrentTable     NVARCHAR(100),
        @min_date         DATE,
        @max_date         DATE;

    -- ==================================================================
    -- STEP 1: START BATCH LOG
    -- ==================================================================
    SET @batch_start_time = SYSDATETIME();

    INSERT INTO etl.BatchLog
        (ProcessName, LayerName, StartTime, Status)
    VALUES 
        ('load_gold', 'gold', @batch_start_time, 'RUNNING');

    SET @BatchID = SCOPE_IDENTITY();

    PRINT '==================================================================';
    PRINT 'Loading Gold Layer (Star Schema)';
    PRINT 'BatchID: ' + CAST(@BatchID AS NVARCHAR);
    PRINT '==================================================================';

    BEGIN TRY
        
        -- =====================================================
        -- STEP 2: BEGIN EXPLICIT TRANSACTION
        -- =====================================================
        BEGIN TRANSACTION;

        -- =====================================================
        -- STEP 3: Disable FK constraints (safety net)
        -- =====================================================
        PRINT '>> Disabling FK constraints...';

        ALTER TABLE gold.fact_sales     NOCHECK CONSTRAINT ALL;
        ALTER TABLE gold.fact_delivery  NOCHECK CONSTRAINT ALL;
        ALTER TABLE gold.fact_payments  NOCHECK CONSTRAINT ALL;
        ALTER TABLE gold.fact_reviews   NOCHECK CONSTRAINT ALL;

        PRINT '>> FK constraints disabled.';
        PRINT '';

        -- =====================================================
        -- STEP 4: DELETE ALL TABLES IN CORRECT ORDER + RESEED
        -- Facts first (children), then Dimensions (parents)
        -- =====================================================
        PRINT '>> Clearing Fact Tables (DELETE + RESEED)...';

        DELETE FROM gold.fact_sales;
        DELETE FROM gold.fact_delivery;
        DELETE FROM gold.fact_payments;
        DELETE FROM gold.fact_reviews;

        -- Reset identity seeds for Fact tables
        DBCC CHECKIDENT ('gold.fact_sales', RESEED, 0);
        DBCC CHECKIDENT ('gold.fact_delivery', RESEED, 0);
        DBCC CHECKIDENT ('gold.fact_payments', RESEED, 0);
        DBCC CHECKIDENT ('gold.fact_reviews', RESEED, 0);

        PRINT '>> Clearing Dimension Tables (DELETE + RESEED)...';

        DELETE FROM gold.dim_customer;
        DELETE FROM gold.dim_product;
        DELETE FROM gold.dim_seller;
        DELETE FROM gold.dim_date;
        DELETE FROM gold.dim_order_status;
        DELETE FROM gold.dim_payment_method;

        -- Reset identity seeds for Dimension tables
        DBCC CHECKIDENT ('gold.dim_customer', RESEED, 0);
        DBCC CHECKIDENT ('gold.dim_product', RESEED, 0);
        DBCC CHECKIDENT ('gold.dim_seller', RESEED, 0);
        DBCC CHECKIDENT ('gold.dim_order_status', RESEED, 0);
        DBCC CHECKIDENT ('gold.dim_payment_method', RESEED, 0);
        -- dim_date uses manual integer key, no identity reset needed

        PRINT '>> All Gold tables cleared and reseeded.';
        PRINT '';

        -- =====================================================
        -- STEP 5: Re-enable FK constraints BEFORE inserting
        -- This validates the structure and keeps them trusted.
        -- =====================================================
        PRINT '>> Re-enabling FK constraints...';

        ALTER TABLE gold.fact_sales     CHECK CONSTRAINT ALL;
        ALTER TABLE gold.fact_delivery  CHECK CONSTRAINT ALL;
        ALTER TABLE gold.fact_payments  CHECK CONSTRAINT ALL;
        ALTER TABLE gold.fact_reviews   CHECK CONSTRAINT ALL;

        PRINT '>> FK constraints re-enabled.';
        PRINT '';

        -- ==================================================================
        -- Dimension 1: gold.dim_customer
        -- ==================================================================
        SET @CurrentTable = 'dim_customer';
        SET @start_time   = SYSDATETIME(); 

        PRINT '>> Inserting Data Into: gold.dim_customer';
        INSERT INTO gold.dim_customer 
            (customer_unique_id, customer_zip_code, customer_city, customer_state)
        SELECT
            customer_unique_id,
            customer_zip_code,
            customer_city,
            customer_state
        FROM (
            SELECT
                customer_id,
                customer_unique_id,
                customer_zip_code_prefix AS customer_zip_code,
                customer_city,
                customer_state,
                ROW_NUMBER() OVER(PARTITION BY customer_unique_id ORDER BY customer_id) AS rn
            FROM silver.olist_customers_dataset
        ) dedup
        WHERE rn = 1;

        SET @RowsLoaded = @@ROWCOUNT;
        SET @end_time   = SYSDATETIME();

        INSERT INTO etl.TableLoadLog
        (
            BatchID, SchemaName, TableName,
            StartTime, EndTime, DurationSeconds,
            RowsLoaded, RowsRejected, Status
        )
        VALUES
        (
            @BatchID, 'gold', @CurrentTable,
            @start_time, @end_time, DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
            @RowsLoaded, 0, 'SUCCESS'
        );

        PRINT '>> Rows Loaded: ' + CAST(@RowsLoaded AS NVARCHAR(20));
        PRINT '>> ------------------------------------------------';

        -- ==================================================================
        -- Dimension 2: gold.dim_product
        -- Joins category translation for English category name.
        -- LEFT JOIN because some category names have no English
        -- mapping in the source translation file.
        -- ==================================================================
        SET @CurrentTable = 'dim_product';
        SET @start_time   = SYSDATETIME();

        PRINT '>> Inserting Data Into: gold.dim_product';
        INSERT INTO gold.dim_product
            (product_id, product_category_name, product_category_english,
            product_weight_g, product_length_cm, product_height_cm,
            product_width_cm, product_volume_cm3)
        SELECT
            p.product_id,
            p.product_category_name,
            t.product_category_name_english,
            p.product_weight_g,
            p.product_length_cm,
            p.product_height_cm,
            p.product_width_cm,
            p.product_volume_cm3
        FROM silver.olist_products_dataset p
        LEFT JOIN silver.product_category_name_translation t
            ON p.product_category_name = t.product_category_name;

        SET @RowsLoaded = @@ROWCOUNT;
        SET @end_time   = SYSDATETIME();

        INSERT INTO etl.TableLoadLog
        (
            BatchID, SchemaName, TableName,
            StartTime, EndTime, DurationSeconds,
            RowsLoaded, RowsRejected, Status
        )
        VALUES
        (
            @BatchID, 'gold', @CurrentTable,
            @start_time, @end_time, DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
            @RowsLoaded, 0, 'SUCCESS'
        );

        PRINT '>> Rows Loaded: ' + CAST(@RowsLoaded AS NVARCHAR(20));
        PRINT '>> ------------------------------------------------';

        -- ==================================================================
        -- Dimension 3: gold.dim_seller
        -- ==================================================================
        SET @CurrentTable = 'dim_seller';
        SET @start_time   = SYSDATETIME();

        PRINT '>> Inserting Data Into: gold.dim_seller';
        INSERT INTO gold.dim_seller
            (seller_id, seller_zip_code, seller_city, seller_state)
        SELECT
            seller_id,
            seller_zip_code_prefix AS seller_zip_code,
            seller_city,
            seller_state
        FROM silver.olist_sellers_dataset;
    
        SET @RowsLoaded = @@ROWCOUNT;
        SET @end_time   = SYSDATETIME();

        INSERT INTO etl.TableLoadLog
        (
            BatchID, SchemaName, TableName,
            StartTime, EndTime, DurationSeconds,
            RowsLoaded, RowsRejected, Status
        )
        VALUES
        (
            @BatchID, 'gold', @CurrentTable,
            @start_time, @end_time, DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
            @RowsLoaded, 0, 'SUCCESS'
        );

        PRINT '>> Rows Loaded: ' + CAST(@RowsLoaded AS NVARCHAR(20));
        PRINT '>> ------------------------------------------------';

        -- ==================================================================
        -- TABLE 1: gold.dim_date
        -- Generated across the full order date range using a
        -- recursive CTE (capped at 10 years to avoid a runaway loop).
        -- ==================================================================
        SET @CurrentTable = 'dim_date';
        SET @start_time   = SYSDATETIME();

        -- Find absolute min and max across ALL date columns
        SELECT
            @min_date = MIN(DateValue),
            @max_date = MAX(DateValue)
        FROM (
            SELECT order_purchase_timestamp AS DateValue 
            FROM silver.olist_orders_dataset
            UNION ALL
            SELECT order_approved_at 
            FROM silver.olist_orders_dataset 
            WHERE order_approved_at IS NOT NULL
            UNION ALL
            SELECT order_delivered_carrier_date 
            FROM silver.olist_orders_dataset 
            WHERE order_delivered_carrier_date IS NOT NULL
            UNION ALL
            SELECT order_delivered_customer_date 
            FROM silver.olist_orders_dataset 
            WHERE order_delivered_customer_date IS NOT NULL
            UNION ALL
            SELECT order_estimated_delivery_date 
            FROM silver.olist_orders_dataset 
            WHERE order_estimated_delivery_date IS NOT NULL
            UNION ALL
            SELECT shipping_limit_date 
            FROM silver.olist_order_items_dataset 
            WHERE shipping_limit_date IS NOT NULL
            UNION ALL
            SELECT review_creation_date 
            FROM silver.olist_order_reviews_dataset 
            WHERE review_creation_date IS NOT NULL
            UNION ALL
            SELECT review_answer_timestamp 
            FROM silver.olist_order_reviews_dataset 
            WHERE review_answer_timestamp IS NOT NULL
        ) AS AllDates(DateValue)
        WHERE DateValue IS NOT NULL;

        PRINT '>> Inserting Data Into: gold.dim_date';
        WITH date_seq AS (
            SELECT @min_date AS full_date
            UNION ALL
            SELECT DATEADD(Day, 1, full_date)
            FROM date_seq
            WHERE full_date < @max_date
        )
        INSERT INTO gold.dim_date
            (date_key, full_date, year_number, quarter_number, quarter_name, 
            month_number, month_name, week_number, day_number, day_of_week,
            day_name, year_month, is_weekend, brazil_season)
        SELECT
            CAST(FORMAT(full_date, 'yyyyMMdd') AS INT) AS date_key,
            full_date,
            YEAR(full_date) AS year_number,
            DATEPART(QUARTER, full_date) AS quarter_number,
            'Q' + CAST(DATEPART(QUARTER, full_date) AS NVARCHAR(1)) AS quarter_name,
            MONTH(full_date) AS month_number,
            DATENAME(MONTH, full_date) AS month_name,
            DATEPART(WEEK, full_date) AS week_number,
            DAY(full_date) AS day_number,
            DATEPART(WEEKDAY, full_date) AS day_of_week,
            DATENAME(WEEKDAY, full_date) AS day_name,
            FORMAT(full_date, 'yyyy-MM') AS year_month,
            CASE
                WHEN DATEPART(WEEKDAY, full_date) IN (1, 7) THEN 1
                ELSE 0
            END AS is_weekend,
            CASE
                WHEN MONTH(full_date) IN (12, 1, 2)  THEN 'Summer'
                WHEN MONTH(full_date) IN (3,  4, 5)  THEN 'Autumn'
                WHEN MONTH(full_date) IN (6,  7, 8)  THEN 'Winter'
                WHEN MONTH(full_date) IN (9, 10, 11) THEN 'Spring'
            END AS brazil_season
            FROM date_seq
            OPTION (MAXRECURSION 0);

            SET @RowsLoaded = @@ROWCOUNT;
        SET @end_time   = SYSDATETIME();

        INSERT INTO etl.TableLoadLog
        (
            BatchID, SchemaName, TableName,
            StartTime, EndTime, DurationSeconds,
            RowsLoaded, RowsRejected, Status
        )
        VALUES
        (
            @BatchID, 'gold', @CurrentTable,
            @start_time, @end_time, DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
            @RowsLoaded, 0, 'SUCCESS'
        );

        PRINT '>> Rows Loaded: ' + CAST(@RowsLoaded AS NVARCHAR(20));
        PRINT '>> ------------------------------------------------';
        -- ==================================================================
        -- Dimension 5: gold.dim_order_status
        -- ==================================================================
        SET @CurrentTable = 'dim_order_status';
        SET @start_time   = SYSDATETIME();

        PRINT '>> Inserting Data Into: gold.dim_order_status';
        INSERT INTO gold.dim_order_status
        (
            order_status
        )
        SELECT 
        DISTINCT order_status
        FROM silver.olist_orders_dataset;

        SET @RowsLoaded = @@ROWCOUNT;
        SET @end_time   = SYSDATETIME();

        INSERT INTO etl.TableLoadLog
        (
            BatchID, SchemaName, TableName,
            StartTime, EndTime, DurationSeconds,
            RowsLoaded, RowsRejected, Status
        )
        VALUES
        (
            @BatchID, 'gold', @CurrentTable,
            @start_time, @end_time, DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
            @RowsLoaded, 0, 'SUCCESS'
        );

        PRINT '>> Rows Loaded: ' + CAST(@RowsLoaded AS NVARCHAR(20));
        PRINT '>> ------------------------------------------------';

        -- ==================================================================
        -- Dimension 6: gold.dim_payment_type
        -- ==================================================================
        SET @CurrentTable = 'dim_payment_method';
        SET @start_time   = SYSDATETIME();

        PRINT '>> Inserting Data Into: gold.dim_payment_method';
        INSERT INTO gold.dim_payment_method
        (
            payment_type
        )
        SELECT
            DISTINCT payment_type
        FROM silver.olist_order_payments_dataset;

        SET @RowsLoaded = @@ROWCOUNT;
        SET @end_time   = SYSDATETIME();

        INSERT INTO etl.TableLoadLog
        (
            BatchID, SchemaName, TableName,
            StartTime, EndTime, DurationSeconds,
            RowsLoaded, RowsRejected, Status
        )
        VALUES
        (
            @BatchID, 'gold', @CurrentTable,
            @start_time, @end_time, DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
            @RowsLoaded, 0, 'SUCCESS'
        );

        PRINT '>> Rows Loaded: ' + CAST(@RowsLoaded AS NVARCHAR(20));
        PRINT '>> ------------------------------------------------';
    
        -- =====================================================
        -- Fact 1: gold.fact_sales
        -- Grain: one row per order item.
        -- =====================================================
        SET @CurrentTable = 'fact_sales';
        SET @start_time   = SYSDATETIME();

        PRINT '>> Inserting Data Into: gold.fact_sales';
        INSERT INTO gold.fact_sales 
            (order_id, order_item_id, customer_key, product_key, seller_key,
            order_date_key, order_status_key, shipping_limit_date,
            quantity, item_price, freight_value)
        SELECT 
            oi.order_id,
            oi.order_item_id,
            dc.customer_key,
            dp.product_key,
            ds.seller_key,
            CAST(FORMAT(o.order_purchase_timestamp, 'yyyyMMdd') AS INT) AS order_date_key,
            dos.order_status_key,
            oi.shipping_limit_date,
            1 AS quantity,
            oi.price AS item_price,
            oi.freight_value
        FROM silver.olist_order_items_dataset oi
        LEFT JOIN silver.olist_orders_dataset o
            ON oi.order_id = o.order_id
        LEFT JOIN silver.olist_customers_dataset c
            ON o.customer_id = c.customer_id
        LEFT JOIN gold.dim_customer dc
            ON c.customer_unique_id = dc.customer_unique_id
        LEFT JOIN gold.dim_product dp
            ON oi.product_id = dp.product_id
        LEFT JOIN gold.dim_seller ds
            ON oi.seller_id = ds.seller_id
        LEFT JOIN gold.dim_date dd
            ON CAST(o.order_purchase_timestamp AS DATE) = dd.full_date
        LEFT JOIN gold.dim_order_status dos
            ON o.order_status = dos.order_status
    
        SET @RowsLoaded = @@ROWCOUNT;
        SET @end_time   = SYSDATETIME();

        INSERT INTO etl.TableLoadLog
        (
            BatchID, SchemaName, TableName, 
            StartTime, EndTime, DurationSeconds, 
            RowsLoaded, RowsRejected, Status)
        VALUES
        (
            @BatchID, 'gold', @CurrentTable, 
            @start_time, @end_time,
            DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0, 
            @RowsLoaded, 0, 'SUCCESS'
        );

        PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
        PRINT '>> -----------------------------------';

        -- =============================================================
        -- FACT 2: gold.fact_delivery
        -- =============================================================
        SET @CurrentTable = 'fact_delivery';
        SET @start_time   = SYSDATETIME();

        PRINT '>> Inserting Data Into: gold.fact_delivery';
        INSERT INTO gold.fact_delivery
            (order_id, customer_key, order_status_key, 
            order_purchase_date_key, order_approved_date_key,
            order_delivered_carrier_date_key, order_delivered_customer_date_key,
            order_estimated_delivery_date_key,
            order_purchase_timestamp, order_approved_at, 
            order_delivered_carrier_date, order_delivered_customer_date,
            order_estimated_delivery_date, delivery_days, approval_hours, late_delivery_flag)
        SELECT
        o.order_id,
        dc.customer_key,
        dos.order_status_key,
        CAST(FORMAT(o.order_purchase_timestamp, 'yyyyMMdd') AS INT),
        CAST(FORMAT(o.order_approved_at, 'yyyyMMdd') AS INT),
        CAST(FORMAT(o.order_delivered_carrier_date, 'yyyyMMdd') AS INT),
        CAST(FORMAT(o.order_delivered_customer_date, 'yyyyMMdd') AS INT),
        CAST(FORMAT(o.order_estimated_delivery_date, 'yyyyMMdd') AS INT),
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        o.delivery_days,
        o.approval_hours,
        o.late_delivery_flag
        FROM silver.olist_orders_dataset o
        LEFT JOIN silver.olist_customers_dataset c
            ON o.customer_id = c.customer_id
        LEFT JOIN gold.dim_customer dc
            ON c.customer_unique_id = dc.customer_unique_id
        LEFT JOIN gold.dim_order_status dos
            ON o.order_status = dos.order_status;

        SET @RowsLoaded = @@ROWCOUNT;
        SET @end_time   = SYSDATETIME();

        INSERT INTO etl.TableLoadLog
        (
            BatchID, SchemaName, TableName, 
            StartTime, EndTime, DurationSeconds, 
            RowsLoaded, RowsRejected, Status
        )
        VALUES
        (
            @BatchID, 'gold', @CurrentTable, 
            @start_time, @end_time,
            DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0, 
            @RowsLoaded, 0, 'SUCCESS'
        );

        PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
        PRINT '>> -----------------------------------';
    
        -- =============================================================
        -- FACT 3: gold.fact_reviews
        -- Grain = 1 row per review
        -- =============================================================
        SET @CurrentTable = 'fact_reviews';
        SET @start_time   = SYSDATETIME();

        PRINT '>> Inserting Data Into: gold.fact_reviews';
        INSERT INTO gold.fact_reviews
            (review_id, order_id, customer_key, review_date_key,
            review_creation_date, review_answer_timestamp, review_score,
            review_sentiment, has_comment)
        SELECT
            r.review_id,
            r.order_id,
            dc.customer_key,
            dd.date_key,
            r.review_creation_date,
            r.review_answer_timestamp,
            r.review_score,
            r.review_sentiment,
            CASE
                WHEN r.review_comment_message IS NOT NULL THEN 1
                ELSE 0
            END AS has_comment
        FROM silver.olist_order_reviews_dataset r
        LEFT JOIN silver.olist_orders_dataset o
            ON r.order_id = o.order_id
        LEFT JOIN silver.olist_customers_dataset c
            ON o.customer_id = c.customer_id
        LEFT JOIN gold.dim_customer dc
            ON c.customer_unique_id = dc.customer_unique_id
        LEFT JOIN gold.dim_date dd
            ON CAST(r.review_creation_date AS DATE) = dd.full_date;

        SET @RowsLoaded = @@ROWCOUNT;
        SET @end_time   = SYSDATETIME();

        INSERT INTO etl.TableLoadLog
        (
            BatchID, SchemaName, TableName, 
            StartTime, EndTime, DurationSeconds, 
            RowsLoaded, RowsRejected, Status
        )
        VALUES
        (
            @BatchID, 'gold', @CurrentTable,
            @start_time, @end_time,
            DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
            @RowsLoaded, 0, 'SUCCESS');

        PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
        PRINT '>> -----------------------------------';

        -- =============================================================
        -- FACT 4: gold.fact_payments
        -- Grain: 1 row per payment installment.
        -- No aggregation needed—direct mapping from Silver.
        -- This fact exists so analysts can analyze payment behavior
        -- (installments, payment methods, total order value) without
        -- multiplying item-level sales facts.
        -- =============================================================
        SET @CurrentTable = 'fact_payments';
        SET @start_time   = SYSDATETIME();

        PRINT '>> Inserting Data Into: gold.fact_payments';
        INSERT INTO gold.fact_payments
            (order_id, payment_sequential, customer_key, order_date_key, 
             payment_method_key, payment_installments, payment_value)
        SELECT
            p.order_id,
            p.payment_sequential,
            dc.customer_key,
            dd.date_key,
            dpm.payment_method_key,
            p.payment_installments,
            p.payment_value
        FROM silver.olist_order_payments_dataset p
        LEFT JOIN silver.olist_orders_dataset o
            ON p.order_id = o.order_id
        LEFT JOIN silver.olist_customers_dataset c
            ON o.customer_id = c.customer_city
        LEFT JOIN gold.dim_customer dc
            ON c.customer_unique_id = dc.customer_unique_id
        LEFT JOIN gold.dim_date dd
            ON CAST(o.order_purchase_timestamp AS DATE) = dd.full_date
        LEFT JOIN gold.dim_payment_method dpm
            ON p.payment_type = dpm.payment_type;

        SET @RowsLoaded = @@ROWCOUNT;
        SET @end_time   = SYSDATETIME();

        INSERT INTO etl.TableLoadLog
        (
            BatchID, SchemaName, TableName, 
            StartTime, EndTime, DurationSeconds,
            RowsLoaded, RowsRejected, Status
        )
        VALUES
        (
            @BatchID, 'gold', @CurrentTable, 
            @start_time, @end_time,
            DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
            @RowsLoaded, 0, 'SUCCESS'
        );

        PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
        PRINT '>> -----------------------------------';

        -- =====================================================
        -- STEP 6: COMMIT TRANSACTION (Everything succeeded!)
        -- =====================================================
        COMMIT TRANSACTION;

        PRINT '>> Transaction COMMITTED successfully.';

        -- =====================================================
        -- STEP 7: UPDATE BATCH LOG ON SUCCESS
        -- =====================================================
	    SET @batch_end_time = SYSDATETIME();

	    UPDATE etl.BatchLog
	    SET 
		    EndTime           = @batch_end_time,
		    Status            = 'SUCCESS',
		    DurationSeconds   = DATEDIFF_BIG(MILLISECOND, @batch_start_time, @batch_end_time)/1000.0
        WHERE BatchID = @BatchID;
        -- count the total tables
	    SELECT @TotalTables = COUNT(*)
	    FROM etl.TableLoadLog 
	    WHERE BatchID = @BatchID AND Status = 'SUCCESS';

	    PRINT '================================================';
        PRINT 'Gold Layer Load Completed Successfully';
        PRINT '   - Batch ID      : ' + CAST(@BatchID AS NVARCHAR);
        PRINT '   - Total Tables  : ' + CAST(@TotalTables AS NVARCHAR);
        PRINT '   - Total Duration: ' + CAST(DATEDIFF_BIG(MILLISECOND, @batch_start_time, @batch_end_time)/1000.0 AS NVARCHAR) + ' seconds';
        PRINT '================================================';

    END TRY

	  -- =========================================================
    -- ERROR HANDLING 
    -- =========================================================
    BEGIN CATCH
        
        -- =====================================================
        -- STEP 8: ROLLBACK TRANSACTION ON ERROR
        -- =====================================================
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT '>> Transaction ROLLED BACK due to error.';
        END
        
        -- =====================================================
        -- STEP 9: Best-effort re-enable FKs (Outside transaction)
        -- This ensures the database is left in a consistent state
        -- even though the load failed.
        -- =====================================================
        BEGIN TRY
            ALTER TABLE gold.fact_sales     CHECK CONSTRAINT ALL;
            ALTER TABLE gold.fact_delivery  CHECK CONSTRAINT ALL;
            ALTER TABLE gold.fact_payments  CHECK CONSTRAINT ALL;
            ALTER TABLE gold.fact_reviews   CHECK CONSTRAINT ALL;
        END TRY
        BEGIN CATCH
            -- Ignore — best effort. The original error is preserved.
        END CATCH;

        -- =====================================================
        -- STEP 10: Log the failure
        -- =====================================================
        SET @batch_end_time = SYSDATETIME();

		    -- Update batch as FAILED
		    UPDATE etl.BatchLog
		    SET
			    EndTime         = @batch_end_time,
		      Status          = 'FAILED',
			    DurationSeconds = DATEDIFF_BIG(MILLISECOND, @batch_start_time, @batch_end_time)/1000.0,
			    ErrorMessage    = ERROR_MESSAGE()
		    WHERE BatchID = @BatchID;

		    -- Log the failing table (use @batch_start_time if @start_time is NULL)
		    SET @start_time = ISNULL(@start_time, @batch_start_time);

		    -- Log which table failed
		    INSERT INTO etl.TableLoadLog
		    (
		      BatchID, SchemaName, TableName,
			    StartTime, EndTime, DurationSeconds,
			    RowsLoaded, RowsRejected, Status, ErrorMessage
		    )
		    VALUES
		    (
			    @BatchID, 'gold', ISNULL(@CurrentTable, 'UNKNOWN'),
			    @start_time, @batch_end_time, DATEDIFF_BIG(MILLISECOND, @start_time, @batch_end_time)/1000.0,
		      0 , 0, 'FAILED', ERROR_MESSAGE()
		    );

	      PRINT '================================================';
	      PRINT 'ERROR OCCURRED DURING GOLD LAYER LOAD';
	      PRINT 'Batch ID     : ' + CAST(@BatchID AS NVARCHAR);
	      PRINT 'Table        : ' + ISNULL(@CurrentTable, 'UNKNOWN');
	      PRINT 'Error Message: ' + ERROR_MESSAGE();
	      PRINT 'Error Number : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
	      PRINT 'Error State  : ' + CAST(ERROR_STATE() AS NVARCHAR); 
	      PRINT '================================================';

	      THROW;
    END CATCH
END;
GO

PRINT '============================================================';
PRINT 'DEPLOYMENT SUMMARY:';
PRINT '  Stored Procedure: gold.load_gold';
PRINT '  Status          : SUCCESS';
PRINT '============================================================';
GO
