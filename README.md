# vPIC Database Pipeline

A production-ready pipeline for downloading, processing, and optimizing the NHTSA vPIC (Vehicle Product Information Catalog) database for VIN decoding applications.

## 🚀 Quick Start

```bash
# Clone and setup
git clone <repository-url>
cd vpic-pipeline

# Run complete pipeline (downloads latest vPIC data and creates optimized database)
make sqlite-pipeline

# Find your optimized databases in temp/compressed/
ls -lh temp/compressed/
```

## 📋 Overview

This pipeline transforms the massive NHTSA vPIC database into optimized, compressed formats suitable for production VIN decoding applications:

- **Download**: Latest vPIC database from NHTSA (~180MB ZIP, ~1.1GB uncompressed)
- **Process**: Restore SQL Server backup and migrate to SQLite 
- **Optimize**: Remove unnecessary tables and data for VIN decoding (336MB → 63MB)
- **Compress**: Multiple compression formats (63MB → 12MB with xz)

## 🎯 Output Results

| Database Type | Uncompressed | gzip | bzip2 | xz | zstd |
|---------------|--------------|------|-------|----|----- |
| **Full** | 336MB | 92MB | 68MB | - | - |
| **Lite** (optimized) | 63MB | 20MB | 17MB | **12MB** | 15MB |

The **lite database** contains only essential tables for VIN decoding while maintaining 100% decoding accuracy.

## 🏗️ Architecture

```
vPIC API → SQL Server (Docker) → SQLite → Optimize → Compress → Production DB
```

### Key Components

- **Docker**: SQL Server container for .bak file restoration
- **Python**: Migration engine with type mapping and validation
- **SQLite**: Target database optimized for read-heavy VIN decoding
- **Bash Scripts**: Orchestration and optimization pipeline

## 📁 Project Structure

```
vpic-pipeline/
├── Makefile              # Main automation targets
├── docker-compose.yml    # SQL Server & PostgreSQL containers  
├── .env.example          # Environment configuration template
├── scripts/              # Pipeline scripts
│   ├── 01-download.sh    # Download latest vPIC data
│   ├── 02-restore.sh     # Restore SQL Server backup
│   ├── 03-verify.sh      # Verify database restoration
│   ├── 04-optimize.sh    # Remove unnecessary tables/data
│   └── 05-compress.sh    # Compress optimized database
├── src/                  # Python migration code
│   ├── migrate.py        # Main migration orchestrator
│   ├── database.py       # Database connection handlers
│   └── settings.py       # Configuration and type mappings
└── temp/                 # Working directory (ignored by git)
    ├── vpic.db           # Full SQLite database
    ├── vpic.lite.db      # Optimized database
    └── compressed/       # Final compressed outputs
```

## 🛠️ Installation

### Prerequisites

- **Docker** and **Docker Compose**
- **Python 3.8+**
- **Make**
- Standard Unix tools: `curl`, `unzip`, `gzip`, `bzip2`, `xz`, `sqlite3`

### Setup

```bash
# 1. Clone repository
git clone <repository-url>
cd vpic-pipeline

# 2. Copy environment template
cp .env.example .env

# 3. Install Python dependencies
make setup

# 4. Run complete pipeline
make sqlite-pipeline
```

## 🎮 Usage

### Full Pipeline (Recommended)

```bash
# Complete pipeline: download → restore → migrate → optimize → compress
make sqlite-pipeline
```

### Individual Steps

```bash
# Start containers
make start-containers

# Download latest vPIC data  
make download

# Restore to SQL Server
make restore

# Migrate to SQLite
make migrate-sqlite

# Optimize for VIN decoding
make optimize

# Compress database
make compress

# Clean up
make clean
```

### Database Outputs

After running the pipeline, you'll find:

```bash
temp/
├── vpic.db                                    # Full database (336MB)
├── vpic.lite.db                               # Optimized database (63MB)  
└── compressed/
    ├── vpic_lite_YYYYMMDD.db.gz              # 20MB - Most compatible
    ├── vpic_lite_YYYYMMDD.db.bz2             # 17MB - Good balance
    ├── vpic_lite_YYYYMMDD.db.xz              # 12MB - Best compression
    ├── vpic_lite_YYYYMMDD.db.zst             # 15MB - Fastest decompression
    ├── vpic_lite_YYYYMMDD_checksums.sha256   # Integrity verification
    └── vpic_lite_YYYYMMDD_info.json          # Release metadata
```

## ⚙️ Configuration

### Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
# Database Passwords
MSSQL_SA_PASSWORD=DevPassword123#
POSTGRES_PASSWORD=postgres

# Container Names  
SQL_CONTAINER=vpic-sql
PG_CONTAINER=vpic-postgres

# Directories
TEMP_DATA_DIR=temp

# Connection Settings
CONNECTION_TIMEOUT=30
```

### Optimization Settings

The optimization process keeps only essential tables for VIN decoding:

- **Core Tables**: Make, Model, Pattern, Element, VinSchema, Wmi
- **Plant Info**: Plant location and manufacturing data
- **Vehicle Specs**: Body style, engine, fuel type, drivetrain
- **Removed**: Safety features, specialized vehicles, detailed technical specs
