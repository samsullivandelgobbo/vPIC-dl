# vPIC Database Migration Tool

A robust tool for downloading, migrating, and managing the NHTSA's Vehicle Product Information Catalog (vPIC) database across different database platforms (SQL Server, PostgreSQL, and SQLite).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

This tool facilitates the migration of the NHTSA's vPIC database, which contains comprehensive vehicle specification data, including:
- Vehicle Makes, Models, and Types
- Manufacturer Information
- Vehicle Specifications and Features
- WMI (World Manufacturer Identifier) Data
- VIN Decoder implementation

## Features

- 🚀 Automated download of the latest vPIC database backup
- 🔄 Migration support for multiple database platforms:
  - Microsoft SQL Server
  - PostgreSQL
  - SQLite
- ✅ Data integrity verification
- 📊 Progress tracking with detailed logging
- 🔧 Configurable settings and type mappings
- 🐳 Docker support for easy deployment

## Prerequisites

- Python 3.8 or higher
- Docker and Docker Compose
- Make (optional, but recommended)


## Quick Start

1. Clone the repository:
```
   git clone https://github.com/samsullivandelgobbo/vPIC-dl.git
   cd vpic-migration
```
2. Install dependencies:
   # On macOS
```
   ./install_deps.sh
```
   # On Windows / Linux
```
   python -m venv .venv
   .venv\Scripts\activate
   pip install -r requirements.txt
```

3. Start the containers:
```
   make start-containers
```

4. Run the migration:
```
  make download
   make restore
   make migrate-pg
   make migrate-sqlite
   make verify-pg
   make backup
```

   or
```
   make all
```
## Usage

### Basic Usage

The simplest way to use the tool is through the provided Makefile commands:

# Run all steps
```
make all
```
# Download latest vPIC data
```
make download
```
# Restore SQL Server backup
```
make restore
```
# Migrate to PostgreSQL
```
make migrate-pg
```
# Migrate to SQLite
```
make migrate-sqlite
```
# Verify migration
```
make verify
```
# Create backup
```
make backup
```

## Configuration

Configuration can be modified through environment variables or by editing vpic_migration/settings.py:
```python
SQL_SERVER = {
    "driver": "ODBC Driver 18 for SQL Server",
    "server": "localhost",
    "database": "vpic",
    "user": "SA",
    "password": "YourPassword",
    "trust_cert": "yes"
}
```

## Data Structure

The vPIC database contains numerous tables with vehicle-related information. Key tables include:

- Make: Vehicle manufacturers
- Model: Vehicle models
- VehicleType: Types of vehicles
- WMI: World Manufacturer Identifier information
- And many more...

For complete schema information, see [DATA_STRUCTURE.md](docs/DATA_STRUCTURE.md).
