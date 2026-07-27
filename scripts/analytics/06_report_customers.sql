/*
===============================================================================
View: gold.report_customers
===============================================================================
Purpose: One row per customer with the metrics you'd actually put on a
customer-360 dashboard: recency, order count, spend, segment, age group.

Segment rule (same as 05_data_segmentation.sql):
    VIP     = active 12+ months AND total spend > 5,000
    Regular = active 12+ months AND total spend <= 5,000
    New     = active less than 12 months
===============================================================================
*/

USE gold;

DROP VIEW IF EXISTS report_customers;

CREATE VIEW report_customers AS
WITH base AS (
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name)        AS customer_name,
        TIMESTAMPDIFF(YEAR, c.birth_date, CURDATE())  AS age
    FROM fact_sales f
    JOIN dim_customers c ON f.customer_key = c.customer_key
),
aggregated AS (
    SELECT
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number)  AS total_orders,
        SUM(sales_amount)             AS total_sales,
        SUM(quantity)                 AS total_quantity,
        COUNT(DISTINCT product_key)   AS total_products,
        MIN(order_date)               AS first_order_date,
        MAX(order_date)               AS last_order_date,
        TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan_months
    FROM base
    GROUP BY customer_key, customer_number, customer_name, age
)
SELECT
    customer_key,
    customer_number,
    customer_name,
    age,
    CASE
        WHEN age IS NULL THEN 'n/a'
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 and above'
    END AS age_group,
    CASE
        WHEN lifespan_months >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan_months >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    last_order_date,
    TIMESTAMPDIFF(MONTH, last_order_date, CURDATE()) AS recency_months,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan_months,
    CASE WHEN total_orders = 0 THEN 0 ELSE ROUND(total_sales / total_orders, 2) END AS avg_order_value,
    CASE WHEN lifespan_months = 0 THEN total_sales ELSE ROUND(total_sales / lifespan_months, 2) END AS avg_monthly_spend
FROM aggregated;

-- Usage:
-- SELECT * FROM gold.report_customers ORDER BY total_sales DESC LIMIT 20;
-- SELECT customer_segment, COUNT(*), SUM(total_sales) FROM gold.report_customers GROUP BY customer_segment;
