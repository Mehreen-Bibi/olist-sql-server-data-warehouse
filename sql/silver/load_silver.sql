/*
================================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
================================================================================
Script Purpose:
    Loads cleaned, standardized, and transformed data from the Bronze layer
    into the Silver layer.

Silver Layer Responsibilities:
    - Clean and standardize Bronze data
    - Convert data types
    - Create derived business columns
    - Log ETL execution details.

Parameters:
    None

Usage:
    EXEC silver.load_silver;
================================================================================
*/
USE OlistDataWarehouse;
GO

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	
    -- =========================================================
    -- VARIABLES
    -- =========================================================
	DECLARE 
		@BatchID          INT,
		@RowsLoaded       INT,
		@RowsRejected     INT,
		@TotalTables      INT,
		@BronzeTotal      INT,
		@start_time       DATETIME2, 
		@end_time         DATETIME2, 
		@batch_start_time DATETIME2, 
		@batch_end_time   DATETIME2,
		@CurrentTable     NVARCHAR(100);

	-- =========================================================
  -- STEP 1: START BATCH LOGGING
  -- =========================================================
	SET @batch_start_time = SYSDATETIME();

	INSERT INTO etl.BatchLog 
		(ProcessName, LayerName, StartTime, Status)
	VALUES 
		('load_silver', 'silver', @batch_start_time, 'RUNNING');

	SET @BatchID = SCOPE_IDENTITY();

	PRINT '================================================';
	PRINT 'Loading Silver Layer';
	PRINT 'Batch ID: ' + CAST(@BatchID AS NVARCHAR);
	PRINT '================================================';

	BEGIN TRY
    
		-- ====================================================
    -- TABLE 1: silver.olist_customers_dataset
    -- ====================================================
		SET @CurrentTable = 'olist_customers_dataset';
		SET @start_time   = SYSDATETIME();

		PRINT '>> Truncating Table: silver.olist_customers_dataset';
		TRUNCATE TABLE silver.olist_customers_dataset;

		PRINT '>> Inserting Data Into: silver.olist_customers_dataset';
		INSERT INTO silver.olist_customers_dataset WITH (TABLOCK)
			(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state)
		SELECT 
			customer_id,
			customer_unique_id,
			customer_zip_code_prefix, -- Keep as NVARCHAR — zip "01310" would become 1310 as INT
			TRIM(customer_city)         AS customer_city,
			UPPER(TRIM(customer_state)) AS customer_state
		FROM bronze.olist_customers_dataset;

		SET @RowsLoaded = @@ROWCOUNT;
		SET @end_time	= SYSDATETIME();

		INSERT INTO etl.TableLoadLog
		(
		  BatchID, SchemaName, TableName,
			StartTime, EndTime, DurationSeconds, 
			RowsLoaded, RowsRejected, Status
		)
		VALUES
		(
			@BatchID, 'silver', @CurrentTable,
			@start_time, @end_time,
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time) / 1000.0,
			@RowsLoaded, 0, 'SUCCESS'
		);

		PRINT '>> Rows Loaded: ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------------';

		-- =====================================================
    -- TABLE 2: silver.olist_geolocation_dataset
    -- =====================================================
		SET @CurrentTable = 'olist_geolocation_dataset';
		SET @start_time   = SYSDATETIME();

		-- Get total Bronze rows first for rejection calculation
		SELECT @BronzeTotal = COUNT(*) FROM bronze.olist_geolocation_dataset;

		PRINT '>> Truncating Table: silver.olist_geolocation_dataset';
		TRUNCATE TABLE silver.olist_geolocation_dataset;

		PRINT '>> Inserting Data Into: silver.olist_geolocation_dataset';
		INSERT INTO silver.olist_geolocation_dataset WITH (TABLOCK)
			(geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state)
		SELECT 
			geolocation_zip_code_prefix,
			TRY_CAST(geolocation_lat AS DECIMAL(9,6)) AS geolocation_lat,
			TRY_CAST(geolocation_lng AS DECIMAL(9,6)) AS geolocation_lng,
			TRIM(geolocation_city)                    AS geolocation_city,
			UPPER(TRIM(geolocation_state))            AS geolocation_state
		FROM bronze.olist_geolocation_dataset
		-- Filter out invalid Brazil coordinates
		WHERE TRY_CAST(geolocation_lat AS DECIMAL(9,6)) BETWEEN -35 AND 5
		  AND TRY_CAST(geolocation_lng AS DECIMAL(9,6)) BETWEEN -75 AND -30;
		
		SET @RowsLoaded   = @@ROWCOUNT;
		SET @RowsRejected = @BronzeTotal - @RowsLoaded;
		SET @end_time     = SYSDATETIME();

		INSERT INTO etl.TableLoadLog
		(
			BatchID, SchemaName, TableName,
			StartTime, EndTime, DurationSeconds,
			RowsLoaded, RowsRejected, Status
		)
		VALUES
		(
			@BatchID, 'silver', @CurrentTable,
			@start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time) / 1000.0,
			@RowsLoaded, @RowsRejected, 'SUCCESS'
		);
		PRINT '>> Rows Loaded   : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Rows Rejected : ' + CAST(@RowsRejected AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------------';

		-- =====================================================
    -- Table 3: silver.olist_order_items_dataset
    -- =====================================================
		SET @CurrentTable = 'olist_order_items_dataset';
		SET @start_time = SYSDATETIME();

		PRINT '>> Truncating Table: silver.olist_order_items_dataset';
		TRUNCATE TABLE silver.olist_order_items_dataset;

		PRINT '>> Inserting Data Into: silver.olist_order_items_dataset';
		INSERT INTO silver.olist_order_items_dataset WITH (TABLOCK)
			(order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value)
		SELECT 
			order_id,
			order_item_id,
			product_id,
			seller_id,
			TRY_CAST(shipping_limit_date AS DATETIME2)      AS shipping_limit_date,
			TRY_CAST(price               AS DECIMAL(10, 2)) AS price,
      TRY_CAST(freight_value       AS DECIMAL(10, 2)) AS freight_value
		FROM bronze.olist_order_items_dataset;

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
			@BatchID, 'silver', @CurrentTable,
			@start_time, @end_time,
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time) / 1000.0,
			@RowsLoaded, 0, 'SUCCESS'
		);

		PRINT '>> Rows Loaded   : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------------';

		-- =====================================================
    -- TABLE 4: silver.olist_order_payments_dataset
    -- =====================================================
		SET @CurrentTable = 'olist_order_payments_dataset';
		SET @start_time   = SYSDATETIME();

		PRINT '>> Truncating Table: silver.olist_order_payments_dataset';
		TRUNCATE TABLE silver.olist_order_payments_dataset;

		PRINT '>> Inserting Data Into: silver.olist_order_payments_dataset';
		INSERT INTO silver.olist_order_payments_dataset WITH (TABLOCK)
			](order_id, payment_sequential, payment_type, payment_installments, payment_value)
		SELECT 
			order_id,
			payment_sequential,
			payment_type,
			payment_installments,
			NULLIF(TRY_CAST(payment_value AS DECIMAL(10, 2)), 0) AS payment_value
		FROM bronze.olist_order_payments_dataset;

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
			@BatchID, 'silver', @CurrentTable,
			@start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time) / 1000.0,
			@RowsLoaded, 0, 'SUCCESS'
		);

		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------------';

		-- ====================================================
    -- TABLE 5: silver.olist_order_reviews_dataset
    -- ====================================================
		SET @CurrentTable = 'olist_order_reviews_dataset';
		SET @start_time   = SYSDATETIME();

		PRINT '>> Truncating Table: silver.olist_order_reviews_dataset';
        TRUNCATE TABLE silver.olist_order_reviews_dataset;

		PRINT '>> Inserting Data Into: silver.olist_order_reviews_dataset';
		INSERT INTO silver.olist_order_reviews_dataset WITH (TABLOCK)
			(review_id, order_id, review_score, review_sentiment,  review_comment_title, 
			review_comment_message, review_creation_date, review_answer_timestamp)
		SELECT 
			review_id,
			order_id,
			NULLIF(review_score, 0) AS review_score,
			CASE
				WHEN review_score >= 4 THEN 'Positive'
				WHEN review_score = 3 THEN 'Neutral'
				WHEN review_score <= 2 THEN 'Negative'
			    ELSE NULL
		    END AS review_sentiment, -- Derived sentiment classification
			CASE
				WHEN NULLIF(TRIM(review_comment_title), '') IS NULL THEN NULL
				WHEN TRIM(review_comment_title) IN ('?', '??', '???', '????', '.', '..', '...', '....', '.....') THEN NULL
				ELSE TRIM(review_comment_title)
			END AS review_comment_title,
			CASE 
				WHEN NULLIF(TRIM(review_comment_message), '') IS NULL THEN NULL
				WHEN TRIM(review_comment_message) IN ('?', '??', '???', '????', '.', '..', '...', '....', '.....') THEN NULL
				ELSE NULLIF(TRIM(REPLACE(REPLACE(REPLACE(REPLACE(review_comment_message, '"', ''), CHAR(10), ''), CHAR(13), ''), CHAR(9), '')), '')
			END AS review_comment_message, -- Remove quotes, line breaks, carriage returns, tabs
			TRY_CAST(review_creation_date    AS DATETIME2) AS review_creation_date,
			TRY_CAST(review_answer_timestamp AS DATETIME2) AS review_answer_timestamp
		FROM bronze.olist_order_reviews_dataset;

		SET @RowsLoaded = @@ROWCOUNT;
		SET @end_time = SYSDATETIME();

		INSERT INTO etl.TableLoadLog
		(
			BatchID, SchemaName, TableName,
			StartTime, EndTime, DurationSeconds,
			RowsLoaded, RowsRejected, Status
		)
		VALUES
		(
			@BatchID, 'silver', @CurrentTable,
			@start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time) / 1000.0,
			@RowsLoaded, 0, 'SUCCESS'
		);

		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded   AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------------';

		-- ===============================================================
		-- TABLE 6: silver.olist_orders_dataset
    -- ===============================================================
		SET @CurrentTable = 'olist_orders_dataset';
		SET @start_time = SYSDATETIME();

		PRINT '>> Truncating Table: silver.olist_orders_dataset';
		TRUNCATE TABLE silver.olist_orders_dataset;

		PRINT '>> Inserting Data Into: silver.olist_orders_dataset';
		INSERT INTO silver.olist_orders_dataset WITH (TABLOCK)
			(order_id, customer_id, order_status, order_purchase_timestamp,
			order_approved_at, order_delivered_carrier_date, order_delivered_customer_date,
			order_estimated_delivery_date, delivery_days, approval_hours, late_delivery_flag)

		SELECT 
			order_id,
			customer_id,
			order_status,
			TRY_CAST(order_purchase_timestamp      AS DATETIME2) AS order_purchase_timestamp,
			TRY_CAST(order_approved_at             AS DATETIME2) AS order_approved_at ,
			TRY_CAST(order_delivered_carrier_date  AS DATETIME2) AS order_delivered_carrier_date,
			TRY_CAST(order_delivered_customer_date AS DATETIME2) AS order_delivered_customer_date,
			TRY_CAST(order_estimated_delivery_date AS DATETIME2) AS order_estimated_delivery_date,

			-- Derived: delivery duration in days
			CASE
				WHEN TRY_CAST(order_purchase_timestamp AS DATETIME2) IS NOT NULL
				AND TRY_CAST(order_delivered_customer_date AS DATETIME2) IS NOT NULL
				THEN DATEDIFF(DAY, TRY_CAST(order_purchase_timestamp AS DATETIME2), TRY_CAST(order_delivered_customer_date AS DATETIME2)) 
				ELSE NULL
			END	AS delivery_days,
			
			-- Derived: approval speed in hours
			CASE
				WHEN TRY_CAST(order_purchase_timestamp AS DATETIME2) IS NOT NULL
				AND TRY_CAST(order_approved_at AS DATETIME2) IS NOT NULL
				THEN DATEDIFF(HOUR, TRY_CAST(order_purchase_timestamp AS DATETIME2), TRY_CAST(order_approved_at AS DATETIME2))
				ELSE NULL            
			END AS approval_hours,
			-- Derived: late delivery flag (1=late, 0=on time, NULL=not yet delivered)
			CASE
				WHEN TRY_CAST(order_delivered_customer_date AS DATETIME2) IS NULL THEN NULL
				WHEN TRY_CAST(order_delivered_customer_date AS DATETIME2) > TRY_CAST(order_estimated_delivery_date AS DATETIME2) THEN 1
				ELSE 0
			END AS late_delivery_flag
		FROM bronze.olist_orders_dataset;

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
      @BatchID, 'silver', @CurrentTable,
      @start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time) / 1000.0,
      @RowsLoaded, 0, 'SUCCESS'
    );
		
		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------------';

		-- =====================================================
    -- TABLE 7: silver.olist_products_dataset
    -- =====================================================
		SET @CurrentTable = 'olist_products_dataset';
		SET @start_time = SYSDATETIME();

		PRINT '>> Truncating Table: silver.olist_products_dataset';
		TRUNCATE TABLE silver.olist_products_dataset;

		PRINT '>> Inserting Data Into: silver.olist_products_dataset';
		INSERT INTO silver.olist_products_dataset WITH (TABLOCK)
			(product_id, product_category_name, product_name_lenght, product_description_lenght,
			product_photos_qty, product_weight_g, product_length_cm, product_height_cm,
			product_width_cm, product_volume_cm3)

		SELECT 
			product_id,
			product_category_name,
			product_name_lenght,
			product_description_lenght,
			product_photos_qty,
			NULLIF(product_weight_g, 0) AS product_weight_g,
			product_length_cm,
			product_height_cm,
			product_width_cm,
			-- Derived: product volume in cubic centimeters
			CASE 
				WHEN (product_length_cm > 0) AND (product_height_cm > 0) AND (product_width_cm > 0) 
				THEN product_length_cm * product_height_cm * product_width_cm
				ELSE NULL
			END AS product_volume_cm3 
		FROM bronze.olist_products_dataset;

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
      @BatchID, 'silver', @CurrentTable,
      @start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time) / 1000.0,
      @RowsLoaded, 0, 'SUCCESS'
    );
		
		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------------';

		-- =====================================================
    -- TABLE 8: silver.olist_sellers_dataset
    -- =====================================================
		SET @CurrentTable = 'olist_sellers_dataset';
		SET @start_time = SYSDATETIME();

		PRINT '>> Truncating Table: silver.olist_sellers_dataset';
		TRUNCATE TABLE silver.olist_sellers_dataset;

		PRINT '>> Inserting Data Into: silver.olist_sellers_dataset';
		INSERT INTO silver.olist_sellers_dataset WITH (TABLOCK)
			(seller_id, seller_zip_code_prefix, seller_city, seller_state)	
		SELECT 
			seller_id,
			seller_zip_code_prefix,
			TRIM(seller_city)         AS seller_city,
			UPPER(TRIM(seller_state)) AS seller_state
		FROM bronze.olist_sellers_dataset;

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
      @BatchID, 'silver', @CurrentTable,
      @start_time, @end_time, 
      DATEDIFF_BIG(MILLISECOND, @start_time, @end_time) / 1000.0,
      @RowsLoaded, 0, 'SUCCESS'
    );
		
		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------------';

		-- ====================================================
    -- TABLE 9: silver.product_category_name_translation
    -- ====================================================
		SET @CurrentTable = 'product_category_name_translation';
		SET @start_time   = SYSDATETIME();

		PRINT '>> Truncating Table: silver.product_category_name_translation';
		TRUNCATE TABLE silver.product_category_name_translation;

		PRINT '>> Inserting Data Into: silver.product_category_name_translation';
		INSERT INTO silver.product_category_name_translation WITH (TABLOCK)
			(product_category_name,
			product_category_name_english)
		SELECT
			TRIM(product_category_name)         AS product_category_name,
			TRIM(product_category_name_english) AS product_category_name_english
		FROM bronze.product_category_name_translation;

		SET @RowsLoaded = @@ROWCOUNT;
		SET @end_time = SYSDATETIME();

		INSERT INTO etl.TableLoadLog
    (
      BatchID, SchemaName, TableName,
      StartTime, EndTime, DurationSeconds,
      RowsLoaded, RowsRejected, Status
    )
    VALUES
    (
      @BatchID, 'silver', @CurrentTable,
      @start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time) / 1000.0,
      @RowsLoaded, 0, 'SUCCESS'
    );

		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------------';

		-- =====================================================
    -- STEP 2: UPDATE BATCH LOG ON SUCCESS
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
    PRINT 'Silver Layer Load Completed Successfully';
    PRINT '   - Batch ID      : ' + CAST(@BatchID AS NVARCHAR);
    PRINT '   - Total Tables  : ' + CAST(@TotalTables AS NVARCHAR);
    PRINT '   - Total Duration: ' + CAST(DATEDIFF_BIG(MILLISECOND, @batch_start_time, @batch_end_time)/1000.0 AS NVARCHAR) + ' seconds';
    PRINT '================================================';
  END TRY
    
	-- =========================================================
  -- ERROR HANDLING 
  -- =========================================================
	BEGIN CATCH
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
			@BatchID, 'silver', ISNULL(@CurrentTable, 'UNKNOWN'),
			@start_time, @batch_end_time,
			DATEDIFF_BIG(MILLISECOND, @start_time, @batch_end_time) / 1000.0,
			0, 0, 'FAILED', ERROR_MESSAGE()
		);

		PRINT '================================================';
		PRINT 'ERROR OCCURRED DURING SILVER LAYER LOAD';
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
PRINT '  Stored Procedure: silver.load_silver';
PRINT '  Status          : SUCCESS';
PRINT '============================================================';
GO
