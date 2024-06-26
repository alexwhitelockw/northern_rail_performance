WITH PERIOD_PERFORMANCE AS (
    SELECT COMPONENT,
           AREA,
           DATE AS PERIOD_DATE_RANGE,
           DATE(20 || SUBSTR(DATE, 7, 2) || '-' || SUBSTR(DATE, 4, 2) || '-' || SUBSTR(DATE, 1, 2)) AS PERIOD_START_DATE,
           CAST(REPLACE(PERFORMANCE, '%', '') AS FLOAT) AS PERFORMANCE_PRCNT
    FROM SERVICE_QUALITY
)

SELECT *,
       PERFORMANCE_PRCNT - LAG(PERFORMANCE_PRCNT) OVER 
            (PARTITION BY COMPONENT, AREA 
             ORDER BY PERIOD_START_DATE) AS PERFORMANCE_CHNG,
       AVG(PERFORMANCE_PRCNT) OVER (
            PARTITION BY COMPONENT, AREA 
            ORDER BY PERIOD_START_DATE 
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS AVG_PERFORMANCE_PRCNT
FROM PERIOD_PERFORMANCE;
