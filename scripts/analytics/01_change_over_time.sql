/*
===============================================================================
Change Over Time Analysis
===============================================================================
Purpose: How do orders, customers, and revenue move month over month?
Data: 2010-12 to 2014-01 (from order_date range verified against source CSVs).
===============================================================================
*/

USE gold;

SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS order_month,
    COUNT(DISTINCT order_number)     AS total_orders,
    COUNT(DISTINCT customer_key)     AS total_customers,
    SUM(quantity)                    AS total_quantity,
    SUM(sales_amount)                AS total_sales
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY order_month;
