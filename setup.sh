#!/bin/bash
set -euo pipefail

echo "Setting up vPIC migration environment..."

# Check if python3 is installed
if ! command -v python &> /dev/null; then
    echo "Python is required but not installed. Please install Python first."
    exit 1
fi

# Check if pip3 is installed
if ! command -v pip &> /dev/null; then
    echo "pip is required but not installed. Please install pip first."
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python -m venv venv
fi

# Activate virtual environment
source .venv/bin/activate

# Install requirements
echo "Installing Python dependencies..."
pip install -r requirements.txt

# Install ODBC driver for Mac
if [[ "$OSTYPE" == "darwin"* ]]; then

fi

echo "Setup completed successfully!"