/*
===============================================================================
Performance Analysis (Year-over-Year, per product)
===============================================================================
Purpose: For each product, compare each year's sales against that product's
own average across all years, and against its previous year — flags whether
a product is trending up or down.
===============================================================================
*/

USE gold;

WITH yearly_product_sales AS (
    SELECT
        YEAR(f.order_date)   AS order_year,
        p.product_name,
        SUM(f.sales_amount)  AS current_sales
    FROM fact_sales f
    JOIN dim_products p ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY YEAR(f.order_date), p.product_name
)
SELECT
    order_year,
    product_name,
    current_sales,
    ROUND(AVG(current_sales) OVER (PARTITION BY product_name), 2) AS avg_sales,
    ROUND(current_sales - AVG(current_sales) OVER (PARTITION BY product_name), 2) AS diff_from_avg,
    CASE
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Average'
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Average'
        ELSE 'Average'
    END AS avg_comparison,
    LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS previous_year_sales,
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS yoy_change,
    CASE
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
        WHEN LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) IS NULL THEN 'First Year'
        ELSE 'No Change'
    END AS yoy_trend
FROM yearly_product_sales
ORDER BY product_name, order_year;
