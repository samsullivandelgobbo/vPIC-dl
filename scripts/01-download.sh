# ./scripts/download_vpic.sh
#!/usr/bin/env bash
set -euo pipefail

VPIC_PAGE_URL="https://vpic.nhtsa.dot.gov/downloads/"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-temp}"

mkdir -p "$DOWNLOAD_DIR"

echo "Fetching vPIC downloads page..."
content=$(curl -s "$VPIC_PAGE_URL")

# 1) Extract the filename. For example, vPICList_lite_2025_12.bak.zip
# We'll look for:  vPICList_lite_YYYY_MM.bak.zip

latest_filename=$(echo "$content" \
  | grep -oE 'vPICList_lite_[0-9]{4}_[0-9]{2}\.bak\.zip' \
  | sort -u \
  | tail -n 1)

if [ -z "$latest_filename" ]; then
  echo "ERROR: Could not find any .bak.zip link on $VPIC_PAGE_URL"
  exit 1
fi

# 2) Build the full download URL
latest_url="https://vpic.nhtsa.dot.gov/downloads/${latest_filename}"

echo "Latest link found: $latest_url"

# 3) Download the file
zipfile="${DOWNLOAD_DIR}/vpic.bak.zip"
echo "Downloading to $zipfile ..."
curl -L "$latest_url" -o "$zipfile"

# 4) Unzip
echo "Unzipping $zipfile ..."
unzip -o "$zipfile" -d "$DOWNLOAD_DIR"

echo "Contents in $DOWNLOAD_DIR:"
ls -l "$DOWNLOAD_DIR"
