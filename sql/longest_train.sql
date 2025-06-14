-- Create and select the database
CREATE DATABASE IF NOT EXISTS train_route;
USE train_route;

-- View the data
SELECT * FROM train_route_2;

-- Remove duplicate rows based on key columns
WITH duplicates AS (
    SELECT *, 
           ROW_NUMBER() OVER (PARTITION BY `No.`, `Name`, `Type`, `Zone`) AS row_num
    FROM train_route_2
)
DELETE FROM train_route_2 
WHERE `No.` IN (
    SELECT `No.` FROM duplicates WHERE row_num > 1
);

-- Drop unnecessary columns
ALTER TABLE train_route_2 
    DROP COLUMN `Date From`,
    DROP COLUMN `Date To`,
    DROP COLUMN `Dep Days`;

-- Clean and convert 'distance' and 'Speed' columns
-- Remove trailing 'k' or text
UPDATE train_route_2 
SET distance = CASE 
    WHEN distance LIKE '%k%' THEN SUBSTRING_INDEX(distance, 'k', 1)
    ELSE distance 
END;

-- Update any known malformed rows (example for `No.` = 19036)
UPDATE train_route_2 
SET distance = SUBSTRING(distance, 1, 2)
WHERE `No.` = 19036;

-- Update speed values to extract numeric parts only
UPDATE train_route_2 
SET Speed = SUBSTRING(Speed, 1, 2);

-- Change data types for distance and speed to INT
ALTER TABLE train_route_2 
    MODIFY distance INT,
    MODIFY Speed INT;

-- Format and extract duration into hours and minutes
ALTER TABLE train_route_2 
    ADD COLUMN duration_1 TEXT AFTER duration,
    ADD COLUMN duration_2 TEXT AFTER duration_1;

-- Extract hours and minutes from duration string (e.g., "5h 30m")
UPDATE train_route_2 
SET duration_1 = SUBSTRING_INDEX(duration, 'h', 1);

UPDATE train_route_2 
SET duration_2 = SUBSTRING_INDEX(SUBSTRING_INDEX(duration, 'h', -1), 'm', 1);

-- Trim and convert to numeric
UPDATE train_route_2 
SET duration_2 = TRIM(duration_2);

-- Convert duration columns to DOUBLE
ALTER TABLE train_route_2 
    MODIFY duration_1 DOUBLE,
    MODIFY duration_2 DOUBLE;

-- Convert minutes to fraction of hours
UPDATE train_route_2 
SET duration_2 = duration_2 / 60;

-- Remove old duration column
ALTER TABLE train_route_2 
    DROP COLUMN duration;

-- Add new `duration` column to store total duration in hours
ALTER TABLE train_route_2 
    ADD COLUMN duration DOUBLE AFTER Arr;

-- Set new duration value
UPDATE train_route_2 
SET duration = duration_1 + duration_2;

-- Round the duration to nearest hour
UPDATE train_route_2 
SET duration = ROUND(duration);

-- Drop temporary columns
ALTER TABLE train_route_2 
    DROP COLUMN duration_1,
    DROP COLUMN duration_2;

-- Create a view for the final cleaned dataset
CREATE OR REPLACE VIEW `Longest Train route` AS
SELECT * FROM train_route_2;
select * from train_route_2 ;
-- TRAIN INSIGHTS

-- 1. Which train travels the shortest distance and has the fewest halts in its journey?
SELECT `No.`, `Name`, distance, halts
FROM train_route_2
WHERE distance = (
        SELECT MIN(distance)
        FROM train_route_2
    )
  AND halts = (
        SELECT MIN(halts)
        FROM train_route_2
        WHERE distance = (
            SELECT MIN(distance)
            FROM train_route_2
        )
    );

-- 2. Count of trains by type
SELECT `Type`, COUNT(*) AS Total_count
FROM train_route_2
GROUP BY `Type`
ORDER BY Total_count DESC;

-- 3. The fastest train(s) by speed
SELECT *
FROM train_route_2
WHERE speed = (SELECT MAX(speed) FROM train_route_2);

-- 4. Average speed of trains by type (e.g., Express, Superfast)
SELECT `Type`, AVG(speed) AS Average_speed
FROM train_route_2
GROUP BY `Type`
ORDER BY Average_speed DESC;

-- 5. Zone based analysis: Which zones operate the highest number of trains?
WITH data_1 AS (
    SELECT Zone, COUNT(*) AS Count_of_trains
    FROM train_route_2
    GROUP BY Zone
)
SELECT *
FROM data_1
WHERE Count_of_trains = (SELECT MAX(Count_of_trains) FROM data_1);

-- 6. Are Superfast trains always faster than Express trains?
WITH comparison AS (
    SELECT `Type`, AVG(speed) AS Average_speed
    FROM train_route_2
    GROUP BY `Type`
)
SELECT `Type`, Average_speed
FROM comparison
WHERE `Type` IN ('SF', 'Exp');

-- 7. Which trains have unusually high halts for their duration?
SELECT *
FROM train_route_2
WHERE halts = (SELECT MAX(halts) FROM train_route_2);

-- 8. Are there trains with similar distances but very different durations?
WITH duration_diff AS (
    SELECT 
        distance,
        MAX(duration) AS max_duration,
        MIN(duration) AS min_duration,
        MAX(duration) - MIN(duration) AS duration_range
    FROM train_route_2
    GROUP BY distance
    HAVING duration_range > 2 -- duration difference greater than 2 hours
)
SELECT t.*
FROM train_route_2 t
JOIN duration_diff d ON t.distance = d.distance
ORDER BY t.distance, t.duration;


