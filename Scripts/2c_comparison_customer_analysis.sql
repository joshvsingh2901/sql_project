/* ============================================================
   Script: 2c:comparispon_customer_analysis.sql
   Purpose: Compare 2023 vs Historical Baseline (2015–2022)
*/

--A) Roll up 2023 to year totals
WITH y23 AS (
  SELECT
    SUM(gross_profit_new_orders)        AS gp_new_2023,
    SUM(gross_profit_returning_orders)  AS gp_ret_2023,
    SUM(count_of_new_orders)            AS ord_new_2023,
    SUM(count_of_returning_orders)      AS ord_ret_2023
  FROM customer_data_2023
), 
--B) Roll up historical monthly averages to an "average year" 
hist AS (
  SELECT
    SUM(gross_new_orders_avg)        AS gp_new_hist_year,
    SUM(gross_returning_orders_avg)  AS gp_ret_hist_year,
    SUM(num_of_new_orders)           AS ord_new_hist_year,
    SUM(num_of_returning_orders)     AS ord_ret_hist_year
  FROM hist_customer_data
),

--C) Derive shares & AOVs for both periods 
derived AS (
  SELECT
    -- raw totals
    y.gp_new_2023, y.gp_ret_2023, y.ord_new_2023, y.ord_ret_2023,
    h.gp_new_hist_year, h.gp_ret_hist_year, h.ord_new_hist_year, h.ord_ret_hist_year,

    -- totals
    (y.gp_new_2023 + y.gp_ret_2023) AS gp_total_2023,
    (h.gp_new_hist_year + h.gp_ret_hist_year) AS gp_total_hist,

    -- shares (gross profit)
    ROUND(100 * (y.gp_ret_2023 / NULLIF((y.gp_new_2023 + y.gp_ret_2023),0))::numeric, 2) AS gp_share_ret_2023_pct,
    ROUND(100 * (y.gp_new_2023 / NULLIF((y.gp_new_2023 + y.gp_ret_2023),0))::numeric, 2) AS gp_share_new_2023_pct,

    ROUND(100 * (h.gp_ret_hist_year / NULLIF((h.gp_new_hist_year + h.gp_ret_hist_year),0))::numeric, 2) AS gp_share_ret_hist_pct,
    ROUND(100 * (h.gp_new_hist_year / NULLIF((h.gp_new_hist_year + h.gp_ret_hist_year),0))::numeric, 2) AS gp_share_new_hist_pct,

    -- order shares
    ROUND(100 * (y.ord_ret_2023 / NULLIF((y.ord_new_2023 + y.ord_ret_2023),0))::numeric, 2) AS ord_share_ret_2023_pct,
    ROUND(100 * (y.ord_new_2023 / NULLIF((y.ord_new_2023 + y.ord_ret_2023),0))::numeric, 2) AS ord_share_new_2023_pct,

    ROUND(100 * (h.ord_ret_hist_year / NULLIF((h.ord_new_hist_year + h.ord_ret_hist_year),0))::numeric, 2) AS ord_share_ret_hist_pct,
    ROUND(100 * (h.ord_new_hist_year / NULLIF((h.ord_new_hist_year + h.ord_ret_hist_year),0))::numeric, 2) AS ord_share_new_hist_pct,

    -- AOVs
    ROUND((y.gp_new_2023 / NULLIF(y.ord_new_2023,0))::numeric, 2) AS aov_new_2023,
    ROUND((y.gp_ret_2023 / NULLIF(y.ord_ret_2023,0))::numeric, 2) AS aov_ret_2023,

    ROUND((h.gp_new_hist_year / NULLIF(h.ord_new_hist_year,0))::numeric, 2) AS aov_new_hist,
    ROUND((h.gp_ret_hist_year / NULLIF(h.ord_ret_hist_year,0))::numeric, 2) AS aov_ret_hist
  FROM y23 y CROSS JOIN hist h
),

--D) Build a tidy "long" summary with % deltas 
annual_comparison_summary AS (
  SELECT 'Gross Profit Share – Returning (%)' AS metric,
         gp_share_ret_2023_pct               AS value_2023,
         gp_share_ret_hist_pct               AS value_hist,
         ROUND(100 * (gp_share_ret_2023_pct - gp_share_ret_hist_pct) 
                 / NULLIF(gp_share_ret_hist_pct,0), 2) AS pct_delta
  FROM derived
  UNION ALL
  SELECT 'Gross Profit Share – New (%)', gp_share_new_2023_pct, gp_share_new_hist_pct,
         ROUND(100 * (gp_share_new_2023_pct - gp_share_new_hist_pct) 
                 / NULLIF(gp_share_new_hist_pct,0), 2)
  FROM derived
  UNION ALL
  SELECT 'Order Share – Returning (%)', ord_share_ret_2023_pct, ord_share_ret_hist_pct,
         ROUND(100 * (ord_share_ret_2023_pct - ord_share_ret_hist_pct) 
                 / NULLIF(ord_share_ret_hist_pct,0), 2)
  FROM derived
  UNION ALL
  SELECT 'Order Share – New (%)', ord_share_new_2023_pct, ord_share_new_hist_pct,
         ROUND(100 * (ord_share_new_2023_pct - ord_share_new_hist_pct) 
                 / NULLIF(ord_share_new_hist_pct,0), 2)
  FROM derived
  UNION ALL
  SELECT 'AOV – Returning ($)', aov_ret_2023, aov_ret_hist,
         ROUND(100 * (aov_ret_2023 - aov_ret_hist) / NULLIF(aov_ret_hist,0), 2)
  FROM derived
  UNION ALL
  SELECT 'AOV – New ($)', aov_new_2023, aov_new_hist,
         ROUND(100 * (aov_new_2023 - aov_new_hist) / NULLIF(aov_new_hist,0), 2)
  FROM derived
),

--E) Month-by-month comparison (good for charts)
monthly_comparison_detail AS (
  SELECT
    c23.month_order::int                                    AS month_order,
    -- 2023 actuals
    ROUND(c23.gross_profit_new_orders::numeric, 0)          AS gp_new_2023,
    ROUND(c23.gross_profit_returning_orders::numeric, 0)    AS gp_ret_2023,
    c23.count_of_new_orders                                 AS ord_new_2023,
    c23.count_of_returning_orders                           AS ord_ret_2023,

    -- historical monthly average (baseline)
    ROUND(h.gross_new_orders_avg::numeric, 0)               AS gp_new_hist_avg,
    ROUND(h.gross_returning_orders_avg::numeric, 0)         AS gp_ret_hist_avg,
    h.num_of_new_orders                                     AS ord_new_hist_avg,
    h.num_of_returning_orders                               AS ord_ret_hist_avg,

    -- deltas vs baseline (levels and %)
    ROUND((c23.gross_profit_new_orders - h.gross_new_orders_avg)::numeric, 0)  AS gp_new_delta,
    ROUND((c23.gross_profit_returning_orders - h.gross_returning_orders_avg)::numeric, 0) AS gp_ret_delta,

    ROUND(100 * (c23.gross_profit_new_orders - h.gross_new_orders_avg)
          / NULLIF(h.gross_new_orders_avg,0), 2) AS gp_new_delta_pct,
    ROUND(100 * (c23.gross_profit_returning_orders - h.gross_returning_orders_avg)
          / NULLIF(h.gross_returning_orders_avg,0), 2) AS gp_ret_delta_pct
  FROM customer_data_2023 c23
  JOIN hist_customer_data h USING (month_order)
)

-- Choose which result to materialize:
-- 1) Annual summary (recommended for README)
SELECT * FROM annual_comparison_summary
ORDER BY metric;

-- 2) Or, per-month detail for plotting
-- SELECT * FROM monthly_comparison_detail ORDER BY month_order;


