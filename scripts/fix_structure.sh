#!/bin/bash
set -euo pipefail

echo "Creating package structure..."

# Create base package directory if it doesn't exist
mkdir -p vpic_migration/{config,utils,scripts}

# Create __init__.py files
touch vpic_migration/__init__.py
touch vpic_migration/config/__init__.py
touch vpic_migration/utils/__init__.py
touch vpic_migration/scripts/__init__.py

# Move files to their new locations
if [ -f "scripts/migrate.py" ]; then
    mv scripts/migrate.py vpic_migration/migrate.py
fi

if [ -d "scripts/utils" ]; then
    mv scripts/utils/* vpic_migration/utils/
fi

if [ -d "config" ]; then
    mv config/* vpic_migration/config/
fi

# Clean up empty directories
rm -rf scripts/utils config 2>/dev/null || true

echo "Package structure created!"
ls -R vpic_migration/ 