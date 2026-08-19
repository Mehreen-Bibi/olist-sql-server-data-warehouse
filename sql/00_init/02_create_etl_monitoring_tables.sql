/*
===============================================================================
SCRIPT: Create ETL Monitoring Tables
===============================================================================
PURPOSE:
    Creates the ETL logging and monitoring tables. These tables provide full 
    observability into pipeline execution, performance, and error handling.

TABLES:
    etl.BatchLog      - Captures high-level metadata for each layer execution 
                        (bronze, silver, or gold).
    etl.TableLoadLog  - Captures granular performance and row-count metrics 
                        for each individual table loaded within a batch.
USAGE:
    Run 01_create_database_schemas.sql first. Then run this script.
===============================================================================
*/


USE OlistDataWarehouse;
GO

-- ----------------------------------------------------------------------------
-- 1.0 Drop Existing Objects (Reverse Dependency Order)
-- ----------------------------------------------------------------------------
IF OBJECT_ID('etl.TableLoadLog', 'U') IS NOT NULL
    DROP TABLE etl.TableLoadLog;
GO

IF OBJECT_ID('etl.BatchLog', 'U') IS NOT NULL
    DROP TABLE etl.BatchLog;
GO

-- ----------------------------------------------------------------------------
-- 2.0 TABLE: etl.BatchLog
-- ----------------------------------------------------------------------------
CREATE TABLE etl.BatchLog
(
    -- Primary Key
    BatchID         INT IDENTITY(1,1) PRIMARY KEY,
    -- ETL Identification
    ProcessName     NVARCHAR(100)  NOT NULL,
    LayerName       NVARCHAR(20)   NOT NULL,
    -- Execution Timing
    StartTime       DATETIME2      NOT NULL,
    EndTime         DATETIME2      NULL,
    DurationSeconds DECIMAL(10, 2) NULL,
    -- Execution Results
    Status          NVARCHAR(20)   NOT NULL,
   -- Error Details
    ErrorMessage    NVARCHAR(MAX)  NULL,
    -- Audit Trail
    CreatedDateTime DATETIME2      NOT NULL 
        CONSTRAINT DF_BatchLog_CreatedDateTime DEFAULT SYSDATETIME(),


    CONSTRAINT CHK_BatchLog_Status
        CHECK (Status IN ('RUNNING', 'SUCCESS', 'FAILED')),

    CONSTRAINT CHK_BatchLog_LayerName 
        CHECK (LayerName IN ('bronze', 'silver', 'gold'))
);
GO

-- ----------------------------------------------------------------------------
-- 3.0 TABLE: etl.TableLoadLog
-- ----------------------------------------------------------------------------
CREATE TABLE etl.TableLoadLog
(   
    -- Primary Key
    LogID           INT IDENTITY(1,1) PRIMARY KEY,
    -- Link to Batch
    BatchID         INT           NOT NULL,
    -- Table Identification
    SchemaName      NVARCHAR(50)   NOT NULL,
    TableName       NVARCHAR(150)  NOT NULL,
    FullTableName   AS (SchemaName + '.' + TableName),
    -- Executation Timing
    StartTime       DATETIME2      NOT NULL,
    EndTime         DATETIME2      NULL,
    DurationSeconds DECIMAL(10, 2) NULL,  
    -- Data Volume Metrics
    RowsLoaded      INT            NULL DEFAULT 0,
    RowsRejected    INT            NULL DEFAULT 0,
    -- Operational State
    Status          NVARCHAR(20)   NOT NULL,
    ErrorMessage    NVARCHAR(MAX)  NULL,
    -- Audit Trail
    CreatedDateTime DATETIME2      NOT NULL
        CONSTRAINT DF_TableLoadLog_CreatedDateTime DEFAULT SYSDATETIME(),
    
    -- Foreign Key ensures referential integrity
    CONSTRAINT FK_TableLoadLog_BatchLog FOREIGN KEY (BatchID)
        REFERENCES etl.BatchLog(BatchID) ON DELETE CASCADE,

    -- Data Integrity Constraint
    CONSTRAINT CHK_TableLoadLog_Status
        CHECK (Status IN ('RUNNING', 'SUCCESS', 'FAILED'))
);
GO

-- ----------------------------------------------------------------------------
-- 4.0 Performance Indexes (Optimized for Monitoring Dashboards)
-- ----------------------------------------------------------------------------
-- Speeds up joins from TableLoadLog to BatchLog
CREATE INDEX IX_TableLoadLog_BatchID
ON etl.TableLoadLog(BatchID);
GO

-- Speeds up queries filtering by pipeline status
CREATE INDEX IX_BatchLog_Status
ON etl.BatchLog(Status);
GO

-- Speeds up trend analysis and recent-run queries
CREATE INDEX IX_BatchLog_StartTime 
ON etl.BatchLog(StartTime DESC);
GO

-- Speeds up per-table history lookups (e.g. last N loads of a given table)
CREATE INDEX IX_TableLoadLog_TableName
ON etl.TableLoadLog(TableName, StartTime DESC);
GO

-- ----------------------------------------------------------------------------
-- 5.0 Deployment Summary
-- ----------------------------------------------------------------------------
PRINT '=============================================================';
PRINT 'DEPLOYMENT SUMMARY:';
PRINT '  Tables Created: etl.BatchLog, etl.TableLoadLog';
PRINT '  Constraints   : CHECK, DEFAULT, FOREIGN KEY applied.';
PRINT '  Indexes       : 4 performance indexes created.';
PRINT '  Status        : SUCCESS';
PRINT '============================================================';
GO
