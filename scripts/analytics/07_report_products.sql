/*
===============================================================================
View: gold.report_products
===============================================================================
Purpose: One row per product with revenue, reach (distinct customers/orders),
recency, and a performance tier — the product-side counterpart to
report_customers.

Segment thresholds (High/Mid/Low performer) were set from the actual
distribution of total sales per current product (see docs/data_catalog.md):
25th percentile ~25k, median ~55k, 90th percentile ~692k.
===============================================================================
*/

USE gold;

DROP VIEW IF EXISTS report_products;

CREATE VIEW report_products AS
WITH base AS (
    SELECT
        f.order_number,
        f.customer_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        p.product_key,
        p.product_number,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM fact_sales f
    JOIN dim_products p ON f.product_key = p.product_key
),
aggregated AS (
    SELECT
        product_key, product_number, product_name, category, subcategory, cost,
        COUNT(DISTINCT order_number)  AS total_orders,
        COUNT(DISTINCT customer_key)  AS total_customers,
        SUM(sales_amount)             AS total_sales,
        SUM(quantity)                 AS total_quantity,
        MIN(order_date)               AS first_sale_date,
        MAX(order_date)               AS last_sale_date,
        TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan_months
    FROM base
    GROUP BY product_key, product_number, product_name, category, subcategory, cost
)
SELECT
    product_key,
    product_number,
    product_name,
    COALESCE(category, 'n/a')    AS category,
    COALESCE(subcategory, 'n/a') AS subcategory,
    cost,
    CASE
        WHEN total_sales > 50000 THEN 'High Performer'
        WHEN total_sales >= 10000 THEN 'Mid Performer'
        ELSE 'Low Performer'
    END AS product_segment,
    last_sale_date,
    TIMESTAMPDIFF(MONTH, last_sale_date, CURDATE()) AS recency_months,
    lifespan_months,
    total_orders,
    total_customers,
    total_sales,
    total_quantity,
    CASE WHEN total_orders = 0 THEN 0 ELSE ROUND(total_sales / total_orders, 2) END AS avg_order_revenue,
    CASE WHEN lifespan_months = 0 THEN total_sales ELSE ROUND(total_sales / lifespan_months, 2) END AS avg_monthly_revenue
FROM aggregated;

-- Usage:
-- SELECT * FROM gold.report_products ORDER BY total_sales DESC LIMIT 20;
-- SELECT product_segment, COUNT(*), SUM(total_sales) FROM gold.report_products GROUP BY product_segment;
