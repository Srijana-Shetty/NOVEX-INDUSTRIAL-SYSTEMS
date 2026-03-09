-- See the first 10 rows
SELECT *
FROM NIS
LIMIT 10;

-- Count total number of rows
SELECT COUNT(*) AS TotalRows
FROM NIS;

SELECT DISTINCT MachineID
FROM NIS;

-- to See all unique plants
SELECT DISTINCT Plant
FROM NIS;

-- to See all unique machines
SELECT DISTINCT MachineID
FROM NIS
ORDER BY MachineID;

-- See the date range of data
SELECT
    MIN(Timestamp) AS StartDate,
    MAX(Timestamp) AS EndDate
FROM NIS;

-- Count how many machines per plant
SELECT
    Plant,
    COUNT(DISTINCT MachineID) AS NumberOfMachines
FROM NIS
GROUP BY Plant
ORDER BY Plant;

-- Check for NULL or missing values in each column
-- If result is 0 for all columns — data is clean!
SELECT
    SUM(CASE WHEN Timestamp         IS NULL THEN 1 ELSE 0 END) AS Null_Timestamp,
    SUM(CASE WHEN MachineID         IS NULL THEN 1 ELSE 0 END) AS Null_MachineID,
    SUM(CASE WHEN Plant             IS NULL THEN 1 ELSE 0 END) AS Null_Plant,
    SUM(CASE WHEN Temperature       IS NULL THEN 1 ELSE 0 END) AS Null_Temperature,
    SUM(CASE WHEN Vibration         IS NULL THEN 1 ELSE 0 END) AS Null_Vibration,
    SUM(CASE WHEN Pressure          IS NULL THEN 1 ELSE 0 END) AS Null_Pressure,
    SUM(CASE WHEN EnergyConsumption IS NULL THEN 1 ELSE 0 END) AS Null_Energy,
    SUM(CASE WHEN ProductionUnits   IS NULL THEN 1 ELSE 0 END) AS Null_Production,
    SUM(CASE WHEN DefectCount       IS NULL THEN 1 ELSE 0 END) AS Null_Defects,
    SUM(CASE WHEN MaintenanceFlag   IS NULL THEN 1 ELSE 0 END) AS Null_Maintenance
FROM NIS;

-- Check for duplicate rows
-- If result = 0, no duplicates exist
SELECT COUNT(*) AS DuplicateRows
FROM (
    SELECT Timestamp, MachineID, COUNT(*) AS cnt
    FROM NIS
    GROUP BY Timestamp, MachineID
    HAVING COUNT(*) > 1
) AS duplicate_data;

-- Check for negative or zero values which is impossible in real machines
SELECT
    SUM(CASE WHEN EnergyConsumption <= 0 THEN 1 ELSE 0 END) AS Zero_Energy,
    SUM(CASE WHEN ProductionUnits   <= 0 THEN 1 ELSE 0 END) AS Zero_Production,
    SUM(CASE WHEN Temperature       <= 0 THEN 1 ELSE 0 END) AS Zero_Temperature,
    SUM(CASE WHEN Vibration         <  0 THEN 1 ELSE 0 END) AS Negative_Vibration,
    SUM(CASE WHEN Pressure          <= 0 THEN 1 ELSE 0 END) AS Zero_Pressure
FROM NIS;


-- Check MaintenanceFlag only has 0 or 1
SELECT
    MaintenanceFlag,
    COUNT(*) AS Count
FROM NIS
GROUP BY MaintenanceFlag;


-- Summary statistics for all numeric columns
SELECT
    -- Energy
    ROUND(MIN(EnergyConsumption), 2)  AS Energy_Min,
    ROUND(MAX(EnergyConsumption), 2)  AS Energy_Max,
    ROUND(AVG(EnergyConsumption), 2)  AS Energy_Avg,

    -- Production
    MIN(ProductionUnits)               AS Production_Min,
    MAX(ProductionUnits)               AS Production_Max,
    ROUND(AVG(ProductionUnits), 2)     AS Production_Avg,

    -- Temperature
    ROUND(MIN(Temperature), 2)         AS Temp_Min,
    ROUND(MAX(Temperature), 2)         AS Temp_Max,
    ROUND(AVG(Temperature), 2)         AS Temp_Avg,

    -- Vibration
    ROUND(MIN(Vibration), 2)           AS Vibration_Min,
    ROUND(MAX(Vibration), 2)           AS Vibration_Max,
    ROUND(AVG(Vibration), 2)           AS Vibration_Avg,

    -- Pressure
    ROUND(MIN(Pressure), 2)            AS Pressure_Min,
    ROUND(MAX(Pressure), 2)            AS Pressure_Max,
    ROUND(AVG(Pressure), 2)            AS Pressure_Avg,

    -- Defects
    MIN(DefectCount)                   AS Defects_Min,
    MAX(DefectCount)                   AS Defects_Max,
    ROUND(AVG(DefectCount), 2)         AS Defects_Avg

FROM NIS;


-- Drop view if it already exists
DROP VIEW IF EXISTS NIS_KPI;

-- Create KPI View
CREATE VIEW NIS_KPI AS
SELECT
    -- Original columns
    Timestamp,
    MachineID,
    Plant,
    Temperature,
    Vibration,
    Pressure,
    EnergyConsumption,
    ProductionUnits,
    DefectCount,
    MaintenanceFlag,

    -- KPI 1: Energy per Unit (Lower is better)
    ROUND(EnergyConsumption / NULLIF(ProductionUnits, 0), 4)
        AS EnergyPerUnit,

    -- KPI 2: Efficiency Score (Higher is better)
    ROUND((ProductionUnits - DefectCount) / NULLIF(EnergyConsumption, 0), 4)
        AS EfficiencyScore,

    -- KPI 3: Defect Rate (Lower is better)
    ROUND(DefectCount / NULLIF(ProductionUnits, 0), 4)
        AS DefectRate,

    -- Time breakdowns (MySQL functions)
    YEAR(Timestamp) AS Year,
    MONTH(Timestamp) AS Month,
    HOUR(Timestamp) AS Hour,
    DATE_FORMAT(Timestamp, '%Y-%m') AS YearMonth,

    -- Quarter (Built-in MySQL function)
    CONCAT('Q', QUARTER(Timestamp)) AS Quarter,

    -- Maintenance label
    CASE 
        WHEN MaintenanceFlag = 1 THEN 'Under Maintenance'
        ELSE 'Normal Operation'
    END AS MaintenanceLabel

FROM NIS;


-- PLANT LEVEL ANALYSIS
-- Full plant summary
SELECT
    Plant,
    COUNT(*) AS TotalReadings,
    COUNT(DISTINCT MachineID) AS MachineCount,
    ROUND(SUM(EnergyConsumption), 0) AS TotalEnergy_kWh,
    ROUND(AVG(EnergyConsumption), 2) AS AvgEnergy_kWh,
    ROUND(AVG(EnergyPerUnit), 4) AS AvgEnergyPerUnit,
    ROUND(AVG(EfficiencyScore), 4) AS AvgEfficiencyScore,
    ROUND(AVG(DefectRate) * 100, 2) AS AvgDefectRate_Pct,
    SUM(ProductionUnits) AS TotalProduction,
    SUM(DefectCount) AS TotalDefects
FROM NIS_KPI
GROUP BY Plant
ORDER BY AvgEnergyPerUnit DESC;  -- Worst efficiency at top

-- Which plant wastes the most energy?
-- now Comparing each plant to the fleet average
SELECT
    Plant,
    ROUND(AVG(EnergyPerUnit), 4)              AS AvgEnergyPerUnit,
    ROUND(AVG(EnergyPerUnit) -
          (SELECT AVG(EnergyPerUnit) FROM NIS_KPI), 4)
                                              AS DiffFromFleetAvg,
    CASE
        WHEN AVG(EnergyPerUnit) >
             (SELECT AVG(EnergyPerUnit) FROM NIS_KPI)
        THEN 'Above Average (Inefficient)'
        ELSE 'Below Average (Efficient)'
    END AS Status
FROM NIS_KPI
GROUP BY Plant
ORDER BY AvgEnergyPerUnit DESC;

--  Total energy share by plant (%)
SELECT
    Plant,
    ROUND(SUM(EnergyConsumption), 0) AS TotalEnergy,
    ROUND(SUM(EnergyConsumption) * 100.0 /
          (SELECT SUM(EnergyConsumption) FROM NIS_KPI), 2)
                                              AS EnergyShare_Pct
FROM NIS_KPI
GROUP BY Plant
ORDER BY TotalEnergy DESC;


--  MACHINE LEVEL ANALYSIS
-- Finding the worst machines so engineers know where to focus.
-- Full machine summary — sorted worst to best
SELECT
    MachineID,
    Plant,
    COUNT(*)                                  AS TotalReadings,
    ROUND(AVG(EnergyPerUnit), 4)              AS AvgEnergyPerUnit,
    ROUND(AVG(EfficiencyScore), 4)            AS AvgEfficiencyScore,
    ROUND(AVG(DefectRate) * 100, 3)           AS AvgDefectRate_Pct,
    ROUND(SUM(EnergyConsumption), 0)          AS TotalEnergy_kWh,
    SUM(ProductionUnits)                      AS TotalProduction
FROM NIS_KPI
GROUP BY MachineID, Plant
ORDER BY AvgEnergyPerUnit DESC;

--  Top 10 WORST machines (highest energy per unit = most wasteful)
SELECT
    MachineID,
    Plant,
    ROUND(AVG(EnergyPerUnit), 4)              AS AvgEnergyPerUnit,
    ROUND(AVG(EfficiencyScore), 4)            AS AvgEfficiencyScore,
    ROUND(AVG(DefectRate) * 100, 3)           AS AvgDefectRate_Pct,
    'HIGH WASTE — Needs Audit'                AS Recommendation
FROM NIS_KPI
GROUP BY MachineID, Plant
ORDER BY AvgEnergyPerUnit DESC
LIMIT 10;

--  Top 10 BEST machines (lowest energy per unit = most efficient)
SELECT
    MachineID,
    Plant,
    ROUND(AVG(EnergyPerUnit), 4)              AS AvgEnergyPerUnit,
    ROUND(AVG(EfficiencyScore), 4)            AS AvgEfficiencyScore,
    ROUND(AVG(DefectRate) * 100, 3)           AS AvgDefectRate_Pct,
    'BENCHMARK — Use as Best Practice'        AS Recommendation
FROM NIS_KPI
GROUP BY MachineID, Plant
ORDER BY AvgEnergyPerUnit ASC
LIMIT 10;

--  Flag high-waste machines (above fleet average)
SELECT
    MachineID,
    Plant,
    ROUND(AVG(EnergyPerUnit), 4)              AS AvgEnergyPerUnit,
    CASE
        WHEN AVG(EnergyPerUnit) >
             (SELECT AVG(EnergyPerUnit) FROM NIS_KPI)
        THEN 'HIGH WASTE'
        ELSE 'NORMAL'
    END AS WasteStatus
FROM NIS_KPI
GROUP BY MachineID, Plant
ORDER BY AvgEnergyPerUnit DESC;

-- Counting how many machines are high waste vs normal
SELECT
    CASE
        WHEN AvgEPU > (SELECT AVG(EnergyPerUnit) FROM NIS_KPI)
        THEN 'HIGH WASTE'
        ELSE 'NORMAL'
    END AS WasteStatus,
    COUNT(*) AS MachineCount
FROM (
    SELECT MachineID, AVG(EnergyPerUnit) AS AvgEPU
    FROM NIS_KPI
    GROUP BY MachineID
) AS t
GROUP BY WasteStatus;

-- ANOMALY DETECTION
-- WHY: Energy spikes = energy waste events.
-- Finding them helps engineers investigate root causes immediately.
-- Finding all anomaly readings (energy spikes)
SELECT
    Timestamp,
    MachineID,
    Plant,
    EnergyConsumption,
    ProductionUnits,
    ROUND(EnergyPerUnit, 4)                   AS EnergyPerUnit,
    'ANOMALY — Energy Spike'                  AS AnomalyStatus
FROM NIS_KPI
WHERE EnergyConsumption > 358.2
   OR EnergyConsumption < 141.4
ORDER BY EnergyConsumption DESC;

-- Count total anomalies
SELECT
    COUNT(*)                                  AS TotalAnomalies,
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM NIS_KPI), 2)  AS AnomalyPct
FROM NIS_KPI
WHERE EnergyConsumption > 358.2
   OR EnergyConsumption < 141.4;

-- 8C: Anomalies by plant
SELECT
    Plant,
    COUNT(*)                                  AS AnomalyCount,
    ROUND(AVG(EnergyConsumption), 2)          AS AvgAnomalyEnergy,
    MAX(EnergyConsumption)                    AS MaxEnergySpike
FROM NIS_KPI
WHERE EnergyConsumption > 358.2
   OR EnergyConsumption < 141.4
GROUP BY Plant
ORDER BY AnomalyCount DESC;

-- Which machines have the most anomalies?
SELECT
    MachineID,
    Plant,
    COUNT(*) AS AnomalyCount,
    MAX(EnergyConsumption) AS MaxEnergySpike,
    ROUND(AVG(EnergyConsumption), 2) AS AvgAnomalyEnergy
FROM NIS_KPI
WHERE EnergyConsumption > 358.2
   OR EnergyConsumption < 141.4
GROUP BY MachineID, Plant
ORDER BY AnomalyCount DESC
LIMIT 10;

-- Anomalies by month (are spikes increasing over time?)
SELECT
    YearMonth,
    COUNT(*)                                  AS AnomalyCount
FROM NIS_KPI
WHERE EnergyConsumption > 358.2
   OR EnergyConsumption < 141.4
GROUP BY YearMonth
ORDER BY YearMonth;

-- MAINTENANCE IMPACT ANALYSIS

-- WHY: Does maintenance improve or worsen energy efficiency?
-- If maintenance increases energy without improving quality

--  Compare energy during normal vs maintenance
SELECT
    MaintenanceLabel,
    COUNT(*)                                  AS ReadingCount,
    ROUND(AVG(EnergyConsumption), 2)          AS AvgEnergy_kWh,
    ROUND(AVG(EnergyPerUnit), 4)              AS AvgEnergyPerUnit,
    ROUND(AVG(EfficiencyScore), 4)            AS AvgEfficiencyScore,
    ROUND(AVG(DefectRate) * 100, 3)           AS AvgDefectRate_Pct
FROM NIS_KPI
GROUP BY MaintenanceLabel;

--  Maintenance impact by plant
SELECT
    Plant,
    MaintenanceLabel,
    ROUND(AVG(EnergyPerUnit), 4)              AS AvgEnergyPerUnit,
    ROUND(AVG(EfficiencyScore), 4)            AS AvgEfficiencyScore,
    COUNT(*)                                  AS ReadingCount
FROM NIS_KPI
GROUP BY Plant, MaintenanceLabel
ORDER BY Plant, MaintenanceLabel;

-- 9C: Which machines are under maintenance most often?
SELECT
    MachineID,
    Plant,
    SUM(MaintenanceFlag)                      AS MaintenanceHours,
    COUNT(*)                                  AS TotalReadings,
    ROUND(SUM(MaintenanceFlag) * 100.0 /
          COUNT(*), 2)                        AS MaintenancePct
FROM NIS_KPI
GROUP BY MachineID, Plant
ORDER BY MaintenancePct DESC
LIMIT 10;

-- FINAL KPI SUMMARY
--  Overall headline KPIs
SELECT
    COUNT(*)                                  AS TotalReadings,
    COUNT(DISTINCT MachineID)                 AS TotalMachines,
    COUNT(DISTINCT Plant)                     AS TotalPlants,
    ROUND(SUM(EnergyConsumption) / 1000000.0, 2)
                                              AS TotalEnergy_MillionKWh,
    ROUND(AVG(EnergyPerUnit), 4)              AS FleetAvg_EnergyPerUnit,
    ROUND(AVG(EfficiencyScore), 4)            AS FleetAvg_EfficiencyScore,
    ROUND(AVG(DefectRate) * 100, 3)           AS FleetAvg_DefectRate_Pct,
    SUM(CASE WHEN EnergyConsumption > 358.2
              OR EnergyConsumption < 141.4
             THEN 1 ELSE 0 END)               AS TotalAnomalies,
    SUM(MaintenanceFlag)                      AS TotalMaintenanceHours
FROM NIS_KPI;

--  Plant ranking (best to worst efficiency)
SELECT
    ROW_NUMBER() OVER (ORDER BY AVG(EnergyPerUnit) ASC)
                                              AS EfficiencyRank,
    Plant,
    ROUND(AVG(EnergyPerUnit), 4)              AS AvgEnergyPerUnit,
    ROUND(AVG(EfficiencyScore), 4)            AS AvgEfficiencyScore,
    ROUND(AVG(DefectRate) * 100, 3)           AS AvgDefectRate_Pct,
    CASE
        WHEN AVG(EnergyPerUnit) =
             MIN(AVG(EnergyPerUnit)) OVER ()  THEN 'MOST EFFICIENT'
        WHEN AVG(EnergyPerUnit) =
             MAX(AVG(EnergyPerUnit)) OVER ()  THEN 'LEAST EFFICIENT'
        ELSE 'AVERAGE'
    END AS PlantStatus
FROM NIS_KPI
GROUP BY Plant;

--  Top 5 machines needing immediate action
SELECT
    MachineID,
    Plant,
    ROUND(AVG(EnergyPerUnit), 4)              AS AvgEnergyPerUnit,
    ROUND(AVG(EfficiencyScore), 4)            AS AvgEfficiencyScore,
    ROUND(AVG(DefectRate) * 100, 3)           AS AvgDefectRate_Pct,
    SUM(CASE WHEN EnergyConsumption > 358.2
             THEN 1 ELSE 0 END)               AS AnomalyCount,
    'Immediate Audit Required'                AS Action
FROM NIS_KPI
GROUP BY MachineID, Plant
ORDER BY AvgEnergyPerUnit DESC
LIMIT 5;


