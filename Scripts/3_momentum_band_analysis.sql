-- =============================================================================
-- Script: 3_momentum_band_analysis.sql
-- Purpose: Classify category-level 3-month rolling gross profit (gp_roll3)
--          against historical percentile bands (2015–2022).
--          Outputs band labels (Low, Mid, High) for recent periods (2023+).
-- =============================================================================

WITH hist_bands AS (
    -- Step 1: For each category, calculate historical p25 and p75
    SELECT
        categoryname,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY gp_roll3) AS p25_roll3,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY gp_roll3) AS p75_roll3
    FROM rolling_gp_category
    WHERE year_order BETWEEN 2015 AND 2022  -- baseline years for banding
    GROUP BY categoryname
)

SELECT
    r.categoryname,
    r.year_order,
    r.month_order,
    r.gp_roll3,
    h.p25_roll3,
    h.p75_roll3,
    -- Step 2: Assign momentum band relative to historical distribution
    CASE
        WHEN r.gp_roll3 <  h.p25_roll3 THEN 'Low (<25th)'
        WHEN r.gp_roll3 <= h.p75_roll3 THEN 'Mid (25–75th)'
        ELSE 'High (≥75th)'
    END AS momentum_band
FROM rolling_gp_category r
JOIN hist_bands h
  ON h.categoryname = r.categoryname
WHERE r.year_order >= 2023   -- only classify current period
ORDER BY r.categoryname, r.year_order, r.month_order;