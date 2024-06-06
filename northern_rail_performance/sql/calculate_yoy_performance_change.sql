-- SQLite
WITH EOY_PERFORMANCE AS (
    SELECT COMPONENT,
        AREA,
        SUBSTRING(YEAR, INSTR(YEAR, 2), 4) AS YEAR,
        CAST(REPLACE(PERFORMANCE, "%", "") AS FLOAT) AS PERFORMANCE_PRCNT
    FROM EOY_SERVICE_QUALITY
)

SELECT *,
       PERFORMANCE_PRCNT - LAG(PERFORMANCE_PRCNT, 1) OVER (PARTITION BY AREA ORDER BY YEAR) AS YOY_CHANGE
FROM EOY_PERFORMANCE;