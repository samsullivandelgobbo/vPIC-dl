#!/bin/bash
set -euo pipefail

echo "Installing dependencies for vPIC migration..."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "This script is designed for macOS. Please adapt for your OS."
    exit 1
fi

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

# Install system dependencies
echo "Installing system dependencies..."
brew install unixodbc
brew install postgresql@14

# Install Microsoft ODBC driver
echo "Installing Microsoft ODBC driver..."
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
brew update
brew install msodbcsql18
brew install mssql-tools18

# Set up Python virtual environment
echo "Setting up Python virtual environment..."
python -m venv .venv
source .venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install Python dependencies one by one with verbose output
echo "Installing Python dependencies..."
pip install pyodbc -v
pip install psycopg2-binary -v
pip install tqdm -v
pip install python-dotenv -v

echo "Installation completed!"
echo "You can now activate the virtual environment with: source .venv/bin/activate"
