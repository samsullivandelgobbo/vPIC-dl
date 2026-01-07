#!/bin/bash

set -e

# Load environment variables if .env exists
if [ -f .env ]; then
    source .env
fi

# Variables with defaults
TEMP_DIR="${TEMP_DATA_DIR:-temp}"
SOURCE_DB="${TEMP_DIR}/vpic.db"
WORK_DB="${TEMP_DIR}/vpic.lite.db"
DATE_STAMP=$(date +%Y%m%d)

show_size() {
    local size=$(ls -lh "$WORK_DB" | awk '{print $5}')
    echo "Current database size: $size"
}

show_table_sizes() {
    echo -e "\nLargest tables:"
    sqlite3 "$WORK_DB" "
    SELECT 
        name as Table_Name,
        ROUND(SUM(pgsize)/1024.0/1024.0, 2) as Size_MB,
        CASE 
            WHEN name = 'Pattern' THEN (SELECT COUNT(*) FROM Pattern)
            WHEN name = 'Element' THEN (SELECT COUNT(*) FROM Element)
            WHEN name = 'VinSchema' THEN (SELECT COUNT(*) FROM VinSchema)
            WHEN name = 'Wmi' THEN (SELECT COUNT(*) FROM Wmi)
            ELSE NULL 
        END as Row_Count
    FROM dbstat 
    WHERE name NOT LIKE 'sqlite%'
    GROUP BY name 
    ORDER BY SUM(pgsize) DESC 
    LIMIT 5;"
}

run_sql() {
    local description=$1
    local sql=$2
    echo -e "\nRunning: $description..."
    sqlite3 "$WORK_DB" "$sql"
    show_size
    show_table_sizes
    echo "-------------------"
}

echo "Starting database optimization for minimal VIN decoding..."

# Check if source database exists
if [ ! -f "$SOURCE_DB" ]; then
    echo "Error: Source database not found at $SOURCE_DB"
    exit 1
fi

# Start fresh
if [ -f "$WORK_DB" ]; then
    rm "$WORK_DB"
fi

echo "Creating working copy of database..."
cp "$SOURCE_DB" "$WORK_DB"
show_size
show_table_sizes

# Phase 1: Remove the biggest space user that we don't use
run_sql "Dropping WMIYearValidChars table" "
DROP TABLE IF EXISTS WMIYearValidChars;
VACUUM;"

# Phase 2: Analyze Pattern table usage
run_sql "Analyzing Pattern table" "
SELECT e.Name as Element_Name,
       COUNT(*) as Pattern_Count,
       COUNT(DISTINCT p.Keys) as Unique_Patterns
FROM Pattern p
JOIN Element e ON p.ElementId = e.Id
GROUP BY e.Name
ORDER BY Pattern_Count DESC;"

# Phase 3: Keep patterns for useful elements
run_sql "Focusing Pattern table on valuable elements" "
DELETE FROM Pattern 
WHERE ElementId NOT IN (
    SELECT Id FROM Element 
    WHERE Name IN (
        -- Core VIN elements (MUST KEEP)
        'Model', 'Make', 'Series', 'Trim',
        -- Plant information (MUST KEEP)
        'Plant', 'Plant Country', 'Plant City', 'Plant State',
        -- Vehicle characteristics (MUST KEEP)
        'Body Class', 'Body Style', 'Doors',
        'DriveType', 'Engine Model', 'Engine Configuration',
        'Fuel Type - Secondary',
        'Fuel Type - Primary', 'Fuel Type', 'Transmission',
        -- Additional useful elements
        'Other Engine Info', 'Other Restraint System Info',
        'Turbo', 'Displacement (L)', 'Displacement (CC)',
        'Engine Number of Cylinders', 'Engine Manufacturer', 'Engine Power (KW)',
        'Gross Vehicle Weight Rating',
        'Gross Vehicle Weight Rating From',
        'Gross Vehicle Weight Rating To',
        'Brake System Type',
        'Battery Type', 'Battery Energy (kWh)', 'Charger Level',
        'Electric Range', 'Base Price (\$)', 'Trim Level'
    )
);"

# Phase 4: Remove orphaned patterns
run_sql "Removing orphaned patterns" "
DELETE FROM Pattern 
WHERE VinSchemaId NOT IN (
    SELECT VinSchemaId FROM Wmi_VinSchema
);"

# Phase 5: Optimize indexes
run_sql "Optimizing indexes" "
DROP INDEX IF EXISTS idx_pattern_keys;
CREATE INDEX IF NOT EXISTS idx_pattern_optimized ON Pattern(Keys, ElementId, VinSchemaId);
VACUUM;"

# Phase 6: Remove unused tables but keep essential ones
run_sql "Removing unused tables while keeping essential ones" "
-- Keep these tables (DO NOT DROP):
-- Pattern, Element, VinSchema, Wmi, Wmi_VinSchema
-- Make, Model, Make_Model
-- Series, Trim
-- Plant, Plant_Country, Plant_City, Plant_State
-- Body_Style, DriveType, Engine_Model, Engine_Configuration
-- FuelType, Transmission
-- Turbo, Displacement, Cylinders
-- Battery_Type, Charger_Level


-- Remove safety feature tables (not used in VIN decoding)
DROP TABLE IF EXISTS ABS;
DROP TABLE IF EXISTS AdaptiveCruiseControl;
DROP TABLE IF EXISTS AdaptiveDrivingBeam;
DROP TABLE IF EXISTS AirBagLocFront;
DROP TABLE IF EXISTS AirBagLocKnee;
DROP TABLE IF EXISTS AirBagLocations;
DROP TABLE IF EXISTS AutoBrake;
DROP TABLE IF EXISTS BlindSpotIntervention;
DROP TABLE IF EXISTS BlindSpotMonitoring;
DROP TABLE IF EXISTS DynamicBrakeSupport;
DROP TABLE IF EXISTS LaneDepartureWarning;
DROP TABLE IF EXISTS LaneKeepSystem;
DROP TABLE IF EXISTS ParkAssist;
DROP TABLE IF EXISTS RearCrossTrafficAlert;
DROP TABLE IF EXISTS SeatBeltsAll;
DROP TABLE IF EXISTS TPMS;

-- Remove specialized vehicle types we don't handle
DROP TABLE IF EXISTS BusFloorConfigType;
DROP TABLE IF EXISTS BusType;
DROP TABLE IF EXISTS CustomMotorcycleType;
DROP TABLE IF EXISTS MotorcycleChassisType;
DROP TABLE IF EXISTS MotorcycleSuspensionType;
DROP TABLE IF EXISTS TrailerBodyType;
DROP TABLE IF EXISTS TrailerType;

-- Remove redundant/unused schema tables
DROP TABLE IF EXISTS DEFS_Body;
DROP TABLE IF EXISTS DEFS_Make;
DROP TABLE IF EXISTS DEFS_Model;
DROP TABLE IF EXISTS VehicleSpecPattern;
DROP TABLE IF EXISTS VehicleSpecSchema;
DROP TABLE IF EXISTS VehicleSpecSchema_Model;
DROP TABLE IF EXISTS VehicleSpecSchema_Year;
DROP TABLE IF EXISTS VSpecSchemaPattern;

-- Remove misc unused tables
DROP TABLE IF EXISTS DecodingOutput;
DROP TABLE IF EXISTS DefaultValue;
DROP TABLE IF EXISTS DestinationMarket;
DROP TABLE IF EXISTS ErrorCode;
DROP TABLE IF EXISTS NonLandUse;
DROP TABLE IF EXISTS VinDescriptor;
DROP TABLE IF EXISTS VinException;
DROP TABLE IF EXISTS WMIYearValidChars_CacheExceptions;
VACUUM;"

echo -e "\nOptimization complete!"
show_size
show_table_sizes

echo -e "\nPattern distribution after optimization:"
sqlite3 "$WORK_DB" "
SELECT e.Name as Element_Name,
       COUNT(*) as Pattern_Count,
       COUNT(DISTINCT p.Keys) as Unique_Patterns
FROM Pattern p
JOIN Element e ON p.ElementId = e.Id
GROUP BY e.Name
ORDER BY Pattern_Count DESC;"

echo -e "\nFinal table count:"
sqlite3 "$WORK_DB" "SELECT COUNT(*) as remaining_tables FROM sqlite_master WHERE type='table';"

echo -e "\nOptimized database created: $WORK_DB"