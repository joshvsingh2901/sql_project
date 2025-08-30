-- =============================================================================
-- Script: 2b_historical_customer_analysis.sql
-- Purpose: Build a 2015–2022 monthly baseline to compare NEW vs RETURNING:
--          - Average monthly gross profit by segment
--          - Average monthly order counts by segment
--          - Average monthly AOV proxy (gross profit per order) by segment
-- =============================================================================

WITH first_order_table AS (
  SELECT
    s.orderdate,
    s.customerkey,
    s.orderkey,
    -- Row-level gross profit for later aggregation
    (s.quantity * (s.netprice - s.unitcost) * s.exchangerate) AS gross_profit,
    -- First observed order per customer (to tag new vs returning)
    MIN(s.orderdate) OVER (PARTITION BY s.customerkey) AS first_orderdate
  FROM sales s
),

labeled_hist AS (
  SELECT
    EXTRACT(YEAR  FROM orderdate)::int AS year_order,
    EXTRACT(MONTH FROM orderdate)::int AS month_order,
    orderkey,
    gross_profit,
    CASE
      WHEN orderdate = first_orderdate THEN 'new_order'
      ELSE 'returning_order'
    END AS new_or_old
  FROM first_order_table
  WHERE EXTRACT(YEAR FROM orderdate) BETWEEN 2015 AND 2022
),

-- Aggregate within each year-month by segment; we will average these across years
monthly_per_year AS (
  SELECT
    year_order,
    month_order,
    new_or_old,
    SUM(gross_profit)        AS month_gross_profit,
    COUNT(DISTINCT orderkey) AS month_order_count
  FROM labeled_hist
  GROUP BY year_order, month_order, new_or_old
)

SELECT
  month_order,

  -- Average monthly gross profit across 2015–2022 (by segment)
  ROUND(AVG(month_gross_profit) FILTER (WHERE new_or_old = 'new_order')::numeric, 0)        AS gross_new_orders_avg,
  ROUND(AVG(month_gross_profit) FILTER (WHERE new_or_old = 'returning_order')::numeric, 0)  AS gross_returning_orders_avg,

  -- Average monthly order count across 2015–2022 (by segment)
  ROUND(AVG(month_order_count)  FILTER (WHERE new_or_old = 'new_order')::numeric, 0)        AS num_of_new_orders,
  ROUND(AVG(month_order_count)  FILTER (WHERE new_or_old = 'returning_order')::numeric, 0)  AS num_of_returning_orders,

  -- Average AOV proxy across years:
  --   compute per-year AOV (gp / orders), then average those values by month
  ROUND(AVG( (month_gross_profit::numeric / NULLIF(month_order_count, 0)) )
        FILTER (WHERE new_or_old = 'new_order'), 2)        AS avg_profit_per_new_order,
  ROUND(AVG( (month_gross_profit::numeric / NULLIF(month_order_count, 0)) )
        FILTER (WHERE new_or_old = 'returning_order'), 2)  AS avg_profit_per_returning_order

FROM monthly_per_year
GROUP BY month_order
ORDER BY month_order;