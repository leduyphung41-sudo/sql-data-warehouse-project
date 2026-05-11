/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================

Script Purpose:
    This procedure performs data quality checks and monitoring
    for the bronze layer tables after CSV ingestion.

    The procedure performs the following actions:
    - Checks total row counts in bronze tables
    - Validates imported data
    - Monitors bronze layer loading status

Parameters:
    None.

Usage Example:
    CALL bronze.check_bronze();

===============================================================================
*/

TRUNCATE TABLE bronze.crm_cust_info;

LOAD DATA LOCAL INFILE '/Users/duyphung/Documents/Master of BA/SQL/sql-data-warehouse-project/datasets/source_crm/cust_info.csv'
INTO TABLE bronze.crm_cust_info
FIELDS TERMINATED BY ','
IGNORE 1 ROWS;

DROP PROCEDURE IF EXISTS bronze.check_bronze;

DELIMITER $$

CREATE PROCEDURE bronze.check_bronze()
BEGIN
    SELECT 'crm_cust_info' AS table_name, COUNT(*) AS total_rows FROM bronze.crm_cust_info
    UNION ALL
    SELECT 'crm_prd_info', COUNT(*) FROM bronze.crm_prd_info
    UNION ALL
    SELECT 'crm_sales_details', COUNT(*) FROM bronze.crm_sales_details
    UNION ALL
    SELECT 'erp_cust_az12', COUNT(*) FROM bronze.erp_cust_az12
    UNION ALL
    SELECT 'erp_loc_a101', COUNT(*) FROM bronze.erp_loc_a101
    UNION ALL
    SELECT 'erp_px_cat_g1v2', COUNT(*) FROM bronze.erp_px_cat_g1v2;
END $$

DELIMITER ;

