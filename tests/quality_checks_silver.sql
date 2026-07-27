/*
===============================================================================
Quality Checks: Silver layer
===============================================================================
Every query below should return ZERO rows. If a query returns rows, that is
a data quality issue to investigate before trusting the Gold layer.
===============================================================================
*/

USE silver;

-- crm_cust_info: cst_id must be unique and not null (PK already enforces this,
-- but re-check in case the table was loaded outside load_silver())
SELECT cst_id, COUNT(*) FROM crm_cust_info GROUP BY cst_id HAVING COUNT(*) > 1;

-- crm_cust_info: unwanted whitespace should have been trimmed already
SELECT cst_firstname FROM crm_cust_info WHERE cst_firstname <> TRIM(cst_firstname);
SELECT cst_lastname  FROM crm_cust_info WHERE cst_lastname  <> TRIM(cst_lastname);

-- crm_cust_info: gender/marital status must only contain the mapped values
SELECT DISTINCT cst_gndr FROM crm_cust_info
WHERE cst_gndr NOT IN ('Male', 'Female', 'n/a');
SELECT DISTINCT cst_marital_status FROM crm_cust_info
WHERE cst_marital_status NOT IN ('Married', 'Single', 'n/a');

-- crm_prd_info: prd_end_dt must never be before prd_start_dt
SELECT * FROM crm_prd_info WHERE prd_end_dt < prd_start_dt;

-- crm_prd_info: cost must not be negative
SELECT * FROM crm_prd_info WHERE prd_cost < 0;

-- crm_sales_details: shipping/due date must not be before order date
SELECT * FROM crm_sales_details WHERE sls_ship_dt < sls_order_dt;
SELECT * FROM crm_sales_details WHERE sls_due_dt  < sls_order_dt;

-- crm_sales_details: sales must equal quantity * price, and all must be positive
SELECT * FROM crm_sales_details
WHERE sls_sales <> sls_quantity * sls_price
   OR sls_sales IS NULL OR sls_sales <= 0
   OR sls_quantity IS NULL OR sls_quantity <= 0
   OR sls_price IS NULL OR sls_price <= 0;

-- erp_cust_az12: birthdate must be in a plausible range
SELECT * FROM erp_cust_az12 WHERE bdate < '1925-01-01' OR bdate > CURDATE();

-- erp_loc_a101: country must be a standardized value (spot-check known set)
SELECT DISTINCT cntry FROM erp_loc_a101;

-- Referential check: every crm_prd_info.cat_id (current products) should
-- resolve to a category (small % expected to be unmatched, see README)
SELECT DISTINCT cat_id FROM crm_prd_info
WHERE prd_end_dt IS NULL
  AND cat_id NOT IN (SELECT id FROM erp_px_cat_g1v2);
