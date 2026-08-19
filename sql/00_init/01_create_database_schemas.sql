/*
===============================================================================
SCRIPT: Create Database and Schemas
===============================================================================
PURPOSE:
    Initializes the Olist Data Warehouse database and creates the four-layer 
    schema architecture for the Medallion pipeline.

SCHEMAS:
    bronze  - Raw, unmodified source data.
    silver  - Cleaned, standardized, and deduplicated data.
    gold    - Business-ready dimensional model for analytics.
    etl     - Operational metadata, logging, and audit tables.


USAGE:
    Run once before executing any other deployment script.
===============================================================================
*/


USE master;
GO

-- ----------------------------------------------------------------------------
-- 1.0 Create Database (Idempotent)
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'OlistDataWarehouse')
BEGIN
    CREATE DATABASE OlistDataWarehouse;
    PRINT 'Database [OlistDataWarehouse] created successfully.';
END
ELSE
    PRINT 'Database [OlistDataWarehouse] already exists. Skipping creation.';
GO

USE OlistDataWarehouse;
GO

-- Reduce log file growth for development and staging environments
ALTER DATABASE OlistDataWarehouse SET RECOVERY SIMPLE;
GO



-- ============================================================================
-- 2.0 Create Schemas (Idempotent)
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    EXEC ('CREATE SCHEMA bronze');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    EXEC ('CREATE SCHEMA silver');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC ('CREATE SCHEMA gold');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'etl')
    EXEC ('CREATE SCHEMA etl');
GO

-- ----------------------------------------------------------------------------
-- 3.0 Deployment Summary
-- ----------------------------------------------------------------------------
PRINT '================================================';
PRINT 'DEPLOYMENT SUMMARY:';
PRINT '  Database   : OlistDataWarehouse';
PRINT '  Schemas    : bronze, silver, gold, etl';
PRINT '  Recovery   : SIMPLE';
PRINT '  Status     : SUCCESS';
PRINT '================================================';
GO




