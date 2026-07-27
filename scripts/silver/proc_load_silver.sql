/*
===============================================================================
Stored Procedure: silver.load_silver  (MySQL)
===============================================================================
Purpose:
    Read from bronze, clean/standardize, write to silver. Rules below were
    derived by profiling the actual source CSVs (not guessed):

    crm_cust_info
      - 4 rows have NULL cst_id, 9 cst_id values appear more than once
        -> drop NULL cst_id, keep only the latest row per cst_id
           (ROW_NUMBER by cst_create_date DESC)
      - cst_marital_status / cst_gndr are single-letter codes with ~25% of
        gender values missing -> map to readable labels, default 'n/a'

    crm_prd_info
      - prd_key encodes a category prefix, e.g. 'CO-RF-FR-R92B-58' where
        'CO-RF' (-> 'CO_RF' after replacing '-') matches erp_px_cat_g1v2.id
        for 98% of rows -> split into cat_id + prd_key
      - "duplicate" prd_key values are actually version history of the same
        product (different cost/date ranges) -> derive prd_end_dt as the day
        before the next version's prd_start_dt instead of trusting the
        (often wrong) source end date
      - prd_line is a 1-letter code -> map to full text

    crm_sales_details
      - order/ship/due dates are stored as INT (YYYYMMDD); some are 0 or the
        wrong length -> convert to DATE, NULL out anything invalid
      - 35 rows have sales != quantity * price, 13 rows have NULL/negative
        sales -> recompute sales = quantity * ABS(price) when inconsistent

    erp_cust_az12
      - ~60% of CIDs are prefixed with 'NAS' compared to crm cst_key
        -> stripping the prefix gives a 100% match rate against
           silver.crm_cust_info.cst_key
      - some birthdates are in the future (as far out as year 9999)
        -> NULL out any bdate after today
      - gen has inconsistent casing/whitespace/codes -> standardize

    erp_loc_a101
      - CIDs contain a dash that crm cst_key does not
        ('AW-00011000' vs 'AW00011000') -> stripping it gives a 100% match
      - cntry has blanks and inconsistent codes ('US'/'USA' -> same country,
        'DE' -> Germany, blank/NULL -> 'n/a')

    Zero-date gotcha (found while running this against real MySQL, not
    visible from the CSV profiling alone): LOAD DATA silently turns an
    empty date field into '0000-00-00' instead of NULL. The fix belongs in
    bronze, not here: scripts/bronze/proc_load_bronze.sql now loads
    cst_create_date, prd_start_dt/prd_end_dt and bdate through a session
    variable with SET col = NULLIF(@col, '') so bronze already stores a
    real NULL. (A first attempt fixed this here with
    NULLIF(col, '0000-00-00') instead, but comparing a DATE column to the
    string literal '0000-00-00' throws the same "Incorrect date value"
    error under strict mode regardless of the column's actual value — the
    literal itself is what's invalid. Fixing it at load time avoids the
    comparison entirely.)

Usage:
    CALL silver.load_silver();
===============================================================================
*/

USE silver;

DROP PROCEDURE IF EXISTS load_silver;

DELIMITER $$

CREATE PROCEDURE load_silver()
proc_body: BEGIN
    DECLARE batch_start, batch_end DATETIME;
    DECLARE err_msg TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 err_msg = MESSAGE_TEXT;
        SELECT CONCAT('ERROR loading silver layer: ', err_msg) AS status;
    END;

    SET batch_start = NOW();
    SELECT '================================================' AS status;
    SELECT 'Loading Silver Layer' AS status;
    SELECT '================================================' AS status;

    -- ---------------------------------------------------------------
    -- crm_cust_info: dedupe + standardize
    -- ---------------------------------------------------------------
    TRUNCATE TABLE crm_cust_info;
    INSERT INTO crm_cust_info
        (cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date)
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname),
        TRIM(cst_lastname),
        CASE UPPER(TRIM(cst_marital_status))
            WHEN 'S' THEN 'Single'
            WHEN 'M' THEN 'Married'
            ELSE 'n/a'
        END,
        CASE UPPER(TRIM(cst_gndr))
            WHEN 'M' THEN 'Male'
            WHEN 'F' THEN 'Female'
            ELSE 'n/a'
        END,
        cst_create_date
    FROM (
        SELECT
            b.*,
            ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS rn
        FROM bronze.crm_cust_info b
        WHERE cst_id IS NOT NULL
    ) ranked
    WHERE rn = 1;
    SELECT CONCAT('>> silver.crm_cust_info loaded: ', ROW_COUNT(), ' rows') AS status;

    -- ---------------------------------------------------------------
    -- crm_prd_info: split key, fill cost, map line, recompute end date
    -- ---------------------------------------------------------------
    TRUNCATE TABLE crm_prd_info;
    INSERT INTO crm_prd_info
        (prd_id, cat_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt)
    SELECT
        prd_id,
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_'),
        SUBSTRING(prd_key, 7),
        prd_nm,
        COALESCE(prd_cost, 0),
        CASE UPPER(TRIM(prd_line))
            WHEN 'R' THEN 'Road'
            WHEN 'M' THEN 'Mountain'
            WHEN 'T' THEN 'Touring'
            WHEN 'S' THEN 'Other Sales'
            ELSE 'n/a'
        END,
        prd_start_dt,
        CAST(
            LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - INTERVAL 1 DAY
            AS DATE
        )
    FROM bronze.crm_prd_info;
    SELECT CONCAT('>> silver.crm_prd_info loaded: ', ROW_COUNT(), ' rows') AS status;

    -- ---------------------------------------------------------------
    -- crm_sales_details: parse INT dates, recompute inconsistent sales
    -- ---------------------------------------------------------------
    TRUNCATE TABLE crm_sales_details;
    INSERT INTO crm_sales_details
        (sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt, sls_due_dt,
         sls_sales, sls_quantity, sls_price)
    SELECT
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        CASE WHEN sls_order_dt = 0 OR LENGTH(sls_order_dt) <> 8 THEN NULL
             ELSE STR_TO_DATE(CAST(sls_order_dt AS CHAR), '%Y%m%d') END,
        CASE WHEN sls_ship_dt = 0 OR LENGTH(sls_ship_dt) <> 8 THEN NULL
             ELSE STR_TO_DATE(CAST(sls_ship_dt AS CHAR), '%Y%m%d') END,
        CASE WHEN sls_due_dt = 0 OR LENGTH(sls_due_dt) <> 8 THEN NULL
             ELSE STR_TO_DATE(CAST(sls_due_dt AS CHAR), '%Y%m%d') END,
        CASE WHEN sls_sales IS NULL OR sls_sales <= 0
                  OR sls_sales <> sls_quantity * ABS(sls_price)
             THEN sls_quantity * ABS(sls_price)
             ELSE sls_sales END,
        sls_quantity,
        CASE WHEN sls_price IS NULL OR sls_price <= 0
             THEN sls_sales / NULLIF(sls_quantity, 0)
             ELSE sls_price END
    FROM bronze.crm_sales_details;
    SELECT CONCAT('>> silver.crm_sales_details loaded: ', ROW_COUNT(), ' rows') AS status;

    -- ---------------------------------------------------------------
    -- erp_cust_az12: strip 'NAS' prefix, null out future birthdates
    -- ---------------------------------------------------------------
    TRUNCATE TABLE erp_cust_az12;
    INSERT INTO erp_cust_az12 (cid, bdate, gen)
    SELECT
        CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4) ELSE cid END,
        CASE WHEN bdate > CURDATE() THEN NULL ELSE bdate END,
        CASE
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
            ELSE 'n/a'
        END
    FROM bronze.erp_cust_az12;
    SELECT CONCAT('>> silver.erp_cust_az12 loaded: ', ROW_COUNT(), ' rows') AS status;

    -- ---------------------------------------------------------------
    -- erp_loc_a101: strip dash from cid, standardize country names
    -- ---------------------------------------------------------------
    TRUNCATE TABLE erp_loc_a101;
    INSERT INTO erp_loc_a101 (cid, cntry)
    SELECT
        REPLACE(cid, '-', ''),
        CASE
            WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
            WHEN TRIM(cntry) = 'DE' THEN 'Germany'
            WHEN TRIM(cntry) IS NULL OR TRIM(cntry) = '' THEN 'n/a'
            ELSE TRIM(cntry)
        END
    FROM bronze.erp_loc_a101;
    SELECT CONCAT('>> silver.erp_loc_a101 loaded: ', ROW_COUNT(), ' rows') AS status;

    -- ---------------------------------------------------------------
    -- erp_px_cat_g1v2: straight copy, source is already clean
    -- ---------------------------------------------------------------
    TRUNCATE TABLE erp_px_cat_g1v2;
    INSERT INTO erp_px_cat_g1v2 (id, cat, subcat, maintenance)
    SELECT TRIM(id), TRIM(cat), TRIM(subcat), TRIM(maintenance)
    FROM bronze.erp_px_cat_g1v2;
    SELECT CONCAT('>> silver.erp_px_cat_g1v2 loaded: ', ROW_COUNT(), ' rows') AS status;

    SET batch_end = NOW();
    SELECT '================================================' AS status;
    SELECT CONCAT('Silver Layer load complete. Total duration: ',
                  TIMESTAMPDIFF(SECOND, batch_start, batch_end), 's') AS status;
    SELECT '================================================' AS status;
END proc_body $$

DELIMITER ;
