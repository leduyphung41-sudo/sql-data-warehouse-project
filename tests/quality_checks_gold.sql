/*
===============================================================================
Quality Checks: Gold layer
===============================================================================
Every query below should return ZERO rows.
===============================================================================
*/

USE gold;

-- Surrogate keys must be unique
SELECT customer_key, COUNT(*) FROM dim_customers GROUP BY customer_key HAVING COUNT(*) > 1;
SELECT product_key,  COUNT(*) FROM dim_products  GROUP BY product_key  HAVING COUNT(*) > 1;

-- fact_sales must not contain orphan references (every row must join
-- successfully to both dimensions; since fact_sales uses INNER JOIN this
-- can only happen if the view definition itself is broken)
SELECT f.order_number FROM fact_sales f
LEFT JOIN dim_customers c ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;

SELECT f.order_number FROM fact_sales f
LEFT JOIN dim_products p ON f.product_key = p.product_key
WHERE p.product_key IS NULL;

-- Sanity check on row counts vs the source (adjust the expected numbers if
-- your CSVs differ)
SELECT
    (SELECT COUNT(*) FROM silver.crm_sales_details) AS silver_sales_rows,
    (SELECT COUNT(*) FROM fact_sales)                AS gold_fact_rows;
