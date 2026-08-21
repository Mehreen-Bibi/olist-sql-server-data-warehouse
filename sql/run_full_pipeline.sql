/*
================================================================================
Master Orchestration Script: Run Full Olist ETL Pipeline
================================================================================
Script Purpose:
    Executes the complete Medallion pipeline in the correct dependency order:
        1. Bronze Layer (Raw data ingestion)
        2. Silver Layer (Data cleaning and transformation)
        3. Gold Layer (Star Schema business model)

Error Handling:
    - Stops execution if any layer fails.
    - Prints detailed status messages for monitoring.
    - Each layer handles its own transaction and logging to etl.BatchLog.

Usage:
    - Run this script manually to trigger a full refresh.

Prerequisites:
    - All stored procedures must exist:
        bronze.load_bronze
        silver.load_silver
        gold.load_gold
    - ETL monitoring tables must exist (etl.BatchLog, etl.TableLoadLog).

================================================================================
*/
USE OlistDataWarehouse;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

PRINT '============================================================';
PRINT 'OLIST ETL PIPELINE - FULL EXECUTION';
PRINT 'Start Time: ' + CAST(SYSDATETIME() AS NVARCHAR);
PRINT '============================================================';
PRINT '';

DECLARE @CurrentStep NVARCHAR(50) = 'INITIALIZATION';
DECLARE @OverallStartTime DATETIME2 = SYSDATETIME();
DECLARE @OverallEndTime DATETIME2;
DECLARE @ErrorMessage NVARCHAR(MAX);

BEGIN TRY
    -- =============================================================
    -- STEP 1: Validate that all required stored procedures exist
    -- =============================================================
    SET @CurrentStep = 'VALIDATION';

    IF OBJECT_ID('bronze.load_bronze', 'P') IS NULL
    BEGIN
        RAISERROR('Stored procedure bronze.load_bronze does not exist. Please create it first.', 16, 1);
    END

    IF OBJECT_ID('silver.load_silver', 'P') IS NULL
    BEGIN
        RAISERROR('Stored procedure silver.load_silver does not exist. Please create it first.', 16, 1);
    END

    IF OBJECT_ID('gold.load_gold', 'P') IS NULL
    BEGIN
        RAISERROR('Stored procedure gold.load_gold does not exist. Please create it first.', 16, 1);
    END

    PRINT '>> All required stored procedures exist.';
    PRINT '';

    -- =============================================================
    -- STEP 2: Load Bronze Layer
    -- =============================================================
    SET @CurrentStep = 'BRONZE';
    PRINT '============================================================';
    PRINT '>> STEP 1: Loading Bronze Layer (Raw Data)...';
    PRINT '============================================================';
    PRINT '';

    EXEC bronze.load_bronze;

    PRINT '';
    PRINT '>> Bronze Layer completed successfully.';
    PRINT '';

    -- =============================================================
    -- STEP 3: Load Silver Layer
    -- =============================================================
    SET @CurrentStep = 'SILVER';
    PRINT '============================================================';
    PRINT '>> STEP 2: Loading Silver Layer (Cleaned Data)...';
    PRINT '============================================================';
    PRINT '';

    EXEC silver.load_silver;

    PRINT '';
    PRINT '>> Silver Layer completed successfully.';
    PRINT '';

    -- =============================================================
    -- STEP 4: Load Gold Layer
    -- =============================================================
    SET @CurrentStep = 'GOLD';
    PRINT '============================================================';
    PRINT '>> STEP 3: Loading Gold Layer (Star Schema)...';
    PRINT '============================================================';
    PRINT '';

    EXEC gold.load_gold;

    PRINT '';
    PRINT '>> Gold Layer completed successfully.';
    PRINT '';

    -- =============================================================
    -- STEP 5: Overall Success Summary
    -- =============================================================
    SET @OverallEndTime = SYSDATETIME();

    PRINT '============================================================';
    PRINT 'PIPELINE EXECUTION COMPLETED SUCCESSFULLY';
    PRINT '  - Total Duration: ' + CAST(DATEDIFF_BIG(SECOND, @OverallStartTime, @OverallEndTime) AS NVARCHAR) + ' seconds';
    PRINT '  - End Time     : ' + CAST(@OverallEndTime AS NVARCHAR);
    PRINT '============================================================';

END TRY
BEGIN CATCH
    -- =============================================================
    -- ERROR HANDLING
    -- =============================================================
    SET @OverallEndTime = SYSDATETIME();
    SET @ErrorMessage = ERROR_MESSAGE();

    PRINT '';
    PRINT '============================================================';
    PRINT 'PIPELINE EXECUTION FAILED';
    PRINT '  - Failed Step   : ' + @CurrentStep;
    PRINT '  - Error Message : ' + @ErrorMessage;
    PRINT '  - Error Number  : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
    PRINT '  - Error Line    : ' + CAST(ERROR_LINE() AS NVARCHAR);
    PRINT '  - Duration      : ' + CAST(DATEDIFF_BIG(SECOND, @OverallStartTime, @OverallEndTime) AS NVARCHAR) + ' seconds';
    PRINT '============================================================';

    -- Re-raise the error 
    THROW;
END CATCH
GO
