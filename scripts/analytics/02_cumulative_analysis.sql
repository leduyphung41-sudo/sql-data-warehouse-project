/*
===============================================================================
Cumulative Analysis
===============================================================================
Purpose: Running total of yearly revenue, and a moving average of yearly
average price — shows growth trend rather than one isolated year.
===============================================================================
*/

USE gold;

SELECT
    order_year,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_year)  AS running_total_sales,
    ROUND(AVG(avg_price) OVER (ORDER BY order_year), 2) AS moving_avg_price
FROM (
    SELECT
        YEAR(order_date)   AS order_year,
        SUM(sales_amount)  AS total_sales,
        AVG(price)         AS avg_price
    FROM fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY YEAR(order_date)
) yearly
ORDER BY order_year;
