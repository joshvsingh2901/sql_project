-- =============================================================================
-- Script: 1_category_profitability.sql
-- Purpose: Identify which categories and parent products drive gross profit.
--          Outputs absolute GP, category share of company GP, and product share
--          within each category. Also ranks categories and products.
-- =============================================================================

WITH combine_p_s AS (
    SELECT 
        s.orderdate,
        s.productkey,
        p.categoryname,
        p.parent_product, 
        -- Compute gross profit at the row level to reuse downstream
        (s.netprice - p.cost) * s.quantity * s.exchangerate AS gross_profit
    FROM sales s
    LEFT JOIN product_clean p ON s.productkey = p.productkey
), 

revenue_per_product_and_total_rev AS (
    -- Aggregate to parent_product and carry a window total for company GP
    SELECT 
        categoryname,
        parent_product,
        SUM(gross_profit) AS gross_profit_per_product,
        SUM(SUM(gross_profit)) OVER () AS gross_profit_total_company
    FROM combine_p_s
    GROUP BY categoryname, parent_product
), 

gross_profit_per_category_table AS (
    -- For each category, compute its total GP (to enable within-category shares)
    SELECT 
        *,
        SUM(gross_profit_per_product) OVER (PARTITION BY categoryname) AS gross_profit_by_category
    FROM revenue_per_product_and_total_rev
)

SELECT 
    categoryname,
    parent_product,
    -- Round money-like outputs for reporting readability
    ROUND(gross_profit_per_product::NUMERIC, 0) AS gross_profit_per_product,
    ROUND(gross_profit_total_company::NUMERIC, 0) AS gross_profit_total_company,
    ROUND(gross_profit_by_category::NUMERIC, 0) AS gross_profit_by_category,

    -- Category's share of company GP (how big is the category in the portfolio?)
    ROUND((100 * (gross_profit_by_category / gross_profit_total_company))::NUMERIC, 2) 
        AS category_percent_of_total_gross_profit,

    -- Product's share within its category (which products lead the category?)
    ROUND((100 * (gross_profit_per_product / gross_profit_by_category))::NUMERIC, 2) 
        AS product_percent_of_category,

    -- Ranks to quickly identify top categories/products
    DENSE_RANK () OVER (ORDER BY gross_profit_by_category DESC) 
        AS category_gross_profit_rank,
    RANK () OVER (PARTITION BY categoryname ORDER BY gross_profit_per_product DESC) 
        AS within_catgory_product_rank

FROM gross_profit_per_category_table
-- Keep a stable presentation; change to ORDER BY category_gross_profit_rank for a leaderboard view
ORDER BY categoryname;










