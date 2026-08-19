/*
=============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
=============================================================================
PURPOSE:
    Loads raw CSV data into the Bronze schema tables. Each table is loaded 
    independently to prevent massive rollbacks on partial failures. 
	  Idempotent by design (TRUNCATE before INSERT).

PERFORMANCE OPTIMIZATIONS:
    - Uses TABLOCK for minimal logging.
    - Uses TRUNCATE instead of DELETE.
    - Logs each table's duration with millisecond precision.

USAGE:
    EXEC bronze.load_bronze;                     
=============================================================================
*/

USE OlistDataWarehouse;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN
	
	SET NOCOUNT ON;
	SET XACT_ABORT ON;   -- Automatically rollback on error

    -- =========================================================
    -- VARIABLES
    -- ========================================================= 
	DECLARE 
		@BatchID          INT,
		@RowsLoaded       INT,
        @TotalTables      INT,
		@start_time       DATETIME2, 
		@end_time         DATETIME2, 
		@batch_start_time DATETIME2, 
		@batch_end_time   DATETIME2,
		@CurrentTable     NVARCHAR(100),
		@BasePath         NVARCHAR(200) = 'A:\olist_datasets\',
		@SqlCommand       NVARCHAR(MAX);

	-- =========================================================
    -- STEP 1: START BATCH LOGGING
    -- =========================================================
	SET @batch_start_time = SYSDATETIME();

	INSERT INTO etl.BatchLog 
		(ProcessName, LayerName, StartTime, Status)
	VALUES 
		('load_bronze','bronze',@batch_start_time,'RUNNING');

	SET @BatchID = SCOPE_IDENTITY();

	PRINT '================================================';
    PRINT 'Loading Bronze Layer';
    PRINT 'Batch ID: ' + CAST(@BatchID AS NVARCHAR);
    PRINT '================================================';

	BEGIN TRY		

		-- =====================================================
    -- TABLE 1: bronze.olist_customers_dataset
    -- =====================================================
		SET @CurrentTable = 'olist_customers_dataset';
		SET @start_time   = SYSDATETIME();

		-- Clear existing data before loading fresh data from CSV
		PRINT '>> Truncating Table: bronze.olist_customers_dataset';
		TRUNCATE TABLE bronze.olist_customers_dataset;

		PRINT '>> Inserting Data Into: bronze.olist_customers_dataset';
		SET @SqlCommand = N'
		BULK INSERT bronze.olist_customers_dataset
		FROM ''' + @BasePath + N'olist_customers_dataset.csv''
		WITH (
			FORMAT          = ''CSV'',
			FIRSTROW        = 2,   
			FIELDTERMINATOR = '','',	 
			ROWTERMINATOR   = ''0x0a'', 
			CODEPAGE        = ''65001'',
			TABLOCK					
		);';
		EXEC sp_executesql @SqlCommand;

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
			@BatchID, 'bronze', 'olist_customers_dataset',
			@start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
			@RowsLoaded, 0, 'SUCCESS'
		);

		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
    PRINT '>> -----------------------------------';
		
		-- =====================================================
    -- TABLE 2: bronze.olist_geolocation_dataset
    -- =====================================================
		SET @CurrentTable = 'olist_geolocation_dataset'; 
		SET @start_time   = SYSDATETIME();

		PRINT '>> Truncating Table: bronze.olist_geolocation_dataset';
		TRUNCATE TABLE bronze.olist_geolocation_dataset;

		PRINT '>> Inserting Data Into: bronze.olist_geolocation_dataset';
		SET @SqlCommand = N'
		BULK INSERT bronze.olist_geolocation_dataset
		FROM ''' + @BasePath + N'olist_geolocation_dataset.csv''
		WITH (
			FORMAT          = ''CSV'',
			FIRSTROW        = 2,
			FIELDTERMINATOR = '','',
			ROWTERMINATOR   = ''0x0a'',
			CODEPAGE        = ''65001'',
			TABLOCK
		);';
		EXEC sp_executesql @SqlCommand;

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
			@BatchID, 'bronze', 'olist_geolocation_dataset',
			@start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
			@RowsLoaded, 0, 'SUCCESS'
		);
		
		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------------';

		-- =====================================================
    -- TABLE 3: bronze.olist_order_items_dataset
    -- =====================================================
		SET @CurrentTable = 'olist_order_items_dataset'; 
		SET @start_time   = SYSDATETIME();

		PRINT '>> Truncating Table: bronze.olist_order_items_dataset';
		TRUNCATE TABLE bronze.olist_order_items_dataset;

		PRINT '>> Inserting Data Into: bronze.olist_order_items_dataset';
		SET @SqlCommand = N'
		BULK INSERT bronze.olist_order_items_dataset
		FROM ''' + @BasePath + N'olist_order_items_dataset.csv''
		WITH (
			FORMAT          = ''CSV'',
			FIRSTROW        = 2,
			FIELDTERMINATOR = '','',
			ROWTERMINATOR   = ''0x0a'',
			CODEPAGE        = ''65001'',
			TABLOCK
		);';
		EXEC sp_executesql @SqlCommand;

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
			@BatchID, 'bronze', 'olist_order_items_dataset',
			@start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
			@RowsLoaded, 0, 'SUCCESS'
		);

		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
		PRINT '>> -----------------------------------';

		-- =====================================================
    -- TABLE 4: bronze.olist_order_payments_dataset
    -- =====================================================
		SET @CurrentTable = 'olist_order_payments_dataset';
		SET @start_time   = SYSDATETIME();

		PRINT '>> Truncating Table: bronze.olist_order_payments_dataset';
		TRUNCATE TABLE bronze.olist_order_payments_dataset;

		PRINT '>> Inserting Data Into: bronze.olist_order_payments_dataset';
		SET @SqlCommand = N'
		BULK INSERT bronze.olist_order_payments_dataset
		FROM ''' + @BasePath + N'olist_order_payments_dataset.csv''
		WITH (
			FORMAT          = ''CSV'',
			FIRSTROW        = 2,
			FIELDTERMINATOR = '','',
			ROWTERMINATOR   = ''0x0a'',
			CODEPAGE        = ''65001'',
			TABLOCK
		);';
		EXEC sp_executesql @SqlCommand;
		
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
			@BatchID, 'bronze', 'olist_order_payments_dataset',
			@start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
			@RowsLoaded, 0, 'SUCCESS'
		);
		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
    PRINT '>> -----------------------------------';

		-- =====================================================
    -- TABLE 5: bronze.olist_order_reviews_dataset
		-- NOTE: 
		--	- ROWTERMINATOR intentionally omitted.
		--	- FORMAT = 'CSV' with FIELDQUOTE handles embedded
		--	- line breaks in review_comment_message automatically.
		--	- Adding ROWTERMINATOR conflicts with FORMAT=CSV parser.
    -- =====================================================
		SET @CurrentTable = 'olist_order_reviews_dataset'; 
		SET @start_time   = SYSDATETIME();

		PRINT '>> Truncating Table: bronze.olist_order_reviews_dataset';
		TRUNCATE TABLE bronze.olist_order_reviews_dataset;

		PRINT '>> Inserting Data Into: bronze.olist_order_reviews_dataset';
		SET @SqlCommand = N'
		BULK INSERT bronze.olist_order_reviews_dataset
		FROM ''' + @BasePath + N'olist_order_reviews_dataset.csv''
		WITH (
			      FORMAT          = ''CSV'',
            FIELDQUOTE      = ''"'',
            FIELDTERMINATOR = '','',
			      FIRSTROW        = 2,
            CODEPAGE        = ''65001'',
            TABLOCK
		);';
		EXEC sp_executesql @SqlCommand;

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
			@BatchID, 'bronze', 'olist_order_reviews_dataset',
			@start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
			@RowsLoaded, 0, 'SUCCESS'
		);
		
		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
        PRINT '>> -----------------------------------';

		-- =====================================================
    -- TABLE 6: bronze.olist_orders_dataset
    -- =====================================================
		SET @CurrentTable = 'olist_orders_dataset';
		SET @start_time   = SYSDATETIME();

		PRINT '>> Truncating Table: bronze.olist_orders_dataset';
		TRUNCATE TABLE bronze.olist_orders_dataset;

		PRINT '>> Inserting Data Into: bronze.olist_orders_dataset';
		SET @SqlCommand = N'
		BULK INSERT bronze.olist_orders_dataset
		FROM ''' + @BasePath + N'olist_orders_dataset.csv''
		WITH (
			FORMAT          = ''CSV'',
			FIRSTROW        = 2,
			FIELDTERMINATOR = '','',
			ROWTERMINATOR   = ''0x0a'',
			CODEPAGE        = ''65001'',
			TABLOCK
		);';
		EXEC sp_executesql @SqlCommand;

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
			@BatchID, 'bronze', 'olist_orders_dataset',
			@start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
			@RowsLoaded, 0, 'SUCCESS'
		);
		
		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
    PRINT '>> -----------------------------------';

		-- =====================================================
    -- TABLE 7: bronze.olist_products_dataset
    -- =====================================================
		SET @CurrentTable = 'olist_products_dataset';
		SET @start_time   = SYSDATETIME();

		PRINT '>> Truncating Table: bronze.olist_products_dataset';
		TRUNCATE TABLE bronze.olist_products_dataset;

		PRINT '>> Inserting Data Into: bronze.olist_products_dataset';
		SET @SqlCommand = N'
		BULK INSERT bronze.olist_products_dataset
		FROM ''' + @BasePath + N'olist_products_dataset.csv''
		WITH (
			FORMAT          = ''CSV'',
			FIRSTROW        = 2,
			FIELDTERMINATOR = '','',
			ROWTERMINATOR   = ''0x0a'',
			CODEPAGE        = ''65001'',
			TABLOCK
		);';
		EXEC sp_executesql @SqlCommand;

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
			@BatchID, 'bronze', 'olist_products_dataset',
			@start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
			@RowsLoaded, 0, 'SUCCESS'
		);
		
		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
    PRINT '>> -----------------------------------';

		-- =====================================================
    -- TABLE 8: bronze.olist_sellers_dataset
    -- =====================================================
		SET @CurrentTable = 'olist_sellers_dataset'; 
		SET @start_time   = SYSDATETIME();

		PRINT '>> Truncating Table: bronze.olist_sellers_dataset';
		TRUNCATE TABLE bronze.olist_sellers_dataset;

		PRINT '>> Inserting Data Into: bronze.olist_sellers_dataset';
		SET @SqlCommand = N'
		BULK INSERT bronze.olist_sellers_dataset
		FROM ''' + @BasePath + N'olist_sellers_dataset.csv''
		WITH (
			FORMAT          = ''CSV'',
			FIRSTROW        = 2,
			FIELDTERMINATOR = '','',
			ROWTERMINATOR   = ''0x0a'',
			CODEPAGE        = ''65001'',
			TABLOCK
		);';
		EXEC sp_executesql @SqlCommand;

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
			@BatchID, 'bronze', 'olist_sellers_dataset',
			@start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
			@RowsLoaded, 0, 'SUCCESS'
		);
		
		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
    PRINT '>> -----------------------------------';

		-- =====================================================
    -- TABLE 9: bronze.product_category_name_translation
    -- =====================================================
		SET @CurrentTable = 'product_category_name_translation'; 
		SET @start_time   = SYSDATETIME();

		PRINT '>> Truncating Table: bronze.product_category_name_translation';
		TRUNCATE TABLE bronze.product_category_name_translation;

		PRINT '>> Inserting Data Into: bronze.product_category_name_translation';
		SET @SqlCommand = N'
		BULK INSERT bronze.product_category_name_translation
		FROM ''' + @BasePath + N'product_category_name_translation.csv''
		WITH (
			FORMAT          = ''CSV'',
			FIRSTROW        = 2,
			FIELDTERMINATOR = '','',
			ROWTERMINATOR   = ''0x0a'',
			CODEPAGE        = ''65001'',
			TABLOCK
		);';
		EXEC sp_executesql @SqlCommand;

		SET @RowsLoaded = @@ROWCOUNT;
		SET @end_time   = SYSDATETIME();

		INSERT INTO etl.TableLoadLog
		(
			BatchID, SchemaName,TableName,
			StartTime, EndTime, DurationSeconds,
			RowsLoaded, RowsRejected, Status
		)
		VALUES
		(
			@BatchID, 'bronze', 'product_category_name_translation',
			@start_time, @end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0,
			@RowsLoaded, 0, 'SUCCESS'
		);
		
		PRINT '>> Rows Loaded : ' + CAST(@RowsLoaded AS NVARCHAR(20));
		PRINT '>> Duration    : ' + CAST(DATEDIFF_BIG(MILLISECOND, @start_time, @end_time)/1000.0 AS NVARCHAR) + ' seconds';
    PRINT '>> -----------------------------------';

		-- =========================================================
    -- STEP 2: UPDATE BATCH LOG ON SUCCESS
    -- =========================================================
		SET @batch_end_time = SYSDATETIME();

		UPDATE etl.BatchLog
		SET 
			EndTime         = @batch_end_time,
			Status          = 'SUCCESS',
			DurationSeconds = DATEDIFF_BIG(MILLISECOND, @batch_start_time, @batch_end_time)/1000.0
		WHERE BatchID = @BatchID;

		-- count the total tables
		SELECT @TotalTables = COUNT(*)
		FROM etl.TableLoadLog 
		WHERE BatchID = @BatchID AND Status = 'SUCCESS';

		PRINT '================================================';
        PRINT 'Bronze Layer Load Completed Successfully';
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

		INSERT INTO etl.TableLoadLog
		(
			BatchID, SchemaName, TableName,
			StartTime, EndTime, DurationSeconds,
			RowsLoaded, RowsRejected, Status, ErrorMessage
		)
		VALUES
		(
			@BatchID, 'bronze', @CurrentTable,
			@start_time, @batch_end_time, 
			DATEDIFF_BIG(MILLISECOND, @start_time, @batch_end_time)/1000.0,
			0, 0, 'FAILED', ERROR_MESSAGE()
		);

		PRINT '================================================';
        PRINT 'ERROR OCCURRED DURING BRONZE LAYER LOAD';
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
