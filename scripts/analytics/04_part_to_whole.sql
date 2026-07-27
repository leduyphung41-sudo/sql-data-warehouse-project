/*
===============================================================================
Part-to-Whole Analysis
===============================================================================
Purpose: Which product categories drive the most revenue, as a share of total?
===============================================================================
*/

USE gold;

WITH category_sales AS (
    SELECT
        p.category,
        SUM(f.sales_amount) AS total_sales
    FROM fact_sales f
    JOIN dim_products p ON f.product_key = p.product_key
    GROUP BY p.category
)
SELECT
    COALESCE(category, 'n/a')                              AS category,
    total_sales,
    SUM(total_sales) OVER ()                                AS overall_sales,
    CONCAT(ROUND(total_sales / SUM(total_sales) OVER () * 100, 2), '%') AS pct_of_total
FROM category_sales
ORDER BY total_sales DESC;
