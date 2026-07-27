/*
===============================================================================
DDL: Silver layer tables (MySQL)
===============================================================================
Purpose:
    Silver mirrors the bronze structure but with real types, standardized
    values and deduplication applied. Every table gets a dwh_create_date
    audit column so you can tell when a row was loaded.
===============================================================================
*/

USE silver;

DROP TABLE IF EXISTS crm_cust_info;
CREATE TABLE crm_cust_info (
    cst_id              INT PRIMARY KEY,
    cst_key             VARCHAR(50),
    cst_firstname       VARCHAR(50),
    cst_lastname        VARCHAR(50),
    cst_marital_status  VARCHAR(50),   -- 'Married' | 'Single' | 'n/a'
    cst_gndr            VARCHAR(50),   -- 'Male' | 'Female' | 'n/a'
    cst_create_date     DATE,
    dwh_create_date     DATETIME DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS crm_prd_info;
CREATE TABLE crm_prd_info (
    prd_id           INT,
    cat_id           VARCHAR(50),      -- links to erp_px_cat_g1v2.id
    prd_key          VARCHAR(50),
    prd_nm           VARCHAR(100),
    prd_cost         INT,
    prd_line         VARCHAR(50),      -- 'Road' | 'Mountain' | 'Touring' | 'Other Sales' | 'n/a'
    prd_start_dt     DATE,
    prd_end_dt       DATE,             -- recalculated from the next version's start date
    dwh_create_date  DATETIME DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS crm_sales_details;
CREATE TABLE crm_sales_details (
    sls_ord_num      VARCHAR(50),
    sls_prd_key      VARCHAR(50),
    sls_cust_id      INT,
    sls_order_dt     DATE,
    sls_ship_dt      DATE,
    sls_due_dt       DATE,
    sls_sales        INT,
    sls_quantity     INT,
    sls_price        INT,
    dwh_create_date  DATETIME DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS erp_cust_az12;
CREATE TABLE erp_cust_az12 (
    cid              VARCHAR(50),
    bdate            DATE,
    gen              VARCHAR(50),      -- 'Male' | 'Female' | 'n/a'
    dwh_create_date  DATETIME DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS erp_loc_a101;
CREATE TABLE erp_loc_a101 (
    cid              VARCHAR(50),
    cntry            VARCHAR(50),
    dwh_create_date  DATETIME DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS erp_px_cat_g1v2;
CREATE TABLE erp_px_cat_g1v2 (
    id               VARCHAR(50),
    cat              VARCHAR(50),
    subcat           VARCHAR(50),
    maintenance      VARCHAR(50),
    dwh_create_date  DATETIME DEFAULT CURRENT_TIMESTAMP
);


