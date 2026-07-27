/*
===============================================================================
DDL: Gold layer views (MySQL) — star schema for reporting
===============================================================================
Purpose:
    Gold is a set of views on top of silver, shaped as a star schema:
    2 dimensions + 1 fact. Nothing is stored here; views recompute from
    silver on every query, which is fine at this data volume (~60k sales
    rows, ~18k customers).

Design notes (checked against the real data, not assumed):
    - dim_products keeps only the CURRENT version of each product
      (prd_end_dt IS NULL), i.e. 295 of 397 raw rows. The other rows are
      superseded product versions (different cost over time) — useful for
      history, not for "what does this product cost today" reporting.
    - Every row in silver.crm_sales_details has a matching product and
      customer in the dimensions above (0 orphans verified against the
      actual CSVs), so fact_sales can safely INNER JOIN both.
===============================================================================
*/

USE gold;

DROP VIEW IF EXISTS dim_customers;
CREATE VIEW dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ci.cst_id) AS customer_key,
    ci.cst_id                              AS customer_id,
    ci.cst_key                             AS customer_number,
    ci.cst_firstname                       AS first_name,
    ci.cst_lastname                        AS last_name,
    la.cntry                               AS country,
    ci.cst_marital_status                  AS marital_status,
    CASE WHEN ci.cst_gndr <> 'n/a' THEN ci.cst_gndr
         ELSE COALESCE(ca.gen, 'n/a') END  AS gender,
    ca.bdate                               AS birth_date,
    ci.cst_create_date                     AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la  ON ci.cst_key = la.cid;

DROP VIEW IF EXISTS dim_products;
CREATE VIEW dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY pi.prd_start_dt, pi.prd_key) AS product_key,
    pi.prd_id                                                AS product_id,
    pi.prd_key                                                AS product_number,
    pi.prd_nm                                                 AS product_name,
    pi.cat_id                                                 AS category_id,
    pc.cat                                                     AS category,
    pc.subcat                                                  AS subcategory,
    pc.maintenance                                             AS maintenance,
    pi.prd_cost                                                AS cost,
    pi.prd_line                                                AS product_line,
    pi.prd_start_dt                                            AS start_date
FROM silver.crm_prd_info pi
LEFT JOIN silver.erp_px_cat_g1v2 pc ON pi.cat_id = pc.id
WHERE pi.prd_end_dt IS NULL;   -- current version only

DROP VIEW IF EXISTS fact_sales;
CREATE VIEW fact_sales AS
SELECT
    sd.sls_ord_num  AS order_number,
    dp.product_key,
    dc.customer_key,
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt  AS shipping_date,
    sd.sls_due_dt   AS due_date,
    sd.sls_sales    AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price    AS price
FROM silver.crm_sales_details sd
JOIN dim_products  dp ON sd.sls_prd_key = dp.product_number
JOIN dim_customers dc ON sd.sls_cust_id = dc.customer_id;

SHOW TABLES FROM bronze;

