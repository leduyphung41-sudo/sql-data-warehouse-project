# Data Catalog — Gold Layer

## gold.dim_customers

| Column | Type | Description |
|---|---|---|
| customer_key | INT | Surrogate key, unique per customer, used to join to fact_sales |
| customer_id | INT | Business key from the CRM source (crm_cust_info.cst_id) |
| customer_number | VARCHAR | Alphanumeric customer identifier used for tracking/joining across systems |
| first_name | VARCHAR | Customer's first name |
| last_name | VARCHAR | Customer's last name |
| country | VARCHAR | Country of residence (e.g. 'Australia') |
| marital_status | VARCHAR | 'Married', 'Single', or 'n/a' |
| gender | VARCHAR | 'Male', 'Female', or 'n/a'. CRM value is used when present, ERP value used as a fallback |
| birth_date | DATE | Date of birth |
| create_date | DATE | Date the customer record was created in the source CRM system |

## gold.dim_products

| Column | Type | Description |
|---|---|---|
| product_key | INT | Surrogate key, unique per product, used to join to fact_sales |
| product_id | INT | Business key from the CRM source (crm_prd_info.prd_id) |
| product_number | VARCHAR | Alphanumeric product code |
| product_name | VARCHAR | Descriptive product name |
| category_id | VARCHAR | Category identifier, links to the ERP category table |
| category | VARCHAR | High-level category (e.g. 'Bikes', 'Accessories') |
| subcategory | VARCHAR | More detailed classification within the category |
| maintenance | VARCHAR | Whether the product requires maintenance ('Yes'/'No') |
| cost | INT | Product cost |
| product_line | VARCHAR | 'Road', 'Mountain', 'Touring', 'Other Sales', or 'n/a' |
| start_date | DATE | Date this product version became active |

Only the current version of each product is included (superseded versions
with an earlier end date are excluded).

## gold.fact_sales

| Column | Type | Description |
|---|---|---|
| order_number | VARCHAR | Unique sales order identifier |
| product_key | INT | Foreign key to dim_products |
| customer_key | INT | Foreign key to dim_customers |
| order_date | DATE | Date the order was placed |
| shipping_date | DATE | Date the order was shipped |
| due_date | DATE | Payment/delivery due date |
| sales_amount | INT | Total value of the line item |
| quantity | INT | Number of units sold |
| price | INT | Unit price |

## gold.report_customers

One row per customer (built in `scripts/analytics/06_report_customers.sql`).

| Column | Description |
|---|---|
| customer_key, customer_number, customer_name | Identity |
| age, age_group | Age in years, bucketed (Under 20 / 20-29 / 30-39 / 40-49 / 50 and above / n/a) |
| customer_segment | 'VIP' (12+ months active, spend > 5,000), 'Regular' (12+ months, spend <= 5,000), 'New' (< 12 months) |
| last_order_date, recency_months | Most recent order and months since then |
| total_orders, total_sales, total_quantity, total_products | Lifetime activity |
| lifespan_months | Months between first and last order |
| avg_order_value | total_sales / total_orders |
| avg_monthly_spend | total_sales / lifespan_months |

Segment thresholds were set from the real spend distribution: median
lifetime spend ≈ 272, 75th percentile ≈ 2,511 — the 5,000 cutoff for VIP
sits above the 75th percentile, so VIP is genuinely a top tier, not half
the customer base.

## gold.report_products

One row per current product (built in `scripts/analytics/07_report_products.sql`).

| Column | Description |
|---|---|
| product_key, product_number, product_name, category, subcategory, cost | Identity |
| product_segment | 'High Performer' (total sales > 50,000), 'Mid Performer' (10,000–50,000), 'Low Performer' (< 10,000) |
| last_sale_date, recency_months | Most recent sale and months since then |
| lifespan_months | Months between first and last sale |
| total_orders, total_customers, total_sales, total_quantity | Lifetime activity |
| avg_order_revenue | total_sales / total_orders |
| avg_monthly_revenue | total_sales / lifespan_months |

Segment thresholds were set from the real per-product sales distribution
(only products that actually sold): 25th percentile ≈ 25,400, median ≈
55,400, 90th percentile ≈ 692,000.
