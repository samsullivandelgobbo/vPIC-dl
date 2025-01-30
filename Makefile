# Makefile
.PHONY: all clean setup install start-containers download restore migrate-pg migrate-sqlite verify backup export-pg test

# Variables
BACKUP_NAME := vpic_postgres_$(shell date +%Y%m%d_%H%M%S)
TEMP_DIR := temp_data
SQL_CONTAINER := sqltemp
PG_CONTAINER := pg_target
VENV := .venv
PYTHON := $(VENV)/bin/python
PIP := $(VENV)/bin/pip

# Default target
all: clean setup start-containers download restore migrate-pg verify backup

# Clean environment
clean:
	@echo "Cleaning environment..."
	docker-compose -f docker/docker-compose.yml down -v || true
	rm -rf $(VENV) *.egg-info dist build __pycache__ vpic_migration/__pycache__

# Setup Python virtual environment
$(VENV)/bin/activate: requirements.txt
	python -m venv $(VENV)
	$(PIP) install -U pip setuptools wheel
	$(PIP) install -r requirements.txt
	$(PYTHON) setup.py develop

# Setup environment
setup: $(VENV)/bin/activate

# Install package in development mode
install: setup
	$(PYTHON) setup.py develop

# Start Docker containers
start-containers:
	@echo "Starting containers..."
	docker-compose -f docker/docker-compose.yml up -d
	@echo "Waiting for containers to be ready..."
	sleep 20

# Download vPIC data
download:
	@echo "Downloading vPIC data..."
	./scripts/download_vpic.sh

# Restore SQL Server backup
restore:
	@echo "Restoring SQL Server backup..."
	./scripts/restore_backup.sh
	./scripts/verify_db.sh

# Migrate to PostgreSQL
migrate-pg: install
	@echo "Migrating to PostgreSQL..."
	TARGET_DB=postgres $(PYTHON) -m vpic_migration.migrate

# Migrate to SQLite
migrate-sqlite: install
	@echo "Migrating to SQLite..."
	TARGET_DB=sqlite $(PYTHON) -m vpic_migration.migrate

# Verify migration
verify-pg:
	@echo "Verifying migration..."
	@echo "SQL Server tables:"
	./scripts/verify_db.sh
	@echo "PostgreSQL tables:"
	docker exec $(PG_CONTAINER) psql -U postgres -d vpic -c "\dt+"

# Run tests
test: install
	@echo "Running tests..."
	$(PYTHON) -m pytest tests/

# Create backup
backup: export-pg

# Export PostgreSQL database
export-pg:
	@echo "Exporting PostgreSQL database..."
	mkdir -p $(TEMP_DIR)
	@echo "Creating schema-only backup..."
	docker exec $(PG_CONTAINER) pg_dump -U postgres -d vpic --schema-only > $(TEMP_DIR)/$(BACKUP_NAME)_schema.sql
	@echo "Creating data-only backup..."
	docker exec $(PG_CONTAINER) pg_dump -U postgres -d vpic --data-only > $(TEMP_DIR)/$(BACKUP_NAME)_data.sql
	@echo "Creating complete backup..."
	docker exec $(PG_CONTAINER) pg_dump -U postgres -d vpic -Fc > $(TEMP_DIR)/$(BACKUP_NAME).dump
	@echo "Backup files created in $(TEMP_DIR):"
	@ls -lh $(TEMP_DIR)/$(BACKUP_NAME)*

