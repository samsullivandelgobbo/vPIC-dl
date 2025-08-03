#!/bin/bash
set -euo pipefail

# Load environment variables if .env exists
if [ -f .env ]; then
    source .env
fi

# Variables with defaults
TEMP_DIR="${TEMP_DATA_DIR:-temp}"
DB_FILE="${TEMP_DIR}/vpic.lite.db"
FULL_DB_FILE="${TEMP_DIR}/vpic.db"
COMPRESSED_DIR="${TEMP_DIR}/compressed"
DATE_STAMP=$(date +%Y%m%d)

echo "Starting SQLite database compression..."

# Check if optimized database exists, fallback to full database
if [ -f "$DB_FILE" ]; then
    echo "Using optimized database: $DB_FILE"
elif [ -f "$FULL_DB_FILE" ]; then
    echo "Optimized database not found, using full database: $FULL_DB_FILE"
    DB_FILE="$FULL_DB_FILE"
else
    echo "Error: No SQLite database found at $DB_FILE or $FULL_DB_FILE"
    exit 1
fi

# Create compressed directory
mkdir -p "$COMPRESSED_DIR"

# Get original size
ORIGINAL_SIZE=$(du -h "$DB_FILE" | cut -f1)
echo "Original database size: $ORIGINAL_SIZE"

# Optimize the SQLite database first
echo "Optimizing SQLite database..."
sqlite3 "$DB_FILE" "VACUUM;"
sqlite3 "$DB_FILE" "PRAGMA optimize;"

# Get optimized size
OPTIMIZED_SIZE=$(du -h "$DB_FILE" | cut -f1)
echo "Optimized database size: $OPTIMIZED_SIZE"

# Compress with different methods and compare
echo "Compressing database with multiple algorithms..."

# Determine if we're compressing optimized or full database
DB_TYPE="full"
if [[ "$DB_FILE" == *"lite"* ]]; then
    DB_TYPE="lite"
fi

# Method 1: gzip (good compression, fast)
echo "Creating gzip compressed version..."
gzip -c -9 "$DB_FILE" > "${COMPRESSED_DIR}/vpic_${DB_TYPE}_${DATE_STAMP}.db.gz"
GZIP_SIZE=$(du -h "${COMPRESSED_DIR}/vpic_${DB_TYPE}_${DATE_STAMP}.db.gz" | cut -f1)

# Method 2: bzip2 (better compression, slower)
echo "Creating bzip2 compressed version..."
bzip2 -c -9 "$DB_FILE" > "${COMPRESSED_DIR}/vpic_${DB_TYPE}_${DATE_STAMP}.db.bz2"
BZIP2_SIZE=$(du -h "${COMPRESSED_DIR}/vpic_${DB_TYPE}_${DATE_STAMP}.db.bz2" | cut -f1)

# Method 3: xz (best compression, slowest) - use faster compression
echo "Creating xz compressed version..."
xz -c -6 "$DB_FILE" > "${COMPRESSED_DIR}/vpic_${DB_TYPE}_${DATE_STAMP}.db.xz"
XZ_SIZE=$(du -h "${COMPRESSED_DIR}/vpic_${DB_TYPE}_${DATE_STAMP}.db.xz" | cut -f1)

# Method 4: zstd (good compression, very fast)
if command -v zstd &> /dev/null; then
    echo "Creating zstd compressed version..."
    zstd -19 -c "$DB_FILE" > "${COMPRESSED_DIR}/vpic_${DB_TYPE}_${DATE_STAMP}.db.zst"
    ZSTD_SIZE=$(du -h "${COMPRESSED_DIR}/vpic_${DB_TYPE}_${DATE_STAMP}.db.zst" | cut -f1)
else
    echo "zstd not available, skipping..."
    ZSTD_SIZE="N/A"
fi

# Create checksums
echo "Generating checksums..."
cd "$COMPRESSED_DIR"
sha256sum *${DB_TYPE}_${DATE_STAMP}.db.* > "vpic_${DB_TYPE}_${DATE_STAMP}_checksums.sha256"
cd - > /dev/null

# Summary
echo ""
echo "=== Compression Results ==="
echo "Original size:     $ORIGINAL_SIZE"
echo "Optimized size:    $OPTIMIZED_SIZE"
echo "gzip (-9):         $GZIP_SIZE"
echo "bzip2 (-9):        $BZIP2_SIZE"
echo "xz (-9):           $XZ_SIZE"
echo "zstd (-19):        $ZSTD_SIZE"
echo ""
echo "Compressed files created in: $COMPRESSED_DIR"
echo "Checksums: ${COMPRESSED_DIR}/vpic_${DB_TYPE}_${DATE_STAMP}_checksums.sha256"

# Create a release info file
cat > "${COMPRESSED_DIR}/vpic_${DB_TYPE}_${DATE_STAMP}_info.json" << EOF
{
  "release_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "source_date": "$DATE_STAMP",
  "database_version": "vPIC ${DATE_STAMP}",
  "database_type": "${DB_TYPE}",
  "original_size_bytes": $(stat -f%z "$DB_FILE" 2>/dev/null || stat -c%s "$DB_FILE" 2>/dev/null || echo "0"),
  "optimized_size_bytes": $(stat -f%z "$DB_FILE" 2>/dev/null || stat -c%s "$DB_FILE" 2>/dev/null || echo "0"),
  "compression_formats": {
    "gzip": {
      "file": "vpic_${DATE_STAMP}.db.gz",
      "size_bytes": $(stat -f%z "${COMPRESSED_DIR}/vpic_${DATE_STAMP}.db.gz" 2>/dev/null || stat -c%s "${COMPRESSED_DIR}/vpic_${DATE_STAMP}.db.gz" 2>/dev/null || echo "0")
    },
    "bzip2": {
      "file": "vpic_${DATE_STAMP}.db.bz2", 
      "size_bytes": $(stat -f%z "${COMPRESSED_DIR}/vpic_${DATE_STAMP}.db.bz2" 2>/dev/null || stat -c%s "${COMPRESSED_DIR}/vpic_${DATE_STAMP}.db.bz2" 2>/dev/null || echo "0")
    },
    "xz": {
      "file": "vpic_${DATE_STAMP}.db.xz",
      "size_bytes": $(stat -f%z "${COMPRESSED_DIR}/vpic_${DATE_STAMP}.db.xz" 2>/dev/null || stat -c%s "${COMPRESSED_DIR}/vpic_${DATE_STAMP}.db.xz" 2>/dev/null || echo "0")
    }$(if [ "$ZSTD_SIZE" != "N/A" ]; then echo ",
    \"zstd\": {
      \"file\": \"vpic_${DATE_STAMP}.db.zst\",
      \"size_bytes\": $(stat -f%z "${COMPRESSED_DIR}/vpic_${DATE_STAMP}.db.zst" 2>/dev/null || stat -c%s "${COMPRESSED_DIR}/vpic_${DATE_STAMP}.db.zst" 2>/dev/null || echo "0")
    }"; fi)
  },
  "table_count": $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';"),
  "total_records": $(sqlite3 "$DB_FILE" "SELECT SUM(record_count) FROM (SELECT COUNT(*) as record_count FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%');"),
  "pipeline_version": "1.0.0"
}
EOF

echo "Release info: ${COMPRESSED_DIR}/vpic_${DATE_STAMP}_info.json"
echo "Compression complete!"