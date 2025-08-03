# ./scripts/download_vpic.sh
#!/usr/bin/env bash
set -euo pipefail

VPIC_PAGE_URL="https://vpic.nhtsa.dot.gov/api/"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-temp}"

mkdir -p "$DOWNLOAD_DIR"

echo "Fetching vPIC main API page..."
content=$(curl -s "$VPIC_PAGE_URL")

# 1) Extract the relative URL. For example, /api/vPICList_lite_2024_12.bak.zip
# We’ll look for:  /api/vPICList_lite_YYYY_MM.bak.zip

latest_relative_url=$(echo "$content" \
  | grep -oE '/api/vPICList_lite_[0-9]{4}_[0-9]{2}\.bak\.zip' \
  | head -n 1)

if [ -z "$latest_relative_url" ]; then
  echo "ERROR: Could not find any .bak.zip link on $VPIC_PAGE_URL"
  exit 1
fi

# 2) Prepend https://vpic.nhtsa.dot.gov to get a full download URL
latest_url="https://vpic.nhtsa.dot.gov${latest_relative_url}"

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
