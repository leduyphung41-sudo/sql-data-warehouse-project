/*
===============================================================================
Load Script: Bronze layer (MySQL)
===============================================================================
Purpose:
    Truncate + reload all 6 bronze tables from the source CSV files using
    LOAD DATA LOCAL INFILE, logging duration per table and per batch.

NOTE ON DESIGN:
    This is a plain script, NOT a stored procedure. MySQL does not allow
    LOAD DATA inside a stored procedure/function/trigger (Error 1314),
    unlike SQL Server where BULK INSERT works fine inside a procedure.
    So instead of CALL bronze.load_bronze(), you just open this file and
    run the whole script directly (session variables with @ instead of
    DECLARE, since DECLARE only works inside a routine body).

IMPORTANT before running:
    1. The client must allow local file loading:
       - mysql CLI:  mysql --local-infile=1 -u <user> -p
       - or in a session:  SET GLOBAL local_infile = 1;
    2. The 6 file paths below already point to this project's own
       datasets/ folder. If you move the project, update them.

NOTE ON EMPTY DATE FIELDS:
    By default, LOAD DATA silently turns an empty date field into
    '0000-00-00' instead of NULL, which then breaks any later INSERT into
    another DATE column under MySQL 8's strict SQL mode ("Incorrect date
    value"). cust_info, prd_info and CUST_AZ12 all have some rows with
    blank date fields, so their LOAD DATA statements read the raw value
    into a session variable (@col) and use SET col = NULLIF(@col, '') to
    turn blanks into a real NULL before it ever reaches the table.

Usage:
    Open this file in MySQL Workbench and click Run (the whole script,
    not statement-by-statement).
===============================================================================
*/

USE bronze;

SET @batch_start = NOW();
SELECT '================================================' AS status;
SELECT 'Loading Bronze Layer' AS status;
SELECT '================================================' AS status;

-- ---------------------------------------------------------------
-- CRM source
-- ---------------------------------------------------------------
SET @step_start = NOW();
TRUNCATE TABLE crm_cust_info;
LOAD DATA LOCAL INFILE '/Users/duyphung/Documents/Master of BA/SQL Project/datasets/source_crm/cust_info.csv'
    INTO TABLE crm_cust_info
    FIELDS TERMINATED BY ',' ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, @cst_create_date)
    SET cst_create_date = NULLIF(@cst_create_date, '');
SET @step_end = NOW();
SELECT CONCAT('>> crm_cust_info loaded in ', TIMESTAMPDIFF(SECOND, @step_start, @step_end), 's') AS status;

SET @step_start = NOW();
TRUNCATE TABLE crm_prd_info;
LOAD DATA LOCAL INFILE '/Users/duyphung/Documents/Master of BA/SQL Project/datasets/source_crm/prd_info.csv'
    INTO TABLE crm_prd_info
    FIELDS TERMINATED BY ',' ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (prd_id, prd_key, prd_nm, prd_cost, prd_line, @prd_start_dt, @prd_end_dt)
    SET prd_start_dt = NULLIF(@prd_start_dt, ''),
        prd_end_dt   = NULLIF(@prd_end_dt, '');
SET @step_end = NOW();
SELECT CONCAT('>> crm_prd_info loaded in ', TIMESTAMPDIFF(SECOND, @step_start, @step_end), 's') AS status;

SET @step_start = NOW();
TRUNCATE TABLE crm_sales_details;
LOAD DATA LOCAL INFILE '/Users/duyphung/Documents/Master of BA/SQL Project/datasets/source_crm/sales_details.csv'
    INTO TABLE crm_sales_details
    FIELDS TERMINATED BY ',' ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;
SET @step_end = NOW();
SELECT CONCAT('>> crm_sales_details loaded in ', TIMESTAMPDIFF(SECOND, @step_start, @step_end), 's') AS status;

-- ---------------------------------------------------------------
-- ERP source
-- ---------------------------------------------------------------
SET @step_start = NOW();
TRUNCATE TABLE erp_cust_az12;
LOAD DATA LOCAL INFILE '/Users/duyphung/Documents/Master of BA/SQL Project/datasets/source_erp/CUST_AZ12.csv'
    INTO TABLE erp_cust_az12
    FIELDS TERMINATED BY ',' ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (cid, @bdate, gen)
    SET bdate = NULLIF(@bdate, '');
SET @step_end = NOW();
SELECT CONCAT('>> erp_cust_az12 loaded in ', TIMESTAMPDIFF(SECOND, @step_start, @step_end), 's') AS status;

SET @step_start = NOW();
TRUNCATE TABLE erp_loc_a101;
LOAD DATA LOCAL INFILE '/Users/duyphung/Documents/Master of BA/SQL Project/datasets/source_erp/LOC_A101.csv'
    INTO TABLE erp_loc_a101
    FIELDS TERMINATED BY ',' ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;
SET @step_end = NOW();
SELECT CONCAT('>> erp_loc_a101 loaded in ', TIMESTAMPDIFF(SECOND, @step_start, @step_end), 's') AS status;

SET @step_start = NOW();
TRUNCATE TABLE erp_px_cat_g1v2;
LOAD DATA LOCAL INFILE '/Users/duyphung/Documents/Master of BA/SQL Project/datasets/source_erp/PX_CAT_G1V2.csv'
    INTO TABLE erp_px_cat_g1v2
    FIELDS TERMINATED BY ',' ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS;
SET @step_end = NOW();
SELECT CONCAT('>> erp_px_cat_g1v2 loaded in ', TIMESTAMPDIFF(SECOND, @step_start, @step_end), 's') AS status;

SET @batch_end = NOW();
SELECT '================================================' AS status;
SELECT CONCAT('Bronze Layer load complete. Total duration: ',
              TIMESTAMPDIFF(SECOND, @batch_start, @batch_end), 's') AS status;
SELECT '================================================' AS status;

-- ---------------------------------------------------------------
-- Optional: row-count check procedure (allowed as a procedure since
-- it contains no LOAD DATA, only SELECT/COUNT)
-- ---------------------------------------------------------------
DROP PROCEDURE IF EXISTS check_bronze;

DELIMITER $$
CREATE PROCEDURE check_bronze()
BEGIN
    SELECT 'crm_cust_info' AS table_name, COUNT(*) AS total_rows FROM crm_cust_info
    UNION ALL
    SELECT 'crm_prd_info', COUNT(*) FROM crm_prd_info
    UNION ALL
    SELECT 'crm_sales_details', COUNT(*) FROM crm_sales_details
    UNION ALL
    SELECT 'erp_cust_az12', COUNT(*) FROM erp_cust_az12
    UNION ALL
    SELECT 'erp_loc_a101', COUNT(*) FROM erp_loc_a101
    UNION ALL
    SELECT 'erp_px_cat_g1v2', COUNT(*) FROM erp_px_cat_g1v2;
END $$
DELIMITER ;

-- Usage after loading: CALL bronze.check_bronze();
