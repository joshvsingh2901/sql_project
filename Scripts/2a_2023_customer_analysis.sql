-- =============================================================================
-- Script: 2a_2023_customer_analysis.sql
-- Purpose: For FY 2023 only, compare NEW vs RETURNING customers by month:
--          - Gross profit by segment
--          - Order counts by segment
--          - Average gross profit per order (AOV proxy) by segment
-- =============================================================================


WITH first_order_table AS (
  SELECT
    s.orderdate,
    s.customerkey,
    s.orderkey,
    -- Row-level gross profit to aggregate later
    (s.quantity * (s.netprice - s.unitcost) * s.exchangerate) AS gross_profit,
    -- First-ever order date per customer to tag new vs returning
    MIN(s.orderdate) OVER (PARTITION BY s.customerkey) AS first_orderdate
  FROM sales s
),

labeled_2023 AS (
  SELECT
    EXTRACT(MONTH FROM orderdate)::int AS month_order,
    orderdate,
    customerkey,
    orderkey,
    gross_profit,
    CASE
      WHEN orderdate = first_orderdate THEN 'new_order'
      ELSE 'returning_order'
    END AS new_or_old
  FROM first_order_table
  WHERE EXTRACT(YEAR FROM orderdate) = 2023
)

SELECT
  month_order,

  -- Gross profit by segment
  ROUND(SUM(gross_profit) FILTER (WHERE new_or_old = 'new_order')::numeric, 0)      AS gross_profit_new_orders,
  ROUND(SUM(gross_profit) FILTER (WHERE new_or_old = 'returning_order')::numeric, 0) AS gross_profit_returning_orders,

  -- Order counts by segment
  COUNT(DISTINCT orderkey) FILTER (WHERE new_or_old = 'new_order')        AS count_of_new_orders,
  COUNT(DISTINCT orderkey) FILTER (WHERE new_or_old = 'returning_order')  AS count_of_returning_orders,

  -- AOV proxy (gross profit per order) by segment; NULL-safe division
  ROUND(
    (SUM(gross_profit) FILTER (WHERE new_or_old = 'new_order')::numeric)
    / NULLIF(COUNT(DISTINCT orderkey) FILTER (WHERE new_or_old = 'new_order'), 0),
    2
  ) AS gross_per_new_order,

  ROUND(
    (SUM(gross_profit) FILTER (WHERE new_or_old = 'returning_order')::numeric)
    / NULLIF(COUNT(DISTINCT orderkey) FILTER (WHERE new_or_old = 'returning_order'), 0),
    2
  ) AS gross_per_returning_order

FROM labeled_2023
GROUP BY month_order
ORDER BY month_order;