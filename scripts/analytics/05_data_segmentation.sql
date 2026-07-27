/*
===============================================================================
Data Segmentation
===============================================================================
Purpose: Bucket customers by loyalty/spend, and products by cost tier.
Thresholds below were chosen by looking at the actual distribution (not
arbitrary round numbers) — see docs/data_catalog.md for the underlying
percentiles.
===============================================================================
*/

USE gold;

-- ---------------------------------------------------------------
-- Customer segmentation: New / Regular / VIP
-- ---------------------------------------------------------------
WITH customer_spending AS (
    SELECT
        c.customer_key,
        SUM(f.sales_amount) AS total_spending,
        TIMESTAMPDIFF(MONTH, MIN(f.order_date), MAX(f.order_date)) AS lifespan_months
    FROM fact_sales f
    JOIN dim_customers c ON f.customer_key = c.customer_key
    GROUP BY c.customer_key
)
SELECT
    CASE
        WHEN lifespan_months >= 12 AND total_spending > 5000 THEN 'VIP'
        WHEN lifespan_months >= 12 AND total_spending <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    COUNT(*) AS customer_count
FROM customer_spending
GROUP BY customer_segment
ORDER BY customer_count DESC;

-- ---------------------------------------------------------------
-- Product segmentation: cost tier
-- ---------------------------------------------------------------
SELECT
    CASE
        WHEN cost < 100 THEN 'Below 100'
        WHEN cost BETWEEN 100 AND 499 THEN '100-499'
        WHEN cost BETWEEN 500 AND 999 THEN '500-999'
        ELSE '1000 and above'
    END AS cost_range,
    COUNT(*) AS product_count
FROM dim_products
GROUP BY cost_range
ORDER BY product_count DESC;
